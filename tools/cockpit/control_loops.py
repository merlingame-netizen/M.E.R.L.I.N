#!/usr/bin/env python3
"""Autonomous, free, iterative dev loops for the MERLIN cockpit.

Designed to run unattended (systemd timers on the VM) and stay 100% free. Each cycle is
idempotent, quota-friendly, and logs metrics to status/cockpit_loops.json so the cockpit
can show live loop state.

Subcommands:
  gen       generate N scenario cards via a backend, filter through the deterministic
            scenario_validator, append the accepted ones to an auto-corpus. Backends:
              template   grounded skeleton cards from lore_canon.json — ALWAYS works,
                         even on the bare VM (no LLM). The 24/7 heartbeat + structural corpus.
              ollama     POST to a local/tunnelled Ollama (OLLAMA_URL) for runtime cards.
              workers-ai POST to the Cloudflare Workers AI endpoint (WORKERS_AI_URL).
  validate  run the headless parse check + telemetry (best-effort) and log pass/fail.
  train     cadence gate: if the auto-corpus grew enough since last train, trigger Kaggle.
  status    print the loops state (for /api/loops).

Outputs (gitignored runtime):
  data/ai/training/auto_corpus.jsonl     accepted cards (mode-tagged)
  tools/autodev/status/cockpit_loops.json  metrics per loop
"""
from __future__ import annotations

import argparse
import json
import os
import random
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "lora"))
import scenario_validator as sv  # noqa: E402

CANON = ROOT / "data" / "ai" / "lore_canon.json"
CORPUS = ROOT / "data" / "ai" / "training" / "auto_corpus.jsonl"
LOOPS = ROOT / "tools" / "autodev" / "status" / "cockpit_loops.json"
TRAIN_THRESHOLD = int(os.environ.get("COCKPIT_TRAIN_THRESHOLD", "120"))


def _now():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def _load_json(p, d):
    try:
        return json.loads(Path(p).read_text(encoding="utf-8"))
    except Exception:
        return d


def _log_loop(name, patch: dict):
    data = _load_json(LOOPS, {})
    cur = data.get(name, {})
    cur.update(patch)
    cur["last"] = _now()
    cur["runs"] = cur.get("runs", 0) + 1
    data[name] = cur
    try:
        LOOPS.parent.mkdir(parents=True, exist_ok=True)
        LOOPS.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass
    return cur


# ── canon-grounded template backend (no LLM) ─────────────────────────────────
def _canon():
    return _load_json(CANON, {})


def _gen_template(canon, rng) -> dict:
    """A structurally-valid SKELETON card grounded in the canon (always passes the validator)."""
    sc = canon.get("scenario_constraints", {})
    vbf = sc.get("verbs_by_field") or {"neutre": ["parler", "accepter", "refuser"]}
    fields = [f for f in vbf if vbf[f]]
    factions = [f["id"] for f in canon.get("factions", [])] or ["druides", "anciens", "korrigans", "niamh", "ankou"]
    biomes = canon.get("biomes", [{"id": "foret_broceliande", "name": "Brocéliande", "mood": ""}])
    b = rng.choice(biomes)
    opts = []
    for _ in range(3):
        fld = rng.choice(fields)
        verb = rng.choice(vbf[fld])
        opts.append({"label": verb[:1].upper() + verb[1:], "verb": verb,
                     "primary_faction": rng.choice(factions + ["neutre"]),
                     "effects": [{"type": "ADD_REPUTATION", "faction": rng.choice(factions),
                                  "amount": rng.choice([3, 5, 8])}]})
    return {
        "card_id": "auto_" + format(rng.randrange(16**6), "06x"),
        "type": "NARRATIVE",
        "biome": b.get("id"),
        "summary": f"Près de {b.get('name','la forêt')}, un choix se présente au voyageur.",
        "pole": b.get("pole", "Liminal"),
        "options": opts,
        "branch_label": "trunk",
    }


# ── LLM backends ─────────────────────────────────────────────────────────────
def _http_json(url, payload, timeout=60, headers=None):
    h = {"content-type": "application/json"}
    if headers:
        h.update(headers)
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=h)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def _extract_card(text):
    import re
    try:
        return json.loads(text)
    except Exception:
        m = re.search(r"\{.*\}", text, re.S)
        if m:
            try:
                return json.loads(m.group(0))
            except Exception:
                return None
    return None


def _gen_ollama(canon, rng) -> dict | None:
    url = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434") + "/api/generate"
    biome = rng.choice(canon.get("biomes", [{"name": "Brocéliande"}]))["name"]
    prompt = ("Génère UNE carte de jeu narrative en JSON {text, options:[{label,verb,effects}]}. "
              f"Biome: {biome}. text: 2-4 phrases françaises (40-120 mots), ton druidique, sans mot moderne. "
              "Exactement 3 options, verbe à l'infinitif, effets ADD_REPUTATION (faction druides/anciens/korrigans/niamh/ankou, ±20).")
    try:
        out = _http_json(url, {"model": os.environ.get("OLLAMA_MODEL", "merlin-narrator"),
                               "prompt": prompt, "stream": False, "format": "json"})
        return _extract_card(out.get("response", ""))
    except Exception:
        return None


def _gen_workers_ai(canon, rng) -> dict | None:
    url = os.environ.get("WORKERS_AI_URL", "")
    if not url:
        return None
    biome = rng.choice(canon.get("biomes", [{"name": "Brocéliande"}]))["name"]
    headers = {}
    if os.environ.get("WORKERS_AI_TOKEN"):
        headers["x-gen-token"] = os.environ["WORKERS_AI_TOKEN"]
    try:
        out = _http_json(url, {"task": "scenario_card", "biome": biome}, headers=headers)
        return out.get("card") or _extract_card(json.dumps(out))
    except Exception:
        return None


BACKENDS = {"template": _gen_template, "ollama": _gen_ollama, "workers-ai": _gen_workers_ai}


def cmd_gen(args):
    canon = _canon()
    rng = random.Random()
    backend = args.backend if args.backend in BACKENDS else "template"
    gen = BACKENDS[backend]
    accepted, rejected, recent = 0, 0, []
    CORPUS.parent.mkdir(parents=True, exist_ok=True)
    with CORPUS.open("a", encoding="utf-8") as f:
        for _ in range(max(1, args.count)):
            card = gen(canon, rng)
            if backend != "template" and card is None:
                card = _gen_template(canon, rng)  # graceful fallback keeps the loop alive
                backend_used = "template(fallback)"
            else:
                backend_used = backend
            errs, _w = sv.validate_card(card, recent_texts=recent[-5:])
            if errs:
                rejected += 1
                continue
            body = card.get("text") or card.get("summary") or ""
            if body:
                recent.append(body)
            f.write(json.dumps({"card": card, "backend": backend_used, "ts": _now()}, ensure_ascii=False) + "\n")
            accepted += 1
    total = sum(1 for _ in CORPUS.open(encoding="utf-8")) if CORPUS.exists() else 0
    st = _log_loop("gen", {"backend": backend, "generated": args.count,
                           "accepted": accepted, "rejected": rejected, "corpus_total": total})
    print(json.dumps({"loop": "gen", **st}, ensure_ascii=False))
    return 0


def cmd_validate(args):
    res = {"parse": "skipped", "telemetry": "skipped"}
    for key, argv in (("parse", [sys.executable, "tools/cli.py", "godot", "validate_step0"]),
                      ("telemetry", [sys.executable, "tools/cli.py", "godot", "telemetry"])):
        try:
            p = subprocess.run(argv, cwd=str(ROOT), capture_output=True, text=True, timeout=180)
            res[key] = "ok" if p.returncode == 0 else f"fail({p.returncode})"
        except Exception as e:
            res[key] = f"unavailable: {str(e)[:60]}"
    st = _log_loop("validate", res)
    print(json.dumps({"loop": "validate", **st}, ensure_ascii=False))
    return 0


def cmd_train(args):
    total = sum(1 for _ in CORPUS.open(encoding="utf-8")) if CORPUS.exists() else 0
    state = _load_json(LOOPS, {}).get("train", {})
    last_at = state.get("corpus_at_last_train", 0)
    grown = total - last_at
    if grown < TRAIN_THRESHOLD:
        st = _log_loop("train", {"action": "skip", "corpus_total": total, "grown": grown,
                                 "threshold": TRAIN_THRESHOLD, "reason": "not enough new samples"})
        print(json.dumps({"loop": "train", **st}, ensure_ascii=False))
        return 0
    # cadence reached → trigger Kaggle (needs token; reported either way)
    argv = [sys.executable, "tools/lora/remote_kaggle_train.py", "submit",
            "--workspace", str(ROOT), "--brain", args.brain]
    try:
        p = subprocess.run(argv, cwd=str(ROOT), capture_output=True, text=True, timeout=300)
        action = "submitted" if p.returncode == 0 else f"submit_failed({p.returncode})"
        detail = (p.stdout or p.stderr)[-200:]
    except Exception as e:
        action, detail = "unavailable", str(e)[:120]
    st = _log_loop("train", {"action": action, "detail": detail, "corpus_total": total,
                             "corpus_at_last_train": total, "brain": args.brain})
    print(json.dumps({"loop": "train", **st}, ensure_ascii=False))
    return 0


def cmd_status(args):
    print(json.dumps(_load_json(LOOPS, {}), indent=2, ensure_ascii=False))
    return 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="MERLIN cockpit autonomous loops")
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("gen"); g.add_argument("--count", type=int, default=12); g.add_argument("--backend", default="template")
    sub.add_parser("validate")
    t = sub.add_parser("train"); t.add_argument("--brain", default="narrator")
    sub.add_parser("status")
    a = ap.parse_args(argv)
    return {"gen": cmd_gen, "validate": cmd_validate, "train": cmd_train, "status": cmd_status}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())

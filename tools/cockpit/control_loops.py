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
        # `think: False` : sans lui, la réponse revient vide (voir llm-ask.sh).
        out = _http_json(url, {"model": os.environ.get("OLLAMA_MODEL", "merlin-narrator"),
                               "prompt": prompt, "stream": False, "format": "json",
                               "think": False})
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


GOLD = ROOT / "data" / "ai" / "scenario_golden_prose.json"
REJECTS = ROOT / "data" / "ai" / "training" / "auto_rejects.jsonl"


def _card_schema(canon, verbs=None) -> dict:
    """Contrainte de DÉCODAGE (pas un vœu de prompt) : Ollama force ce schéma.

    `verbs` : la liste fermée du champ lexical tiré — passée en enum, le modèle
    ne PEUT PAS inventer un verbe (mesuré : sans enum, il recopie le nom du
    champ, « bluff » au lieu d'un infinitif)."""
    factions = [f.get("id", "") for f in canon.get("factions", [])] or \
        ["druides", "anciens", "korrigans", "niamh", "ankou"]
    return {
        "type": "object",
        "properties": {
            "text": {"type": "string"},
            "biome": {"type": "string"},
            "options": {
                "type": "array", "minItems": 3, "maxItems": 3,
                "items": {
                    "type": "object",
                    "properties": {
                        "label": {"type": "string"},
                        "verb": {"type": "string", **({"enum": verbs} if verbs else {})},
                        "effects": {
                            "type": "array", "maxItems": 3,
                            "items": {"type": "object", "properties": {
                                "type": {"type": "string"},
                                "faction": {"type": "string", "enum": factions},
                                "amount": {"type": "integer"}},
                                "required": ["type"]}},
                    },
                    "required": ["label", "verb"],
                },
            },
        },
        "required": ["text", "options"],
    }


def _gen_gemma(canon, rng, recent=None) -> dict | None:
    """Backend Gemma 4 local : schéma imposé au décodage + ancrage canon serré.

    Trois choix délibérés : (1) seul le champ lexical TIRÉ est fourni (~6-8
    verbes, pas 45 — le contexte est précieux à 8 tok/s de lecture) ; (2) deux
    exemples d'or humains donnent le ton ; (3) les derniers résumés acceptés
    sont cités en « ne répète pas » — exactement ce que le validateur mesure.
    """
    url = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434") + "/api/generate"
    model = os.environ.get("OLLAMA_MODEL", "gemma4:e4b-it-qat")
    sc = canon.get("scenario_constraints", {})
    vbf = {k: v for k, v in (sc.get("verbs_by_field") or {}).items() if v}
    field = rng.choice(list(vbf)) if vbf else "esprit"
    verbs = vbf.get(field, ["observer", "parler", "fuir"])[:8]
    biome = rng.choice(canon.get("biomes", [{"name": "Brocéliande"}]))
    gold_cards = list(_load_json(GOLD, {}).get("cards", {}).values())
    examples = ""
    for g in rng.sample(gold_cards, min(2, len(gold_cards))):
        opts = " / ".join(o.get("label", "") for o in g.get("options", [])[:3])
        examples += f"- « {g.get('summary', '')} » (options : {opts})\n"
    avoid = "\n".join(f"- {t[:90]}" for t in (recent or [])[-5:])
    prompt = (
        "Tu écris UNE carte narrative du jeu MERLIN (Bretagne celtique, ton druidique, "
        "français uniquement, aucun mot moderne).\n"
        f"Biome : {biome.get('name', '?')}. Champ lexical imposé : {field} — verbes "
        f"AUTORISÉS (un par option, à l'infinitif) : {', '.join(verbs)}.\n"
        "text : 2 à 4 phrases (40-120 mots), concret et sensoriel. Exactement 3 options.\n"
        "effects facultatifs : ADD_REPUTATION (faction druides/anciens/korrigans/niamh/"
        "ankou, -20..20), HEAL_LIFE (≤18), DAMAGE_LIFE (≤15).\n"
        f"Ton attendu (exemples humains) :\n{examples}"
        + (f"NE répète PAS ces situations récentes :\n{avoid}\n" if avoid else ""))
    try:
        out = _http_json(url, {"model": model, "prompt": prompt, "stream": False,
                               "format": _card_schema(canon, verbs),
                               # Gemma 4 raisonne : sans think=false la réponse revient vide.
                               "think": False,
                               "keep_alive": os.environ.get("OLLAMA_KEEP_ALIVE", "30m"),
                               "options": {"num_thread": int(os.environ.get("OLLAMA_NUM_THREAD", "4")),
                                           "num_ctx": 2048, "temperature": 0.85,
                                           "num_predict": 280}},
                         timeout=600)
        card = _extract_card(out.get("response", ""))
        if card is not None:
            # Le biome est IMPOSÉ par le tirage, jamais laissé au modèle : mesuré,
            # il y recopie des bouts de prompt (« Villages Celtes (ton druidique…) »).
            card["biome"] = biome.get("id", biome.get("name", ""))
        return card
    except Exception:
        return None


BACKENDS = {"template": _gen_template, "ollama": _gen_ollama,
            "workers-ai": _gen_workers_ai, "gemma": _gen_gemma}


def cmd_gen(args):
    canon = _canon()
    rng = random.Random()
    backend = args.backend if args.backend in BACKENDS else "template"
    gen = BACKENDS[backend]

    # Les backends LLM cèdent la place au jeu (doctrine « 24/7 sauf jeu ») et
    # exigent de la marge RAM — le template, lui, tourne toujours.
    if backend in ("gemma", "ollama"):
        try:
            sys.path.insert(0, str(ROOT / "tools" / "gd_agents"))
            import gates
            ok, why = gates.chain_allowed()
            if not ok:
                _log_loop("gen", {"backend": backend, "skipped": why})
                print(json.dumps({"loop": "gen", "skipped": why}, ensure_ascii=False))
                return
        except Exception:
            pass
        try:
            mem_kb = int(next(l for l in open("/proc/meminfo") if "MemAvailable" in l).split()[1])
            if mem_kb < 8 * 1024 * 1024:
                why = f"RAM insuffisante ({mem_kb // 1024} Mo)"
                _log_loop("gen", {"backend": backend, "skipped": why})
                print(json.dumps({"loop": "gen", "skipped": why}, ensure_ascii=False))
                return
        except Exception:
            pass

    deadline = time.time() + args.max_secs if args.max_secs else None
    accepted, rejected, recent = 0, 0, []
    CORPUS.parent.mkdir(parents=True, exist_ok=True)
    with CORPUS.open("a", encoding="utf-8") as f, REJECTS.open("a", encoding="utf-8") as rj:
        for _ in range(max(1, args.count)):
            if deadline and time.time() > deadline:
                break
            card = gen(canon, rng, recent[-5:]) if backend == "gemma" else gen(canon, rng)
            if backend != "template" and card is None:
                card = _gen_template(canon, rng)  # graceful fallback keeps the loop alive
                backend_used = "template(fallback)"
            else:
                backend_used = backend
            errs, warns = sv.validate_card(card, recent_texts=recent[-5:])
            if errs:
                rejected += 1
                # Le gisement : les rejets disent EXACTEMENT ce que le modèle rate.
                rj.write(json.dumps({"card": card, "errors": [str(e) for e in errs[:6]],
                                     "backend": backend_used, "ts": _now()},
                                    ensure_ascii=False) + "\n")
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
    g = sub.add_parser("gen"); g.add_argument("--count", type=int, default=12); g.add_argument("--backend", default="template"); g.add_argument("--max-secs", type=int, default=0, help="budget temps (0 = illimité) — à ~1 tok/s, boxer par le temps, pas par le nombre")
    sub.add_parser("validate")
    t = sub.add_parser("train"); t.add_argument("--brain", default="narrator")
    sub.add_parser("status")
    a = ap.parse_args(argv)
    return {"gen": cmd_gen, "validate": cmd_validate, "train": cmd_train, "status": cmd_status}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Routeur de difficulté : choisit le palier de modèle local pour une tâche d'agent.

Principe : une tâche ne DÉCLARE PAS sa difficulté, elle déclare un contrat
mesurable (forme de la sortie, budget de tokens, échéance). Le routeur applique
des portes déterministes. La difficulté réelle est constatée *a posteriori*,
par l'échec du validateur — d'où la porte G5 (escalade sur rejet).

Portes, dans l'ordre :
  G0  le tag existe-t-il vraiment dans /api/tags ?      sinon → palier inférieur
  G1  marge disque suffisante pour un pull ?            sinon → pas de pull
  G2  RAM disponible − RAM du modèle > marge du jeu ?   sinon → palier inférieur
  G3  le jeu tourne (port 5900) hors fenêtre nocturne ? alors → plafond + 2 threads
  G4  le budget temps tient-il l'échéance ?             sinon → palier inférieur
  G5  (appelé par le runner) sortie rejetée 2× ?        alors → un palier au-dessus

Usage :
    python3 tools/gd_agents/router.py --shape compose --out-tokens 250 --deadline 300
    → stdout : gemma4:e4b-it-qat        (une ligne, consommable par llm-ask.sh --model)
    → --explain : + une ligne JSON sur stderr {tier, tag, ctx, num_thread, reason, est_secs}

rc=0 si un palier est utilisable, rc=1 sinon (l'appelant DOIT avoir un repli).
Stdlib uniquement — ce module tourne sur la VM sans dépendances.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import socket
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TIERS_FILE = ROOT / "data" / "ai" / "config" / "model_tiers.json"
BENCH_FILE = Path.home() / ".cache" / "merlin-agents" / "llm-bench-results.json"
OLLAMA = os.environ.get("OLLAMA_HOST", "127.0.0.1:11434")
SHAPES = ("classify", "extract", "judge", "compose")


def _load_tiers() -> dict:
    return json.loads(TIERS_FILE.read_text(encoding="utf-8"))


def installed_tags() -> set[str]:
    """G0 — ce qu'Ollama a RÉELLEMENT. Jamais de supposition sur le registre."""
    try:
        with urllib.request.urlopen(f"http://{OLLAMA}/api/tags", timeout=5) as r:
            return {m.get("name", "") for m in json.load(r).get("models", [])}
    except Exception:
        return set()


def loaded_tags() -> set[str]:
    """Modèles DÉJÀ résidents. Un modèle froid coûte son chargement disque→RAM."""
    try:
        with urllib.request.urlopen(f"http://{OLLAMA}/api/ps", timeout=5) as r:
            return {m.get("name", "") for m in json.load(r).get("models", [])}
    except Exception:
        return set()


def mem_available_mb() -> int:
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            if line.startswith("MemAvailable:"):
                return int(line.split()[1]) // 1024
    except Exception:
        pass
    return 0


def disk_free_gb(path: Path | None = None) -> float:
    try:
        return shutil.disk_usage(str(path or Path.home())).free / 1e9
    except Exception:
        return 0.0


def game_running() -> bool:
    """Le jeu occupe le VNC : ses 4 cœurs ne doivent pas partir dans le LLM."""
    s = socket.socket()
    s.settimeout(0.4)
    try:
        return s.connect_ex(("127.0.0.1", 5900)) == 0
    finally:
        s.close()


def measured_speeds() -> dict:
    """Débits MESURÉS par a_llm_bench.sh. Absents → repli conservateur (jamais en dur)."""
    out = {}
    try:
        data = json.loads(BENCH_FILE.read_text(encoding="utf-8"))
        for row in data.get("rows", []):
            if row.get("tok_s"):
                out[row["model"]] = float(row["tok_s"])
        if data.get("prompt_eval_tok_s"):
            out["_prompt_eval"] = float(data["prompt_eval_tok_s"])
    except Exception:
        pass
    return out


def _is_night(gates: dict, now: dt.datetime | None = None) -> bool:
    h = (now or dt.datetime.now()).hour
    start, end = gates["night_start_hour"], gates["night_end_hour"]
    return start <= h < end if start < end else (h >= start or h < end)


def choose(shape: str, out_tokens: int, deadline_s: int,
           evidence_tokens: int = 600, escalate: int = 0) -> dict:
    """Rend {ok, tier, tag, ctx, num_thread, keep_alive, reason, est_secs, mapreduce}."""
    cfg = _load_tiers()
    gates, tiers = cfg["gates"], cfg["tiers"]
    have, warm = installed_tags(), loaded_tags()
    speeds = measured_speeds()
    # Chargement à froid : mesuré ~18 s/Go sur cette VM (e4b 6,1 Go → 189 s
    # réels contre 78 s de génération seule). Ignorer ce coût fait exploser
    # toutes les premières échéances de la nuit.
    cold_s_per_gb = cfg["gates"].get("cold_load_s_per_gb", 18.0)
    prompt_eval = speeds.get("_prompt_eval", cfg["prompt_eval_tok_s_fallback"])
    mem, free_gb, playing = mem_available_mb(), disk_free_gb(), game_running()
    night = _is_night(gates)
    num_thread = gates["night_num_thread"] if (night or not playing) else gates["day_num_thread"]

    # Plancher de capacité : la forme de la sortie décide du palier minimal.
    floor = next((i for i, t in enumerate(tiers) if shape in t["shapes_ok"]), 0)
    idx = min(len(tiers) - 1, floor + max(0, escalate))       # G5

    # G3 — plafond diurne : le jeu prime le jour.
    if playing and not night:
        cap = next((i for i, t in enumerate(tiers)
                    if t["name"] == gates["day_ceiling_tier"]), 0)
        if idx > cap and shape in tiers[cap]["shapes_ok"]:
            idx = cap

    notes: list[str] = []
    if playing:
        notes.append("jeu actif (5900)")
    if not speeds:
        notes.append("débits estimés")

    # Ordre d'essai : le plancher d'abord, puis les paliers PLUS capables (plus
    # lents mais aptes à la forme), et seulement en dernier recours ceux du
    # dessous — descendre sous le plancher, c'est sortir de la capacité requise.
    order = [idx] + list(range(idx + 1, len(tiers))) + list(range(idx - 1, -1, -1))

    for i in order:
        t = tiers[i]
        tag, rejected = t["tag"], None
        if tag not in have:
            rejected = "absent d'Ollama"
            if free_gb < (t["ram_mb"] / 1000.0) + gates["disk_margin_gb"]:   # G1
                rejected = f"absent, et disque insuffisant ({free_gb:.1f} Go)"
        elif mem and mem - t["ram_mb"] < gates["ram_margin_mb"]:             # G2
            rejected = f"RAM insuffisante ({mem} Mo dispo)"
        else:                                                                # G4
            tok_s = speeds.get(tag, t["tok_s_fallback"])
            cold = 0.0 if tag in warm else (t["ram_mb"] / 1000.0) * cold_s_per_gb
            est = cold + (evidence_tokens / prompt_eval
                          + out_tokens / tok_s) * gates["time_safety_factor"]
            if est > deadline_s:
                rejected = f"budget temps dépassé ({int(est)}s > {deadline_s}s)"
            else:
                return {"ok": True, "tier": t["name"], "tag": tag,
                        "ctx": min(t["ctx"], 8192), "num_thread": num_thread,
                        "keep_alive": "30m" if night else "5m",
                        "est_secs": int(est), "mapreduce": False,
                        "reason": " · ".join(notes + [f"{shape}→{t['name']}"])}
        notes.append(f"{t['name']} écarté : {rejected}")

    # Aucun palier ne tient l'échéance : un palier utilisable en map-reduce ?
    for t in tiers:
        if t["tag"] in have and (not mem or mem - t["ram_mb"] >= gates["ram_margin_mb"]):
            return {"ok": True, "tier": t["name"], "tag": t["tag"],
                    "ctx": min(t["ctx"], 8192), "num_thread": num_thread,
                    "keep_alive": "5m", "est_secs": deadline_s, "mapreduce": True,
                    "reason": " · ".join(notes + ["découpe map-reduce"])}
    return {"ok": False, "tier": None, "tag": None, "ctx": 0, "num_thread": num_thread,
            "keep_alive": "0", "est_secs": 0, "mapreduce": False,
            "reason": " · ".join(notes) or "aucun modèle utilisable"}


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Choisit le palier de modèle pour une tâche.")
    ap.add_argument("--shape", required=True, choices=SHAPES)
    ap.add_argument("--out-tokens", type=int, default=250)
    ap.add_argument("--deadline", type=int, default=300)
    ap.add_argument("--evidence-tokens", type=int, default=600)
    ap.add_argument("--escalate", type=int, default=0, help="G5 : niveaux d'escalade (max 1)")
    ap.add_argument("--explain", action="store_true", help="détail JSON sur stderr")
    a = ap.parse_args(argv)

    d = choose(a.shape, a.out_tokens, a.deadline, a.evidence_tokens, a.escalate)
    if a.explain:
        print(json.dumps(d, ensure_ascii=False), file=sys.stderr)
    if not d["ok"]:
        return 1
    print(d["tag"])
    return 0


if __name__ == "__main__":
    sys.exit(main())

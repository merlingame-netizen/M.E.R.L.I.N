#!/usr/bin/env python3
"""Compare narrator models for MERLIN — answers "does a 0.6B retain enough context?".

For each model, generate N cards via the cockpit gen backend, run them through the
deterministic scenario_validator, and score:
  pass_rate     share of cards with 0 hard errors (structural quality)
  warn_rate     avg warnings/card
  self_sim      mean pairwise Jaccard among card bodies (HIGH = repetition = context loss)
  distinct      unique bodies / total (LOW = the model loops -> poor retention)
A small/forgetful model shows up as low pass_rate AND high self_sim / low distinct.

Usage:
  python3 tools/lora/eval_models.py --models qwen3:0.6b,qwen3.5:2b --count 20 --backend ollama
  python3 tools/lora/eval_models.py --backend template --count 20     # harness self-test (no LLM)
Backends reuse tools/cockpit/control_loops.py (ollama|workers-ai|template).
"""
from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "lora"))
sys.path.insert(0, str(ROOT / "tools" / "cockpit"))
import scenario_validator as sv  # noqa: E402
import control_loops as cl       # noqa: E402


def _body(card: dict) -> str:
    return str(card.get("text") or card.get("summary") or "")


def _jaccard(a: str, b: str) -> float:
    return sv.jaccard(a, b)


def eval_model(model: str, backend: str, count: int) -> dict:
    canon = cl._canon()
    rng = random.Random(1234)
    gen = cl.BACKENDS.get(backend, cl._gen_template)
    if backend == "ollama" and model:
        os.environ["OLLAMA_MODEL"] = model
    passed, total_warn, bodies, errs_total, gen_fail = 0, 0, [], 0, 0
    t0 = time.time()
    for _ in range(count):
        card = gen(canon, rng)
        if card is None:
            gen_fail += 1
            continue
        e, w = sv.validate_card(card, recent_texts=bodies[-5:])
        errs_total += len(e)
        total_warn += len(w)
        if not e:
            passed += 1
        b = _body(card)
        if b:
            bodies.append(b)
    n = max(count - gen_fail, 1)
    # self-similarity: mean pairwise Jaccard among up to 30 bodies
    sample = bodies[:30]
    sims, pairs = 0.0, 0
    for i in range(len(sample)):
        for j in range(i + 1, len(sample)):
            sims += _jaccard(sample[i], sample[j])
            pairs += 1
    self_sim = round(sims / pairs, 3) if pairs else 0.0
    distinct = round(len(set(bodies)) / max(len(bodies), 1), 3)
    return {
        "model": model or backend, "backend": backend, "count": count, "gen_fail": gen_fail,
        "pass_rate": round(passed / n, 3), "warn_per_card": round(total_warn / n, 2),
        "err_per_card": round(errs_total / n, 2), "self_sim": self_sim, "distinct": distinct,
        "secs": round(time.time() - t0, 1),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--models", default="", help="comma-separated Ollama tags (ollama backend)")
    ap.add_argument("--backend", default="template", choices=["template", "ollama", "workers-ai"])
    ap.add_argument("--count", type=int, default=20)
    ap.add_argument("--out", default=str(ROOT / "output" / "model_eval.json"))
    a = ap.parse_args()
    models = [m.strip() for m in a.models.split(",") if m.strip()] or [""]
    rows = [eval_model(m, a.backend, a.count) for m in models]
    # report
    hdr = ["model", "pass_rate", "err_per_card", "warn_per_card", "self_sim", "distinct", "secs"]
    print(" | ".join(f"{h:>12}" for h in hdr))
    print("-" * (15 * len(hdr)))
    for r in rows:
        print(" | ".join(f"{str(r[h]):>12}" for h in hdr))
    print("\nGuide: pass_rate↑ good · self_sim↓ good (high=repetition/context-loss) · distinct↑ good")
    try:
        Path(a.out).parent.mkdir(parents=True, exist_ok=True)
        Path(a.out).write_text(json.dumps({"generated": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                           "rows": rows}, indent=2), encoding="utf-8")
        print(f"\nreport -> {a.out}")
    except Exception:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())

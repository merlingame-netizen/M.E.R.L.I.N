#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
beat_chain_stitcher.py - v7.7.31 (2026-05-18)

Phase 11 Sprint 11.5 - parallel LLM beat-transition stitcher.

The template-based `transition_prose` in v731 is functional but generic.
This module fires one small (~80 token) Gemma call per beat-transition in
parallel, producing 2-sentence narrative bridges that thread the previous
verb + anchor into the next beat's setup. In-game these calls would be
masked diegetically by the UI animation between cards; in the PoC they
add wall-time but in *parallel*, capped by `max_workers=2` to avoid
saturating the Ollama queue.

Library mode:
    from beat_chain_stitcher import stitch_transitions
    transitions = stitch_transitions(beats=[...], anchor="...")
    # -> { 1: "Le seuil murmure ...", 2: "...", ... }
    # key = beat_idx (0-based), value = LLM bridge text or "" on failure.

CLI mode (diagnostic):
    python tools/beat_chain_stitcher.py --beats ~/Downloads/v7.7.31.json

Pre-req:
    Ollama running with the narrator model loaded.

User instruction (verbatim): "continue" (Phase 11 Sprint 11.5 cf
docs/10_llm/PHASE_11_NARRATIVE_DEPTH_PLAN.md).

Caller graph: imported by `tools/simulate_human_run_v731.py` when
MERLIN_STITCHER=1. Standalone CLI also supported.
"""

from __future__ import annotations
import argparse
import json
import logging
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Optional
from urllib.error import URLError
from urllib.request import Request, urlopen

OLLAMA_BASE = "http://localhost:11434"
STITCHER_MODEL = os.environ.get("MERLIN_STITCHER_MODEL", "gemma4:e2b")
THINK_MODE = os.environ.get("MERLIN_THINK", "false").lower() == "true"
MAX_WORKERS = int(os.environ.get("MERLIN_STITCHER_WORKERS", "2"))
PER_CALL_TIMEOUT_S = int(os.environ.get("MERLIN_STITCHER_TIMEOUT", "30"))
NUM_PREDICT = int(os.environ.get("MERLIN_STITCHER_TOKENS", "100"))

log = logging.getLogger("beat_chain_stitcher")


# --- Ollama -----------------------------------------------------------------


def _ollama_generate(system: str, user: str, timeout: int) -> tuple[Optional[str], float]:
    """Phase 16 : retries on HTTP 500 (RAM-swap OOM on constrained hosts).
    The stitcher fires N parallel calls so swap pressure is highest here ;
    survives 2 transient 500s before degrading to fallback transition.
    """
    from urllib.error import HTTPError
    payload = {
        "model": STITCHER_MODEL,
        "system": system,
        "prompt": user,
        "stream": False,
        "think": THINK_MODE,
        "options": {"temperature": 0.65, "num_predict": NUM_PREDICT},
    }
    body = json.dumps(payload).encode("utf-8")
    req = Request(
        f"{OLLAMA_BASE}/api/generate",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    t0 = time.time()
    resp: Optional[dict] = None
    last_exc: Optional[Exception] = None
    for attempt in range(3):
        try:
            with urlopen(req, timeout=timeout) as r:
                resp = json.loads(r.read().decode("utf-8"))
            break
        except HTTPError as e:
            last_exc = e
            if e.code == 500 and attempt < 2:
                time.sleep(2.0 + 2.0 * attempt)
                continue
            log.warning("stitch HTTP %s (final): %s", e.code, e.reason)
            return None, time.time() - t0
        except (URLError, TimeoutError, Exception) as e:
            last_exc = e
            log.warning("stitch call failed: %s", e)
            return None, time.time() - t0
    if resp is None:
        log.warning("stitch exhausted retries: %s", last_exc)
        return None, time.time() - t0
    text = (resp.get("response", "") or "").strip()
    return text or None, time.time() - t0


# --- Prompt assembly --------------------------------------------------------


SYSTEM_PROMPT = (
    "Tu es un narrateur druidique pour MERLIN (Broceliande). "
    "Tu ecris une transition narrative ENTRE deux beats d'une marche. "
    "TON : direct, accessible, ancre dans le concret. "
    "Pas d'enigmes, pas de phrases mysterieuses. Parle de ce que le druide voit, sent, fait.\n\n"
    "REGLES STRICTES :\n"
    "1. Exactement 2 phrases courtes (15-20 mots chacune max), 2eme personne du singulier.\n"
    "2. La PREMIERE phrase rappelle EXPLICITEMENT le geste qui vient d'etre fait et son resultat "
    "(succes = le geste a marche / partial = il a marche a moitie / failure = il a echoue). "
    "Nomme l'action passee si possible.\n"
    "3. La DEUXIEME phrase decrit la nouvelle scene avec un detail concret (un objet, un personnage, "
    "un lieu) - SANS reveler les options du joueur.\n"
    "4. Verbes d'action concrets. Pas de 'la trame', 'le silence se fait', 'l'echo resonne'. "
    "Prefere 'tu marches', 'tu vois', 'l'eau coule', 'il te regarde'.\n"
    "5. Pas de markdown, pas de salutation, pas de question, pas d'action prescriptible. "
    "Reponse brute, 2 phrases claires."
)


def _build_user(prev_beat: dict, next_beat: dict, anchor: str, movement: int) -> str:
    prev_verb = prev_beat.get("chosen_option", {}).get("verb", "")
    prev_label = prev_beat.get("chosen_option", {}).get("label", "")
    prev_outcome = prev_beat.get("dc_result", "")
    prev_resolution = (prev_beat.get("resolution_prose", "") or "")[:200]
    next_summary = next_beat.get("summary", "")[:200]
    # Phase 16 Fix A : explicit echo material. Giving the LLM the concrete
    # resolution sentence + a canonical emotional hint makes cascading much
    # easier than reasoning from "failure" alone (audit showed 0/15 bridges
    # referenced the prior beat with the old prompt).
    outcome_hint = {
        "success": "Le geste a porte. Tu sens un aplomb tranquille.",
        "partial":  "Le geste s'est fait a moitie. Quelque chose reste suspendu.",
        "failure":  "Le geste s'est brise. Un gout d'amertume reste en bouche.",
    }.get(prev_outcome, "")
    lines = [
        f"Mouvement narratif courant : M{movement}",
        f"Tu venais de : {prev_label} ({prev_verb}) - issue {prev_outcome}.",
    ]
    if prev_resolution:
        lines.append(f"Echo de ce qui s'est passe : {prev_resolution}")
    if outcome_hint:
        lines.append(f"Echo emotionnel attendu : {outcome_hint}")
    lines.append(f"Maintenant tu arrives ici : {next_summary}")
    if anchor:
        lines.append(f"Motif d'ancrage du run : {anchor} (fais-le resonner en 1 mot si naturel).")
    lines.append("")
    lines.append(
        "Ecris EXACTEMENT 2 phrases : la premiere cascade l'echo, la seconde amene la nouvelle scene."
    )
    return "\n".join(lines)


# --- Public API -------------------------------------------------------------


def stitch_transitions(
    beats: list[dict],
    anchor: str = "",
    timings_out: Optional[list[float]] = None,
) -> dict[int, str]:
    """Run parallel LLM bridge generation for each beat-pair.

    `beats` is a list of dicts with at least `summary`, `chosen_option`,
    `dc_result`, `movement`. Returns a dict mapping the beat index (0-based)
    to the bridge text that should be shown BEFORE that beat.

    The first beat (index 0) is intentionally skipped - the intro already
    covers it.

    Failures degrade silently to an empty string for that beat; callers
    fall back to the template-based transition.
    """
    if len(beats) < 2:
        return {}

    work: list[tuple[int, dict, dict, int]] = []
    for i in range(1, len(beats)):
        prev = beats[i - 1]
        curr = beats[i]
        mvt = int(curr.get("movement", 1))
        work.append((i, prev, curr, mvt))

    results: dict[int, str] = {}
    durations: list[float] = []
    t_start = time.time()

    log.info(
        "Stitching %d transitions in parallel (workers=%d, model=%s)",
        len(work),
        MAX_WORKERS,
        STITCHER_MODEL,
    )

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {
            pool.submit(
                _ollama_generate,
                SYSTEM_PROMPT,
                _build_user(prev, curr, anchor, mvt),
                PER_CALL_TIMEOUT_S,
            ): idx
            for (idx, prev, curr, mvt) in work
        }
        for fut in as_completed(futures):
            idx = futures[fut]
            try:
                text, dur = fut.result()
            except Exception as e:
                log.warning("worker %d crashed: %s", idx, e)
                text, dur = None, 0.0
            durations.append(dur)
            results[idx] = (text or "").strip()
            log.info(
                "  bridge %d/%d ready (%.1fs, %d chars)",
                idx,
                len(beats) - 1,
                dur,
                len(text or ""),
            )

    elapsed = time.time() - t_start
    log.info(
        "Stitching done in %.1fs (sum durations %.1fs, parallel speedup %.1fx)",
        elapsed,
        sum(durations),
        sum(durations) / max(1e-6, elapsed),
    )
    if timings_out is not None:
        timings_out.extend(durations)
    return results


# --- CLI --------------------------------------------------------------------


def _cli_main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    parser = argparse.ArgumentParser(description="Phase 11.5 - stitch beat transitions")
    parser.add_argument(
        "--beats",
        type=Path,
        required=True,
        help="Path to a v7.7.31 JSON trace (uses cards_played + anchor_motif)",
    )
    parser.add_argument("--out", type=Path, default=None, help="Optional output JSON path")
    args = parser.parse_args()

    if not args.beats.exists():
        log.error("Beats file not found: %s", args.beats)
        return 1
    trace = json.loads(args.beats.read_text(encoding="utf-8"))
    cards = trace.get("cards_played", [])
    anchor = trace.get("anchor_motif") or trace.get("anchor_hint") or ""
    log.info("Loaded %d beats from %s, anchor=%r", len(cards), args.beats.name, anchor)

    durations: list[float] = []
    transitions = stitch_transitions(cards, anchor=anchor, timings_out=durations)

    print("\n=== Transitions ===")
    for idx in sorted(transitions.keys()):
        text = transitions[idx] or "(empty)"
        print(f"\n[beat {idx + 1}] {text}")

    out_path = args.out or Path.home() / "Downloads" / f"stitcher_smoke_{int(time.time())}.json"
    out_path.write_text(
        json.dumps(
            {
                "stitcher_model": STITCHER_MODEL,
                "max_workers": MAX_WORKERS,
                "n_transitions": len(transitions),
                "durations_s": durations,
                "transitions": {str(k): v for k, v in transitions.items()},
                "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    log.info("Wrote %s", out_path)
    return 0


if __name__ == "__main__":
    sys.exit(_cli_main())

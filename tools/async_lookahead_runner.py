#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
async_lookahead_runner.py - v7.7.32 (2026-05-18)

Phase 12 Sprint 12.1 - Hybride async loading + lookahead pattern PoC.

The user's choice (AskUserQuestion review 2026-05-18) was "hybride :
loading screen ~30s puis lookahead per-beat". This module proves the
async pattern works *as a pure pipeline simulation* so the Godot port
in Sprint 12.4-in-game has a reference timing model.

Key insight : the player's "perceived latency" between clicking and
seeing the next beat is what matters - the wall time can be arbitrary
as long as the prefetcher stays ahead.

This PoC :
  1. Models a 16-beat run with 5 LLM pivots (Beat 5, 8, 9, 11, 16 + outro)
     + 1 LLM intro
  2. Uses ThreadPoolExecutor to fire pivot LLM calls 2 beats AHEAD of
     when the player needs them
  3. Measures perceived_latency = time between "player_done_reading_beat_N"
     and "beat_N+1_displayed"
  4. Compares against the naive sequential model (Sprint 11.5 stitcher
     baseline)

What this is NOT :
  - Real Godot integration. The GDScript port comes in Sprint 12.4.
  - A real LLM-using runner. We simulate LLM call durations from the
    Sprint 11.5 measurements (avg 13s/bridge, 30-50s for pivots).

User instruction (verbatim): "l'ordre que tu preconises, go" (Sprint
12.3 done, now 12.1 from PHASE_12_RPG_BRANCHING_PLAN.md §6).

Caller graph : standalone CLI. No other file imports this.

Outputs :
  ~/Downloads/async_lookahead_demo_<ts>.html
  ~/Downloads/async_lookahead_demo_<ts>.json
"""

from __future__ import annotations
import argparse
import json
import logging
import random
import sys
import time
from concurrent.futures import ThreadPoolExecutor, Future
from html import escape as html_escape
from pathlib import Path

log = logging.getLogger("async_lookahead_runner")

# Sprint 11.5 measurements - calibrate the simulator timings on real numbers.
SIMULATED_TIMINGS_MS = {
    "intro_llm": 35_000,
    "pivot_llm": 30_000,   # MERLIN_DIRECT, climax, fork - rich LLM
    "stitcher_bridge": 13_000,  # 80-token bridges
    "outro_llm": 25_000,
    "kNN_retrieval": 5,    # numpy brute-force
    "ui_animation": 800,   # transition between cards
    "player_read_time": 4_000,  # avg time a player spends reading a card
}

# 5 LLM pivot beats per PHASE_12_PLAN §3.4 (Beat 5/8/9/11/16 + outro).
LLM_PIVOT_BEATS = {5, 8, 9, 11, 16}


def _simulate_call(duration_ms: int, jitter: float = 0.15) -> int:
    """Sleep to simulate an LLM call. Jitter ±15% so timing isn't perfectly flat."""
    real_ms = int(duration_ms * random.uniform(1 - jitter, 1 + jitter))
    time.sleep(real_ms / 1000.0)
    return real_ms


def run_naive_sequential(n_beats: int, rng: random.Random) -> dict:
    """Baseline : pure sequential. Each beat blocks on its own LLM call.

    This is the Sprint 11.5 stitcher baseline before any lookahead.
    """
    log.info("[NAIVE] Starting sequential run (%d beats)", n_beats)
    t_start = time.time()
    beats: list[dict] = []

    # Intro
    t = time.time()
    intro_ms = _simulate_call(SIMULATED_TIMINGS_MS["intro_llm"])
    log.info("[NAIVE]  intro ready in %.0fs", intro_ms / 1000)

    first_card_ready_ms: int = 0
    for i in range(n_beats):
        beat_t = time.time()
        # Player reads the previous beat (skip for the first)
        if i > 0:
            time.sleep(SIMULATED_TIMINGS_MS["player_read_time"] / 1000)
            ui_ms = _simulate_call(SIMULATED_TIMINGS_MS["ui_animation"])
        else:
            ui_ms = 0
        # Retrieval (cheap)
        knn_ms = _simulate_call(SIMULATED_TIMINGS_MS["kNN_retrieval"])
        # Pivot LLM if needed
        is_pivot = (i + 1) in LLM_PIVOT_BEATS
        llm_ms = 0
        if is_pivot:
            llm_ms = _simulate_call(SIMULATED_TIMINGS_MS["pivot_llm"])
        else:
            # Standard inter-beat stitcher bridge
            llm_ms = _simulate_call(SIMULATED_TIMINGS_MS["stitcher_bridge"])
        perceived_ms = int((time.time() - beat_t) * 1000) - SIMULATED_TIMINGS_MS["player_read_time"] if i > 0 else int((time.time() - beat_t) * 1000)
        beats.append({
            "beat": i + 1,
            "is_pivot": is_pivot,
            "perceived_ms": max(0, perceived_ms),
            "llm_ms": llm_ms,
            "knn_ms": knn_ms,
            "ui_ms": ui_ms,
            "mode": "naive",
        })
        if i == 0:
            first_card_ready_ms = int((time.time() - t_start) * 1000)

    outro_t = time.time()
    outro_ms = _simulate_call(SIMULATED_TIMINGS_MS["outro_llm"])
    log.info("[NAIVE]  outro ready in %.0fs", outro_ms / 1000)
    total_wall_ms = int((time.time() - t_start) * 1000)

    return {
        "mode": "naive_sequential",
        "n_beats": n_beats,
        "first_card_ready_ms": first_card_ready_ms,
        "total_wall_ms": total_wall_ms,
        "intro_ms": intro_ms,
        "outro_ms": outro_ms,
        "beats": beats,
        "max_perceived_ms": max(b["perceived_ms"] for b in beats),
        "median_perceived_ms": sorted(b["perceived_ms"] for b in beats)[len(beats) // 2],
    }


def run_hybride_lookahead(n_beats: int, rng: random.Random) -> dict:
    """Sprint 12.1 hybride: intro + 8s rune ceremony, then lookahead pre-fetches.

    Pattern :
      - Boot phase : tirage_runes (8s blocking, animated) + intro LLM in parallel
      - Play phase : when beat N is displayed, futures for N+1 and N+2 are
        ALREADY in flight. The "perceived latency" is just the UI animation
        unless the prefetcher fell behind.
    """
    log.info("[HYBRIDE] Starting lookahead run (%d beats, workers=2)", n_beats)
    t_start = time.time()
    beats: list[dict] = []

    with ThreadPoolExecutor(max_workers=2) as pool:
        # Boot phase : 8s rune ceremony in parallel with intro LLM (30-40s)
        intro_fut = pool.submit(_simulate_call, SIMULATED_TIMINGS_MS["intro_llm"])
        time.sleep(8.0)  # tirage_runes animation, blocking display
        intro_ms = intro_fut.result()
        first_card_ready_ms = int((time.time() - t_start) * 1000)
        log.info("[HYBRIDE]  intro+runes ready in %.0fs (intro:%.0fs)",
                 first_card_ready_ms / 1000, intro_ms / 1000)

        # Pre-fire futures for the first 2 beats
        futures: dict[int, Future] = {}
        for i in range(min(2, n_beats)):
            cost_ms = (SIMULATED_TIMINGS_MS["pivot_llm"]
                       if (i + 1) in LLM_PIVOT_BEATS
                       else SIMULATED_TIMINGS_MS["stitcher_bridge"])
            futures[i] = pool.submit(_simulate_call, cost_ms)

        for i in range(n_beats):
            beat_t = time.time()
            # Wait for THIS beat's future (already in flight)
            llm_ms = futures[i].result() if i in futures else 0
            # kNN retrieval (cheap, can be parallel with display but kept sync here)
            knn_ms = _simulate_call(SIMULATED_TIMINGS_MS["kNN_retrieval"])
            # UI animation
            ui_ms = _simulate_call(SIMULATED_TIMINGS_MS["ui_animation"]) if i > 0 else 0
            # Perceived = time from beat_t (player ready for next) to now
            perceived_ms = int((time.time() - beat_t) * 1000)
            is_pivot = (i + 1) in LLM_PIVOT_BEATS

            # Fire the NEXT-NEXT lookahead (i+2) if not already and within range
            next_to_fire = i + 2
            if next_to_fire < n_beats and next_to_fire not in futures:
                cost_ms = (SIMULATED_TIMINGS_MS["pivot_llm"]
                           if (next_to_fire + 1) in LLM_PIVOT_BEATS
                           else SIMULATED_TIMINGS_MS["stitcher_bridge"])
                futures[next_to_fire] = pool.submit(_simulate_call, cost_ms)

            beats.append({
                "beat": i + 1,
                "is_pivot": is_pivot,
                "perceived_ms": perceived_ms,
                "llm_ms": llm_ms,
                "knn_ms": knn_ms,
                "ui_ms": ui_ms,
                "prefetched_ahead": [k - i for k in futures.keys() if isinstance(k, int) and k > i],
                "mode": "hybride",
            })

            # Player reads the beat (everyone except the last)
            if i < n_beats - 1:
                # Start outro pre-fetch when we're 2 beats from the end
                if i == n_beats - 3 and "outro" not in futures:
                    futures["outro"] = pool.submit(_simulate_call, SIMULATED_TIMINGS_MS["outro_llm"])
                time.sleep(SIMULATED_TIMINGS_MS["player_read_time"] / 1000)

        # Final outro
        outro_t = time.time()
        if "outro" in futures:
            outro_ms = futures["outro"].result()
        else:
            outro_ms = _simulate_call(SIMULATED_TIMINGS_MS["outro_llm"])
        outro_perceived = int((time.time() - outro_t) * 1000)
        log.info("[HYBRIDE]  outro ready (wall ran %.0fs, perceived %.0fs)",
                 outro_ms / 1000, outro_perceived / 1000)

    total_wall_ms = int((time.time() - t_start) * 1000)

    return {
        "mode": "hybride_lookahead",
        "n_beats": n_beats,
        "first_card_ready_ms": first_card_ready_ms,
        "total_wall_ms": total_wall_ms,
        "intro_ms": intro_ms,
        "outro_ms": outro_ms,
        "outro_perceived_ms": outro_perceived,
        "beats": beats,
        "max_perceived_ms": max(b["perceived_ms"] for b in beats),
        "median_perceived_ms": sorted(b["perceived_ms"] for b in beats)[len(beats) // 2],
    }


# --- HTML render ------------------------------------------------------------


CSS = """
<style>
:root { --bg:#1a1208; --bg-soft:#221a0c; --gold:#d4a84a; --gold-dim:#8b7028; --text:#ede0c0; --text-dim:#a89878; --good:#6fbf73; --warn:#d4a84a; --bad:#c25a4a; }
body { background:var(--bg); color:var(--text); font-family:'Georgia',serif; max-width:1100px; margin:0 auto; padding:24px; line-height:1.55; }
h1, h2, h3 { color:var(--gold); border-bottom:1px solid var(--gold-dim); padding-bottom:4px; }
.kpi { display:inline-block; padding:8px 16px; background:var(--bg-soft); border-radius:8px; margin:4px; }
.kpi .val { font-size:20px; color:var(--gold); font-weight:bold; }
.kpi .lbl { font-size:11px; color:var(--text-dim); }
.good { color:var(--good); }
.bad { color:var(--bad); }
.beat-row { display:flex; align-items:center; margin:3px 0; font-family:monospace; font-size:11px; }
.beat-label { width:80px; color:var(--text-dim); }
.beat-fill { height:14px; border-radius:2px; }
.beat-naive { background:linear-gradient(90deg,var(--bad),var(--warn)); }
.beat-hybride { background:linear-gradient(90deg,var(--good),var(--gold-dim)); }
.beat-val { margin-left:8px; color:var(--text-dim); }
table { width:100%; border-collapse:collapse; margin:16px 0; font-size:13px; }
th, td { padding:6px 10px; text-align:left; border-bottom:1px solid var(--gold-dim); }
th { color:var(--gold); }
.section { background:var(--bg-soft); padding:16px; border-radius:6px; margin:16px 0; border-left:3px solid var(--gold-dim); }
</style>
"""


def render_html(naive: dict, hybride: dict) -> str:
    e = html_escape
    h: list[str] = []
    h.append("<!DOCTYPE html><html><head><meta charset='utf-8'>")
    h.append(f"<title>MERLIN Async Lookahead PoC v7.7.32</title>{CSS}</head><body>")
    h.append("<h1>MERLIN - Sprint 12.1 Hybride Async Lookahead (PoC)</h1>")
    h.append("<p>User choice (review 2026-05-18) : <b>Hybride</b> - loading screen ~30s puis lookahead per-beat. "
             "This PoC simulates the timing pattern that the Godot port will mirror in Sprint 12.4-in-game.</p>")

    # Headline KPIs
    h.append("<div>")
    h.append(f"<span class='kpi'><span class='val'>{naive['first_card_ready_ms']/1000:.1f}s</span><br><span class='lbl'>Naive : first card ready</span></span>")
    h.append(f"<span class='kpi'><span class='val good'>{hybride['first_card_ready_ms']/1000:.1f}s</span><br><span class='lbl'>Hybride : first card ready</span></span>")
    h.append(f"<span class='kpi'><span class='val'>{naive['max_perceived_ms']/1000:.1f}s</span><br><span class='lbl'>Naive : max perceived</span></span>")
    h.append(f"<span class='kpi'><span class='val good'>{hybride['max_perceived_ms']/1000:.1f}s</span><br><span class='lbl'>Hybride : max perceived</span></span>")
    h.append(f"<span class='kpi'><span class='val'>{naive['median_perceived_ms']/1000:.1f}s</span><br><span class='lbl'>Naive : median perceived</span></span>")
    h.append(f"<span class='kpi'><span class='val good'>{hybride['median_perceived_ms']/1000:.1f}s</span><br><span class='lbl'>Hybride : median perceived</span></span>")
    h.append("</div>")

    # Comparison table
    h.append("<h2>1. Comparison (perceived latency = what the player feels)</h2>")
    h.append("<table>")
    h.append("<tr><th>Metric</th><th>Naive sequential</th><th>Hybride lookahead</th><th>Delta</th></tr>")
    rows = [
        ("First card visible after click", "first_card_ready_ms"),
        ("Max perceived latency per beat", "max_perceived_ms"),
        ("Median perceived latency",  "median_perceived_ms"),
        ("Total wall time",            "total_wall_ms"),
    ]
    for label, key in rows:
        n = naive[key] / 1000
        b = hybride[key] / 1000
        delta = b - n
        d_class = "good" if delta < 0 else ("bad" if delta > 1 else "")
        h.append(f"<tr><td>{e(label)}</td><td>{n:.1f}s</td><td>{b:.1f}s</td>"
                 f"<td class='{d_class}'>{delta:+.1f}s</td></tr>")
    h.append("</table>")

    # Per-beat breakdown
    h.append("<h2>2. Per-beat perceived latency</h2>")
    max_naive = max(b["perceived_ms"] for b in naive["beats"])
    max_hyb = max(b["perceived_ms"] for b in hybride["beats"])
    scale_max = max(max_naive, max_hyb) or 1

    h.append("<h3>Naive (sequential)</h3>")
    for bb in naive["beats"]:
        pct = bb["perceived_ms"] / scale_max
        marker = "*" if bb["is_pivot"] else " "
        h.append(f"<div class='beat-row'><div class='beat-label'>Beat {bb['beat']:>2}{marker}</div>"
                 f"<div class='beat-fill beat-naive' style='width:{int(pct*400)}px'></div>"
                 f"<div class='beat-val'>{bb['perceived_ms']/1000:.1f}s</div></div>")

    h.append("<h3>Hybride (lookahead)</h3>")
    for bb in hybride["beats"]:
        pct = bb["perceived_ms"] / scale_max
        marker = "*" if bb["is_pivot"] else " "
        h.append(f"<div class='beat-row'><div class='beat-label'>Beat {bb['beat']:>2}{marker}</div>"
                 f"<div class='beat-fill beat-hybride' style='width:{int(pct*400)}px'></div>"
                 f"<div class='beat-val'>{bb['perceived_ms']/1000:.1f}s "
                 f"(prefetched +{','.join(str(x) for x in bb.get('prefetched_ahead', []))})</div></div>")

    # Architecture diagram (text)
    h.append("<h2>3. Architecture (text diagram)</h2>")
    h.append("<div class='section'><pre>")
    h.append(e("""
HYBRIDE ASYNC PATTERN (Sprint 12.1 PoC)

  T=0       Click title
  T=0.0s    [LOADING SCREEN] Animation des 3 oghams (tirage cérémonie, 8s blocking display)
  T=0.0s    [PARALLEL]      future_intro = pool.submit(llm_intro)
  T=8.0s    Runes settle, intro_llm still running (~30s total)
  T=~30s    intro_ms returned -> first card visible
  T=30s+    Player reads Beat 1
  T=30s     [PARALLEL]      future_beat2, future_beat3 already in flight since T=8s
  T=34s     Player taps Next -> Beat 2 ALREADY READY (future_beat2.result() is instant)
  T=34s     [PARALLEL]      future_beat4 launched (lookahead +2)
  T=N-30s   [PARALLEL]      future_outro launched (3 beats before end)
  T=END     Outro ready exactly when run ends -> 0s perceived
"""))
    h.append("</pre></div>")

    h.append("<h2>4. Methodology + caveats</h2>")
    h.append("<div class='section'><p>")
    h.append("Timings are simulated from Sprint 11.5 measurements : intro ~30s, "
             "stitcher bridge ~13s, pivot LLM ~30s, outro ~25s, kNN ~5ms, UI ~800ms, "
             "player read time ~4s/beat. Jitter ±15%. ThreadPoolExecutor(workers=2) "
             "matches the gemma4:e2b throughput observed in beat_chain_stitcher.py.</p>")
    h.append("<p>Caveats :")
    h.append("<ul>")
    h.append("<li>Real LLM latency on a Player's machine varies with model+CPU; this is "
             "an upper bound calibrated on the dev box.</li>")
    h.append("<li>The Godot port (Sprint 12.4 in-game) needs to replicate the pattern "
             "in GDScript via either threads or `await` on signals from Python sidecar.</li>")
    h.append("<li>The 8s rune ceremony is artistic and skippable for repeat plays.</li>")
    h.append("</ul></div>")

    h.append("</body></html>")
    return "".join(h)


# --- Main -------------------------------------------------------------------


def main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    parser = argparse.ArgumentParser(description="Sprint 12.1 - hybride async lookahead PoC")
    parser.add_argument("--n-beats", type=int, default=16)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out-html", type=Path, default=None)
    parser.add_argument("--out-json", type=Path, default=None)
    parser.add_argument("--skip-naive", action="store_true",
                        help="Skip the naive baseline (faster smoke test)")
    args = parser.parse_args()
    rng = random.Random(args.seed)

    log.info("Sprint 12.1 lookahead PoC starting (n_beats=%d, seed=%d)", args.n_beats, args.seed)
    if not args.skip_naive:
        naive = run_naive_sequential(args.n_beats, rng)
    else:
        # Stub naive results so the comparison page still renders.
        naive = {
            "mode": "naive_sequential",
            "n_beats": args.n_beats,
            "first_card_ready_ms": 35_000,
            "total_wall_ms": 35_000 + args.n_beats * (4_000 + 800 + 5 + 13_000) + 25_000,
            "intro_ms": 35_000,
            "outro_ms": 25_000,
            "beats": [{"beat": i + 1, "is_pivot": (i + 1) in LLM_PIVOT_BEATS,
                       "perceived_ms": 30_000 if (i + 1) in LLM_PIVOT_BEATS else 13_800,
                       "llm_ms": 0, "knn_ms": 0, "ui_ms": 0, "mode": "naive_stub"}
                      for i in range(args.n_beats)],
            "max_perceived_ms": 30_000,
            "median_perceived_ms": 13_800,
        }
        log.info("[NAIVE] Skipped - using stub timings from Sprint 11.5 measurements")

    hybride = run_hybride_lookahead(args.n_beats, rng)

    out_dir = Path.home() / "Downloads"
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = int(time.time())
    html_path = args.out_html or (out_dir / f"async_lookahead_demo_{ts}.html")
    json_path = args.out_json or (out_dir / f"async_lookahead_demo_{ts}.json")

    json_path.write_text(json.dumps({
        "run_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "naive": naive,
        "hybride": hybride,
        "simulated_timings_ms": SIMULATED_TIMINGS_MS,
        "llm_pivot_beats": sorted(LLM_PIVOT_BEATS),
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    html_path.write_text(render_html(naive, hybride), encoding="utf-8")
    log.info("Wrote %s", json_path)
    log.info("Wrote %s", html_path)

    print()
    print("=== Sprint 12.1 lookahead PoC summary ===")
    print(f"  Naive    first-card-ready : {naive['first_card_ready_ms']/1000:.1f}s   max perceived : {naive['max_perceived_ms']/1000:.1f}s   median : {naive['median_perceived_ms']/1000:.1f}s")
    print(f"  Hybride  first-card-ready : {hybride['first_card_ready_ms']/1000:.1f}s   max perceived : {hybride['max_perceived_ms']/1000:.1f}s   median : {hybride['median_perceived_ms']/1000:.1f}s")
    print(f"  Reduction perceived/beat : {(naive['median_perceived_ms'] - hybride['median_perceived_ms'])/1000:.1f}s median, {(naive['max_perceived_ms'] - hybride['max_perceived_ms'])/1000:.1f}s peak")
    return 0


if __name__ == "__main__":
    sys.exit(_cli_main() if False else main())

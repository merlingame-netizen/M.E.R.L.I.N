#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
montecarlo_balance.py - v7.7.32 (2026-05-18)

Phase 12 Sprint 12.5 - Monte-Carlo balance harness.

Runs N simulated MERLIN runs (no LLM calls) across K agent strategies,
aggregates the outcome distributions, and produces an HTML balance report.

Strategies modeled:
  - greedy        : always pick the [Confiant] option (maximises success)
  - balanced      : current v731 agent (signal + balance bonus + jitter)
  - random        : uniform pick among non-gated options
  - trait_focused : prefer options with rich gated_on/tags (long-game)
  - cross_pole    : prefer options whose dc_against.pole != current dominant pole

Outputs:
  ~/Downloads/montecarlo_balance_<ts>.html
  ~/Downloads/montecarlo_balance_<ts>.json

Pre-req:
  python tools/embed_reference_cards.py   # once
  python tools/dedup_and_expand_pool.py   # once
  No Ollama runtime needed - the harness skips intro/outro/stitcher LLM
  calls deliberately to make 1000 runs tractable (~3-4 min total).

Run example:
  python tools/montecarlo_balance.py --runs 250 --strategies greedy,balanced,random

Caller graph: standalone CLI - no other file imports this module.
"""

from __future__ import annotations
import argparse
import json
import logging
import random
import sys
import time
from collections import Counter
from html import escape as html_escape
from pathlib import Path
from typing import Callable

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cards_rag import CardsRAG, CardHit  # noqa: E402
from simulate_human_run_v731 import (  # noqa: E402
    apply_effects,
    card_options,
    derive_effects_from_dc,
    estimate_dc_signal,
    load_v2_pool,
    option_is_gated,
    resolve_dc,
)

ROOT = Path(__file__).resolve().parent.parent
SCENARIOS_PATH = ROOT / "data" / "ai" / "scenarios_reference_broceliande.json"

log = logging.getLogger("montecarlo_balance")


# --- Strategies -------------------------------------------------------------


Strategy = Callable[[list[dict], dict, random.Random], tuple[int, dict]]


def strategy_greedy(options: list[dict], state: dict, rng: random.Random) -> tuple[int, dict]:
    """Always pick the most-Confiant option (or first non-gated)."""
    pool = [(i, o) for i, o in enumerate(options) if not option_is_gated(o, state)[0]]
    if not pool:
        return 0, options[0]
    scored = []
    for i, o in pool:
        sig = estimate_dc_signal(o, state)
        scored.append((4 if sig == "Confiant" else 2 if sig == "Risque" else 0, i, o))
    scored.sort(key=lambda x: -x[0])
    _, i, o = scored[0]
    return i, o


def strategy_balanced(options: list[dict], state: dict, rng: random.Random) -> tuple[int, dict]:
    """Current v731 agent: signal score + faction balance bonus + rng jitter."""
    rep = state.get("faction_rep", {})
    scored = []
    for i, opt in enumerate(options):
        locked, _ = option_is_gated(opt, state)
        if locked:
            continue
        faction = opt.get("primary_faction", "")
        sig = estimate_dc_signal(opt, state)
        sig_s = {"Confiant": 2.0, "Risque": 1.0, "Eprouve": -0.5}.get(sig, 0.5)
        balance = max(0, 30 - rep.get(faction, 0)) / 30.0
        scored.append((sig_s + balance + rng.uniform(0, 0.3), i, opt))
    if not scored:
        return 0, options[0]
    scored.sort(key=lambda x: -x[0])
    _, i, o = scored[0]
    return i, o


def strategy_random(options: list[dict], state: dict, rng: random.Random) -> tuple[int, dict]:
    """Uniform pick among non-gated options."""
    pool = [(i, o) for i, o in enumerate(options) if not option_is_gated(o, state)[0]]
    if not pool:
        return 0, options[0]
    i, o = rng.choice(pool)
    return i, o


def strategy_trait_focused(options: list[dict], state: dict, rng: random.Random) -> tuple[int, dict]:
    """Prefer options that grant ADD_TAG (long-game accumulation)."""
    rep = state.get("faction_rep", {})
    scored = []
    for i, opt in enumerate(options):
        locked, _ = option_is_gated(opt, state)
        if locked:
            continue
        tag_potential = sum(
            1
            for outcome in ("success_effects", "partial_effects", "failure_effects")
            for eff in (opt.get(outcome) or [])
            if str(eff).startswith("ADD_TAG")
        )
        sig = estimate_dc_signal(opt, state)
        sig_s = {"Confiant": 2.0, "Risque": 1.0, "Eprouve": -0.3}.get(sig, 0.5)
        scored.append((tag_potential * 1.5 + sig_s + rng.uniform(0, 0.2), i, opt))
    if not scored:
        return 0, options[0]
    scored.sort(key=lambda x: -x[0])
    _, i, o = scored[0]
    return i, o


def strategy_cross_pole(options: list[dict], state: dict, rng: random.Random) -> tuple[int, dict]:
    """Always reach for the pole opposite to current dominant rep."""
    rep = state.get("faction_rep", {})
    pole_factions = {
        "Ordre": {"druides", "anciens"},
        "Chaos": {"korrigans", "ankou"},
        "Liminal": {"niamh"},
    }
    pole_rep = {pole: sum(rep.get(f, 0) for f in facs) for pole, facs in pole_factions.items()}
    dominant = max(pole_rep, key=lambda k: pole_rep[k]) if any(pole_rep.values()) else "Neutre"

    scored = []
    for i, opt in enumerate(options):
        locked, _ = option_is_gated(opt, state)
        if locked:
            continue
        opt_pole = (opt.get("dc_against") or {}).get("pole", "")
        contrast_bonus = 2.0 if opt_pole and opt_pole != dominant else 0.0
        sig = estimate_dc_signal(opt, state)
        sig_s = {"Confiant": 1.5, "Risque": 1.0, "Eprouve": -0.3}.get(sig, 0.5)
        scored.append((contrast_bonus + sig_s + rng.uniform(0, 0.2), i, opt))
    if not scored:
        return 0, options[0]
    scored.sort(key=lambda x: -x[0])
    _, i, o = scored[0]
    return i, o


STRATEGIES: dict[str, Strategy] = {
    "greedy": strategy_greedy,
    "balanced": strategy_balanced,
    "random": strategy_random,
    "trait_focused": strategy_trait_focused,
    "cross_pole": strategy_cross_pole,
}


# --- Headless run simulator -------------------------------------------------


def simulate_run(
    rag: CardsRAG,
    v2_pool: dict[str, dict],
    scenarios: list[dict],
    strategy: Strategy,
    n_cards: int,
    seed: int,
) -> dict:
    """One headless run. Returns a compact result dict.

    No LLM calls at all. Title sampled, intro/outro/transitions skipped.
    Cards retrieved via dedup_summary + MMR kNN.
    """
    rng = random.Random(seed)
    chosen = rng.choice(scenarios)

    arc_emotions = ["curiosite", "tension", "peur", "fascination", "sagesse"]
    seed_text = f"{chosen.get('archetype_name','')} . marche druidique broceliande"
    base_vec = rag.embed_query(seed_text)
    route_vec = base_vec

    selected: list[CardHit] = []
    excluded: list[str] = []
    seen_summaries: set[str] = set()
    for i in range(n_cards):
        emotion = arc_emotions[i * len(arc_emotions) // n_cards]
        hits = rag.knn(
            route_vec,
            k=8,
            filters={"emotion": emotion} if i % 2 == 0 else None,
            exclude_uids=excluded,
            mmr_lambda=0.6,
            mmr_pool=48,
            dedup_summary=True,
        )
        hits = [h for h in hits if (h.summary or "") not in seen_summaries]
        if not hits:
            hits = rag.knn(
                route_vec,
                k=8,
                exclude_uids=excluded,
                mmr_lambda=0.6,
                mmr_pool=48,
                dedup_summary=True,
            )
            hits = [h for h in hits if (h.summary or "") not in seen_summaries]
        if not hits:
            break
        pick = hits[rng.randint(0, min(2, len(hits) - 1))]
        selected.append(pick)
        excluded.append(pick.card_uid)
        seen_summaries.add(pick.summary or "")
        route_vec = rag.compose_route_vec(
            beat_vec=base_vec,
            recent_choice_vecs=[],
            intro_vec=base_vec,
            weights=(0.6, 0.0, 0.4),
        )

    state = {"life_essence": 80, "karma": 0, "faction_rep": {}, "tags": [], "promises": []}
    dc_counter: Counter[str] = Counter()
    chosen_factions: Counter[str] = Counter()
    locked_seen = 0
    for hit in selected:
        options, _ps, _pl, _motif, _card, _br = card_options(hit, v2_pool)
        if not options:
            continue
        opt_idx, option = strategy(options, state, rng)
        dc_result = resolve_dc(option, state, rng)
        effects = derive_effects_from_dc(option, dc_result)
        apply_effects(state, effects)
        dc_counter[dc_result] += 1
        chosen_factions[option.get("primary_faction", "")] += 1
        for o in options:
            locked, _ = option_is_gated(o, state)
            if locked:
                locked_seen += 1

    faction_rep = state.get("faction_rep", {})
    dom_faction = max(faction_rep.items(), key=lambda kv: kv[1])[0] if faction_rep else "none"
    pole_factions = {
        "Ordre": ["druides", "anciens"],
        "Chaos": ["korrigans", "ankou"],
        "Liminal": ["niamh"],
    }
    pole_scores = {p: sum(faction_rep.get(f, 0) for f in facs) for p, facs in pole_factions.items()}
    dom_pole = max(pole_scores, key=lambda k: pole_scores[k]) if any(pole_scores.values()) else "Neutre"

    won = (
        state["life_essence"] >= 50
        and (max(faction_rep.values()) if faction_rep else 0) >= 8
        and dc_counter["success"] >= max(2, int(0.25 * sum(dc_counter.values())))
    )

    return {
        "seed": seed,
        "title": chosen.get("title", ""),
        "n_cards_played": len(selected),
        "unique_summaries": len(seen_summaries),
        "life_essence_final": state["life_essence"],
        "karma": state["karma"],
        "faction_rep": dict(faction_rep),
        "dom_faction": dom_faction,
        "dom_pole": dom_pole,
        "dc_counter": dict(dc_counter),
        "locked_seen_total": locked_seen,
        "tags_acquired": len(state.get("tags", [])),
        "promises_open": len(state.get("promises", [])),
        "won": won,
    }


# --- Aggregator -------------------------------------------------------------


def aggregate_strategy(results: list[dict]) -> dict:
    n = len(results)
    if n == 0:
        return {"n_runs": 0}

    wins = sum(1 for r in results if r["won"])
    dc_total: Counter[str] = Counter()
    dom_factions: Counter[str] = Counter()
    dom_poles: Counter[str] = Counter()
    life_finals: list[int] = []
    karma_finals: list[int] = []
    unique_summaries: list[int] = []
    tags_finals: list[int] = []

    for r in results:
        for k, v in r["dc_counter"].items():
            dc_total[k] += v
        dom_factions[r["dom_faction"]] += 1
        dom_poles[r["dom_pole"]] += 1
        life_finals.append(r["life_essence_final"])
        karma_finals.append(r["karma"])
        unique_summaries.append(r["unique_summaries"])
        tags_finals.append(r["tags_acquired"])

    dc_total_sum = sum(dc_total.values()) or 1
    return {
        "n_runs": n,
        "win_rate": round(wins / n, 3),
        "dc_distribution": {k: round(v / dc_total_sum, 3) for k, v in dc_total.items()},
        "faction_dominant_pct": {
            k: round(v / n, 3) for k, v in dom_factions.most_common()
        },
        "pole_dominant_pct": {k: round(v / n, 3) for k, v in dom_poles.most_common()},
        "life_essence_p10": _percentile(life_finals, 10),
        "life_essence_p50": _percentile(life_finals, 50),
        "life_essence_p90": _percentile(life_finals, 90),
        "karma_p50": _percentile(karma_finals, 50),
        "unique_summaries_p50": _percentile(unique_summaries, 50),
        "tags_acquired_p50": _percentile(tags_finals, 50),
    }


def _percentile(values: list[int], p: int) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    idx = max(0, min(len(s) - 1, int(len(s) * p / 100)))
    return float(s[idx])


# --- HTML render ------------------------------------------------------------


CSS = """
<style>
:root { --bg:#1a1208; --bg-soft:#221a0c; --gold:#d4a84a; --gold-dim:#8b7028; --parchment:#ede0c0; --text:#ede0c0; --text-dim:#a89878; --good:#6fbf73; --warn:#d4a84a; --bad:#c25a4a; }
body { background:var(--bg); color:var(--text); font-family:'Georgia',serif; max-width:1100px; margin:0 auto; padding:24px; line-height:1.55; }
h1 { color:var(--gold); border-bottom:2px solid var(--gold-dim); padding-bottom:8px; }
h2 { color:var(--gold); margin-top:32px; border-bottom:1px solid var(--gold-dim); padding-bottom:4px; }
table { width:100%; border-collapse:collapse; margin:16px 0; font-size:13px; }
th, td { padding:8px 10px; text-align:left; border-bottom:1px solid var(--gold-dim); }
th { color:var(--gold); }
.kpi { display:inline-block; padding:8px 16px; background:var(--bg-soft); border-radius:8px; margin:4px; }
.kpi .val { font-size:20px; color:var(--gold); font-weight:bold; }
.kpi .lbl { font-size:11px; color:var(--text-dim); }
.bar-row { display:flex; align-items:center; margin:3px 0; font-family:monospace; font-size:11px; }
.bar-label { width:130px; color:var(--text-dim); }
.bar-fill { height:14px; background:linear-gradient(90deg,var(--gold-dim),var(--gold)); border-radius:2px; }
.bar-val { margin-left:6px; color:var(--text-dim); }
.good { color:var(--good); }
.warn { color:var(--warn); }
.bad { color:var(--bad); }
.section { background:var(--bg-soft); padding:16px; border-radius:6px; margin:16px 0; border-left:3px solid var(--gold-dim); }
</style>
"""


def _bar_row(label: str, frac: float, raw: str = "") -> str:
    e = html_escape
    width = max(1, int(frac * 320))
    return (
        f"<div class='bar-row'>"
        f"<div class='bar-label'>{e(label)}</div>"
        f"<div class='bar-fill' style='width:{width}px'></div>"
        f"<div class='bar-val'>{e(raw or f'{frac:.0%}')}</div>"
        f"</div>"
    )


def _verdict_class(value: float, good_range: tuple[float, float]) -> str:
    lo, hi = good_range
    if lo <= value <= hi:
        return "good"
    if value < lo - 0.1 or value > hi + 0.1:
        return "bad"
    return "warn"


def render_html(trace: dict) -> str:
    e = html_escape
    h: list[str] = []
    h.append("<!DOCTYPE html><html><head><meta charset='utf-8'>")
    h.append(f"<title>MERLIN Monte-Carlo Balance v7.7.32</title>{CSS}</head><body>")
    h.append("<h1>MERLIN - Monte-Carlo Balance Harness (Sprint 12.5)</h1>")
    h.append(
        f"<p>Run at {e(trace['run_at'])} - {trace['n_runs_per_strategy']} runs per strategy - "
        f"{trace['n_cards']} cards/run - seed_base {trace['seed_base']}</p>"
    )

    h.append("<div>")
    for strat in trace["strategies"]:
        s = trace["aggregates"][strat]
        wr = s.get("win_rate", 0)
        wr_class = _verdict_class(wr, (0.40, 0.60))
        h.append(
            f"<span class='kpi'><span class='val {wr_class}'>{wr:.0%}</span>"
            f"<br><span class='lbl'>{e(strat)} win-rate</span></span>"
        )
    h.append("</div>")

    h.append("<h2>1. Acceptance criteria (Sprint 12.5 plan §7.3)</h2>")
    h.append("<table>")
    h.append("<tr><th>Criterion</th><th>Target</th><th>Status per strategy</th></tr>")

    h.append("<tr><td>Win-rate per strategy</td><td>40-60%</td><td>")
    h.append("<br>".join(
        f"<span class='{_verdict_class(trace['aggregates'][s].get('win_rate',0), (0.40,0.60))}'>"
        f"{e(s)}: {trace['aggregates'][s].get('win_rate',0):.0%}</span>"
        for s in trace["strategies"]
    ))
    h.append("</td></tr>")

    max_wr = max(trace["aggregates"][s].get("win_rate", 0) for s in trace["strategies"])
    cls_dom = "bad" if max_wr >= 0.70 else "good"
    h.append(
        f"<tr><td>No dominant strategy</td><td>max &lt; 70%</td>"
        f"<td><span class='{cls_dom}'>{max_wr:.0%} max</span></td></tr>"
    )

    pole_share_global: Counter[str] = Counter()
    for s in trace["strategies"]:
        for p, frac in trace["aggregates"][s].get("pole_dominant_pct", {}).items():
            pole_share_global[p] += frac / len(trace["strategies"])
    min_pole = min(pole_share_global.values()) if pole_share_global else 0.0
    cls_pole = "good" if min_pole >= 0.20 else "warn"
    h.append(
        f"<tr><td>Each route &ge; 20% representation</td><td>per pole</td>"
        f"<td><span class='{cls_pole}'>min pole share = {min_pole:.0%}</span></td></tr>"
    )

    dc_fail_per_strat = [
        trace["aggregates"][s].get("dc_distribution", {}).get("failure", 0)
        for s in trace["strategies"]
    ]
    avg_fail = sum(dc_fail_per_strat) / max(1, len(dc_fail_per_strat))
    h.append(
        f"<tr><td>DC failure rate</td><td>10-25%</td>"
        f"<td><span class='{_verdict_class(avg_fail,(0.10,0.25))}'>{avg_fail:.0%} avg</span></td></tr>"
    )
    h.append("</table>")

    h.append("<h2>2. Per-strategy aggregates</h2>")
    h.append("<table>")
    h.append("<tr><th>Strategy</th><th>n_runs</th><th>Win %</th><th>DC succ/part/fail</th><th>Life P50</th><th>Karma P50</th><th>Tags P50</th><th>Unique sums P50</th></tr>")
    for strat in trace["strategies"]:
        s = trace["aggregates"][strat]
        dc = s.get("dc_distribution", {})
        h.append(
            "<tr>"
            f"<td><b>{e(strat)}</b></td>"
            f"<td>{s['n_runs']}</td>"
            f"<td>{s.get('win_rate',0):.0%}</td>"
            f"<td>{dc.get('success',0):.0%} / {dc.get('partial',0):.0%} / {dc.get('failure',0):.0%}</td>"
            f"<td>{s.get('life_essence_p50',0):.0f}</td>"
            f"<td>{s.get('karma_p50',0):.0f}</td>"
            f"<td>{s.get('tags_acquired_p50',0):.0f}</td>"
            f"<td>{s.get('unique_summaries_p50',0):.0f}</td>"
            "</tr>"
        )
    h.append("</table>")

    h.append("<h2>3. Pole dominant distribution (per strategy)</h2>")
    h.append("<div class='section'>")
    for strat in trace["strategies"]:
        h.append(f"<h3>{e(strat)}</h3>")
        for p, frac in sorted(
            trace["aggregates"][strat].get("pole_dominant_pct", {}).items(),
            key=lambda kv: -kv[1],
        ):
            h.append(_bar_row(p, frac))
    h.append("</div>")

    h.append("<h2>4. Faction dominant distribution (per strategy)</h2>")
    h.append("<div class='section'>")
    for strat in trace["strategies"]:
        h.append(f"<h3>{e(strat)}</h3>")
        for f, frac in sorted(
            trace["aggregates"][strat].get("faction_dominant_pct", {}).items(),
            key=lambda kv: -kv[1],
        )[:8]:
            h.append(_bar_row(f or "(none)", frac))
    h.append("</div>")

    h.append("<h2>5. DC outcome distribution (per strategy)</h2>")
    h.append("<table>")
    h.append("<tr><th>Strategy</th><th>Success</th><th>Partial</th><th>Failure</th></tr>")
    for strat in trace["strategies"]:
        dc = trace["aggregates"][strat].get("dc_distribution", {})
        h.append(
            "<tr>"
            f"<td>{e(strat)}</td>"
            f"<td class='good'>{dc.get('success',0):.0%}</td>"
            f"<td class='warn'>{dc.get('partial',0):.0%}</td>"
            f"<td class='bad'>{dc.get('failure',0):.0%}</td>"
            "</tr>"
        )
    h.append("</table>")

    h.append("<h2>6. Runtime</h2>")
    h.append("<table>")
    for k, v in trace["timings_s"].items():
        h.append(f"<tr><td>{e(k)}</td><td>{v} s</td></tr>")
    h.append("</table>")

    h.append("<h2>7. Methodology</h2>")
    h.append(
        "<div class='section'><p>Each strategy plays <b>" + str(trace["n_runs_per_strategy"])
        + " runs</b> with <b>" + str(trace["n_cards"]) + " cards/run</b>. "
        "No LLM calls (intro/outro/stitcher skipped). "
        "Seeds are <code>seed_base + i</code> for run i. "
        "Win condition (Sprint 12.5 spec): life_essence &ge;50 + max(faction_rep) &ge;8 + "
        "DC success count &ge; max(2, 25% of total beats).</p></div>"
    )

    h.append("</body></html>")
    return "".join(h)


# --- Main -------------------------------------------------------------------


def main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    parser = argparse.ArgumentParser(description="MERLIN Sprint 12.5 - Monte-Carlo balance")
    parser.add_argument("--runs", type=int, default=200, help="Runs per strategy (default 200)")
    parser.add_argument(
        "--strategies",
        type=str,
        default="greedy,balanced,random,trait_focused,cross_pole",
        help="Comma-separated strategy list",
    )
    parser.add_argument("--n-cards", type=int, default=16, help="Cards per run (default 16)")
    parser.add_argument("--seed-base", type=int, default=42, help="Base seed for run i (default 42)")
    parser.add_argument("--out-json", type=Path, default=None)
    parser.add_argument("--out-html", type=Path, default=None)
    args = parser.parse_args()

    strategies = [s.strip() for s in args.strategies.split(",") if s.strip()]
    unknown = [s for s in strategies if s not in STRATEGIES]
    if unknown:
        log.error("Unknown strategies: %s. Available: %s", unknown, list(STRATEGIES.keys()))
        return 1

    log.info("Loading rag + v2 pool ...")
    t0 = time.time()
    rag = CardsRAG.load()
    v2_pool, _stats = load_v2_pool()
    scenarios = json.loads(SCENARIOS_PATH.read_text(encoding="utf-8"))
    boot_s = time.time() - t0
    log.info("Boot: %.2fs (kNN=%d cards, v2=%d canonicals)", boot_s, rag.count, len(v2_pool))

    trace = {
        "version": "v7.7.32",
        "run_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "n_runs_per_strategy": args.runs,
        "n_cards": args.n_cards,
        "seed_base": args.seed_base,
        "strategies": strategies,
        "results": {},
        "aggregates": {},
        "timings_s": {"boot": round(boot_s, 2)},
    }

    pipeline_t0 = time.time()
    for strat_name in strategies:
        strat = STRATEGIES[strat_name]
        log.info("Strategy %s starting (%d runs)...", strat_name, args.runs)
        t_strat = time.time()
        results: list[dict] = []
        for i in range(args.runs):
            r = simulate_run(
                rag,
                v2_pool,
                scenarios,
                strat,
                args.n_cards,
                args.seed_base + i,
            )
            results.append(r)
            if (i + 1) % 50 == 0:
                log.info("  %s: %d/%d done", strat_name, i + 1, args.runs)
        dur = time.time() - t_strat
        trace["results"][strat_name] = results
        trace["aggregates"][strat_name] = aggregate_strategy(results)
        trace["timings_s"][f"strategy_{strat_name}"] = round(dur, 2)
        log.info(
            "Strategy %s done in %.1fs  win_rate=%.0f%%",
            strat_name,
            dur,
            trace["aggregates"][strat_name].get("win_rate", 0) * 100,
        )

    trace["timings_s"]["total"] = round(time.time() - pipeline_t0, 2)

    out_dir = Path.home() / "Downloads"
    out_dir.mkdir(parents=True, exist_ok=True)
    ts = int(time.time())
    json_path = args.out_json or (out_dir / f"montecarlo_balance_{ts}.json")
    html_path = args.out_html or (out_dir / f"montecarlo_balance_{ts}.html")
    slim = dict(trace)
    if len(trace["results"].get(strategies[0], [])) > 50:
        slim["results"] = {
            s: {"first_3_runs": rs[:3], "n_runs_total": len(rs)}
            for s, rs in trace["results"].items()
        }
    json_path.write_text(json.dumps(slim, ensure_ascii=False, indent=2), encoding="utf-8")
    html_path.write_text(render_html(trace), encoding="utf-8")
    log.info("Wrote %s", json_path)
    log.info("Wrote %s", html_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())

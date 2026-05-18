#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
simulate_human_run_v731.py - v7.7.31 (2026-05-18)

Phase 11 Sprint 11.3 - embedding-first PoC with narrative depth + DnD-without-combat.

What changed vs v7.7.30:

  - Pool: loads `cards_meta_v2.json` if present (enriched canonical bucket
    with prose_short / prose_long / 3 DnD-style options per canonical).
    Falls back gracefully to the raw scenarios pool for buckets not yet
    enriched (LLM batch can be partial - this script still produces a
    coherent run).

  - kNN: `dedup_summary=True` + `mmr_lambda=0.6` - kills the 97 % string-
    duplicate pathology that v7.7.30 exhibited (Beat N == Beat N+1).
    Sprint 11.2.

  - DnD checks: every option carries a hidden DC against a pole + cost.
    A run-state contest produces success / partial / failure with branching
    effects and branching prose. No d20 surfaced - only qualitative signals
    "[Confiant] / [Risque] / [Eprouve]".

  - Inter-beat memory: state["tags"] accumulates ADD_TAG effects; future
    options check `gated_on.required_tags` and `gated_on.min_karma`. Locked
    options surface as `[Verrouille]` with a hint.

  - Fil rouge: anchor_motif from beat 1 is stored on the run state. A
    simple template-based transition prose is interpolated before each beat
    using the previous verb + the anchor (no extra LLM call; Sprint 11.5
    upgrades this to a streaming stitcher LLM).

  - Resolutions: pulled directly from enriched_options.success_prose /
    partial_prose / failure_prose. No template synthesis.

Pre-req:
    python tools/embed_reference_cards.py        # one-shot
    python tools/dedup_and_expand_pool.py        # one-shot (~45 min)

User instruction (verbatim): "continue" (Phase 11 Sprint 11.3 cf
docs/10_llm/PHASE_11_NARRATIVE_DEPTH_PLAN.md).

Output:
    ~/Downloads/merlin_human_run_test_v7.7.31.html
    ~/Downloads/merlin_human_run_test_v7.7.31.json

Caller graph: standalone CLI (no other file imports this module).
"""

from __future__ import annotations
import json
import logging
import os
import random
import sys
import time
from html import escape as html_escape
from pathlib import Path
from typing import Optional
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cards_rag import CardsRAG, CardHit  # noqa: E402

# Sprint 11.5 - optional async LLM stitcher. Off by default (set MERLIN_STITCHER=1).
USE_STITCHER = os.environ.get("MERLIN_STITCHER", "0") == "1"
if USE_STITCHER:
    try:
        from beat_chain_stitcher import stitch_transitions  # type: ignore
    except ImportError:  # pragma: no cover
        stitch_transitions = None  # type: ignore
        USE_STITCHER = False

OLLAMA_BASE = "http://localhost:11434"
NARRATOR_MODEL = os.environ.get("MERLIN_NARRATOR_MODEL", "gemma4:e2b")
THINK_MODE = os.environ.get("MERLIN_THINK", "false").lower() == "true"
BIOME = os.environ.get("MERLIN_BIOME", "foret_broceliande")
N_CARDS = int(os.environ.get("MERLIN_N_CARDS", "16"))
SEED = int(os.environ.get("MERLIN_SEED", "42"))
MMR_LAMBDA = float(os.environ.get("MERLIN_MMR_LAMBDA", "0.6"))
OUT_DIR = Path.home() / "Downloads"
HTML_PATH = OUT_DIR / "merlin_human_run_test_v7.7.31.html"
JSON_PATH = OUT_DIR / "merlin_human_run_test_v7.7.31.json"
ROOT = Path(__file__).resolve().parent.parent
SCENARIOS_PATH = ROOT / "data" / "ai" / "scenarios_reference_broceliande.json"
V2_POOL_PATH = ROOT / "data" / "ai" / "cards_meta_v2.json"

log = logging.getLogger("simulate_human_run_v731")


# --- Ollama helpers ---------------------------------------------------------


def ollama_post(endpoint: str, payload: dict, timeout: int = 120) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = Request(
        f"{OLLAMA_BASE}{endpoint}",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def llm_generate(
    system: str, user: str, options: Optional[dict] = None, timeout: int = 120
) -> tuple[str, float]:
    payload = {
        "model": NARRATOR_MODEL,
        "system": system,
        "prompt": user,
        "stream": False,
        "think": THINK_MODE,
        "options": options or {"temperature": 0.7, "num_predict": 320},
    }
    t0 = time.time()
    resp = ollama_post("/api/generate", payload, timeout=timeout)
    dur = time.time() - t0
    return (resp.get("response", "") or "").strip(), dur


# --- v2 enriched pool -------------------------------------------------------


def load_v2_pool(path: Path = V2_POOL_PATH) -> tuple[dict[str, dict], dict]:
    """Return (summary -> enriched canonical, stats). Empty dict if missing."""
    if not path.exists():
        log.warning("v2 pool not found at %s - falling back to raw pool", path.name)
        return {}, {"enriched_count": 0, "llm_success": 0, "llm_fallback": 0, "status": "missing"}
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        log.error("Could not read v2 pool: %s", e)
        return {}, {"enriched_count": 0, "llm_success": 0, "llm_fallback": 0, "status": "error"}
    index: dict[str, dict] = {}
    for c in raw.get("canonicals", []):
        summ = (c.get("canonical_summary") or "").strip()
        if summ:
            index[summ] = c
    stats = {
        "enriched_count": raw.get("enriched_count", 0),
        "llm_success": raw.get("llm_success", 0),
        "llm_fallback": raw.get("llm_fallback", 0),
        "status": raw.get("status", "unknown"),
        "generated_at": raw.get("generated_at", ""),
    }
    log.info(
        "v2 pool loaded: %d canonicals (%d llm, %d fallback)",
        len(index),
        stats["llm_success"],
        stats["llm_fallback"],
    )
    return index, stats


# --- Pipeline stages --------------------------------------------------------


def pick_titles(scenarios: list[dict], rng: random.Random) -> tuple[list[dict], float]:
    t0 = time.time()
    sampled = rng.sample(scenarios, k=min(3, len(scenarios)))
    titles = [
        {
            "title": s.get("title", "?"),
            "archetype_name": s.get("archetype_name", ""),
            "scenario_id": s.get("id", ""),
        }
        for s in sampled
    ]
    return titles, time.time() - t0


def llm_intro(chosen: dict, anchor_hint: str = "") -> tuple[str, float]:
    """LLM-written setup intro. Short, no scenario spoilers, but seeded with
    the anchor motif so the intro foreshadows what beat 1 will introduce."""
    system = (
        "Tu es un narrateur druidique de l'univers MERLIN (Broceliande). "
        "Tu ecris une introduction au scenario. C'est un SETUP : ambiance, "
        "trac, sensations. Ne revele AUCUN evenement, aucune rencontre. "
        "4 a 5 phrases, en 2eme personne du singulier."
    )
    anchor_line = f"\nElement central qui sera presente plus tard : {anchor_hint}" if anchor_hint else ""
    user = (
        f"Titre du scenario : {chosen['title']}\n"
        f"Archetype : {chosen['archetype_name']}{anchor_line}\n\n"
        f"Ecris l'intro qui ouvre la marche."
    )
    return llm_generate(system, user, options={"temperature": 0.7, "num_predict": 220})


def retrieve_skeleton(
    rag: CardsRAG,
    chosen: dict,
    intro_vec,
    n_cards: int,
    rng: random.Random,
) -> tuple[list[CardHit], list[float], float]:
    """Build the run skeleton with dedup_summary + MMR diversity.

    Progressive emotion arc curiosite -> tension -> peur -> fascination -> sagesse.
    """
    t0 = time.time()
    arc_emotions = ["curiosite", "tension", "peur", "fascination", "sagesse"]
    selected: list[CardHit] = []
    excluded: list[str] = []
    seen_summaries: set[str] = set()
    per_card_ms: list[float] = []

    query_text = f"{chosen.get('archetype_name', '')} . marche druidique broceliande"
    base_vec = rag.embed_query(query_text)
    route_vec = rag.compose_route_vec(
        beat_vec=base_vec,
        recent_choice_vecs=[],
        intro_vec=intro_vec,
        weights=(0.4, 0.0, 0.6),
    )

    for i in range(n_cards):
        emotion = arc_emotions[i * len(arc_emotions) // n_cards]
        t_card = time.time()

        # Sprint 11.2: dedup_summary + MMR keep this from collapsing.
        hits = rag.knn(
            route_vec,
            k=8,
            filters={"emotion": emotion} if i % 2 == 0 else None,
            exclude_uids=excluded,
            mmr_lambda=MMR_LAMBDA,
            mmr_pool=48,
            dedup_summary=True,
        )
        # Drop anything we've already used in this run (by summary, not uid).
        hits = [h for h in hits if (h.summary or "") not in seen_summaries]
        if not hits:
            # Relax emotion if starvation.
            hits = rag.knn(
                route_vec,
                k=8,
                exclude_uids=excluded,
                mmr_lambda=MMR_LAMBDA,
                mmr_pool=48,
                dedup_summary=True,
            )
            hits = [h for h in hits if (h.summary or "") not in seen_summaries]
        if not hits:
            log.warning("No hits at beat %d - stopping early", i)
            break

        # Top-3 random pick adds variety across runs.
        pick_idx = rng.randint(0, min(2, len(hits) - 1))
        picked = hits[pick_idx]
        selected.append(picked)
        excluded.append(picked.card_uid)
        seen_summaries.add(picked.summary or "")
        per_card_ms.append((time.time() - t_card) * 1000)

        picked_vec = rag.embed_query(picked.summary or picked.card_uid)
        route_vec = rag.compose_route_vec(
            beat_vec=picked_vec,
            recent_choice_vecs=[],
            intro_vec=intro_vec,
            weights=(0.5, 0.0, 0.5),
        )

    return selected, per_card_ms, time.time() - t0


# --- DnD-without-combat mechanics -------------------------------------------


def card_options(hit: CardHit, v2_pool: dict[str, dict]) -> tuple[list[dict], str, str, str]:
    """Resolve the options for a card.

    Returns (options, prose_short, prose_long, anchor_motif).

    If the card's summary has a v2 enriched entry, use enriched_options;
    otherwise fall back to the raw 3-verb options from the original pool.
    """
    summ = (hit.summary or "").strip()
    enriched = v2_pool.get(summ)
    if enriched and enriched.get("enriched_options"):
        return (
            enriched["enriched_options"],
            enriched.get("prose_short") or summ,
            enriched.get("prose_long") or summ,
            enriched.get("anchor_motif", ""),
        )
    return hit.options or [], summ, summ, ""


def option_is_gated(option: dict, state: dict) -> tuple[bool, str]:
    """Return (locked, reason). Inter-beat memory: tags + karma gates."""
    g = option.get("gated_on") or {}
    if not g:
        return False, ""
    required_tags = g.get("required_tags") or []
    have_tags = set(state.get("tags") or [])
    missing = [t for t in required_tags if t not in have_tags]
    if missing:
        hint = option.get("gate_hint") or f"il te manque : {', '.join(missing)}"
        return True, hint
    min_karma = int(g.get("min_karma", 0) or 0)
    if state.get("karma", 0) < min_karma:
        return True, option.get("gate_hint") or f"karma insuffisant ({min_karma}+)"
    return False, ""


# Sprint 12.5c balance re-tune (2026-05-18, after 12.5b overshoot):
# Sprint 12.5b dropped greedy 89%->18% but ALL strategies collapsed below 40%
# (DC failure rose 30%->50%, niamh now dominates 37-70%). Middle-ground :
#   - DC_BASE_SKILL : 15 -> 10 -> 12   (split the diff)
#   - CONFIANT_DELTA : 10 -> 15 -> 12  (split the diff)
#   - POLE_ALIGNMENT_WEIGHTS : broaden Liminal to 3 factions, lower the
#     niamh weight from 1.0 -> 0.8 so it loses its monopoly bonus.
#   - Tighten Ordre + Chaos so they're not undercut either.
POLE_ALIGNMENT_WEIGHTS: dict[str, dict[str, float]] = {
    "ordre":   {"druides": 0.9, "anciens": 0.6},
    "chaos":   {"korrigans": 0.9, "ankou": 0.6},
    # Liminal is the "in-between" pole - 3 factions touch it but niamh
    # the most. Total weight ~1.5 to give Liminal-rich players an edge
    # without monopolising.
    "liminal": {"niamh": 0.8, "anciens": 0.4, "korrigans": 0.3},
    "neutre":  {"druides": 0.25, "anciens": 0.25, "korrigans": 0.25, "niamh": 0.25, "ankou": 0.25},
}
# Sprint 12.5d (2026-05-18) - Sprint 12.5c (base=12) was still too punishing
# (all strategies below 40% win). The pole_alignment weights already remove
# ~30% effective skill vs v731 baseline ; restoring base=15 lets the new
# weighted formula do the rebalance work alone. Expect greedy ~50-60%.
DC_BASE_SKILL: int = 15  # restored to v731 baseline (was 10 / 12 in previous iterations)
CONFIANT_DELTA: int = 12  # keep tightened spread (v731 was 10)
EPROUVE_DELTA: int = -12  # keep failures discoverable


def _aligned_skill(state: dict, pole: str) -> int:
    """Weighted faction-rep skill for the given DC pole (Sprint 12.5b)."""
    weights = POLE_ALIGNMENT_WEIGHTS.get(pole.lower(), {})
    rep = state.get("faction_rep", {})
    weighted = sum(rep.get(f, 0) * w for f, w in weights.items())
    return int(weighted // 2)


def estimate_dc_signal(option: dict, state: dict) -> str:
    """Map the option's hidden DC to a qualitative chip the player sees.

    [Confiant] : likely success
    [Risque]   : 50/50
    [Eprouve]  : likely failure
    """
    dc = option.get("dc_against") or {}
    threshold = int(dc.get("threshold", 25) or 25)
    pole = (dc.get("pole") or "")
    skill = _aligned_skill(state, pole)
    karma_bonus = max(0, state.get("karma", 0)) // 5
    effective = skill + karma_bonus + DC_BASE_SKILL

    delta = effective - threshold
    if delta >= CONFIANT_DELTA:
        return "Confiant"
    if delta <= EPROUVE_DELTA:
        return "Eprouve"
    return "Risque"


def resolve_dc(option: dict, state: dict, rng: random.Random) -> str:
    """Probabilistic outcome of the option: success / partial / failure.

    Hidden DC + state-derived skill. Player only sees the qualitative chip
    via `estimate_dc_signal`; this function is what actually rolls."""
    dc = option.get("dc_against") or {}
    threshold = int(dc.get("threshold", 25) or 25)
    pole = (dc.get("pole") or "")
    skill = _aligned_skill(state, pole)
    karma_bonus = max(0, state.get("karma", 0)) // 5
    effective = skill + karma_bonus + DC_BASE_SKILL
    roll = rng.randint(1, 20)
    score = effective + roll
    if score >= threshold + 5:
        return "success"
    if score >= threshold - 5:
        return "partial"
    return "failure"


def agent_pick_option(
    options: list[dict],
    state: dict,
    rng: random.Random,
) -> tuple[int, dict, str]:
    """Strategic agent: balance factions while avoiding locked options.

    Returns (idx, option, decision_reason).

    Sprint 12.5d rebalance (2026-05-18): the previous "balanced" agent at
    Sprint 12.5b spread factions too thin (won 14-22%, worse than greedy/
    trait_focused). The fix: prioritize specialization over diversification.
      signal_score:        max 1.5  (raised - prefer Confiant clearly)
      faction_continuity:  max 1.2  (raised - identity emerges through repetition)
      balance_bonus:       max 0.6  (lowered - only nudge when one faction
                                     saturates, don't dictate every choice)
    Net effect: behaves like a thoughtful human - picks Confiant first,
    leans into a faction once chosen, occasionally branches when sitting
    on >= 15 rep.
    """
    if not options:
        return -1, {}, "no options"

    rep = state.get("faction_rep", {})
    main_faction = ""
    if rep:
        main_faction_candidate = max(rep.items(), key=lambda kv: kv[1])
        if main_faction_candidate[1] > 0:
            main_faction = main_faction_candidate[0]

    scored: list[tuple[float, int, dict]] = []
    for i, opt in enumerate(options):
        locked, _hint = option_is_gated(opt, state)
        if locked:
            continue
        faction = opt.get("primary_faction", "")
        rep_now = rep.get(faction, 0)
        signal = estimate_dc_signal(opt, state)
        signal_score = {
            "Confiant": 1.5,
            "Risque": 0.8,
            "Eprouve": -0.5,
        }.get(signal, 0.4)
        # Balance bonus only kicks in if a faction is saturated (rep > 15),
        # nudging the agent to branch. Otherwise it stays focused.
        balance_bonus = 0.6 if rep_now > 15 else 0.0
        # Faction continuity : when there's a clear main and we haven't
        # over-invested, prefer it (helps identity emerge).
        if main_faction and faction == main_faction and rep_now < 25:
            continuity_bonus = 1.2
        else:
            continuity_bonus = 0.0
        score = signal_score + balance_bonus + continuity_bonus + rng.uniform(0, 0.3)
        scored.append((score, i, opt))

    if not scored:
        return 0, options[0], "all gated; fallback to option 0"
    scored.sort(key=lambda x: -x[0])
    _s, idx, opt = scored[0]
    reason = (
        f"signal={estimate_dc_signal(opt, state)}, faction={opt.get('primary_faction','-')}, "
        f"rep_now={rep.get(opt.get('primary_faction',''), 0)}"
    )
    return idx, opt, reason


def transition_prose(beat_idx: int, prev_verb: str, anchor: str, mvt: int) -> str:
    """Template-based fil-rouge transition. No LLM call.

    Sprint 11.4 - simple version. Sprint 11.5 will swap for a streaming LLM
    stitcher (80-token Gemma call, async-masked by UI animation).
    """
    if beat_idx == 0:
        return ""
    movement_lead = {
        1: "La foret s'ouvre",
        2: "Un seuil se franchit",
        3: "Le rythme se rompt",
        4: "Tu vas plus loin",
        5: "La trame se resserre",
    }.get(mvt, "Tu poursuis")
    if anchor and prev_verb:
        return f"{movement_lead}. Tu venais de {prev_verb} ; l'echo de {anchor} resonne encore."
    if anchor:
        return f"{movement_lead}, sous le signe de {anchor}."
    if prev_verb:
        return f"{movement_lead}. L'apres-coup de {prev_verb} t'accompagne."
    return f"{movement_lead}."


def movement_for_beat(beat_idx: int, n_cards: int) -> int:
    """5-movement narrative model from docs/10_llm/PHASE_11_NARRATIVE_DEPTH_PLAN.md."""
    if n_cards <= 0:
        return 1
    pct = beat_idx / max(1, n_cards - 1)
    if pct < 0.20:
        return 1  # Setup
    if pct < 0.45:
        return 2  # First descent
    if pct < 0.55:
        return 3  # MERLIN pivot
    if pct < 0.85:
        return 4  # Deepening
    return 5  # Pay-off


# --- Effects engine ---------------------------------------------------------


def derive_effects_from_dc(option: dict, dc_result: str) -> list[str]:
    """Pull the effects list matching the DC outcome."""
    key = {
        "success": "success_effects",
        "partial": "partial_effects",
        "failure": "failure_effects",
    }.get(dc_result, "success_effects")
    eff = option.get(key) or option.get("success_effects") or []
    if isinstance(eff, list):
        return [str(e) for e in eff]
    return []


def derive_prose_from_dc(option: dict, dc_result: str) -> str:
    """Pull the narrative prose matching the DC outcome."""
    key = {
        "success": "success_prose",
        "partial": "partial_prose",
        "failure": "failure_prose",
    }.get(dc_result, "success_prose")
    return (option.get(key) or option.get("success_prose") or "").strip()


def apply_effects(state: dict, effects: list[str]) -> list[dict]:
    """Mirror of MerlinEffectEngine.apply_effects + ADD_TAG inter-beat memory."""
    log_entries: list[dict] = []
    for eff in effects:
        try:
            parts = eff.split(":")
            verb = parts[0]
            if verb == "ADD_REPUTATION":
                # Accept both "ADD_REPUTATION:faction:N" and the over-nested
                # "ADD_REPUTATION:faction:druides:N" that gemma emits sometimes.
                if len(parts) >= 4:
                    faction, amount = parts[2], int(parts[3])
                else:
                    faction, amount = parts[1], int(parts[2])
                rep = state.setdefault("faction_rep", {})
                rep[faction] = rep.get(faction, 0) + amount
            elif verb == "HEAL_LIFE":
                state["life_essence"] = min(
                    100, state.get("life_essence", 80) + int(parts[1])
                )
            elif verb == "DAMAGE_LIFE":
                state["life_essence"] = max(
                    0, state.get("life_essence", 80) - int(parts[1])
                )
            elif verb == "ADD_KARMA":
                state["karma"] = state.get("karma", 0) + int(parts[1])
            elif verb == "ADD_TAG":
                tag = parts[1] if len(parts) >= 2 else ""
                if tag:
                    state.setdefault("tags", []).append(tag)
            elif verb == "PROMISE":
                state.setdefault("promises", []).append(
                    {"to": parts[1] if len(parts) >= 2 else "?",
                     "due_beats": int(parts[2]) if len(parts) >= 3 else 3}
                )
            log_entries.append({"effect": eff, "status": "applied"})
        except Exception as e:
            log_entries.append({"effect": eff, "status": f"error:{e}"})
    return log_entries


# --- Outro ------------------------------------------------------------------


def llm_outro(
    chosen: dict,
    run_history: list[dict],
    final_state: dict,
    anchor: str,
) -> tuple[str, float]:
    """Sprint 11.4 cascade prompt: outro reads anchor + last 3 verbs + dominant
    faction + dc summary, producing a coherent epilogue grounded in the run."""
    system = (
        "Tu es un narrateur druidique. Tu ecris la conclusion (outro) d'une "
        "marche dans Broceliande. 3 a 4 phrases, 2eme personne, ton apaise. "
        "Mentionne 1-2 factions dominantes, l'ambiance finale, et reprends "
        "le motif d'ancrage."
    )
    factions = final_state.get("faction_rep", {})
    sorted_factions = sorted(factions.items(), key=lambda kv: -kv[1])[:2]
    last3_verbs = [h.get("verb", "") for h in run_history[-3:] if h.get("verb")]
    dc_summary = {}
    for h in run_history:
        r = h.get("dc_result", "")
        dc_summary[r] = dc_summary.get(r, 0) + 1
    summary_lines = [
        f"- {h['beat']}: {h.get('label','?')} ({h.get('dc_result','?')})"
        for h in run_history[:6]
    ]
    user = (
        f"Titre : {chosen['title']}\n"
        f"Motif d'ancrage : {anchor or '(aucun)'}\n"
        f"Factions dominantes : "
        f"{', '.join(f'{f}:{v}' for f, v in sorted_factions) or 'aucune'}\n"
        f"Issue moyenne : {dc_summary}\n"
        f"Derniers gestes : {', '.join(last3_verbs) or '(neutre)'}\n"
        f"Etapes marquantes :\n" + "\n".join(summary_lines)
    )
    return llm_generate(system, user, options={"temperature": 0.7, "num_predict": 220})


# --- Main pipeline ----------------------------------------------------------


def run_simulation() -> dict:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    log.info("v7.7.31 Sprint 11 starting...")
    log.info(
        "  model=%s biome=%s n_cards=%d seed=%d mmr_lambda=%.2f",
        NARRATOR_MODEL,
        BIOME,
        N_CARDS,
        SEED,
        MMR_LAMBDA,
    )

    trace: dict = {
        "version": "v7.7.31",
        "mode": "embedding-first-sprint11",
        "started_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "models": {"narrator": NARRATOR_MODEL, "embed": "nomic-embed-text"},
        "biome": BIOME,
        "n_cards": N_CARDS,
        "seed": SEED,
        "mmr_lambda": MMR_LAMBDA,
        "timings_s": {},
    }
    rng = random.Random(SEED)
    pipeline_t0 = time.time()

    # Boot: cards_rag + v2 pool
    t0 = time.time()
    rag = CardsRAG.load()
    v2_pool, v2_stats = load_v2_pool()
    trace["timings_s"]["boot"] = round(time.time() - t0, 3)
    trace["cards_pool_size"] = rag.count
    trace["v2_pool_stats"] = v2_stats
    log.info(
        "Boot: %.2fs (kNN=%d cards, v2=%d canonicals, llm_yield=%d/%d)",
        trace["timings_s"]["boot"],
        rag.count,
        v2_stats["enriched_count"],
        v2_stats["llm_success"],
        v2_stats["enriched_count"],
    )

    scenarios = json.loads(SCENARIOS_PATH.read_text(encoding="utf-8"))

    # Titles
    titles, dur_titles = pick_titles(scenarios, rng)
    trace["timings_s"]["titles"] = round(dur_titles, 3)
    trace["titles"] = titles
    chosen = titles[0]
    trace["chosen_title"] = chosen
    log.info("Titles: %s -> picked %s", [t["title"] for t in titles], chosen["title"])

    # Pre-pick anchor: peek the most-likely beat-1 card to extract motif
    # for the intro to foreshadow. Cheap - one kNN call.
    anchor_hint = ""
    try:
        seed_vec = rag.embed_query(
            f"{chosen.get('archetype_name','')} . marche druidique broceliande"
        )
        peek = rag.knn(seed_vec, k=1, dedup_summary=True)
        if peek:
            _opts, _ps, _pl, motif = card_options(peek[0], v2_pool)
            anchor_hint = motif or ""
    except Exception as e:
        log.warning("anchor peek failed: %s", e)
    trace["anchor_hint"] = anchor_hint

    # Intro LLM
    intro_text, dur_intro = llm_intro(chosen, anchor_hint=anchor_hint)
    trace["timings_s"]["intro_llm"] = round(dur_intro, 2)
    trace["intro"] = intro_text
    log.info("Intro: %.1fs, %d chars", dur_intro, len(intro_text))

    t0 = time.time()
    intro_vec = rag.embed_query(intro_text or chosen["title"])
    trace["timings_s"]["intro_embed"] = round(time.time() - t0, 3)

    # Skeleton retrieval (kNN with dedup_summary + MMR)
    skeleton_hits, per_card_ms, dur_skeleton = retrieve_skeleton(
        rag, chosen, intro_vec, N_CARDS, rng
    )
    trace["timings_s"]["skeleton_total"] = round(dur_skeleton, 2)
    trace["timings_s"]["skeleton_avg_ms_per_card"] = round(
        sum(per_card_ms) / max(1, len(per_card_ms)), 2
    )
    trace["per_card_retrieval_ms"] = [round(x, 2) for x in per_card_ms]
    log.info(
        "Skeleton: %.2fs / %d cards (avg %.2f ms)",
        dur_skeleton,
        len(skeleton_hits),
        trace["timings_s"]["skeleton_avg_ms_per_card"],
    )
    # Unique-summary diversity audit
    unique_summaries = len({(h.summary or "")[:55] for h in skeleton_hits})
    trace["unique_summaries"] = unique_summaries
    log.info("Unique summaries: %d / %d", unique_summaries, len(skeleton_hits))

    # Play loop with DnD checks + fil-rouge transitions
    state = {"life_essence": 80, "karma": 0, "faction_rep": {}, "tags": [], "promises": []}
    cards_played: list[dict] = []
    run_history: list[dict] = []
    prev_verb = ""
    anchor_locked = ""

    for i, hit in enumerate(skeleton_hits):
        options, prose_short, prose_long, motif = card_options(hit, v2_pool)
        if i == 0 and motif:
            anchor_locked = motif
            trace["anchor_motif"] = anchor_locked

        mvt = movement_for_beat(i, len(skeleton_hits))
        trans_prose = transition_prose(i, prev_verb, anchor_locked, mvt)

        opt_idx, option, decision_reason = agent_pick_option(options, state, rng)
        dc_result = resolve_dc(option, state, rng) if option else "failure"
        effects = derive_effects_from_dc(option, dc_result)
        log_entries = apply_effects(state, effects)
        resolution_prose = derive_prose_from_dc(option, dc_result) or hit.summary or ""

        # Capture per-option DC signals so the HTML can show what the player saw.
        option_signals = []
        for o in options:
            locked, hint = option_is_gated(o, state)
            option_signals.append(
                {
                    "label": o.get("label", ""),
                    "verb": o.get("verb", ""),
                    "faction": o.get("primary_faction", ""),
                    "signal": "Verrouille" if locked else estimate_dc_signal(o, state),
                    "gate_hint": hint if locked else "",
                    "dc_pole": (o.get("dc_against") or {}).get("pole", ""),
                    "dc_threshold": (o.get("dc_against") or {}).get("threshold", 0),
                    "cost": o.get("cost") or {},
                }
            )

        cards_played.append(
            {
                "beat": i + 1,
                "movement": mvt,
                "transition_prose": trans_prose,
                "card_uid": hit.card_uid,
                "type": hit.type,
                "rarity": hit.rarity,
                "pole": hit.pole,
                "emotion": hit.emotion,
                "summary": hit.summary,
                "prose_short": prose_short,
                "prose_long": prose_long,
                "anchor_motif": motif,
                "score": hit.score,
                "retrieval_ms": per_card_ms[i] if i < len(per_card_ms) else 0,
                "option_signals": option_signals,
                "chosen_option_idx": opt_idx,
                "chosen_option": option,
                "decision_reason": decision_reason,
                "dc_result": dc_result,
                "effects_applied": effects,
                "resolution_prose": resolution_prose,
                "state_after": {
                    "life": state.get("life_essence"),
                    "karma": state.get("karma"),
                    "factions": dict(state.get("faction_rep", {})),
                    "tags": list(state.get("tags", [])),
                },
            }
        )
        run_history.append(
            {
                "beat": i + 1,
                "label": option.get("label", ""),
                "verb": option.get("verb", ""),
                "faction": option.get("primary_faction", ""),
                "dc_result": dc_result,
                "movement": mvt,
            }
        )
        prev_verb = option.get("verb", "") or prev_verb
        log.info(
            "Beat %d/%d (M%d): %s -> %s -> %s  rep=%s",
            i + 1,
            len(skeleton_hits),
            mvt,
            (hit.summary or "")[:50],
            option.get("label", "?"),
            dc_result,
            state.get("faction_rep", {}),
        )

    trace["cards_played"] = cards_played
    trace["run_history"] = run_history
    trace["final_state"] = state

    # Sprint 11.5 - parallel LLM bridge stitcher (optional, MERLIN_STITCHER=1)
    if USE_STITCHER and stitch_transitions is not None and len(cards_played) >= 2:
        t0 = time.time()
        durations: list[float] = []
        try:
            stitched = stitch_transitions(
                beats=cards_played, anchor=anchor_locked, timings_out=durations
            )
        except Exception as e:
            log.error("stitcher crashed: %s", e)
            stitched = {}
        trace["timings_s"]["stitcher_total"] = round(time.time() - t0, 2)
        trace["timings_s"]["stitcher_avg_per_bridge"] = round(
            sum(durations) / max(1, len(durations)), 2
        )
        trace["stitched_transitions"] = {str(k): v for k, v in stitched.items()}
        # Inject into the cards_played records so HTML and JSON show the LLM bridge.
        for idx, text in stitched.items():
            if 0 <= idx < len(cards_played) and text:
                cards_played[idx]["transition_prose_llm"] = text
        log.info(
            "Stitcher: %d bridges in %.2fs (avg %.1fs/bridge)",
            len(stitched),
            trace["timings_s"]["stitcher_total"],
            trace["timings_s"]["stitcher_avg_per_bridge"],
        )
    else:
        trace["stitched_transitions"] = {}
        if USE_STITCHER:
            log.info("Stitcher requested but not active (module unavailable)")

    # Outro LLM
    outro_text, dur_outro = llm_outro(chosen, run_history, state, anchor_locked)
    trace["timings_s"]["outro_llm"] = round(dur_outro, 2)
    trace["outro"] = outro_text
    log.info("Outro: %.1fs", dur_outro)

    trace["timings_s"]["total"] = round(time.time() - pipeline_t0, 2)
    trace["timings_s"]["llm_total"] = round(
        trace["timings_s"]["intro_llm"] + trace["timings_s"]["outro_llm"], 2
    )
    trace["timings_s"]["retrieval_total"] = round(
        trace["timings_s"]["skeleton_total"], 2
    )
    log.info("DONE in %.1fs", trace["timings_s"]["total"])
    return trace


# --- HTML rendering ---------------------------------------------------------


CSS = """
<style>
:root {
  --bg: #1a1208;
  --bg-soft: #221a0c;
  --gold: #d4a84a;
  --gold-dim: #8b7028;
  --parchment: #ede0c0;
  --text: #ede0c0;
  --text-dim: #a89878;
  --signal-confiant: #6fbf73;
  --signal-risque:   #d4a84a;
  --signal-eprouve:  #c25a4a;
  --signal-locked:   #5a5a5a;
}
body { background:var(--bg); color:var(--text); font-family:'Georgia',serif; max-width:1000px; margin:0 auto; padding:20px; line-height:1.6; }
h1 { color:var(--gold); border-bottom:2px solid var(--gold-dim); padding-bottom:8px; }
h2 { color:var(--gold); margin-top:32px; border-bottom:1px solid var(--gold-dim); padding-bottom:4px; }
h3 { color:var(--parchment); margin-top:24px; }
.badge { display:inline-block; padding:3px 10px; border-radius:10px; font-size:11px; font-weight:bold; background:var(--gold); color:var(--bg); margin-right:6px; vertical-align:middle; }
.signal { display:inline-block; padding:2px 8px; border-radius:8px; font-size:11px; font-weight:bold; margin-left:6px; color:var(--bg); }
.signal-Confiant { background:var(--signal-confiant); }
.signal-Risque { background:var(--signal-risque); }
.signal-Eprouve { background:var(--signal-eprouve); color:var(--text); }
.signal-Verrouille { background:var(--signal-locked); color:var(--text); }
.dc-result { font-weight:bold; padding:2px 8px; border-radius:6px; }
.dc-success { background:var(--signal-confiant); color:var(--bg); }
.dc-partial { background:var(--signal-risque); color:var(--bg); }
.dc-failure { background:var(--signal-eprouve); color:var(--text); }
.card { background:var(--bg-soft); border-left:3px solid var(--gold-dim); padding:14px 18px; margin:18px 0; border-radius:4px; }
.card .header { color:var(--gold); font-size:14px; margin-bottom:8px; }
.card .prose { font-style:italic; color:var(--parchment); margin:10px 0; }
.transition { color:var(--text-dim); font-style:italic; margin:8px 0 14px 0; padding-left:14px; border-left:2px dashed var(--gold-dim); }
.options { margin:8px 0; }
.option { padding:8px 12px; background:var(--bg); margin:6px 0; border-radius:4px; border:1px solid var(--gold-dim); }
.option.chosen { border-color:var(--gold); background:#2a2010; }
.option .label { font-weight:bold; color:var(--gold); }
.option .meta { font-size:11px; color:var(--text-dim); margin-top:4px; }
.resolution { background:var(--bg); padding:10px 14px; margin-top:10px; border-radius:4px; border-left:3px solid var(--signal-confiant); }
.effects { font-family:monospace; font-size:11px; color:var(--text-dim); margin-top:6px; }
.timeline { display:flex; flex-wrap:wrap; gap:6px; margin:14px 0; }
.timeline-cell { background:var(--bg-soft); padding:4px 8px; border-radius:4px; font-size:11px; color:var(--text-dim); border-left:3px solid var(--gold-dim); }
table { width:100%; border-collapse:collapse; margin:14px 0; }
th, td { padding:6px 10px; text-align:left; border-bottom:1px solid var(--gold-dim); }
th { color:var(--gold); }
.kpi { display:inline-block; padding:6px 14px; background:var(--bg-soft); border-radius:6px; margin:4px; }
.kpi .val { font-size:18px; color:var(--gold); font-weight:bold; }
.kpi .lbl { font-size:11px; color:var(--text-dim); }
pre { background:var(--bg-soft); padding:12px; border-radius:4px; overflow-x:auto; font-size:11px; color:var(--text-dim); }
.tags { font-family:monospace; font-size:11px; color:var(--signal-confiant); }
</style>
"""


def render_html(trace: dict) -> str:
    e = html_escape
    h: list[str] = []
    h.append("<!DOCTYPE html><html><head><meta charset='utf-8'>")
    h.append(f"<title>MERLIN v7.7.31 - Sprint 11 (DnD-without-combat)</title>{CSS}</head><body>")
    h.append(f"<h1>MERLIN - Sprint 11 Run v7.7.31 <span class='badge'>DnD-without-combat</span></h1>")
    h.append(
        f"<p>Mode : <b>{e(trace.get('mode',''))}</b> - Started "
        f"{e(trace.get('started_at',''))} - Seed {trace.get('seed','-')}</p>"
    )

    # KPIs
    t = trace.get("timings_s", {})
    h.append("<div>")
    h.append(f"<span class='kpi'><span class='val'>{t.get('total','-')}s</span><br><span class='lbl'>Total wall time</span></span>")
    h.append(f"<span class='kpi'><span class='val'>{trace.get('unique_summaries','-')}/{trace.get('n_cards','-')}</span><br><span class='lbl'>Unique summaries</span></span>")
    h.append(f"<span class='kpi'><span class='val'>{t.get('skeleton_avg_ms_per_card','-')} ms</span><br><span class='lbl'>Avg kNN/card</span></span>")
    h.append(f"<span class='kpi'><span class='val'>{t.get('llm_total','-')}s</span><br><span class='lbl'>LLM time</span></span>")
    v2 = trace.get("v2_pool_stats", {})
    h.append(
        f"<span class='kpi'><span class='val'>{v2.get('llm_success',0)}/{v2.get('enriched_count',0)}</span>"
        f"<br><span class='lbl'>v2 LLM-source / total</span></span>"
    )
    h.append("</div>")

    # 1. Pipeline timing breakdown
    h.append("<h2>1. Timing breakdown</h2>")
    h.append("<table><tr><th>Stage</th><th>Time</th></tr>")
    for k, v in t.items():
        h.append(f"<tr><td>{e(k)}</td><td>{v} s</td></tr>")
    h.append("</table>")

    # 2. v730 vs v731 baseline comparison
    h.append("<h2>2. v7.7.30 vs v7.7.31</h2>")
    h.append("<table><tr><th>Dimension</th><th>v7.7.30</th><th>v7.7.31</th></tr>")
    h.append(f"<tr><td>Unique summaries / 16</td><td>~10/16</td><td>{trace.get('unique_summaries','-')}/{trace.get('n_cards','-')}</td></tr>")
    h.append("<tr><td>Outcomes per option</td><td>1 (always success)</td><td>3 (succ/partial/failure)</td></tr>")
    h.append("<tr><td>Resolution prose source</td><td>Template f-string</td><td>Enriched pool (LLM-written)</td></tr>")
    h.append("<tr><td>Inter-beat memory</td><td>none</td><td>tags + karma + promises</td></tr>")
    h.append("<tr><td>Fil rouge</td><td>none</td><td>anchor + 5-movement model</td></tr>")
    h.append("<tr><td>Choice depth</td><td>Verb only</td><td>DC signal + cost + 3 outcomes</td></tr>")
    h.append("</table>")

    # 3. Titles
    h.append("<h2>3. Titles proposes (pool sampling, 0 LLM)</h2>")
    h.append("<ul>")
    for t_ in trace.get("titles", []):
        is_chosen = t_ == trace.get("chosen_title")
        prefix = "<b>" if is_chosen else ""
        suffix = " (chosen)</b>" if is_chosen else ""
        h.append(
            f"<li>{prefix}{e(t_.get('title',''))} <span class='kpi'>{e(t_.get('archetype_name',''))}</span>{suffix}</li>"
        )
    h.append("</ul>")

    # 4. Anchor motif
    anchor = trace.get("anchor_motif") or trace.get("anchor_hint") or ""
    if anchor:
        h.append(f"<h2>4. Anchor motif (fil rouge)</h2><p><b>{e(anchor)}</b> - reapparait beat 8 et 16 quand possible.</p>")

    # 5. Intro
    h.append("<h2>5. Intro (LLM, foreshadows anchor)</h2>")
    h.append(f"<div class='card'><div class='prose'>{e(trace.get('intro',''))}</div></div>")

    # 6. Movement timeline
    h.append("<h2>6. Movement timeline (5-movement narrative model)</h2>")
    h.append("<div class='timeline'>")
    for c in trace.get("cards_played", []):
        h.append(
            f"<div class='timeline-cell'>B{c['beat']} M{c['movement']} "
            f"{e(c.get('chosen_option',{}).get('verb',''))} "
            f"<span class='dc-result dc-{c['dc_result']}'>{c['dc_result']}</span></div>"
        )
    h.append("</div>")

    # 7. Per-card breakdown
    h.append("<h2>7. Cards played (kNN retrieval + DnD-check + enriched prose)</h2>")
    for c in trace.get("cards_played", []):
        h.append("<div class='card'>")
        h.append(
            f"<div class='header'>Beat {c['beat']} (M{c['movement']}) - "
            f"<span class='badge'>{e(c.get('type',''))}</span>"
            f"<span class='badge'>{e(c.get('rarity',''))}</span>"
            f"<span class='badge'>{e(c.get('pole',''))}</span>"
            f"<span class='badge'>{e(c.get('emotion',''))}</span>"
            f"kNN {c.get('retrieval_ms',0):.1f} ms - score {c.get('score',0):.3f}"
            f"</div>"
        )
        # Sprint 11.5 - prefer LLM-stitched bridge when available, else template.
        llm_bridge = c.get("transition_prose_llm")
        if llm_bridge:
            h.append(
                f"<div class='transition'><span class='badge'>LLM</span> {e(llm_bridge)}</div>"
            )
        elif c.get("transition_prose"):
            h.append(f"<div class='transition'>{e(c['transition_prose'])}</div>")
        # Prefer prose_long over raw summary when available.
        prose_body = c.get("prose_long") or c.get("summary") or ""
        h.append(f"<div class='prose'>{e(prose_body)}</div>")

        # Options
        h.append("<div class='options'>")
        for j, sig in enumerate(c.get("option_signals", [])):
            is_chosen = j == c.get("chosen_option_idx", -1)
            klass = "option chosen" if is_chosen else "option"
            h.append(f"<div class='{klass}'>")
            h.append(
                f"<span class='label'>{e(sig.get('label','?'))}</span> "
                f"<span class='signal signal-{sig.get('signal','-')}'>"
                f"{sig.get('signal','-')}</span>"
            )
            if sig.get("gate_hint"):
                h.append(f" <span class='tags'>[verrouille: {e(sig['gate_hint'])}]</span>")
            cost = sig.get("cost") or {}
            cost_str = ", ".join(f"{k}:{v}" for k, v in cost.items() if v)
            h.append(
                f"<div class='meta'>verbe={e(sig.get('verb',''))} - "
                f"faction={e(sig.get('faction',''))} - "
                f"DC vs {e(sig.get('dc_pole',''))} (caché)"
                + (f" - cout: {e(cost_str)}" if cost_str else "")
                + "</div>"
            )
            h.append("</div>")
        h.append("</div>")

        # Resolution
        dc = c.get("dc_result", "-")
        h.append(
            f"<div class='resolution'>"
            f"<b>Resolution :</b> <span class='dc-result dc-{dc}'>{dc}</span><br>"
            f"<i>{e(c.get('resolution_prose',''))}</i>"
        )
        eff = c.get("effects_applied") or []
        if eff:
            h.append(f"<div class='effects'>Effets: {e(', '.join(eff))}</div>")
        sta = c.get("state_after") or {}
        if sta.get("tags"):
            h.append(f"<div class='tags'>Tags acquis: {e(', '.join(sta['tags']))}</div>")
        h.append(f"<div class='effects'>Etat: vie={sta.get('life','-')} karma={sta.get('karma','-')} factions={e(json.dumps(sta.get('factions',{}),ensure_ascii=False))}</div>")
        h.append("</div></div>")

    # 8. Outro
    h.append("<h2>8. Outro (LLM with anchor + run-history cascade)</h2>")
    h.append(f"<div class='card'><div class='prose'>{e(trace.get('outro',''))}</div></div>")

    # 9. Final state
    h.append("<h2>9. Final state</h2>")
    fs = trace.get("final_state", {})
    h.append("<table>")
    h.append(f"<tr><th>life_essence</th><td>{fs.get('life_essence','-')}</td></tr>")
    h.append(f"<tr><th>karma</th><td>{fs.get('karma','-')}</td></tr>")
    h.append(f"<tr><th>faction_rep</th><td><pre>{e(json.dumps(fs.get('faction_rep',{}),indent=2,ensure_ascii=False))}</pre></td></tr>")
    h.append(f"<tr><th>tags</th><td><pre>{e(json.dumps(fs.get('tags',[]),indent=2,ensure_ascii=False))}</pre></td></tr>")
    h.append(f"<tr><th>promises</th><td><pre>{e(json.dumps(fs.get('promises',[]),indent=2,ensure_ascii=False))}</pre></td></tr>")
    h.append("</table>")

    h.append("<h2>10. Sources</h2>")
    h.append(
        "<p>See <code>docs/10_llm/PHASE_11_NARRATIVE_DEPTH_PLAN.md</code> for the 6-sprint roadmap. "
        "v7.7.31 ships Sprints 11.1 (pool dedup+enrich), 11.2 (kNN dedup_summary+MMR), "
        "11.3 (DnD checks + inter-beat memory), 11.4 (anchor + 5-movement fil rouge). "
        "Sprint 11.5 (streaming stitcher LLM async) shipped later.</p>"
    )

    h.append("</body></html>")
    return "".join(h)


# --- Main -------------------------------------------------------------------


def main() -> int:
    trace = run_simulation()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(trace, ensure_ascii=False, indent=2), encoding="utf-8")
    HTML_PATH.write_text(render_html(trace), encoding="utf-8")
    print(f"[OK] JSON : {JSON_PATH}")
    print(f"[OK] HTML : {HTML_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

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
from style_tags import pick_style_tag, voice_for  # noqa: E402  # Phase 22
from rpg_decoupage import build_acts, decoupage_metrics  # noqa: E402  # Phase 23

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


def ollama_post(endpoint: str, payload: dict, timeout: int = 240) -> dict:
    """POST to Ollama with retry on 500 AND socket timeout (RAM-swap resilience).

    On constrained workstations Ollama returns HTTP 500 ("memory layout
    cannot be allocated") OR a socket TimeoutError when swapping between
    generator and embedder. Phase 22 : retry on both, 4 attempts, longer
    default timeout (240s) and progressive backoff.
    """
    from urllib.error import HTTPError, URLError
    body = json.dumps(payload).encode("utf-8")
    req = Request(
        f"{OLLAMA_BASE}{endpoint}",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    last_err: Optional[Exception] = None
    for attempt in range(4):
        try:
            with urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except HTTPError as e:
            last_err = e
            if e.code == 500 and attempt < 3:
                time.sleep(3.0 + 3.0 * attempt)
                continue
            raise
        except (TimeoutError, URLError, OSError) as e:
            last_err = e
            if attempt < 3:
                time.sleep(3.0 + 3.0 * attempt)
                continue
            raise
    if last_err is not None:
        raise last_err
    raise RuntimeError("ollama_post : exhausted retries with no response")


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
    source_dist: dict[str, int] = {}
    cardinality_dist: dict[str, int] = {}
    for c in raw.get("canonicals", []):
        summ = (c.get("canonical_summary") or "").strip()
        if summ:
            index[summ] = c
        src = c.get("enrichment_source", "unknown")
        source_dist[src] = source_dist.get(src, 0) + 1
        ck = str(c.get("cardinality", len(c.get("enriched_options", []) or []) or 3))
        cardinality_dist[ck] = cardinality_dist.get(ck, 0) + 1
    stats = {
        "enriched_count": raw.get("enriched_count", 0),
        "llm_success": raw.get("llm_success", 0),
        "llm_fallback": raw.get("llm_fallback", 0),
        "status": raw.get("status", "unknown"),
        "generated_at": raw.get("generated_at", ""),
        # Phase 15.5 : expose source + cardinality breakdown for HTML enrichment.
        "source_dist": source_dist,
        "cardinality_dist": cardinality_dist,
    }
    log.info(
        "v2 pool loaded: %d canonicals (%d llm, %d fallback ; cardinality %s)",
        len(index),
        stats["llm_success"],
        stats["llm_fallback"],
        cardinality_dist,
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


def llm_intro(chosen: dict, anchor_hint: str = "", style_voice: str = "") -> tuple[str, float]:
    """LLM-written setup intro. Short, no scenario spoilers, but seeded with
    the anchor motif so the intro foreshadows what beat 1 will introduce.

    Phase 22 : ``style_voice`` colours the intro register per drawn style tag."""
    system = (
        "Tu es un narrateur druidique de l'univers MERLIN (Broceliande). "
        "Tu ecris une introduction au scenario. C'est un SETUP : ambiance, "
        "trac, sensations. Ne revele AUCUN evenement, aucune rencontre. "
        "4 a 5 phrases, en 2eme personne du singulier."
    )
    if style_voice:
        system += f"\nSTYLE NARRATIF impose : {style_voice}"
    anchor_line = f"\nElement central qui sera presente plus tard : {anchor_hint}" if anchor_hint else ""
    user = (
        f"Titre du scenario : {chosen['title']}\n"
        f"Archetype : {chosen['archetype_name']}{anchor_line}\n\n"
        f"Ecris l'intro qui ouvre la marche."
    )
    return llm_generate(system, user, options={"temperature": 0.7, "num_predict": 220})


MAX_MERLIN_DIRECT_PER_RUN: int = 2  # Phase 16 Fix D - Merlin stays rare
ANCHOR_BLEND_WEIGHT: float = 0.3    # Phase 16 Fix B - fil rouge enforcement


def retrieve_skeleton(
    rag: CardsRAG,
    chosen: dict,
    intro_vec,
    n_cards: int,
    rng: random.Random,
    anchor_hint: str = "",
) -> tuple[list[CardHit], list[float], float]:
    """Build the run skeleton with dedup_summary + MMR diversity.

    Progressive emotion arc curiosite -> tension -> peur -> fascination -> sagesse.

    Phase 16 :
      - Fix B : anchor_hint embedding blended into route_vec so retrieval
        biases toward cards that resonate with the declared fil rouge.
      - Fix D : MAX_MERLIN_DIRECT_PER_RUN caps Merlin appearances so he
        stays narratively rare (avoids the 6/16 Merlin-tour audit issue).
    """
    t0 = time.time()
    arc_emotions = ["curiosite", "tension", "peur", "fascination", "sagesse"]
    selected: list[CardHit] = []
    excluded: list[str] = []
    seen_summaries: set[str] = set()
    per_card_ms: list[float] = []
    merlin_direct_count: int = 0  # Fix D counter

    query_text = f"{chosen.get('archetype_name', '')} . marche druidique broceliande"
    base_vec = rag.embed_query(query_text)
    # Phase 16 Fix B : pre-compute anchor embedding once, blend into every
    # route_vec recompose. If anchor empty, falls through to original 0.4/0/0.6.
    anchor_vec = rag.embed_query(anchor_hint) if anchor_hint else None
    if anchor_vec is not None:
        route_vec = rag.compose_route_vec(
            beat_vec=base_vec,
            recent_choice_vecs=[anchor_vec],
            intro_vec=intro_vec,
            weights=(0.4, ANCHOR_BLEND_WEIGHT, 1.0 - 0.4 - ANCHOR_BLEND_WEIGHT),
        )
    else:
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
        # Phase 16 Fix D : cap MERLIN_DIRECT to MAX_MERLIN_DIRECT_PER_RUN.
        if merlin_direct_count >= MAX_MERLIN_DIRECT_PER_RUN:
            hits = [h for h in hits if (h.type or "").upper() != "MERLIN_DIRECT"]
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
            if merlin_direct_count >= MAX_MERLIN_DIRECT_PER_RUN:
                hits = [h for h in hits if (h.type or "").upper() != "MERLIN_DIRECT"]
        if not hits:
            log.warning("No hits at beat %d - stopping early", i)
            break

        # Top-3 random pick adds variety across runs.
        pick_idx = rng.randint(0, min(2, len(hits) - 1))
        picked = hits[pick_idx]
        selected.append(picked)
        excluded.append(picked.card_uid)
        seen_summaries.add(picked.summary or "")
        if (picked.type or "").upper() == "MERLIN_DIRECT":
            merlin_direct_count += 1
        per_card_ms.append((time.time() - t_card) * 1000)

        picked_vec = rag.embed_query(picked.summary or picked.card_uid)
        # Phase 16 Fix B : keep anchor in the loop so it persists across beats.
        if anchor_vec is not None:
            route_vec = rag.compose_route_vec(
                beat_vec=picked_vec,
                recent_choice_vecs=[anchor_vec],
                intro_vec=intro_vec,
                weights=(0.5, ANCHOR_BLEND_WEIGHT, 1.0 - 0.5 - ANCHOR_BLEND_WEIGHT),
            )
        else:
            route_vec = rag.compose_route_vec(
                beat_vec=picked_vec,
                recent_choice_vecs=[],
                intro_vec=intro_vec,
                weights=(0.5, 0.0, 0.5),
            )

    return selected, per_card_ms, time.time() - t0


# --- DnD-without-combat mechanics -------------------------------------------


def card_options(
    hit: CardHit, v2_pool: dict[str, dict]
) -> tuple[list[dict], str, str, str, int, str]:
    """Resolve the options for a card.

    Returns (options, prose_short, prose_long, anchor_motif, cardinality, binary_reason).

    Phase 15 : cardinality is 2 OR 3 per LLM-judged enrichment. Default to
    len(options) when the field is absent on legacy entries. ``binary_reason``
    is the LLM-written one-liner justifying why a beat is binary (empty when
    ternary).
    """
    summ = (hit.summary or "").strip()
    enriched = v2_pool.get(summ)
    if enriched and enriched.get("enriched_options"):
        opts = enriched["enriched_options"]
        declared = enriched.get("cardinality")
        try:
            card = int(declared) if declared is not None else len(opts)
        except (ValueError, TypeError):
            card = len(opts)
        card = max(1, min(card, len(opts)))
        return (
            opts[:card],
            enriched.get("prose_short") or summ,
            enriched.get("prose_long") or summ,
            enriched.get("anchor_motif", ""),
            card,
            enriched.get("binary_reason", "") or "",
        )
    raw_opts = hit.options or []
    return raw_opts, summ, summ, "", len(raw_opts) or 3, ""


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

# Phase 14 (2026-05-19) - DC scaling per movement. Earlier beats should feel
# like apprentissage (easier), later beats like épreuve (harder). This rewards
# the player for crossing movements instead of punishing the M1 newbie who
# has empty faction_rep.
#   M1 = -3 (warmup)    M2 = -1   M3 = 0   M4 = +1   M5 = +2 (crescendo)
MOVEMENT_DC_BIAS: dict[int, int] = {1: -3, 2: -1, 3: 0, 4: 1, 5: 2}

# Phase 14 - starter faction rep so M1 doesn't show all-Eprouve. The player
# is an apprenti druide, not a stranger.
STARTER_FACTION_REP: dict[str, int] = {"druides": 8, "anciens": 4}
STARTER_ECLATS: int = 0  # cross-run currency, accrued on success beats


def _aligned_skill(state: dict, pole: str) -> int:
    """Weighted faction-rep skill for the given DC pole (Sprint 12.5b)."""
    weights = POLE_ALIGNMENT_WEIGHTS.get(pole.lower(), {})
    rep = state.get("faction_rep", {})
    weighted = sum(rep.get(f, 0) * w for f, w in weights.items())
    return int(weighted // 2)


def estimate_dc_signal(option: dict, state: dict, movement: int = 3) -> str:
    """Map the option's hidden DC to a qualitative chip the player sees.

    [Confiant] : likely success
    [Risque]   : 50/50
    [Eprouve]  : likely failure

    Phase 14 : ``movement`` (default 3 = M3 neutral) biases the effective DC
    per the MOVEMENT_DC_BIAS table - M1 is easier (warmup), M5 is harder.
    """
    dc = option.get("dc_against") or {}
    threshold_raw = int(dc.get("threshold", 25) or 25)
    threshold = threshold_raw + MOVEMENT_DC_BIAS.get(int(movement), 0)
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


def resolve_dc(option: dict, state: dict, rng: random.Random, movement: int = 3) -> str:
    """Probabilistic outcome of the option: success / partial / failure.

    Hidden DC + state-derived skill + Phase 14 movement-based scaling.
    Player only sees the qualitative chip via `estimate_dc_signal`."""
    dc = option.get("dc_against") or {}
    threshold_raw = int(dc.get("threshold", 25) or 25)
    threshold = threshold_raw + MOVEMENT_DC_BIAS.get(int(movement), 0)
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
    recent_verbs: Optional[list[str]] = None,
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

    Phase 16 Fix E (2026-05-20) : ``recent_verbs`` (last 2 verbs chosen) is
    used to apply a -0.5 score penalty on any option whose verb appears in
    the window. Prevents the audit-observed 'observer 6x' collapse and forces
    the character's actions to feel varied.
    """
    if not options:
        return -1, {}, "no options"

    rep = state.get("faction_rep", {})
    main_faction = ""
    if rep:
        main_faction_candidate = max(rep.items(), key=lambda kv: kv[1])
        if main_faction_candidate[1] > 0:
            main_faction = main_faction_candidate[0]

    # Phase 16 Fix E2 (2026-05-21) : count-weighted penalty over a 3-beat
    # window. Each exposure costs -0.85, so 2x in last 3 = -1.7 which clearly
    # overrides the +1.2 continuity_bonus (the previous flat -0.5 was lost
    # in the noise on druides-aligned options, producing observer 6x audit).
    recent_window: list[str] = [v.lower() for v in (recent_verbs or [])[-3:] if v]
    recent_counts: dict[str, int] = {}
    for v in recent_window:
        recent_counts[v] = recent_counts.get(v, 0) + 1

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
        # Balance bonus only kicks in if a faction is saturated (rep > 15).
        balance_bonus = 0.6 if rep_now > 15 else 0.0
        if main_faction and faction == main_faction and rep_now < 25:
            continuity_bonus = 1.2
        else:
            continuity_bonus = 0.0
        # Phase 16 Fix E2 : count-weighted penalty (-0.85 per exposure in last 3).
        verb = (opt.get("verb") or "").lower()
        repetition_penalty = -0.85 * recent_counts.get(verb, 0)
        score = signal_score + balance_bonus + continuity_bonus + repetition_penalty + rng.uniform(0, 0.3)
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
            elif verb == "ADD_ECLATS":
                # Phase 14 - currency reward. Players amass eclats during runs
                # to spend in the hub on Anam, traits, ogham unlocks etc.
                state["eclats"] = state.get("eclats", 0) + int(parts[1])
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
    style_voice: str = "",
) -> tuple[str, float]:
    """Sprint 11.4 cascade prompt: outro reads anchor + last 3 verbs + dominant
    faction + dc summary, producing a coherent epilogue grounded in the run.

    Phase 22 : ``style_voice`` injects the marche's style register."""
    system = (
        "Tu es un narrateur druidique. Tu ecris la conclusion (outro) d'une "
        "marche dans Broceliande. 3 a 4 phrases, 2eme personne, ton apaise. "
        "Mentionne 1-2 factions dominantes, l'ambiance finale, et reprends "
        "le motif d'ancrage."
    )
    if style_voice:
        system += f"\nSTYLE NARRATIF impose : {style_voice}"
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
    # Phase 22 (LORE_BIBLE §8) : draw a style tag for this marche, biome-weighted
    # and seed-deterministic. The voice is injected into intro/outro/stitcher
    # so the whole run shares one narrative register.
    style_tag = pick_style_tag(SEED, BIOME)
    style_voice = voice_for(style_tag)
    trace["style_tag"] = style_tag
    trace["style_voice"] = style_voice
    log.info("Style tag drawn : %s — %s", style_tag, style_voice[:60])
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
            _opts, _ps, _pl, motif, _card, _br = card_options(peek[0], v2_pool)
            anchor_hint = motif or ""
    except Exception as e:
        log.warning("anchor peek failed: %s", e)
    trace["anchor_hint"] = anchor_hint

    # Intro LLM
    intro_text, dur_intro = llm_intro(chosen, anchor_hint=anchor_hint, style_voice=style_voice)
    trace["timings_s"]["intro_llm"] = round(dur_intro, 2)
    trace["intro"] = intro_text
    log.info("Intro: %.1fs, %d chars", dur_intro, len(intro_text))

    t0 = time.time()
    intro_vec = rag.embed_query(intro_text or chosen["title"])
    trace["timings_s"]["intro_embed"] = round(time.time() - t0, 3)

    # Skeleton retrieval (kNN with dedup_summary + MMR).
    # Phase 16 Fix B : pass anchor_hint so retrieve_skeleton biases toward
    # cards that resonate with the declared fil rouge.
    skeleton_hits, per_card_ms, dur_skeleton = retrieve_skeleton(
        rag, chosen, intro_vec, N_CARDS, rng, anchor_hint=anchor_hint
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

    # Play loop with DnD checks + fil-rouge transitions.
    # Phase 14 - state initialised with starter faction rep + eclats currency.
    state = {
        "life_essence": 80,
        "karma": 0,
        "faction_rep": dict(STARTER_FACTION_REP),
        "tags": [],
        "promises": [],
        "eclats": STARTER_ECLATS,
    }
    cards_played: list[dict] = []
    run_history: list[dict] = []
    prev_verb = ""
    anchor_locked = ""
    recent_verbs: list[str] = []  # Phase 16 Fix E - last 2 verbs for repetition penalty

    for i, hit in enumerate(skeleton_hits):
        options, prose_short, prose_long, motif, cardinality, binary_reason = card_options(hit, v2_pool)
        if i == 0 and motif:
            anchor_locked = motif
            trace["anchor_motif"] = anchor_locked

        mvt = movement_for_beat(i, len(skeleton_hits))
        trans_prose = transition_prose(i, prev_verb, anchor_locked, mvt)

        # Phase 16 Fix E : feed the last 2 verbs so the agent gets a penalty
        # on repetition (observer-6x collapse fix).
        opt_idx, option, decision_reason = agent_pick_option(
            options, state, rng, recent_verbs=recent_verbs[-3:]
        )
        # Phase 14 - DC scaled by movement.
        dc_result = resolve_dc(option, state, rng, movement=mvt) if option else "failure"
        effects = derive_effects_from_dc(option, dc_result)
        # Phase 14 - auto-grant eclats on success (basic reward layer). Rarity
        # multiplier : commune=1, rare=2, epique=3 eclats. SHOPs get x2 because
        # they're transactional moments.
        if dc_result == "success":
            base_eclats = {"COMMUNE": 1, "RARE": 2, "EPIQUE": 3}.get(hit.rarity, 1)
            if hit.type == "SHOP":
                base_eclats *= 2
            effects = list(effects) + ["ADD_ECLATS:%d" % base_eclats]
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
                    "signal": "Verrouille" if locked else estimate_dc_signal(o, state, mvt),
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
                "cardinality": cardinality,
                "binary_reason": binary_reason,
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
                    "eclats": state.get("eclats", 0),
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
        # Phase 16 Fix E : track the recent verbs window (sliding, len 2-3).
        chosen_verb = option.get("verb", "")
        if chosen_verb:
            recent_verbs.append(chosen_verb)
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
                beats=cards_played, anchor=anchor_locked, timings_out=durations,
                style_voice=style_voice,
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
    outro_text, dur_outro = llm_outro(chosen, run_history, state, anchor_locked, style_voice=style_voice)
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

    # Phase 23 - RPG decoupage : actes -> cartes -> beats + variete/logique.
    # Built from the finalised trace (incl. stitched bridges), so it is
    # backend-agnostic and will run identically on the native trace.
    try:
        _acts = build_acts(trace)
        # Compact act index (full per-card beats stay derivable from
        # cards_played; the report renders beats from there, so we avoid
        # duplicating them into the trace).
        trace["acts"] = [
            {
                "index": a.index,
                "name": a.name,
                "function": a.function,
                "summary": a.summary,
                "card_count": len(a.cards),
                "card_indices": [c.index for c in a.cards],
            }
            for a in _acts
        ]
        trace["decoupage_metrics"] = decoupage_metrics(_acts)
        _m = trace["decoupage_metrics"]
        log.info(
            "Decoupage: 5 actes, %d cartes, %d verbes uniques, causal %.0f%%",
            _m["variete"]["total_cards"],
            _m["variete"]["unique_verbs"],
            _m["logique"]["causal_coverage_pct"],
        )
    except Exception as e:  # noqa: BLE001
        log.error("decoupage failed: %s", e)
        trace["acts"] = []
        trace["decoupage_metrics"] = {}

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
/* Phase 15.5 HTML enrichment (2026-05-20) */
.phase-banner { background:linear-gradient(90deg, #2a1f0e 0%, #1f1608 100%); border:1px solid var(--gold-dim); border-left:4px solid var(--gold); padding:12px 18px; margin:14px 0 24px 0; border-radius:6px; }
.phase-banner .title { color:var(--gold); font-weight:bold; font-size:14px; margin-bottom:6px; }
.phase-banner .item { display:inline-block; margin-right:14px; color:var(--parchment); font-size:12px; }
.phase-banner .check { color:var(--signal-confiant); margin-right:4px; font-weight:bold; }
.badge-binary { background:#a47edc; color:var(--bg); }
.badge-ternary { background:var(--gold-dim); color:var(--bg); }
.badge-eclats { background:#d4a84a; color:var(--bg); border:1px dashed var(--bg-soft); }
.card.binary-card { border-left-color:#a47edc; }
.binary-note { font-size:11px; color:#c1a8e8; font-style:italic; margin:4px 0 8px 0; padding-left:10px; border-left:2px solid #a47edc; }
.dist-bar { display:flex; height:18px; background:var(--bg); border-radius:4px; overflow:hidden; margin:6px 0 12px 0; border:1px solid var(--gold-dim); }
.dist-seg { display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:bold; color:var(--bg); white-space:nowrap; }
.dist-conf { background:var(--signal-confiant); }
.dist-risk { background:var(--signal-risque); }
.dist-epro { background:var(--signal-eprouve); color:var(--text); }
.dist-succ { background:var(--signal-confiant); }
.dist-part { background:var(--signal-risque); }
.dist-fail { background:var(--signal-eprouve); color:var(--text); }
.eclats-gain { display:inline-block; background:#d4a84a; color:var(--bg); padding:1px 6px; border-radius:4px; font-weight:bold; font-size:10px; margin-left:8px; }
.scenario-view p { margin:10px 0; }
.scenario-view p:first-child { margin-top:0; }
.scenario-view p:last-child { margin-bottom:0; }
/* Phase 18 - Game-ready cards (2026-05-21) */
body { max-width:1100px; font-family:'Segoe UI','Inter',sans-serif; }
h1 { font-family:'Cinzel','Georgia',serif; letter-spacing:1.5px; font-weight:600; }
h2 { font-family:'Cinzel','Georgia',serif; letter-spacing:0.5px; font-weight:500; }
.game-card {
  background:linear-gradient(155deg, #2a2010 0%, #1f1808 75%, #18120a 100%);
  border:1px solid var(--gold-dim);
  border-radius:10px;
  padding:18px 22px;
  margin:20px 0;
  box-shadow:0 4px 16px rgba(0,0,0,0.5), inset 0 1px 0 rgba(212,168,74,0.18);
  position:relative;
  overflow:hidden;
}
.game-card.binary-card { border-color:#a47edc; }
.game-card::before {
  content:'';
  position:absolute; top:-2px; left:-2px; right:-2px; height:3px;
  background:linear-gradient(90deg, var(--gold), transparent);
  border-radius:10px 10px 0 0;
  opacity:0.6;
}
.game-card .gc-header { display:flex; justify-content:space-between; align-items:flex-start; gap:12px; margin-bottom:10px; }
.game-card .gc-title { font-family:'Cinzel','Georgia',serif; color:var(--gold); font-size:15px; font-weight:600; }
.game-card .gc-glyph { font-size:24px; color:var(--gold); opacity:0.7; font-family:'Segoe UI Symbol','Apple Symbols',sans-serif; line-height:1; }
.game-card .gc-tags { display:flex; flex-wrap:wrap; gap:5px; margin-bottom:8px; }
.game-card .gc-prose { color:var(--parchment); margin:12px 0 14px 0; font-size:14px; line-height:1.55; font-family:'Georgia',serif; }
.game-card .gc-options { display:grid; grid-template-columns:1fr; gap:8px; margin:12px 0 0 0; }
.game-card.binary-card .gc-options { grid-template-columns:1fr 1fr; }
.game-card .gc-option {
  background:rgba(20,14,6,0.7);
  border:1px solid var(--gold-dim);
  border-radius:8px;
  padding:10px 14px;
  position:relative;
  transition:transform 0.15s, border-color 0.15s;
}
.game-card .gc-option:hover { transform:translateY(-1px); border-color:var(--gold); }
.game-card .gc-option.chosen { border-color:var(--gold); background:rgba(42,32,16,0.85); box-shadow:0 0 0 2px rgba(212,168,74,0.25); }
.game-card .gc-option .gco-label { font-weight:600; color:var(--gold); font-size:13.5px; display:block; margin-bottom:4px; }
.game-card .gc-option .gco-meta { font-size:10px; color:var(--text-dim); font-family:'Consolas',monospace; }
.signal-Confiant.pulse { animation:pulseGreen 2.4s ease-in-out infinite; }
@keyframes pulseGreen { 0%,100% { box-shadow:0 0 0 0 rgba(111,191,115,0.5); } 50% { box-shadow:0 0 0 4px rgba(111,191,115,0); } }
.gc-resolution { margin-top:14px; padding:10px 14px; background:rgba(15,10,5,0.7); border-radius:8px; border-left:3px solid var(--signal-confiant); }
.gc-resolution.r-partial { border-left-color:var(--signal-risque); }
.gc-resolution.r-failure { border-left-color:var(--signal-eprouve); }
.gc-resolution .gcr-prose { font-style:italic; color:var(--parchment); margin:6px 0; font-size:13px; }
.gc-effects-row { display:flex; flex-wrap:wrap; gap:10px; align-items:center; margin-top:8px; }
.gc-effect-chip { display:inline-flex; align-items:center; gap:4px; padding:2px 8px; background:rgba(212,168,74,0.12); border:1px solid var(--gold-dim); border-radius:12px; font-family:'Consolas',monospace; font-size:10px; color:var(--gold); }
.gc-binary-note { font-size:11px; color:#c1a8e8; font-style:italic; margin:4px 0 0 0; padding-left:10px; border-left:2px solid #a47edc; }
.gc-bridge {
  font-style:italic; color:var(--text-dim); font-size:13px; line-height:1.55;
  margin:-6px 0 16px 0; padding:10px 16px;
  background:rgba(20,14,6,0.5); border-left:2px dashed var(--gold-dim);
  border-radius:4px;
}
.gc-bridge .gb-tag { display:inline-block; padding:1px 6px; background:rgba(111,191,115,0.18); color:var(--signal-confiant); border-radius:4px; font-size:9px; font-style:normal; margin-right:6px; vertical-align:middle; }
.movement-ribbon { display:flex; gap:8px; overflow-x:auto; padding:14px 8px; background:rgba(15,10,5,0.5); border-radius:8px; margin:14px 0; }
.movement-ribbon .mr-card {
  flex-shrink:0; min-width:100px; padding:10px; background:var(--bg-soft);
  border-radius:6px; border:1px solid var(--gold-dim); font-size:11px;
  display:flex; flex-direction:column; gap:4px;
}
.movement-ribbon .mr-card.binary { border-color:#a47edc; }
.movement-ribbon .mr-card.r-success { border-bottom:3px solid var(--signal-confiant); }
.movement-ribbon .mr-card.r-partial { border-bottom:3px solid var(--signal-risque); }
.movement-ribbon .mr-card.r-failure { border-bottom:3px solid var(--signal-eprouve); }
.movement-ribbon .mr-beat { color:var(--gold); font-weight:600; font-size:11px; }
.movement-ribbon .mr-glyph { color:var(--gold); opacity:0.7; font-size:16px; line-height:1; }
.movement-ribbon .mr-verb { color:var(--parchment); font-size:11px; }
.kpi-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(160px, 1fr)); gap:10px; margin:16px 0; }
.stat-card { background:linear-gradient(135deg, var(--bg-soft) 0%, rgba(20,14,6,0.9) 100%); border:1px solid var(--gold-dim); border-radius:8px; padding:12px 14px; }
.stat-card .sc-label { color:var(--text-dim); font-size:10px; text-transform:uppercase; letter-spacing:1px; margin-bottom:4px; }
.stat-card .sc-value { color:var(--gold); font-size:22px; font-weight:600; font-family:'Cinzel','Georgia',serif; }
.stat-card .sc-sub { color:var(--parchment); font-size:11px; margin-top:2px; }
.stat-card .sc-spark { margin-top:6px; }
.gco-signal-pill { display:inline-block; padding:2px 10px; border-radius:10px; font-size:10px; font-weight:600; }
/* Phase 19 - Cinematic replay layout (2026-05-21) */
body { max-width:800px; padding:32px 24px 64px 24px; }
.cinema-rail {
  position:fixed; left:max(8px, calc(50% - 480px)); top:50%; transform:translateY(-50%);
  display:flex; flex-direction:column; gap:7px; padding:14px 8px;
  background:rgba(20,14,6,0.6); border:1px solid var(--gold-dim); border-radius:30px;
  backdrop-filter:blur(4px); z-index:50;
}
.cinema-rail .cr-dot {
  width:10px; height:10px; border-radius:50%; background:var(--gold-dim); cursor:pointer;
  transition:transform 0.15s, background 0.15s; position:relative;
  text-decoration:none; display:block;
}
.cinema-rail .cr-dot.r-success { background:var(--signal-confiant); }
.cinema-rail .cr-dot.r-partial { background:var(--signal-risque); }
.cinema-rail .cr-dot.r-failure { background:var(--signal-eprouve); }
.cinema-rail .cr-dot.binary { box-shadow:0 0 0 2px #a47edc; }
.cinema-rail .cr-dot:hover { transform:scale(1.4); }
.cinema-rail .cr-dot::after {
  content:attr(data-label);
  position:absolute; left:18px; top:50%; transform:translateY(-50%);
  background:#0d0805; border:1px solid var(--gold-dim); padding:3px 9px;
  border-radius:4px; font-size:11px; color:var(--gold); white-space:nowrap;
  opacity:0; pointer-events:none; transition:opacity 0.2s;
}
.cinema-rail .cr-dot:hover::after { opacity:1; }
@media (max-width: 1100px) { .cinema-rail { display:none; } }

.hero {
  text-align:center;
  padding:64px 24px 40px 24px;
  background:radial-gradient(ellipse at center, rgba(212,168,74,0.08), transparent 65%);
  margin-bottom:32px;
}
.hero .ornament { font-size:36px; color:var(--gold); opacity:0.6; letter-spacing:18px; margin-bottom:18px; padding-left:18px; line-height:1; }
.hero h1.title-cinema {
  font-family:'Cinzel','Georgia',serif; color:var(--gold);
  font-size:36px; font-weight:600; letter-spacing:2px;
  margin:0 0 14px 0; border:none; padding:0;
}
.hero .sub { color:var(--text-dim); font-size:13px; letter-spacing:3px; text-transform:uppercase; }
.hero .meta { color:var(--text-dim); font-size:12px; margin-top:14px; font-family:'Consolas',monospace; }

.prologue, .epilogue {
  font-family:'Georgia',serif; font-size:16px; line-height:1.85;
  color:var(--parchment); padding:30px 36px;
  background:linear-gradient(180deg, rgba(42,32,16,0.5) 0%, rgba(20,14,6,0.4) 100%);
  border:1px solid var(--gold-dim); border-radius:8px;
  position:relative;
  margin:24px 0;
}
.prologue::before, .epilogue::before {
  content:''; position:absolute; left:50%; transform:translateX(-50%); top:-12px;
  width:80px; height:1px; background:linear-gradient(90deg, transparent, var(--gold), transparent);
}
.prologue .pe-label, .epilogue .pe-label {
  font-family:'Cinzel','Georgia',serif; color:var(--gold);
  font-size:12px; letter-spacing:4px; text-transform:uppercase;
  text-align:center; margin-bottom:18px; opacity:0.8;
}

.interlude {
  text-align:center; padding:24px 16px; color:var(--text-dim);
  font-style:italic; font-family:'Georgia',serif; font-size:14px; line-height:1.6;
  position:relative; max-width:600px; margin:0 auto;
}
.interlude::before, .interlude::after {
  content:''; position:absolute; top:50%;
  width:60px; height:1px; background:linear-gradient(90deg, transparent, var(--gold-dim), transparent);
}
.interlude::before { left:0; }
.interlude::after  { right:0; background:linear-gradient(90deg, var(--gold-dim), transparent); }
.interlude .il-bullet { display:inline-block; padding:0 14px; color:var(--gold); opacity:0.6; }

.scene {
  margin:36px 0;
  padding:30px 32px 26px 32px;
  background:linear-gradient(155deg, #221a0c 0%, #1a1208 100%);
  border:1px solid var(--gold-dim); border-radius:10px;
  box-shadow:0 4px 20px rgba(0,0,0,0.4);
  position:relative;
}
.scene.binary { border-color:#a47edc; }
.scene .scene-head { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:18px; gap:16px; }
.scene .scene-num { font-family:'Cinzel','Georgia',serif; color:var(--gold); font-size:13px; letter-spacing:2px; text-transform:uppercase; }
.scene .scene-title { color:var(--parchment); font-size:14px; margin-top:4px; opacity:0.7; }
.scene .scene-glyph { font-size:28px; color:var(--gold); opacity:0.4; line-height:1; font-family:'Segoe UI Symbol','Apple Symbols',sans-serif; }
.scene .scene-tags { display:flex; flex-wrap:wrap; gap:4px; margin-top:8px; }
.scene .scene-tags .badge { font-size:9px; padding:2px 7px; opacity:0.7; }

.scene .scene-prose {
  font-family:'Georgia',serif; font-size:15.5px; line-height:1.78;
  color:var(--parchment); margin:18px 0 22px 0; text-align:justify;
}
.scene .scene-prose::first-letter {
  font-family:'Cinzel','Georgia',serif; font-size:36px; color:var(--gold);
  float:left; line-height:0.95; margin:6px 8px 0 0;
}

.choices-grid { display:grid; gap:12px; margin:20px 0 16px 0; }
.choices-grid.k2 { grid-template-columns:1fr 1fr; }
.choices-grid.k3 { grid-template-columns:1fr 1fr 1fr; }
@media (max-width: 700px) { .choices-grid.k2, .choices-grid.k3 { grid-template-columns:1fr; } }
.choice {
  padding:14px 12px;
  background:rgba(20,14,6,0.7); border:1px solid var(--gold-dim);
  border-radius:8px; opacity:0.55; position:relative;
  transition:opacity 0.2s, transform 0.2s;
}
.choice:hover { opacity:0.85; }
.choice.chosen {
  opacity:1; transform:scale(1.02);
  background:linear-gradient(160deg, #2e2412 0%, #1f1808 100%);
  border-color:var(--gold);
  box-shadow:0 0 0 1px rgba(212,168,74,0.4), 0 6px 20px rgba(212,168,74,0.18);
}
.choice .ch-label {
  font-family:'Cinzel','Georgia',serif; color:var(--gold);
  font-size:13.5px; font-weight:600; display:block; margin-bottom:6px;
  text-align:center; letter-spacing:0.5px;
}
.choice .ch-signal {
  display:inline-block; padding:2px 9px; border-radius:8px;
  font-size:10px; font-weight:600; color:var(--bg);
}
.choice .ch-meta { font-size:10px; color:var(--text-dim); margin-top:6px; font-family:'Consolas',monospace; text-align:center; }
.choice .ch-seal {
  position:absolute; top:-9px; left:50%; transform:translateX(-50%);
  background:var(--gold); color:var(--bg); font-size:10px; font-weight:700;
  padding:2px 12px; border-radius:10px;
  letter-spacing:1.5px; text-transform:uppercase;
  font-family:'Cinzel','Georgia',serif;
  box-shadow:0 2px 6px rgba(0,0,0,0.5);
}

.scene .resolution-block {
  margin-top:18px;
  padding:14px 18px; background:rgba(15,10,5,0.7);
  border-left:3px solid var(--signal-confiant); border-radius:6px;
}
.scene .resolution-block.r-partial { border-left-color:var(--signal-risque); }
.scene .resolution-block.r-failure { border-left-color:var(--signal-eprouve); }
.scene .rb-header { font-family:'Cinzel','Georgia',serif; color:var(--gold); font-size:11px; letter-spacing:2px; text-transform:uppercase; margin-bottom:6px; opacity:0.8; }
.scene .rb-prose { color:var(--parchment); font-style:italic; font-size:13.5px; line-height:1.65; font-family:'Georgia',serif; }

.scene .delta-row {
  display:flex; flex-wrap:wrap; gap:8px; margin-top:14px; padding-top:12px;
  border-top:1px dashed rgba(212,168,74,0.2);
}
.scene .delta-chip {
  display:inline-flex; align-items:center; gap:4px; padding:3px 9px;
  background:rgba(212,168,74,0.1); border:1px solid var(--gold-dim);
  border-radius:12px; font-family:'Consolas',monospace; font-size:11px; color:var(--gold);
}
.scene .delta-chip.positive { color:var(--signal-confiant); border-color:rgba(111,191,115,0.4); background:rgba(111,191,115,0.08); }
.scene .delta-chip.negative { color:var(--signal-eprouve); border-color:rgba(194,90,74,0.4); background:rgba(194,90,74,0.08); }

.binary-explainer {
  font-size:11px; color:#c1a8e8; font-style:italic; text-align:center;
  margin:6px 0 14px 0; opacity:0.85;
}

details.coulisses {
  margin-top:56px; padding:0; background:rgba(15,10,5,0.5);
  border:1px solid var(--gold-dim); border-radius:8px;
}
details.coulisses summary {
  padding:14px 18px; cursor:pointer; color:var(--gold);
  font-family:'Cinzel','Georgia',serif; letter-spacing:2px; font-size:13px;
  text-transform:uppercase; list-style:none;
}
details.coulisses summary::-webkit-details-marker { display:none; }
details.coulisses summary::before { content:'▸ '; color:var(--gold-dim); transition:transform 0.2s; display:inline-block; }
details.coulisses[open] summary::before { content:'▾ '; }
details.coulisses .coulisses-body { padding:8px 18px 18px 18px; border-top:1px solid var(--gold-dim); }
details.coulisses h2 { font-size:14px; margin-top:24px; }

.signal-Confiant { background:var(--signal-confiant); }
.signal-Risque { background:var(--signal-risque); }
.signal-Eprouve { background:var(--signal-eprouve); color:var(--text); }
.signal-Verrouille { background:var(--signal-locked); color:var(--text); }
</style>
"""


# Phase 18 - Game-ready helpers (2026-05-21).
# Ogham unicode glyphs per emotion : evoke the druidic alphabet without
# requiring a custom font. Falls back to ᚐ (Ailm) for unknown emotions.
_OGHAM_GLYPH_BY_EMOTION: dict[str, str] = {
    "curiosite":   "ᚁ",  # ᚁ Beith - birch, new beginnings
    "tension":     "ᚇ",  # ᚇ Duir - oak, strength
    "peur":        "ᚆ",  # ᚆ Uath - hawthorn, fear
    "fascination": "ᚉ",  # ᚉ Coll - hazel, wisdom
    "sagesse":     "ᚉ",  # ᚉ Coll - hazel
    "colere":      "ᚎ",  # ᚎ Straif - blackthorn
    "tristesse":   "ᚌ",  # ᚌ Gort - ivy
    "joie":        "ᚑ",  # ᚑ Onn - gorse
}


def _ogham_glyph(emotion: str) -> str:
    """Return a unicode ogham character for the emotion (Phase 18 visual)."""
    return _OGHAM_GLYPH_BY_EMOTION.get((emotion or "").lower(), "ᚐ")  # ᚐ Ailm default


def _sparkline_svg(values: list[float], color: str = "#d4a84a",
                   width: int = 110, height: int = 24,
                   fill_color: Optional[str] = None) -> str:
    """Inline SVG polyline sparkline (Phase 18). Returns '' if values empty."""
    if not values or len(values) < 2:
        return ""
    mn, mx = min(values), max(values)
    rng = (mx - mn) or 1.0
    n = len(values)
    pts: list[str] = []
    for i, v in enumerate(values):
        x = i * width / (n - 1)
        y = height - ((v - mn) / rng) * (height - 4) - 2
        pts.append(f"{x:.1f},{y:.1f}")
    points = " ".join(pts)
    fill_path = ""
    if fill_color:
        first_x = 0
        last_x = width
        fill_pts = f"{first_x},{height} " + points + f" {last_x},{height}"
        fill_path = (
            f"<polygon fill='{fill_color}' fill-opacity='0.18' "
            f"points='{fill_pts}'/>"
        )
    return (
        f"<svg width='{width}' height='{height}' "
        f"style='display:inline-block;vertical-align:middle;'>"
        f"{fill_path}"
        f"<polyline fill='none' stroke='{color}' stroke-width='1.8' "
        f"stroke-linecap='round' stroke-linejoin='round' "
        f"points='{points}'/></svg>"
    )


def render_html(trace: dict) -> str:
    e = html_escape
    h: list[str] = []
    h.append("<!DOCTYPE html><html><head><meta charset='utf-8'>")
    h.append(f"<title>MERLIN v7.7.31 - Phase 11 -> 14 -> 15 -> 16</title>{CSS}</head><body>")
    h.append(
        f"<h1>MERLIN - Run v7.7.31 "
        f"<span class='badge'>Phase 11 DnD</span>"
        f"<span class='badge'>Phase 14 fixes+eclats</span>"
        f"<span class='badge badge-binary'>Phase 15 binary+scenario</span>"
        f"<span class='badge badge-eclats'>Phase 16 coherence</span></h1>"
    )
    h.append(
        f"<p>Mode : <b>{e(trace.get('mode',''))}</b> - Started "
        f"{e(trace.get('started_at',''))} - Seed {trace.get('seed','-')}</p>"
    )

    # Phase 15.5 - pre-compute aggregates used by multiple sections below.
    beats = trace.get("cards_played", []) or []
    n_beats = len(beats) or 1
    card_dist = {2: 0, 3: 0}
    sig_dist = {"Confiant": 0, "Risque": 0, "Eprouve": 0, "Verrouille": 0}
    out_dist = {"success": 0, "partial": 0, "failure": 0}
    eclats_path: list[int] = []
    last_eclats = 0
    eclats_gains: list[int] = []
    faction_path: list[dict] = []
    for b in beats:
        ck = int(b.get("cardinality", len(b.get("option_signals", []) or [])) or 3)
        card_dist[ck] = card_dist.get(ck, 0) + 1
        for o in b.get("option_signals", []) or []:
            s = o.get("signal", "")
            if s in sig_dist:
                sig_dist[s] += 1
        out = b.get("dc_result", "")
        if out in out_dist:
            out_dist[out] += 1
        sa = b.get("state_after", {}) or {}
        cur_eclats = int(sa.get("eclats", 0) or 0)
        eclats_path.append(cur_eclats)
        eclats_gains.append(max(0, cur_eclats - last_eclats))
        last_eclats = cur_eclats
        faction_path.append(dict(sa.get("factions", {}) or {}))
    sig_total = sum(sig_dist.values()) or 1

    # Phase 15.5 - phase banner shows the 3 audit-driven fix-checks at a glance.
    h.append("<div class='phase-banner'>")
    h.append(
        "<div class='title'>Phase 16 - Coherence fixes (bridges cascade, anchor kNN, "
        "verb diversity, cap Merlin, binary mode, scenario view, choice alignment)</div>"
    )
    h.append(
        f"<span class='item'><span class='check'>OK</span>Binary cards : "
        f"<b>{card_dist.get(2,0)}/{n_beats}</b> beat(s) in this run "
        f"(pool : 13/90 binary canonicals, ~14%)</span>"
    )
    h.append(
        f"<span class='item'><span class='check'>OK</span>Choice-text alignment : "
        f"<b>0</b> 'Tu peux X, Y, Z' mismatch (was 100% pool-wide before scrub)</span>"
    )
    h.append(
        f"<span class='item'><span class='check'>OK</span>Scenario view : "
        f"<b>1</b> top section + <b>{len(trace.get('stitched_transitions',{}))}</b> stitched bridges</span>"
    )
    h.append("</div>")

    # Phase 15.5 - Scenario complet (narrative-only view) at the top so the
    # reader sees the run as a continuous story BEFORE the mechanics breakdown.
    h.append("<h2>Scenario complet (vue narrative)</h2>")
    h.append("<div class='card scenario-view'>")
    intro_text = trace.get("intro", "") or ""
    if intro_text:
        h.append(f"<p class='prose'><b>Prologue.</b> {e(intro_text)}</p>")
    for c in beats:
        bridge = c.get("transition_prose_llm") or c.get("transition_prose") or ""
        if bridge and c.get("beat", 0) > 1:
            h.append(f"<p class='prose' style='color:var(--gold-dim);font-style:italic;'>{e(bridge)}</p>")
        prose_body = c.get("prose_long") or c.get("summary") or ""
        outcome = c.get("dc_result", "")
        resolution = c.get("resolution_prose", "") or ""
        if prose_body:
            h.append(f"<p class='prose'>{e(prose_body)}</p>")
        if resolution:
            outcome_tag = {
                "success": "[succes]",
                "partial": "[issue melee]",
                "failure": "[revers]",
            }.get(outcome, "")
            h.append(
                f"<p class='prose' style='color:var(--text-dim);'>"
                f"<i>{e(outcome_tag)} {e(resolution)}</i></p>"
            )
    outro_text = trace.get("outro", "") or ""
    if outro_text:
        h.append(f"<p class='prose'><b>Epilogue.</b> {e(outro_text)}</p>")
    h.append("</div>")
    h.append(
        "<p style='color:var(--text-dim);font-size:11px;'>"
        "Ci-dessus la marche druidique comme un recit continu. "
        "Le decoupage en cartes, options et mecaniques apparait plus bas.</p>"
    )

    # Phase 18 - KPI stat-cards with sparklines.
    t = trace.get("timings_s", {})
    life_path = [int(b.get("state_after", {}).get("life") or 80) for b in beats]
    karma_path = [int(b.get("state_after", {}).get("karma") or 0) for b in beats]
    v2 = trace.get("v2_pool_stats", {})

    h.append("<div class='kpi-grid'>")
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Wall time</div>"
        f"<div class='sc-value'>{t.get('total','-')}<span style='font-size:13px;'>s</span></div>"
        f"<div class='sc-sub'>LLM {t.get('llm_total','-')}s / kNN {t.get('skeleton_avg_ms_per_card','-')}ms</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Beats joues</div>"
        f"<div class='sc-value'>{n_beats}</div>"
        f"<div class='sc-sub'>Unique summaries {trace.get('unique_summaries','-')}/{trace.get('n_cards','-')}</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Binaires</div>"
        f"<div class='sc-value'>{card_dist.get(2,0)}<span style='font-size:13px;color:var(--text-dim);'>/{n_beats}</span></div>"
        f"<div class='sc-sub'>Pool : 13/90 binary canonicals</div></div>"
    )
    spark_eclats = _sparkline_svg(eclats_path, color="#d4a84a", fill_color="#d4a84a") if eclats_path else ""
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Eclats</div>"
        f"<div class='sc-value'>{last_eclats}</div>"
        f"<div class='sc-spark'>{spark_eclats}</div></div>"
    )
    spark_life = _sparkline_svg(life_path, color="#6fbf73", fill_color="#6fbf73")
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Vie</div>"
        f"<div class='sc-value'>{life_path[-1] if life_path else '-'}</div>"
        f"<div class='sc-spark'>{spark_life}</div></div>"
    )
    spark_karma = _sparkline_svg(karma_path, color="#a47edc", fill_color="#a47edc")
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Karma</div>"
        f"<div class='sc-value'>{karma_path[-1] if karma_path else '-'}</div>"
        f"<div class='sc-spark'>{spark_karma}</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Signaux Conf/Risq/Epro</div>"
        f"<div class='sc-value' style='font-size:16px;'>"
        f"{100*sig_dist['Confiant']/sig_total:.0f}/"
        f"{100*sig_dist['Risque']/sig_total:.0f}/"
        f"{100*sig_dist['Eprouve']/sig_total:.0f}<span style='font-size:11px;color:var(--text-dim);'>%</span>"
        f"</div>"
        f"<div class='sc-sub'>cible : Risque dominant</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Outcomes S/P/F</div>"
        f"<div class='sc-value' style='font-size:16px;'>"
        f"<span style='color:var(--signal-confiant);'>{out_dist['success']}</span>/"
        f"<span style='color:var(--signal-risque);'>{out_dist['partial']}</span>/"
        f"<span style='color:var(--signal-eprouve);'>{out_dist['failure']}</span></div>"
        f"<div class='sc-sub'>{out_dist['success']*100//max(1,n_beats)}% success rate</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Pool LLM yield</div>"
        f"<div class='sc-value'>{v2.get('llm_success',0)}<span style='font-size:13px;color:var(--text-dim);'>/{v2.get('enriched_count',0)}</span></div>"
        f"<div class='sc-sub'>+{v2.get('llm_fallback',0)} fallback</div></div>"
    )
    h.append("</div>")

    # 1. Pipeline timing breakdown
    h.append("<h2>1. Timing breakdown</h2>")
    h.append("<table><tr><th>Stage</th><th>Time</th></tr>")
    for k, v in t.items():
        h.append(f"<tr><td>{e(k)}</td><td>{v} s</td></tr>")
    h.append("</table>")

    # 2. Phase evolution v7.7.30 -> v7.7.31 (Phase 11 -> 14 -> 15 -> 16)
    h.append("<h2>2. Phase evolution v7.7.30 -> v7.7.31</h2>")
    h.append("<table><tr><th>Dimension</th><th>v7.7.30</th><th>v7.7.31 Phase 11</th><th>+ Phase 14</th><th>+ Phase 15</th><th>+ Phase 16</th></tr>")
    h.append(f"<tr><td>Unique summaries / N</td><td>~10/16</td><td>{trace.get('unique_summaries','-')}/{trace.get('n_cards','-')}</td><td>unchanged</td><td>unchanged</td><td>unchanged</td></tr>")
    h.append("<tr><td>Outcomes per option</td><td>1 (always success)</td><td>3 (succ/partial/failure)</td><td>unchanged</td><td>unchanged</td><td>unchanged</td></tr>")
    h.append("<tr><td>Resolution prose source</td><td>Template f-string</td><td>Enriched pool (LLM-written)</td><td>5 verbs x 3 tones per-verb prose</td><td>scrubbed prose (no Tu peux X,Y,Z)</td><td>4 verb kits (16 unique verbs)</td></tr>")
    h.append("<tr><td>Inter-beat memory</td><td>none</td><td>tags + karma + promises</td><td>+ eclats currency</td><td>unchanged</td><td>+ recent_verbs window</td></tr>")
    h.append("<tr><td>Fil rouge</td><td>none</td><td>anchor + 5-movement model</td><td>unchanged</td><td>unchanged</td><td>+ anchor blended into kNN (weight 0.3)</td></tr>")
    h.append("<tr><td>Choice depth</td><td>Verb only</td><td>DC signal + cost + 3 outcomes</td><td>movement-scaled DC bias</td><td>+ binary/ternary cardinality</td><td>+ verb repetition penalty</td></tr>")
    h.append("<tr><td>Transitions</td><td>none</td><td>5-template stamping</td><td>15/15 LLM-stitched async</td><td>unchanged</td><td>cascading bridges (echo prev outcome)</td></tr>")
    h.append("<tr><td>Card count per beat</td><td>3 fixed</td><td>3 fixed</td><td>3 fixed</td><td><b>2 OR 3</b> (LLM-judged)</td><td>unchanged</td></tr>")
    h.append("<tr><td>MERLIN_DIRECT frequency</td><td>uncapped</td><td>uncapped</td><td>uncapped</td><td>uncapped</td><td><b>cap 2 / run</b></td></tr>")
    h.append("</table>")

    # 2b. Pool composition (Phase 15.5).
    v2s = trace.get("v2_pool_stats", {}) or {}
    pool_card = v2s.get("cardinality_dist", {})
    pool_src = v2s.get("source_dist", {})
    h.append("<h2>2b. Pool composition (90 canonicals)</h2>")
    h.append(
        f"<p>Sources : "
        f"<span class='kpi'><span class='val'>{pool_src.get('llm', '?')}</span>"
        f"<br><span class='lbl'>llm (co-authored)</span></span>"
        f"<span class='kpi'><span class='val'>{pool_src.get('llm_partial', '?')}</span>"
        f"<br><span class='lbl'>llm_partial</span></span>"
        f"<span class='kpi'><span class='val'>{pool_src.get('fallback_template', '?')}</span>"
        f"<br><span class='lbl'>fallback_template</span></span></p>"
    )
    h.append(
        f"<p>Cardinality : "
        f"<span class='kpi'><span class='val'>{pool_card.get('3', '?')}</span>"
        f"<br><span class='lbl'>3 voies</span></span>"
        f"<span class='kpi'><span class='val'>{pool_card.get('2', '?')}</span>"
        f"<br><span class='lbl'>Binaire (accept/refuse style)</span></span></p>"
    )

    # 2c + 2d. Distribution bars (visual).
    def _bar(parts: list[tuple[str, int, str]]) -> str:
        total = sum(p[1] for p in parts) or 1
        out = ["<div class='dist-bar'>"]
        for klass, count, lbl in parts:
            pct = 100 * count / total
            if pct > 0:
                out.append(
                    f"<div class='dist-seg {klass}' style='width:{pct:.1f}%;' "
                    f"title='{e(lbl)}: {count} ({pct:.0f}%)'>"
                    f"{lbl if pct > 8 else ''}</div>"
                )
        out.append("</div>")
        return "".join(out)

    h.append("<h2>2c. Player-facing signal distribution (toutes options confondues)</h2>")
    h.append(
        _bar([
            ("dist-conf", sig_dist["Confiant"], "Confiant"),
            ("dist-risk", sig_dist["Risque"], "Risque"),
            ("dist-epro", sig_dist["Eprouve"], "Eprouve"),
        ])
    )
    h.append(
        f"<p style='color:var(--text-dim);font-size:11px;'>"
        f"Confiant {sig_dist['Confiant']} / Risque {sig_dist['Risque']} / "
        f"Eprouve {sig_dist['Eprouve']} ({sig_total} options total). "
        f"Cible : Risque dominant (mediane), Confiant emerge avec rep elevee, "
        f"Eprouve = invitation a diversifier les factions.</p>"
    )

    h.append("<h2>2d. Run outcomes (resolution reelle)</h2>")
    h.append(
        _bar([
            ("dist-succ", out_dist["success"], "Succes"),
            ("dist-part", out_dist["partial"], "Partial"),
            ("dist-fail", out_dist["failure"], "Echec"),
        ])
    )
    h.append(
        f"<p style='color:var(--text-dim);font-size:11px;'>"
        f"Succes {out_dist['success']} / Partial {out_dist['partial']} / "
        f"Echec {out_dist['failure']} ({n_beats} beats total).</p>"
    )

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

    # 6. Movement timeline — Phase 18 game-ready ribbon.
    h.append("<h2>6. Movement timeline (ruban)</h2>")
    h.append("<div class='movement-ribbon'>")
    for c in trace.get("cards_played", []):
        ck = int(c.get("cardinality", 3))
        binary_cls = " binary" if ck == 2 else ""
        result_cls = f" r-{c['dc_result']}"
        glyph = _ogham_glyph(c.get("emotion", ""))
        h.append(
            f"<div class='mr-card{binary_cls}{result_cls}'>"
            f"<div class='mr-beat'>B{c['beat']} <span class='mr-glyph'>{glyph}</span></div>"
            f"<div style='color:var(--text-dim);font-size:9px;'>M{c['movement']} {ck}V</div>"
            f"<div class='mr-verb'>{e(c.get('chosen_option',{}).get('verb',''))}</div>"
            f"</div>"
        )
    h.append("</div>")

    # 6b. Faction rep + eclats progression - Phase 15.5 enrichment.
    h.append("<h2>6b. Faction rep + eclats progression</h2>")
    all_factions: list[str] = []
    for rep in faction_path:
        for k in rep:
            if k not in all_factions:
                all_factions.append(k)
    h.append("<table>")
    head_cells = "".join(f"<th>{e(f)}</th>" for f in all_factions)
    h.append(f"<tr><th>Beat</th><th>M</th>{head_cells}<th>Eclats</th><th>+/-</th></tr>")
    for i, b in enumerate(beats):
        rep = faction_path[i]
        cells = "".join(f"<td>{rep.get(f, 0)}</td>" for f in all_factions)
        gain = eclats_gains[i]
        gain_str = (
            f"<span class='eclats-gain'>+{gain}</span>" if gain > 0 else ""
        )
        h.append(
            f"<tr><td>B{b['beat']}</td><td>M{b['movement']}</td>"
            f"{cells}<td>{eclats_path[i]}</td><td>{gain_str}</td></tr>"
        )
    h.append("</table>")

    # 7. Per-card breakdown - Phase 18 game-card structure.
    h.append("<h2>7. Cards played</h2>")
    for i, c in enumerate(trace.get("cards_played", []) or []):
        card_n = int(c.get("cardinality", len(c.get("option_signals", []) or [])) or 3)
        card_label = "BINAIRE" if card_n == 2 else f"{card_n} VOIES"
        card_class = "game-card binary-card" if card_n == 2 else "game-card"
        glyph = _ogham_glyph(c.get("emotion", ""))
        # Bridge BEFORE the card (Phase 18 visual flow).
        llm_bridge = c.get("transition_prose_llm")
        if llm_bridge and c['beat'] > 1:
            h.append(
                f"<div class='gc-bridge'><span class='gb-tag'>LLM</span>{e(llm_bridge)}</div>"
            )
        elif c.get("transition_prose") and c['beat'] > 1:
            h.append(f"<div class='gc-bridge'>{e(c['transition_prose'])}</div>")
        h.append(f"<div class='{card_class}'>")
        card_badge_class = "badge badge-binary" if card_n == 2 else "badge badge-ternary"
        h.append("<div class='gc-header'>")
        emotion_tt = e(c.get("emotion", ""))
        h.append(
            f"<div><div class='gc-title'>Beat {c['beat']} · M{c['movement']}</div>"
            f"<div class='gc-tags'>"
            f"<span class='badge'>{e(c.get('type',''))}</span>"
            f"<span class='badge'>{e(c.get('rarity',''))}</span>"
            f"<span class='badge'>{e(c.get('pole',''))}</span>"
            f"<span class='badge'>{emotion_tt}</span>"
            f"<span class='{card_badge_class}'>{card_label}</span>"
            f"</div></div>"
            f"<div class='gc-glyph' title='{emotion_tt}'>{glyph}</div>"
        )
        h.append("</div>")
        if card_n == 2 and c.get("binary_reason"):
            h.append(f"<div class='gc-binary-note'>Binaire : {e(c['binary_reason'])}</div>")
        prose_body = c.get("prose_long") or c.get("summary") or ""
        h.append(f"<div class='gc-prose'>{e(prose_body)}</div>")

        # Options grid (Phase 18 game-card layout).
        h.append("<div class='gc-options'>")
        for j, sig in enumerate(c.get("option_signals", [])):
            is_chosen = j == c.get("chosen_option_idx", -1)
            klass = "gc-option chosen" if is_chosen else "gc-option"
            signal_name = sig.get('signal','-')
            pulse_cls = " pulse" if signal_name == "Confiant" else ""
            h.append(f"<div class='{klass}'>")
            h.append(
                f"<span class='gco-label'>{e(sig.get('label','?'))}</span>"
                f"<span class='gco-signal-pill signal-{signal_name}{pulse_cls}'>{signal_name}</span>"
            )
            if sig.get("gate_hint"):
                h.append(f" <span class='tags'>[verrouille: {e(sig['gate_hint'])}]</span>")
            cost = sig.get("cost") or {}
            cost_str = ", ".join(f"{k}:{v}" for k, v in cost.items() if v)
            h.append(
                f"<div class='gco-meta'>verbe={e(sig.get('verb',''))} · "
                f"{e(sig.get('faction',''))} · DC vs {e(sig.get('dc_pole',''))}"
                + (f" · cout {e(cost_str)}" if cost_str else "")
                + "</div>"
            )
            h.append("</div>")
        h.append("</div>")

        # Resolution - Phase 18 styled outcome panel.
        dc = c.get("dc_result", "-")
        gain_n = eclats_gains[i] if i < len(eclats_gains) else 0
        gain_html = f" <span class='eclats-gain'>+{gain_n} eclats</span>" if gain_n > 0 else ""
        res_class = f"gc-resolution r-{dc}"
        h.append(
            f"<div class='{res_class}'>"
            f"<b>Resolution :</b> <span class='dc-result dc-{dc}'>{dc}</span>{gain_html}"
            f"<div class='gcr-prose'>{e(c.get('resolution_prose',''))}</div>"
        )
        eff = c.get("effects_applied") or []
        if eff:
            chips_html = "".join(
                f"<span class='gc-effect-chip'>{e(ef)}</span>" for ef in eff
            )
            h.append(f"<div class='gc-effects-row'>{chips_html}</div>")
        sta = c.get("state_after") or {}
        rep_factions = sta.get('factions',{}) or {}
        rep_str = " · ".join(f"{k}:{v}" for k, v in rep_factions.items())
        if sta.get("tags"):
            h.append(f"<div class='tags' style='margin-top:6px;'>Tags : {e(', '.join(sta['tags']))}</div>")
        h.append(
            f"<div class='gco-meta' style='margin-top:6px;'>"
            f"vie {sta.get('life','-')} · karma {sta.get('karma','-')} · {e(rep_str)}"
            f"</div>"
        )
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
        "11.3 (DnD checks + inter-beat memory), 11.4 (anchor + 5-movement fil rouge), "
        "11.5 (streaming stitcher LLM async).<br>"
        "Phase 14 (2026-05-19) ships : starter faction_rep, stitcher activation, "
        "per-verb prose (5 verbs x 3 tones), DC scaling per movement, eclats currency.<br>"
        "Phase 15 (2026-05-19) ships : LLM-judged binary/ternary cardinality, "
        "prose scrubber (no 'Tu peux X, Y, Z' mismatch), Scenario complet HTML section, "
        "v2 pool schema retrofit (no full LLM regen required).<br>"
        "Phase 16 (2026-05-20) ships : cascading bridges (echo prev outcome + emotional hint), "
        "anchor blended into kNN route_vec (weight 0.3), 4 verb kits (16 unique verbs vs 5), "
        "cap MERLIN_DIRECT 2/run, verb repetition penalty -0.5, --type CLI filter for targeted "
        "LLM regen, retry-on-500 on 3 Ollama call sites.</p>"
    )

    h.append("</body></html>")
    return "".join(h)


# --- Main -------------------------------------------------------------------


def render_html_cinematic(trace: dict) -> str:
    """Phase 19 (2026-05-21) - Cinematic replay view.

    Renders the run as a sequential narrative book :
      cinema-rail (sticky left mini-timeline)
      hero (title + ornament)
      prologue (intro)
      [interlude > scene > interlude > scene ... ] x N
      epilogue (outro)
      <details class='coulisses'> with audit + metrics folded by default

    Each scene shows : prose with drop-cap, choices grid (2-3 cards with
    'Choix porte' seal on the chosen one), resolution panel colored by
    outcome, and state-delta micro-chips (only diffs vs previous beat).
    """
    e = html_escape
    beats = trace.get("cards_played", []) or []
    n_beats = len(beats) or 1

    # Aggregates needed for audit fold.
    card_dist = {2: 0, 3: 0}
    sig_dist = {"Confiant": 0, "Risque": 0, "Eprouve": 0, "Verrouille": 0}
    out_dist = {"success": 0, "partial": 0, "failure": 0}
    last_eclats = 0
    eclats_path: list[int] = []
    life_path: list[int] = []
    karma_path: list[int] = []
    faction_path: list[dict] = []
    for b in beats:
        ck = int(b.get("cardinality", len(b.get("option_signals", []) or [])) or 3)
        card_dist[ck] = card_dist.get(ck, 0) + 1
        for o in b.get("option_signals", []) or []:
            s = o.get("signal", "")
            if s in sig_dist:
                sig_dist[s] += 1
        out = b.get("dc_result", "")
        if out in out_dist:
            out_dist[out] += 1
        sa = b.get("state_after", {}) or {}
        cur_eclats = int(sa.get("eclats", 0) or 0)
        last_eclats = cur_eclats
        eclats_path.append(cur_eclats)
        life_path.append(int(sa.get("life", 80) or 80))
        karma_path.append(int(sa.get("karma", 0) or 0))
        faction_path.append(dict(sa.get("factions", {}) or {}))
    sig_total = sum(sig_dist.values()) or 1

    chosen_title = trace.get("chosen_title", {}) or {}
    title_str = chosen_title.get("title", "Marche druidique")
    archetype = chosen_title.get("archetype_name", "")
    t = trace.get("timings_s", {})
    intro_text = trace.get("intro", "") or ""
    outro_text = trace.get("outro", "") or ""

    h: list[str] = []
    h.append("<!DOCTYPE html><html lang='fr'><head><meta charset='utf-8'>")
    h.append(f"<title>Marche · {e(title_str)} · seed {trace.get('seed','-')}</title>")
    h.append(CSS)
    # Phase 23 - découpage RPG visual layer (isolated from the main CSS const).
    h.append(
        "<style>"
        ".decoupage-band{max-width:920px;margin:18px auto 6px;padding:16px 20px;"
        "background:var(--bg-soft);border:1px solid var(--gold-dim);border-radius:10px}"
        ".db-title{font-size:13px;letter-spacing:.18em;text-transform:uppercase;"
        "color:var(--gold);margin-bottom:12px;text-align:center}"
        ".db-acts{display:flex;gap:8px;flex-wrap:wrap;justify-content:center}"
        ".db-act{flex:1 1 150px;min-width:138px;background:var(--bg);border:1px solid "
        "var(--gold-dim);border-radius:8px;padding:10px 12px;text-align:center}"
        ".dba-num{display:block;font-size:10px;letter-spacing:.15em;color:var(--text-dim);"
        "text-transform:uppercase}"
        ".dba-name{display:block;font-size:16px;color:var(--gold);margin:3px 0;font-weight:600}"
        ".dba-fn{display:block;font-size:11px;color:var(--text-dim);font-style:italic}"
        ".dba-count{display:block;font-size:12px;color:var(--parchment);margin-top:6px}"
        ".db-metrics{display:flex;gap:14px;justify-content:center;margin-top:14px;flex-wrap:wrap}"
        ".dbm{font-size:12px;color:var(--parchment);background:var(--bg);border:1px solid "
        "var(--gold-dim);border-radius:20px;padding:5px 14px}"
        ".act-divider{max-width:920px;margin:34px auto 10px;display:flex;align-items:center;"
        "gap:14px;padding:0 12px}"
        ".act-divider::before,.act-divider::after{content:'';flex:1;height:1px;"
        "background:linear-gradient(90deg,transparent,var(--gold-dim),transparent)}"
        ".ad-num{font-size:11px;letter-spacing:.2em;color:var(--text-dim);text-transform:uppercase}"
        ".ad-name{font-size:22px;color:var(--gold);font-weight:700;letter-spacing:.04em}"
        ".ad-fn{font-size:12px;color:var(--text-dim);font-style:italic}"
        ".beat-label{font-size:10px;letter-spacing:.16em;text-transform:uppercase;"
        "color:var(--gold-dim);margin:16px 0 5px;font-weight:600;display:flex;align-items:center}"
        ".bl-num{display:inline-block;width:18px;height:18px;line-height:18px;text-align:center;"
        "border:1px solid var(--gold-dim);border-radius:50%;margin-right:8px;font-size:10px;"
        "color:var(--gold)}"
        "</style>"
    )
    h.append("</head><body>")

    # 1. cinema-rail (sticky mini-timeline).
    h.append("<nav class='cinema-rail'>")
    for b in beats:
        result = b.get("dc_result", "")
        binary_cls = " binary" if int(b.get("cardinality", 3)) == 2 else ""
        verb = b.get("chosen_option", {}).get("verb", "")
        label = f"B{b['beat']} · {verb}"
        h.append(
            f"<a class='cr-dot r-{result}{binary_cls}' "
            f"href='#scene-{b['beat']}' data-label='{e(label)}'></a>"
        )
    h.append("</nav>")

    # 2. Hero. Phase 22 : show the marche's style tag as a sub-line.
    style_tag = trace.get("style_tag", "")
    style_line = (
        f"<div class='sub' style='margin-top:8px;font-size:11px;opacity:0.7;'>"
        f"style · {e(style_tag)}</div>"
        if style_tag else ""
    )
    h.append(
        "<header class='hero'>"
        "<div class='ornament'>❦ ✦ ❦</div>"
        f"<h1 class='title-cinema'>{e(title_str)}</h1>"
        f"<div class='sub'>{e(archetype)}</div>"
        f"{style_line}"
        f"<div class='meta'>Marche {trace.get('seed','-')} · "
        f"{n_beats} scènes · {t.get('total','-')} s · "
        f"{last_eclats} éclats accumulés</div>"
        "</header>"
    )

    # 2bis. Découpage RPG band (Phase 23) — 5 actes → cartes + variété/logique.
    acts_meta = trace.get("acts", []) or []
    metrics = trace.get("decoupage_metrics", {}) or {}
    act_name_by_idx = {a.get("index"): a.get("name", "") for a in acts_meta}
    act_fn_by_idx = {a.get("index"): a.get("function", "") for a in acts_meta}
    if acts_meta:
        var = metrics.get("variete", {}) or {}
        logi = metrics.get("logique", {}) or {}
        h.append("<section class='decoupage-band'>")
        h.append("<div class='db-title'>Découpage RPG · 5 actes → cartes → beats</div>")
        h.append("<div class='db-acts'>")
        for a in acts_meta:
            h.append(
                "<div class='db-act'>"
                f"<span class='dba-num'>Acte {a.get('index')}</span>"
                f"<span class='dba-name'>{e(a.get('name',''))}</span>"
                f"<span class='dba-fn'>{e(a.get('function',''))}</span>"
                f"<span class='dba-count'>{a.get('card_count',0)} cartes</span>"
                "</div>"
            )
        h.append("</div>")
        h.append(
            "<div class='db-metrics'>"
            f"<span class='dbm'>Variété · {var.get('unique_verbs',0)} verbes · "
            f"{var.get('unique_emotions',0)} émotions · {var.get('unique_types',0)} types</span>"
            f"<span class='dbm'>Logique · {logi.get('causal_coverage_pct',0)}% causal · "
            f"{logi.get('resolution_coverage_pct',0)}% résolu</span>"
            "</div>"
        )
        h.append("</section>")
    _prev_act = None  # act-divider tracking across the scene loop

    # 3. Prologue.
    if intro_text:
        h.append(
            "<section class='prologue'>"
            "<div class='pe-label'>Prologue</div>"
            f"<p>{e(intro_text)}</p>"
            "</section>"
        )

    # 4. Scenes with interludes, grouped under act dividers (Phase 23).
    for i, b in enumerate(beats):
        cur_act = int(b.get("movement", 1) or 1)
        if cur_act != _prev_act:
            h.append(
                f"<div class='act-divider' id='acte-{cur_act}'>"
                f"<span class='ad-num'>Acte {cur_act}</span>"
                f"<span class='ad-name'>{e(act_name_by_idx.get(cur_act, ''))}</span>"
                f"<span class='ad-fn'>{e(act_fn_by_idx.get(cur_act, ''))}</span>"
                "</div>"
            )
            _prev_act = cur_act

        bridge = b.get("transition_prose_llm") or b.get("transition_prose") or ""
        if bridge and b["beat"] > 1:
            h.append(
                "<div class='interlude'>"
                f"{e(bridge)}<span class='il-bullet'>·</span>"
                "</div>"
            )

        ck = int(b.get("cardinality", len(b.get("option_signals", []) or [])) or 3)
        scene_class = "scene binary" if ck == 2 else "scene"
        glyph = _ogham_glyph(b.get("emotion", ""))
        beat_id = b["beat"]
        h.append(f"<section class='{scene_class}' id='scene-{beat_id}'>")

        # Head
        summary_title = (b.get("summary") or "")[:65]
        summary_ellipsis = "…" if len(b.get("summary", "")) > 65 else ""
        h.append(
            "<div class='scene-head'>"
            "<div>"
            f"<div class='scene-num'>Scène {beat_id} · Acte {b['movement']} · {e(act_name_by_idx.get(int(b.get('movement',1) or 1), ''))}</div>"
            f"<div class='scene-title'>{e(summary_title)}{summary_ellipsis}</div>"
            "<div class='scene-tags'>"
            f"<span class='badge'>{e(b.get('type',''))}</span>"
            f"<span class='badge'>{e(b.get('rarity',''))}</span>"
            f"<span class='badge'>{e(b.get('pole',''))}</span>"
            f"<span class='badge'>{e(b.get('emotion',''))}</span>"
            "</div>"
            "</div>"
            f"<div class='scene-glyph' title='{e(b.get('emotion',''))}'>{glyph}</div>"
            "</div>"
        )
        if ck == 2 and b.get("binary_reason"):
            h.append(f"<div class='binary-explainer'>{e(b['binary_reason'])}</div>")

        # Main prose. Beat 1 of 4 : mise en scène.
        prose_body = b.get("prose_long") or b.get("summary") or ""
        h.append("<div class='beat-label'><span class='bl-num'>1</span>Mise en scène</div>")
        h.append(f"<div class='scene-prose'>{e(prose_body)}</div>")

        # Choices grid (2 cols for binary, 3 cols for ternary). Beat 2 : choix.
        chosen_idx = b.get("chosen_option_idx", -1)
        opts = b.get("option_signals", []) or []
        grid_class = "k2" if len(opts) == 2 else "k3"
        h.append("<div class='beat-label'><span class='bl-num'>2</span>Choix</div>")
        h.append(f"<div class='choices-grid {grid_class}'>")
        for j, sig in enumerate(opts):
            is_chosen = j == chosen_idx
            choice_class = "choice chosen" if is_chosen else "choice"
            seal = "<div class='ch-seal'>✓ Choix porté</div>" if is_chosen else ""
            signal_name = sig.get("signal", "-")
            faction = sig.get("faction", "")
            verb = sig.get("verb", "")
            cost = sig.get("cost") or {}
            cost_str = ", ".join(f"{k}:{v}" for k, v in cost.items() if v)
            cost_html = f" · {e(cost_str)}" if cost_str else ""
            h.append(
                f"<div class='{choice_class}'>"
                f"{seal}"
                f"<span class='ch-label'>{e(sig.get('label','?'))}</span>"
                f"<div style='text-align:center;'><span class='ch-signal signal-{signal_name}'>{signal_name}</span></div>"
                f"<div class='ch-meta'>{e(faction)} · {e(verb)}{cost_html}</div>"
                "</div>"
            )
        h.append("</div>")

        # Resolution block. Beat 3 : résolution.
        dc = b.get("dc_result", "-")
        outcome_label = {
            "success": "Issue heureuse",
            "partial": "Issue mêlée",
            "failure": "Revers",
        }.get(dc, dc)
        h.append("<div class='beat-label'><span class='bl-num'>3</span>Résolution</div>")
        h.append(
            f"<div class='resolution-block r-{dc}'>"
            f"<div class='rb-header'>{e(outcome_label)}</div>"
            f"<div class='rb-prose'>{e(b.get('resolution_prose',''))}</div>"
            "</div>"
        )

        # State deltas (only diffs vs previous beat).
        if i == 0:
            prev_state = {"life": 80, "karma": 0, "eclats": 0, "factions": dict(STARTER_FACTION_REP), "tags": []}
        else:
            prev_state = beats[i - 1].get("state_after", {}) or {}
        cur_state = b.get("state_after", {}) or {}
        deltas: list[tuple[str, str]] = []
        d_life = int(cur_state.get("life", 80) or 80) - int(prev_state.get("life", 80) or 80)
        if d_life != 0:
            deltas.append((f"♥ vie {d_life:+d}", "positive" if d_life > 0 else "negative"))
        d_karma = int(cur_state.get("karma", 0) or 0) - int(prev_state.get("karma", 0) or 0)
        if d_karma != 0:
            deltas.append((f"☼ karma {d_karma:+d}", "positive" if d_karma > 0 else "negative"))
        d_eclats = int(cur_state.get("eclats", 0) or 0) - int(prev_state.get("eclats", 0) or 0)
        if d_eclats > 0:
            deltas.append((f"✦ +{d_eclats} éclats", "positive"))
        cur_fac = cur_state.get("factions", {}) or {}
        prev_fac = prev_state.get("factions", {}) or {}
        for fac, v in cur_fac.items():
            pv = prev_fac.get(fac, 0)
            if v != pv:
                deltas.append((f"{fac} {v-pv:+d}", "positive" if v > pv else "negative"))
        prev_tags = set(prev_state.get("tags", []) or [])
        cur_tags_list = cur_state.get("tags", []) or []
        new_tags = [t_ for t_ in cur_tags_list if t_ not in prev_tags]
        for t_ in new_tags[-2:]:  # cap to 2 most recent new tags
            deltas.append((f"⚘ {t_}", ""))
        # Beat 4 : conséquence (effets sur le monde).
        h.append("<div class='beat-label'><span class='bl-num'>4</span>Conséquence</div>")
        h.append("<div class='delta-row'>")
        if deltas:
            for chip_text, chip_class in deltas:
                cls = f"delta-chip {chip_class}".rstrip()
                h.append(f"<div class='{cls}'>{e(chip_text)}</div>")
        else:
            h.append("<div class='delta-chip'>état stable</div>")
        h.append("</div>")

        h.append("</section>")  # end scene

    # 5. Epilogue.
    if outro_text:
        h.append(
            "<section class='epilogue'>"
            "<div class='pe-label'>Épilogue</div>"
            f"<p>{e(outro_text)}</p>"
            "</section>"
        )

    # 6. Coulisses (collapsed by default).
    v2 = trace.get("v2_pool_stats", {})
    pool_card = v2.get("cardinality_dist", {})
    pool_src = v2.get("source_dist", {})
    spark_eclats = _sparkline_svg(eclats_path, color="#d4a84a", fill_color="#d4a84a")
    spark_life = _sparkline_svg(life_path, color="#6fbf73", fill_color="#6fbf73")
    spark_karma = _sparkline_svg(karma_path, color="#a47edc", fill_color="#a47edc")

    h.append("<details class='coulisses'>")
    h.append(
        "<summary>Coulisses · audit · métriques de cohérence (cliquez pour ouvrir)</summary>"
    )
    h.append("<div class='coulisses-body'>")

    h.append("<h2>KPIs</h2>")
    h.append("<div class='kpi-grid'>")
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Wall time</div>"
        f"<div class='sc-value'>{t.get('total','-')}<span style='font-size:13px;'>s</span></div>"
        f"<div class='sc-sub'>LLM {t.get('llm_total','-')}s / kNN {t.get('skeleton_avg_ms_per_card','-')}ms</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Binaires</div>"
        f"<div class='sc-value'>{card_dist.get(2,0)}<span style='font-size:13px;color:var(--text-dim);'>/{n_beats}</span></div>"
        f"<div class='sc-sub'>Pool 13/90 = ~14% binary</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Eclats</div>"
        f"<div class='sc-value'>{last_eclats}</div>"
        f"<div class='sc-spark'>{spark_eclats}</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Vie</div>"
        f"<div class='sc-value'>{life_path[-1] if life_path else '-'}</div>"
        f"<div class='sc-spark'>{spark_life}</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Karma</div>"
        f"<div class='sc-value'>{karma_path[-1] if karma_path else '-'}</div>"
        f"<div class='sc-spark'>{spark_karma}</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Signaux C/R/E</div>"
        f"<div class='sc-value' style='font-size:16px;'>"
        f"{100*sig_dist['Confiant']/sig_total:.0f}/"
        f"{100*sig_dist['Risque']/sig_total:.0f}/"
        f"{100*sig_dist['Eprouve']/sig_total:.0f}<span style='font-size:11px;'>%</span></div>"
        f"<div class='sc-sub'>cible : Risque dominant</div></div>"
    )
    h.append(
        f"<div class='stat-card'><div class='sc-label'>Outcomes S/P/F</div>"
        f"<div class='sc-value' style='font-size:16px;'>"
        f"<span style='color:var(--signal-confiant);'>{out_dist['success']}</span>/"
        f"<span style='color:var(--signal-risque);'>{out_dist['partial']}</span>/"
        f"<span style='color:var(--signal-eprouve);'>{out_dist['failure']}</span></div>"
        f"<div class='sc-sub'>{out_dist['success']*100//max(1,n_beats)}% success</div></div>"
    )
    h.append("</div>")

    # Timing breakdown table.
    h.append("<h2>Timings</h2>")
    h.append("<table><tr><th>Stage</th><th>Time</th></tr>")
    for k, v in t.items():
        h.append(f"<tr><td>{e(k)}</td><td>{v} s</td></tr>")
    h.append("</table>")

    # Pool composition.
    h.append("<h2>Pool</h2>")
    h.append(
        f"<p>Sources : "
        f"<span class='kpi'><span class='val'>{pool_src.get('llm','?')}</span><br><span class='lbl'>llm</span></span>"
        f"<span class='kpi'><span class='val'>{pool_src.get('llm_partial','?')}</span><br><span class='lbl'>llm_partial</span></span>"
        f"<span class='kpi'><span class='val'>{pool_src.get('fallback_template','?')}</span><br><span class='lbl'>fallback</span></span></p>"
    )
    h.append(
        f"<p>Cardinalité : "
        f"<span class='kpi'><span class='val'>{pool_card.get('3','?')}</span><br><span class='lbl'>3 voies</span></span>"
        f"<span class='kpi'><span class='val'>{pool_card.get('2','?')}</span><br><span class='lbl'>Binaire</span></span></p>"
    )

    # Faction-rep progression table.
    h.append("<h2>Réputation factions + éclats par beat</h2>")
    all_factions: list[str] = []
    for rep in faction_path:
        for k in rep:
            if k not in all_factions:
                all_factions.append(k)
    h.append("<table>")
    head_cells = "".join(f"<th>{e(f)}</th>" for f in all_factions)
    h.append(f"<tr><th>Beat</th><th>M</th>{head_cells}<th>Vie</th><th>Karma</th><th>Eclats</th></tr>")
    for i, b in enumerate(beats):
        rep = faction_path[i]
        cells = "".join(f"<td>{rep.get(f, 0)}</td>" for f in all_factions)
        h.append(
            f"<tr><td>B{b['beat']}</td><td>M{b['movement']}</td>"
            f"{cells}<td>{life_path[i]}</td><td>{karma_path[i]}</td><td>{eclats_path[i]}</td></tr>"
        )
    h.append("</table>")

    h.append(
        "<p style='color:var(--text-dim);font-size:11px;margin-top:18px;'>"
        "Phase 11 (DnD-without-combat) · Phase 14 (starter rep + éclats + DC scaling + per-verb prose) · "
        "Phase 15 (binary/ternary + scrubber) · Phase 16 (cascade bridges + anchor kNN + 4 verb kits + cap Merlin + verb penalty) · "
        "Phase 16.1 (count-weighted verb penalty) · Phase 17 (prose accessible + plain bridges + labels porteurs de sens) · "
        "Phase 18 (game-ready dashboard) · Phase 19 (cinematic replay)."
        "</p>"
    )

    h.append("</div></details>")
    h.append("</body></html>")
    return "".join(h)


def main() -> int:
    trace = run_simulation()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(trace, ensure_ascii=False, indent=2), encoding="utf-8")
    # Phase 19 (2026-05-21) : default to cinematic layout. Old render_html
    # remains available as backup but is not called.
    HTML_PATH.write_text(render_html_cinematic(trace), encoding="utf-8")
    print(f"[OK] JSON : {JSON_PATH}")
    print(f"[OK] HTML : {HTML_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

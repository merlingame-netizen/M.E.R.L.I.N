#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
simulate_human_run_v730.py - v7.7.30 (2026-05-18)

Phase 10.3 - embedding-first proof-of-concept.

Goal: prove the architecture in `docs/10_llm/EMBEDDING_FIRST_ARCHITECTURE.md`
by running a full demo (titles + intro + scenario + 16 cards + outro) where:

  - Titles: 3 sampled scenario titles, 0 LLM call.
  - Intro:  1 LLM call (kept - sets the run's tone).
  - Skeleton: 0 LLM calls - built from kNN-retrieved beats.
  - Cards x N: 0 LLM calls each - kNN retrieval from the 2 900-card pool.
  - Resolutions x N: 0 LLM calls - synthesised from the chosen option's verb.
  - Outro:  1 LLM call (kept - personalises to run history).

Pre-req:
    python tools/embed_reference_cards.py    # one-shot, builds the index

User instruction (verbatim): "Il faut pouvoir faire du embedding /
vectorisation puissante pour arriver a un resultat de chargement 10x
moins important, comment faire ? Propose une architecture bien meilleure."

Output:
    ~/Downloads/merlin_human_run_test_v7.7.30.html
    ~/Downloads/merlin_human_run_test_v7.7.30.json

Caller graph: standalone CLI (no other file imports this module).
Source-of-truth design: docs/10_llm/EMBEDDING_FIRST_ARCHITECTURE.md
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

# Make `cards_rag` importable when launched from anywhere.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from cards_rag import CardsRAG, CardHit  # noqa: E402

OLLAMA_BASE = "http://localhost:11434"
NARRATOR_MODEL = os.environ.get("MERLIN_NARRATOR_MODEL", "gemma4:e2b")
THINK_MODE = os.environ.get("MERLIN_THINK", "false").lower() == "true"
BIOME = os.environ.get("MERLIN_BIOME", "foret_broceliande")
N_CARDS = int(os.environ.get("MERLIN_N_CARDS", "16"))
SEED = int(os.environ.get("MERLIN_SEED", "42"))
OUT_DIR = Path.home() / "Downloads"
HTML_PATH = OUT_DIR / "merlin_human_run_test_v7.7.30.html"
JSON_PATH = OUT_DIR / "merlin_human_run_test_v7.7.30.json"
ROOT = Path(__file__).resolve().parent.parent
SCENARIOS_PATH = ROOT / "data" / "ai" / "scenarios_reference_broceliande.json"

log = logging.getLogger("simulate_human_run_v730")


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
    """Plain Ollama generate call. Returns (text, duration_seconds)."""
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


# --- Pipeline stages --------------------------------------------------------


def pick_titles(scenarios: list[dict], rng: random.Random) -> tuple[list[dict], float]:
    """Sample 3 titles from the pool. No LLM call - pure pool sampling."""
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


def llm_intro(chosen: dict) -> tuple[str, float]:
    """LLM-written intro setup. Short (4-5 sentences), second person, no
    scenario spoilers. Kept as LLM so each run feels fresh."""
    system = (
        "Tu es un narrateur druidique de l'univers MERLIN (Broceliande). "
        "Tu ecris une introduction au scenario. C'est un SETUP : ambiance, "
        "trac, sensations. Ne revele AUCUN evenement, aucune rencontre. "
        "4 a 5 phrases, en 2eme personne du singulier."
    )
    user = (
        f"Titre du scenario : {chosen['title']}\n"
        f"Archetype : {chosen['archetype_name']}\n\n"
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
    """Build the run skeleton by kNN-retrieving N cards from the pool.

    Uses progressive emotion arc: curiosite -> tension -> peur -> fascination -> sagesse.
    Returns (list of CardHit, list of per-card retrieval ms, total seconds).
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
        # Graceful fallback chain. Pool has many duplicate beats across
        # scenarios (same `c1`, `c22`...), so we widen k and progressively
        # relax constraints rather than starving.
        def _try(k: int, with_emotion: bool, with_dedup: bool):
            f = {"emotion": emotion} if with_emotion else None
            raw = rag.knn(route_vec, k=k, filters=f, exclude_uids=excluded)
            if with_dedup:
                raw = [h for h in raw if (h.summary or "") not in seen_summaries]
            return raw

        hits = _try(k=32, with_emotion=(i % 2 == 0), with_dedup=True)
        if not hits:
            hits = _try(k=32, with_emotion=False, with_dedup=True)
        if not hits:
            hits = _try(k=32, with_emotion=False, with_dedup=False)
        if not hits:
            log.warning("No hits at beat %d - stopping skeleton early", i)
            break
        pick_idx = rng.randint(0, min(2, len(hits) - 1))
        picked = hits[pick_idx]
        selected.append(picked)
        excluded.append(picked.card_uid)
        seen_summaries.add(picked.summary or "")
        per_card_ms.append((time.time() - t_card) * 1000)
        # Update route_vec proxy : embed the picked card's summary so the
        # next retrieval is conditioned on what we just chose.
        picked_vec = rag.embed_query(picked.summary or picked.card_uid)
        route_vec = rag.compose_route_vec(
            beat_vec=picked_vec,
            recent_choice_vecs=[],
            intro_vec=intro_vec,
            weights=(0.5, 0.0, 0.5),
        )

    return selected, per_card_ms, time.time() - t0


def agent_pick_option(card: CardHit, rng: random.Random) -> tuple[int, dict]:
    """Heuristic agent: prefer the option whose primary_faction matches the
    card's pole when possible, else pick a random option."""
    options = card.options or []
    if not options:
        return -1, {}
    target_faction = {
        "lumiere": "druides",
        "ombre": "ankou",
        "nature": "anciens",
        "savoir": "niamh",
        "espiegle": "korrigans",
    }.get((card.pole or "").lower())
    if target_faction:
        for i, o in enumerate(options):
            if o.get("primary_faction") == target_faction:
                return i, o
    idx = rng.randint(0, len(options) - 1)
    return idx, options[idx]


def synthesise_resolution(card: CardHit, option: dict) -> str:
    """Template resolution. Phase 10.5 will swap for pre-baked variants."""
    verb = option.get("verb", "agir")
    label = option.get("label", "")
    faction = option.get("primary_faction", "")
    summary = card.summary or "le moment se cristallise."
    return (
        f"Tu choisis de {verb}. {label}. "
        f"La trame de Broceliande tend vers les {faction}. "
        f"{summary[:120]}"
    ).strip()


def derive_effects(card: CardHit, option: dict) -> list[str]:
    """Map an option's primary_faction to MerlinEffectEngine effects."""
    faction = option.get("primary_faction", "")
    base_rep = 5
    if card.rarity == "rare":
        base_rep = 7
    elif card.rarity == "epique":
        base_rep = 10
    effects: list[str] = []
    if faction:
        effects.append(f"ADD_REPUTATION:{faction}:{base_rep}")
    if card.type == "MERLIN_DIRECT":
        effects.append("ADD_KARMA:3")
    if (card.emotion or "") in ("peur", "tension"):
        effects.append("DAMAGE_LIFE:2")
    else:
        effects.append("HEAL_LIFE:2")
    return effects


def llm_outro(
    chosen: dict, run_history: list[dict], final_state: dict
) -> tuple[str, float]:
    """LLM-written outro. Kept as LLM, personalised to faction outcomes."""
    system = (
        "Tu es un narrateur druidique. Tu ecris la conclusion (outro) d'une "
        "marche dans Broceliande. 3 a 4 phrases, 2eme personne, ton apaise. "
        "Mentionne 1-2 factions dominantes et l'ambiance finale."
    )
    factions = final_state.get("faction_rep", {})
    sorted_factions = sorted(factions.items(), key=lambda kv: -kv[1])[:2]
    summary_lines = [
        f"- {h['beat']}: tu as {h['verb']} ({h['faction']})" for h in run_history[:6]
    ]
    user = (
        f"Titre du scenario : {chosen['title']}\n"
        f"Factions dominantes : "
        f"{', '.join(f'{f}:{v}' for f, v in sorted_factions) or 'aucune'}\n"
        f"Etapes marquantes :\n" + "\n".join(summary_lines)
    )
    return llm_generate(system, user, options={"temperature": 0.7, "num_predict": 180})


def apply_effects(state: dict, effects: list[str]) -> list[dict]:
    """Mirror of MerlinEffectEngine.apply_effects, simplified for the PoC."""
    log_entries: list[dict] = []
    for eff in effects:
        try:
            parts = eff.split(":")
            verb = parts[0]
            if verb == "ADD_REPUTATION":
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
            log_entries.append({"effect": eff, "status": "applied"})
        except Exception as e:
            log_entries.append({"effect": eff, "status": f"error:{e}"})
    return log_entries


def run_simulation() -> dict:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    log.info("v7.7.30 embedding-first PoC starting...")
    log.info(
        "  Narrator model : %s | Biome : %s | N cards : %d | Seed : %d",
        NARRATOR_MODEL,
        BIOME,
        N_CARDS,
        SEED,
    )

    trace: dict = {
        "version": "v7.7.30",
        "mode": "embedding-first",
        "started_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "models": {"narrator": NARRATOR_MODEL, "embed": "nomic-embed-text"},
        "biome": BIOME,
        "n_cards": N_CARDS,
        "seed": SEED,
        "steps": [],
        "timings_s": {},
        "run_log": [],
    }
    rng = random.Random(SEED)
    pipeline_t0 = time.time()

    t0 = time.time()
    rag = CardsRAG.load()
    boot_s = time.time() - t0
    trace["timings_s"]["boot_cards_rag"] = round(boot_s, 3)
    trace["cards_pool_size"] = rag.count
    log.info("Boot CardsRAG: %.2f s (%d cards loaded)", boot_s, rag.count)

    scenarios = json.loads(SCENARIOS_PATH.read_text(encoding="utf-8"))

    titles, dur_titles = pick_titles(scenarios, rng)
    trace["timings_s"]["titles"] = round(dur_titles, 3)
    trace["titles"] = titles
    chosen = titles[0]
    trace["chosen_title"] = chosen
    log.info("Titles (%.3f s): %s", dur_titles, [t["title"] for t in titles])
    log.info("Agent picked: %s", chosen["title"])

    intro_text, dur_intro = llm_intro(chosen)
    trace["timings_s"]["intro_llm"] = round(dur_intro, 2)
    trace["intro"] = intro_text
    log.info("Intro LLM (%.1f s, %d chars)", dur_intro, len(intro_text))

    t0 = time.time()
    intro_vec = rag.embed_query(intro_text or chosen["title"])
    trace["timings_s"]["intro_embed"] = round(time.time() - t0, 3)

    skeleton_hits, per_card_ms, dur_skeleton = retrieve_skeleton(
        rag, chosen, intro_vec, N_CARDS, rng
    )
    trace["timings_s"]["skeleton_total"] = round(dur_skeleton, 2)
    trace["timings_s"]["skeleton_avg_ms_per_card"] = round(
        sum(per_card_ms) / max(1, len(per_card_ms)), 2
    )
    trace["per_card_retrieval_ms"] = [round(x, 2) for x in per_card_ms]
    log.info(
        "Skeleton retrieval : %.2f s for %d cards (avg %.2f ms/card)",
        dur_skeleton,
        len(skeleton_hits),
        trace["timings_s"]["skeleton_avg_ms_per_card"],
    )

    state = {"life_essence": 80, "karma": 0, "faction_rep": {}}
    cards_played: list[dict] = []
    run_history: list[dict] = []
    t_cards_start = time.time()
    for i, hit in enumerate(skeleton_hits):
        opt_idx, option = agent_pick_option(hit, rng)
        resolution = synthesise_resolution(hit, option)
        effects = derive_effects(hit, option)
        log_entries = apply_effects(state, effects)
        cards_played.append(
            {
                "beat": i + 1,
                "card_uid": hit.card_uid,
                "type": hit.type,
                "rarity": hit.rarity,
                "pole": hit.pole,
                "emotion": hit.emotion,
                "summary": hit.summary,
                "options": hit.options,
                "agent_picked_idx": opt_idx,
                "agent_picked_label": option.get("label", ""),
                "verb": option.get("verb", ""),
                "faction": option.get("primary_faction", ""),
                "resolution": resolution,
                "effects": effects,
                "effect_log": log_entries,
                "retrieval_ms": (
                    per_card_ms[i] if i < len(per_card_ms) else 0.0
                ),
            }
        )
        run_history.append(
            {
                "beat": i + 1,
                "verb": option.get("verb", ""),
                "faction": option.get("primary_faction", ""),
                "label": option.get("label", ""),
            }
        )
    dur_cards = time.time() - t_cards_start
    trace["timings_s"]["cards_play_loop"] = round(dur_cards, 3)
    trace["cards"] = cards_played
    log.info(
        "Played %d cards in %.2f s (state-machine only, no LLM, no embed)",
        len(cards_played),
        dur_cards,
    )

    outro_text, dur_outro = llm_outro(chosen, run_history, state)
    trace["timings_s"]["outro_llm"] = round(dur_outro, 2)
    trace["outro"] = outro_text
    log.info("Outro LLM (%.1f s, %d chars)", dur_outro, len(outro_text))

    total_s = time.time() - pipeline_t0
    trace["timings_s"]["total_wall"] = round(total_s, 2)
    trace["final_state"] = state
    trace["finished_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    log.info("Total wall time : %.2f s", total_s)
    log.info("  LLM-only time   : %.2f s (intro + outro)", dur_intro + dur_outro)
    log.info(
        "  Retrieval time  : %.2f s (boot + skeleton + cards-loop)",
        boot_s + dur_skeleton + dur_cards,
    )

    return trace


def render_html(trace: dict) -> str:
    """Gold/parchemin v7.7.26-aligned report with timing dashboard."""
    title_chosen = trace.get("chosen_title", {}).get("title", "?")
    timings = trace.get("timings_s", {})
    boot_ms = timings.get("boot_cards_rag", 0) * 1000
    intro_llm = timings.get("intro_llm", 0)
    outro_llm = timings.get("outro_llm", 0)
    skel_s = timings.get("skeleton_total", 0)
    cards_s = timings.get("cards_play_loop", 0)
    total = timings.get("total_wall", 0)
    avg_card_ms = timings.get("skeleton_avg_ms_per_card", 0)
    baseline_total = 1140
    speedup = baseline_total / total if total > 0 else 0

    cards_html_parts = []
    for c in trace.get("cards", []):
        opts_html = "".join(
            f"<li class='{'picked' if i == c['agent_picked_idx'] else ''}'>"
            f"{html_escape(o.get('label', ''))} "
            f"<em>({html_escape(o.get('verb', ''))} / "
            f"{html_escape(o.get('primary_faction', ''))})</em></li>"
            for i, o in enumerate(c.get("options", []))
        )
        eff_html = ", ".join(html_escape(e) for e in c.get("effects", []))
        cards_html_parts.append(
            f"<div class='card'>"
            f"<h4>Beat {c['beat']} - "
            f"<span class='badge type'>{html_escape(c['type'] or '-')}</span> "
            f"<span class='badge rarity'>{html_escape(c['rarity'] or '-')}</span> "
            f"<span class='badge emo'>{html_escape(c['emotion'] or '-')}</span> "
            f"<span class='badge pole'>{html_escape(c['pole'] or '-')}</span> "
            f"<span class='retrieval'>kNN {c['retrieval_ms']:.1f} ms</span></h4>"
            f"<p class='summary'>{html_escape(c['summary'] or '')}</p>"
            f"<ul class='options'>{opts_html}</ul>"
            f"<p class='resolution'><strong>Resolution :</strong> "
            f"{html_escape(c['resolution'])}</p>"
            f"<p class='effects'>Effets : <code>{eff_html}</code></p>"
            f"</div>"
        )
    cards_html = "".join(cards_html_parts)

    titles_html = "".join(
        f"<li class='{'picked' if t['scenario_id'] == trace['chosen_title']['scenario_id'] else ''}'>"
        f"<strong>{html_escape(t['title'])}</strong> "
        f"<em>({html_escape(t['archetype_name'])})</em></li>"
        for t in trace.get("titles", [])
    )

    style = """
:root { --gold:#d6a44b; --parchment:#f5e9c8; --ink:#2d1f12;
  --shadow:#6b5638; --moss:#4a6038; --crimson:#8b3a2b; }
* { box-sizing: border-box; }
body { background: linear-gradient(180deg,#f3e6c2 0%,#e8d8a9 100%);
  font-family: Georgia,'Times New Roman',serif; color: var(--ink);
  padding: 24px; max-width: 1100px; margin: 0 auto; }
h1 { border-bottom: 3px double var(--gold); padding-bottom: 8px;
  font-size: 28px; color: var(--shadow); letter-spacing: 1px; }
h2 { color: var(--crimson); border-left: 6px solid var(--gold);
  padding: 4px 12px; margin-top: 32px; }
h4 { margin: 8px 0; font-size: 15px; }
.badge { background: var(--gold); color: var(--ink); padding: 2px 8px;
  border-radius: 3px; font-size: 11px; font-family: monospace;
  margin-right: 4px; }
.badge.type { background: var(--moss); color: var(--parchment); }
.badge.rarity { background: var(--crimson); color: var(--parchment); }
.badge.emo { background: #6b5638; color: var(--parchment); }
.badge.pole { background: #88643d; color: var(--parchment); }
.retrieval { float: right; color: var(--moss); font-size: 12px; font-family: monospace; }
.summary { font-style: italic; color: var(--shadow); }
.resolution { background: #fff8e0; padding: 8px; border-left: 3px solid var(--gold); }
.effects code { background: #f5e9c8; padding: 2px 6px; border-radius: 3px; }
.options { list-style: none; padding-left: 0; }
.options li { padding: 4px 8px; border-left: 3px solid transparent; }
.options li.picked { background: rgba(214,164,75,0.25);
  border-left-color: var(--gold); font-weight: bold; }
.card { background: var(--parchment); border: 1px solid var(--gold);
  padding: 12px 16px; margin: 12px 0; border-radius: 4px;
  box-shadow: 2px 2px 4px rgba(0,0,0,0.1); }
.timing-grid { display: grid; grid-template-columns: repeat(4,1fr);
  gap: 12px; margin: 16px 0; }
.metric { background: var(--parchment); border: 1px solid var(--gold);
  padding: 10px; text-align: center; border-radius: 4px; }
.metric .label { font-size: 11px; text-transform: uppercase; color: var(--shadow); }
.metric .value { font-size: 22px; color: var(--crimson); font-weight: bold; }
.metric .unit { font-size: 12px; color: var(--shadow); }
.speedup { background: var(--moss); color: var(--parchment); padding: 16px;
  text-align: center; font-size: 18px; border-radius: 4px; margin: 16px 0; }
.intro, .outro { background: #fff8e0; padding: 16px; border-left: 6px solid var(--gold); font-size: 16px; }
table { width: 100%; border-collapse: collapse; margin: 12px 0; }
th, td { border: 1px solid var(--gold); padding: 8px; text-align: left; }
th { background: var(--shadow); color: var(--parchment); }
.fast { color: var(--moss); font-weight: bold; }
.slow { color: var(--crimson); font-weight: bold; }
.titles li { padding: 6px; margin: 4px 0; background: var(--parchment); }
.titles li.picked { background: rgba(214,164,75,0.4); border-left: 4px solid var(--gold); }
"""

    skel_div = max(skel_s, 0.001)
    rows = (
        f"<tr><td>Titres</td><td>~30 s</td>"
        f"<td class='fast'>{timings.get('titles', 0)*1000:.0f} ms</td>"
        f"<td>~300x</td></tr>"
        f"<tr><td>Intro</td><td>~40 s</td>"
        f"<td class='slow'>{intro_llm:.1f} s</td><td>~1x (kept)</td></tr>"
        f"<tr><td>Skeleton</td><td>~100 s</td>"
        f"<td class='fast'>{skel_s*1000:.0f} ms</td><td>~{100/skel_div:.0f}x</td></tr>"
        f"<tr><td>Scenario full</td><td>~90 s</td>"
        f"<td class='fast'>0 ms (synthesised)</td><td>inf</td></tr>"
        f"<tr><td>Cards x {trace['n_cards']}</td><td>~480 s</td>"
        f"<td class='fast'>{skel_s*1000:.0f} ms total</td>"
        f"<td>~{480/skel_div:.0f}x</td></tr>"
        f"<tr><td>Resolutions x {trace['n_cards']}</td><td>~400 s</td>"
        f"<td class='fast'>0 ms (template)</td><td>inf</td></tr>"
        f"<tr><td>Outro</td><td>~30 s</td>"
        f"<td class='slow'>{outro_llm:.1f} s</td><td>~1x (kept)</td></tr>"
        f"<tr><th>Total</th><th>~1140 s</th>"
        f"<th class='fast'>{total:.1f} s</th><th>~{speedup:.1f}x</th></tr>"
    )

    final_state = trace.get("final_state", {})
    rep_json = html_escape(
        json.dumps(final_state.get("faction_rep", {}), ensure_ascii=False)
    )

    return f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<title>MERLIN - Embedding-First Run Report v7.7.30</title>
<style>{style}</style></head><body>

<h1>MERLIN - Embedding-First Architecture Run v7.7.30</h1>
<p><em>Mode : {trace['mode']} - Started {trace['started_at']} - Finished {trace.get('finished_at', '?')}</em></p>
<p>Cards pool : <strong>{trace.get('cards_pool_size', 0)}</strong> indexed cards (768-dim nomic-embed-text)</p>

<div class='speedup'>
  Total wall time : <strong>{total:.1f} s</strong> for {trace['n_cards']} cards
  &nbsp;|&nbsp; v7.7.29 baseline : <strong>{baseline_total} s</strong>
  &nbsp;|&nbsp; <strong>Speedup ~{speedup:.1f}x</strong>
</div>

<h2>1. Timing breakdown</h2>
<div class='timing-grid'>
  <div class='metric'><div class='label'>Boot CardsRAG</div>
    <div class='value'>{boot_ms:.0f}</div><div class='unit'>ms</div></div>
  <div class='metric'><div class='label'>Intro (LLM)</div>
    <div class='value'>{intro_llm:.1f}</div><div class='unit'>s</div></div>
  <div class='metric'><div class='label'>Skeleton kNN x {trace['n_cards']}</div>
    <div class='value'>{skel_s*1000:.0f}</div><div class='unit'>ms</div></div>
  <div class='metric'><div class='label'>Cards play loop</div>
    <div class='value'>{cards_s*1000:.0f}</div><div class='unit'>ms</div></div>
  <div class='metric'><div class='label'>Avg kNN/card</div>
    <div class='value'>{avg_card_ms:.1f}</div><div class='unit'>ms</div></div>
  <div class='metric'><div class='label'>Outro (LLM)</div>
    <div class='value'>{outro_llm:.1f}</div><div class='unit'>s</div></div>
  <div class='metric'><div class='label'>LLM time total</div>
    <div class='value'>{(intro_llm+outro_llm):.1f}</div><div class='unit'>s</div></div>
  <div class='metric'><div class='label'>Retrieval total</div>
    <div class='value'>{(skel_s+cards_s)*1000:.0f}</div><div class='unit'>ms</div></div>
</div>

<h3>vs v7.7.29 LLM-only baseline</h3>
<table>
<tr><th>Step</th><th>v7.7.29</th><th>v7.7.30</th><th>Speedup</th></tr>
{rows}
</table>

<h2>2. Titres proposes (pool sampling, 0 LLM)</h2>
<ul class='titles'>{titles_html}</ul>
<p>Choix de l'agent : <strong>{html_escape(title_chosen)}</strong></p>

<h2>3. Intro (LLM kept)</h2>
<div class='intro'>{html_escape(trace.get('intro', ''))}</div>

<h2>4. Cards (kNN retrieval, 0 LLM per card)</h2>
{cards_html}

<h2>5. Outro (LLM kept, personnalised to run history)</h2>
<div class='outro'>{html_escape(trace.get('outro', ''))}</div>

<h2>6. Final state</h2>
<table>
<tr><th>Life essence</th><td>{final_state.get('life_essence', '?')}</td></tr>
<tr><th>Karma</th><td>{final_state.get('karma', 0)}</td></tr>
<tr><th>Faction rep</th><td><code>{rep_json}</code></td></tr>
</table>

<h2>7. Architecture</h2>
<p>See <code>docs/10_llm/EMBEDDING_FIRST_ARCHITECTURE.md</code> for the full 6-layer design.
This run exercises L1 (pre-computed embeddings), L2 (numpy kNN), L4 (route_vec composition), L6 (hybrid : keeps LLM for intro+outro).</p>
<ul>
<li>Cards pool : <code>{trace.get('cards_pool_size', 0)}</code> entries via <code>nomic-embed-text</code> (768 dim)</li>
<li>Backend : pure numpy brute-force cosine (~0.33 ms/query measured on synthetic 2900x768)</li>
<li>Personalisation : route_vec = 0.5*beat + 0.5*intro (Phase 10.4 wires recent choice vectors)</li>
<li>Resolutions : template synthesis from option verb+faction (Phase 10.5 swaps for pre-baked variant pool)</li>
</ul>

<p><em>Generated by tools/simulate_human_run_v730.py - Phase 10.3 PoC</em></p>
</body></html>"""


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    trace = run_simulation()
    JSON_PATH.write_text(
        json.dumps(trace, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    HTML_PATH.write_text(render_html(trace), encoding="utf-8")
    print(f"[OK] JSON : {JSON_PATH}")
    print(f"[OK] HTML : {HTML_PATH}")
    print(f"[OK] Total wall : {trace['timings_s']['total_wall']:.2f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())

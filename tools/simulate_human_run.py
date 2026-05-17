#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
simulate_human_run.py — v7.7.25 (2026-05-17)

End-to-end "playwright humain" simulation of a player's run through MERLIN's
LLM pipeline. Calls Ollama directly with the SAME prompts the in-game
ScenarioPlanner + BiBrainPipeline use (per v7.7.23 reference-augmented pipeline),
captures every step with timestamps + RPG state deltas, renders a rich HTML
report showing : 3 titles, player pick, intro, skeleton, every card + choice +
effect, RPG state evolution across the whole run.

User mandate : « Test en playwright humain le jeu [...] tout en etape et en
seconde pour voir si ça s'enchaine bien. Inclus la dimension RPG »

Output : ~/Downloads/merlin_human_run_test_v7.7.25.html + .json
"""

from __future__ import annotations
import json
import math
import random
import sys
import time
from pathlib import Path
from urllib.request import urlopen, Request

OLLAMA_BASE = "http://localhost:11434"
# v7.7.27 — Switched from qwen3.5:2b/4b to Gemma 4 family.
# E2B for both narrator + GM keeps wall-clock under ~10 min on CPU-only.
# Override via env vars to swap to gemma4:e4b / gemma4:26b on faster hardware:
#   MERLIN_NARRATOR_MODEL=gemma4:e4b python tools/simulate_human_run.py
import os as _os
NARRATOR_MODEL = _os.environ.get("MERLIN_NARRATOR_MODEL", "gemma4:e2b")
GM_MODEL = _os.environ.get("MERLIN_GM_MODEL", "gemma4:e2b")
EMBED_MODEL = _os.environ.get("MERLIN_EMBED_MODEL", "nomic-embed-text")
# v7.7.27 — Gemma 4 has chain-of-thought enabled by default on Ollama.
# Without explicit "think": false the response goes to a "thinking" field
# and "response" stays empty until num_predict fits both. Force off.
THINK_MODE = _os.environ.get("MERLIN_THINK", "false").lower() == "true"

REPO = Path(__file__).resolve().parent.parent
REFERENCES_PATH = REPO / "data" / "ai" / "scenarios_reference_broceliande.json"
EMBEDDINGS_PATH = REPO / "data" / "ai" / "scenarios_reference_broceliande.embeddings.json"

OUT_DIR = Path.home() / "Downloads"
HTML_PATH = OUT_DIR / "merlin_human_run_test_v7.7.27.html"
JSON_PATH = OUT_DIR / "merlin_human_run_test_v7.7.27.json"

BIOME = "foret_broceliande"


def ollama_post(endpoint: str, payload: dict, timeout: int = 60) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = Request(f"{OLLAMA_BASE}{endpoint}", data=body,
                  headers={"Content-Type": "application/json"})
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def embed(text: str) -> list:
    return ollama_post("/api/embeddings", {"model": EMBED_MODEL, "prompt": text}).get("embedding", [])


def generate(model: str, system: str, user: str, options: dict | None = None,
             timeout: int = 240) -> tuple[str, float]:
    # v7.7.27 — default timeout bumped 90 → 240 s for Gemma 4 E2B CPU (~7 tok/s).
    payload = {"model": model, "system": system, "prompt": user,
               "stream": False, "think": THINK_MODE, "options": options or {}}
    t0 = time.time()
    try:
        resp = ollama_post("/api/generate", payload, timeout=timeout)
        return resp.get("response", "").strip(), time.time() - t0
    except Exception as e:
        return f"[ERREUR Ollama : {e}]", time.time() - t0


class RAG:
    def __init__(self) -> None:
        self.scenarios: list = []
        self.embeddings: dict = {}
        self._load()

    def _load(self) -> None:
        self.scenarios = json.loads(REFERENCES_PATH.read_text(encoding="utf-8"))
        data = json.loads(EMBEDDINGS_PATH.read_text(encoding="utf-8"))
        for e in data.get("embeddings", []):
            self.embeddings[e["id"]] = e["vector"]

    def by_id(self, sid: str) -> dict:
        for s in self.scenarios:
            if s.get("id") == sid:
                return s
        return {}

    def query(self, text: str, top_k: int = 3) -> list:
        qvec = embed(text)
        if not qvec:
            return []
        scored = []
        for sid, ref_vec in self.embeddings.items():
            scored.append((sid, _cosine(qvec, ref_vec)))
        scored.sort(key=lambda x: x[1], reverse=True)
        out = []
        for sid, sim in scored[:top_k]:
            entry = dict(self.by_id(sid))
            entry["similarity"] = sim
            out.append(entry)
        return out


def _cosine(a: list, b: list) -> float:
    if len(a) != len(b) or not a:
        return 0.0
    dot = sum(av * bv for av, bv in zip(a, b))
    na = math.sqrt(sum(av * av for av in a))
    nb = math.sqrt(sum(bv * bv for bv in b))
    return dot / (na * nb) if na > 0 and nb > 0 else 0.0


def llm_titles(rag: RAG, biome: str) -> tuple[list, dict]:
    matches = rag.query("titres mystérieux pour " + biome, 5)
    few_shot = "\n".join(f'- "{m.get("title", "?")}"' for m in matches)
    system = (
        f"Tu produis EXACTEMENT 3 titres mystérieux pour une aventure dans le biome {biome}.\n"
        "Format STRICT : 1 ligne par titre, 3-7 mots chacun, francais, ton druidique.\n"
        "Pas de numérotation, pas de synopsis, pas de tirets. Une ligne = un titre.\n"
        "\nExemples de titres canoniques :\n" + few_shot
    )
    raw, dur = generate(NARRATOR_MODEL, system, "Génère 3 titres.",
                       {"temperature": 0.95, "num_predict": 80})
    lines = [ln.strip().lstrip("-*0123456789. )") for ln in raw.split("\n") if ln.strip()]
    titles = [ln for ln in lines if 3 <= len(ln) <= 60][:3]
    while len(titles) < 3:
        titles.append("La Voie du Hêtre Silencieux")
    return titles, {"duration_s": dur, "rag_matches": [m["title"] for m in matches]}


def llm_intro(rag: RAG, biome: str, chosen_title: str) -> tuple[str, dict]:
    matches = rag.query(f"{chosen_title} · {biome}", 3)
    refs_block = "\n\n".join(f"Exemple {i+1} :\n{m.get('intro', '')[:600]}"
                              for i, m in enumerate(matches))
    system = (
        "Tu rédiges l'intro d'une marche druidique dans le bois de Brocéliande.\n"
        "POV : second-person, jeune druide en initiation. Le monde druidique est réel.\n"
        "CONTRAINTES : EXACTEMENT 6 à 8 phrases ; français celtique ; PAS d'anglicismes ; "
        "PAS de cyber/technologie ; PAS de rupture du 4e mur (pas de jeu/simulation).\n"
        f"\nExemples de qualité :\n{refs_block}\n\n"
        f"Maintenant rédige pour : \"{chosen_title}\"."
    )
    raw, dur = generate(NARRATOR_MODEL, system, "Rédige l'intro 6-8 phrases.",
                       {"temperature": 0.85, "num_predict": 400})
    return raw.strip(), {"duration_s": dur, "rag_matches": [m["title"] for m in matches]}


def llm_skeleton(rag: RAG, biome: str, chosen_title: str) -> tuple[dict, dict]:
    matches = rag.query(f"{chosen_title} · structure narrative", 2)
    beats_block = []
    for i, m in enumerate(matches):
        cards = m.get("cards", [])[:5]
        block = f"Exemple {i+1} ({m.get('title', '?')}) :\n"
        for c in cards:
            block += f"  n={c.get('n','?')} emotion={c.get('emotion','?')} pole={c.get('pole','?')}\n"
        beats_block.append(block)
    refs = "\n".join(beats_block)
    system = (
        "Tu es le Gamemaster M.E.R.L.I.N.. Génère un skeleton narratif au format JSON strict.\n"
        f"Titre : \"{chosen_title}\" (biome : {biome}).\n"
        "Structure : {\"title\": str, \"beats\": [5-7 entries]}.\n"
        "Chaque beat = {n: 1..N, summary: 1 phrase 10-20 mots, faction_tilt, emotion}.\n"
        "faction_tilt ∈ {druides, anciens, korrigans, niamh, ankou, neutre}.\n"
        "emotion ∈ {curiosite, tension, peur, espoir, sagesse, fascination, melancolie, emerveillement}.\n"
        f"\nExemples :\n{refs}\n"
        "\nRéponds UNIQUEMENT avec le JSON, sans markdown."
    )
    raw, dur = generate(GM_MODEL, system, "Génère le skeleton JSON.",
                       {"temperature": 0.8, "num_predict": 600}, timeout=120)
    skeleton = _parse_json_lax(raw)
    if not skeleton or not skeleton.get("beats"):
        skeleton = {"title": chosen_title, "beats": [
            {"n": 1, "summary": "Tu entres dans le bois — quelque chose t'observe.",
             "faction_tilt": "neutre", "emotion": "curiosite"},
            {"n": 2, "summary": "Un signe dans la mousse capte ton regard.",
             "faction_tilt": "druides", "emotion": "fascination"},
            {"n": 3, "summary": "Tu fais face à un choix moral.",
             "faction_tilt": "korrigans", "emotion": "tension"},
            {"n": 4, "summary": "La forêt te répond, vaste et lente.",
             "faction_tilt": "anciens", "emotion": "peur"},
            {"n": 5, "summary": "Tu repars marqué par ton choix.",
             "faction_tilt": "niamh", "emotion": "sagesse"},
        ]}
    return skeleton, {"duration_s": dur, "rag_matches": [m["title"] for m in matches]}


def llm_card(rag: RAG, biome: str, beat: dict, beat_idx: int, total: int) -> tuple[dict, dict]:
    ratio = beat_idx / max(total, 1)
    if beat_idx == total - 1:
        act_type = "boss"
    elif abs(ratio - 0.15) < 0.06:
        act_type = "shop"
    elif 0.30 <= ratio <= 0.65 and (beat_idx % 2 == 1):
        act_type = "event"
    else:
        act_type = "standard"

    matches = rag.query(beat.get("summary", ""), 2)
    cards_refs = []
    for m in matches:
        for c in m.get("cards", []):
            if c.get("type") in ("NARRATIVE", "EVENT", "SHOP", "MERLIN_DIRECT"):
                summary = c.get("summary", "")
                opts = [o.get("label", "?") for o in c.get("options", [])]
                cards_refs.append(f'- "{summary}" → [{", ".join(opts)}]')
                if len(cards_refs) >= 3:
                    break
        if len(cards_refs) >= 3:
            break
    cards_block = "\n".join(cards_refs)
    system = (
        "Tu es le Gamemaster de M.E.R.L.I.N.. Produis UNE carte au format JSON strict.\n"
        "Format : {\"text\": str (1-3 phrases druidiques), \"speaker\": \"merlin\", "
        "\"options\": [3 items {\"label\": str, \"effects\": [{type, faction?, amount}]}]}.\n"
        "Effects : DAMAGE_LIFE/HEAL_LIFE/ADD_REPUTATION/ADD_ANAM. "
        "Factions : druides/anciens/korrigans/niamh/ankou.\n"
        f"Biome : {biome}. Type d'acte : {act_type}. "
        f"Faction tilt : {beat.get('faction_tilt','neutre')}. Emotion : {beat.get('emotion','')}.\n"
        f"Contexte beat : {beat.get('summary','')}\n"
        f"\nExemples canoniques :\n{cards_block}\n"
        "\nRéponds UNIQUEMENT le JSON, sans markdown."
    )
    raw, dur = generate(GM_MODEL, system, "Génère la carte JSON.",
                       {"temperature": 0.7, "num_predict": 400}, timeout=60)
    card = _parse_json_lax(raw)
    if not card or "options" not in card:
        card = {
            "text": beat.get("summary", "Une rencontre te dépasse."),
            "speaker": "merlin",
            "options": [
                {"label": "Observer", "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]},
                {"label": "Avancer", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
                {"label": "Reculer", "effects": [{"type": "DAMAGE_LIFE", "amount": 2}]},
            ],
        }
    return card, {"duration_s": dur, "act_type": act_type,
                  "rag_matches": [m["title"] for m in matches]}


def _parse_json_lax(text: str) -> dict:
    if not text:
        return {}
    t = text.strip()
    if t.startswith("```"):
        first_nl = t.find("\n")
        if first_nl > 0:
            t = t[first_nl + 1:]
        if t.endswith("```"):
            t = t[:-3]
    a, b = t.find("{"), t.rfind("}")
    if a < 0 or b <= a:
        return {}
    try:
        return json.loads(t[a:b + 1])
    except json.JSONDecodeError:
        return {}


class RPGState:
    """Bible §13 — life drain -1/card, 5 factions ±20 caps, Anam cross-run, 4 stats."""
    def __init__(self) -> None:
        self.life = 100
        self.factions = {"druides": 0, "anciens": 0, "korrigans": 0, "niamh": 0, "ankou": 0}
        self.anam = 0
        self.stats = {"logic": 3, "empathie": 3, "volonte": 3, "instinct": 3}
        self.oghams_equipped = ["beith"]
        self.confiance_merlin = 1
        self.history: list = []

    def apply_card_choice(self, card: dict, option_idx: int, beat_idx: int) -> dict:
        options = card.get("options", [])
        option = options[option_idx] if 0 <= option_idx < len(options) else {}
        delta = {"life": -1, "factions": {}, "anam": 0, "xp": {}}
        self.life = max(0, self.life - 1)
        for eff in option.get("effects", []):
            t = eff.get("type", "")
            if t == "DAMAGE_LIFE":
                amount = int(eff.get("amount", 3))
                self.life = max(0, self.life - amount)
                delta["life"] -= amount
            elif t == "HEAL_LIFE":
                amount = int(eff.get("amount", 5))
                self.life = min(100, self.life + amount)
                delta["life"] += amount
            elif t == "ADD_REPUTATION":
                fac = str(eff.get("faction", ""))
                amount = int(eff.get("amount", 5))
                if fac in self.factions:
                    self.factions[fac] = max(0, min(100, self.factions[fac] + amount))
                    delta["factions"][fac] = amount
            elif t == "ADD_ANAM":
                amount = int(eff.get("amount", 1))
                self.anam += amount
                delta["anam"] += amount
        stat_map = {0: "logic", 1: "empathie", 2: "volonte"}
        target_stat = stat_map.get(option_idx, "instinct")
        delta["xp"][target_stat] = 1
        self.history.append({
            "beat_idx": beat_idx, "option_idx": option_idx,
            "option_label": option.get("label", "?"),
            "delta": delta, "snapshot": self.snapshot(),
        })
        return delta

    def snapshot(self) -> dict:
        return {
            "life": self.life, "factions": dict(self.factions), "anam": self.anam,
            "stats": dict(self.stats), "confiance_merlin": self.confiance_merlin,
        }


def pick_option_heuristic(card: dict, beat: dict, rng: random.Random) -> int:
    target = beat.get("faction_tilt", "neutre")
    options = card.get("options", [])
    if not options:
        return 0
    if target == "neutre":
        return rng.randint(0, len(options) - 1)
    for i, opt in enumerate(options):
        for eff in opt.get("effects", []):
            if eff.get("type") == "ADD_REPUTATION" and eff.get("faction") == target:
                return i
    return 0


def run_simulation() -> dict:
    rng = random.Random(42)
    rag = RAG()
    rpg = RPGState()
    trace = {
        "started_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "biome": BIOME,
        "models": {"narrator": NARRATOR_MODEL, "gamemaster": GM_MODEL, "embed": EMBED_MODEL},
        "rpg_initial": rpg.snapshot(),
        "steps": [],
        "ended_at": None,
        "total_duration_s": 0.0,
    }
    t_run_start = time.time()

    # Step 0 : brain check
    t0 = time.time()
    try:
        tags = json.loads(urlopen(f"{OLLAMA_BASE}/api/tags", timeout=5).read().decode())
        models_present = [m["name"] for m in tags.get("models", [])]
        brain_ready = (any(NARRATOR_MODEL in n for n in models_present)
                       and any(GM_MODEL in n for n in models_present))
    except Exception:
        brain_ready = False
        models_present = []
    trace["steps"].append({
        "step": 0, "phase": "brain_check", "label": "Vérification disponibilité du cerveau (strict mode)",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": round(time.time() - t0, 2),
        "result": {"brain_ready": brain_ready, "models_present": models_present},
    })
    if not brain_ready:
        print("[FATAL] Brain not ready — aborting")
        trace["ended_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
        return trace

    # Step 1 : titles
    print("[Step 1] Generating 3 titles…")
    titles, meta_titles = llm_titles(rag, BIOME)
    trace["steps"].append({
        "step": 1, "phase": "titles", "label": "LLM 1 — Génération des 3 titres",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": round(meta_titles["duration_s"], 2),
        "model": NARRATOR_MODEL,
        "rag_few_shot_used": meta_titles["rag_matches"],
        "output": {"titles": titles},
    })

    # Step 2 : player picks
    chosen_idx = rng.randint(0, 2)
    chosen_title = titles[chosen_idx]
    print(f"[Step 2] Player picks: « {chosen_title} »")
    trace["steps"].append({
        "step": 2, "phase": "player_pick", "label": "Joueur choisit un titre",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": 0.6,
        "output": {"chosen_idx": chosen_idx, "chosen_title": chosen_title},
    })

    # Step 3 : intro
    print("[Step 3] Generating intro…")
    intro, meta_intro = llm_intro(rag, BIOME, chosen_title)
    sentence_count = intro.count(".") + intro.count("!") + intro.count("?")
    trace["steps"].append({
        "step": 3, "phase": "intro", "label": "LLM 2 — Intro lore-aware (parchemin)",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": round(meta_intro["duration_s"], 2),
        "model": NARRATOR_MODEL,
        "rag_few_shot_used": meta_intro["rag_matches"],
        "output": {"intro": intro, "sentence_count": sentence_count},
    })

    # Step 4 : parchment animation
    parch_duration = 1.2 + (len(intro) / 16.6) + 3.0 + 0.8
    trace["steps"].append({
        "step": 4, "phase": "parchment", "label": "Parchemin se déroule + typewriter + hold + close",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": round(parch_duration, 2),
        "output": {"phases": "unroll 1.2s + typewriter %.1fs + hold 3s + roll-out 0.8s"
                              % (len(intro) / 16.6)},
    })

    # Step 5 : skeleton
    print("[Step 5] Generating skeleton…")
    skeleton, meta_skel = llm_skeleton(rag, BIOME, chosen_title)
    beats = skeleton.get("beats", [])
    trace["steps"].append({
        "step": 5, "phase": "skeleton", "label": "LLM 3 — Skeleton 5-10 beats",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": round(meta_skel["duration_s"], 2),
        "model": GM_MODEL,
        "rag_few_shot_used": meta_skel["rag_matches"],
        "output": {"title": skeleton.get("title"), "beats_count": len(beats), "beats": beats},
    })

    # Step 6+ : per-beat card gen + player play
    for beat_idx, beat in enumerate(beats):
        print(f"[Step {6 + beat_idx * 2}] Card beat {beat_idx + 1}/{len(beats)}…")
        card, meta_card = llm_card(rag, BIOME, beat, beat_idx, len(beats))
        trace["steps"].append({
            "step": 6 + beat_idx * 2, "phase": "card_gen",
            "label": "LLM 4 — Carte beat %d/%d (%s)" % (beat_idx + 1, len(beats), meta_card["act_type"]),
            "t_offset_s": round(time.time() - t_run_start, 2),
            "duration_s": round(meta_card["duration_s"], 2),
            "model": GM_MODEL,
            "rag_few_shot_used": meta_card["rag_matches"],
            "act_type": meta_card["act_type"],
            "output": {"card": card, "beat": beat},
        })
        option_idx = pick_option_heuristic(card, beat, rng)
        options = card.get("options", [])
        chosen_opt = options[option_idx] if 0 <= option_idx < len(options) else {}
        delta = rpg.apply_card_choice(card, option_idx, beat_idx)
        trace["steps"].append({
            "step": 7 + beat_idx * 2, "phase": "card_play",
            "label": "Joueur choisit « %s » → effets appliqués" % chosen_opt.get("label", "?"),
            "t_offset_s": round(time.time() - t_run_start, 2),
            "duration_s": 2.0,
            "output": {
                "option_idx": option_idx,
                "option_label": chosen_opt.get("label", "?"),
                "effects": chosen_opt.get("effects", []),
                "rpg_delta": delta,
                "rpg_snapshot": rpg.snapshot(),
            },
        })
        if rpg.life <= 0:
            trace["steps"].append({
                "step": 8 + beat_idx * 2, "phase": "death",
                "label": "Le druide meurt avant la fin",
                "t_offset_s": round(time.time() - t_run_start, 2),
                "duration_s": 0,
                "output": {"final_life": rpg.life},
            })
            break

    # Final summary
    dominant_faction = max(rpg.factions.items(), key=lambda x: x[1])
    final_snapshot = rpg.snapshot()
    trace["steps"].append({
        "step": 99, "phase": "summary", "label": "Fin de run + résumé",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": 0,
        "output": {
            "final_rpg": final_snapshot,
            "dominant_faction": dominant_faction,
            "cards_played": len(rpg.history),
            "alive": rpg.life > 0,
        },
    })

    trace["ended_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
    trace["total_duration_s"] = round(time.time() - t_run_start, 2)
    trace["rpg_final"] = final_snapshot
    return trace


def html_escape(s) -> str:
    if s is None:
        return ""
    return (str(s).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace('"', "&quot;"))


def render_html(trace: dict) -> str:
    parts = ["""<!DOCTYPE html>
<html lang="fr"><head><meta charset="UTF-8">
<title>M.E.R.L.I.N. — Test humain run end-to-end (v7.7.25)</title>
<style>
:root {
  --gold:#eba84d;--gold-dim:#8c7a4b;--gold-bright:#ffd76b;
  --white:#f7f7f0;--bg-dark:#0d0a08;--bg-panel:#1a1612;--bg-hover:#25201a;
  --crimson:#c72929;--violet:#9f62ff;--cyan:#5a8aa8;--green:#5a8a4d;
  --druides:#5a8a4d;--anciens:#d4a868;--korrigans:#9b59ff;--niamh:#5a8aa8;--ankou:#888;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg-dark);color:var(--white);font-family:'Georgia',serif;line-height:1.6}
header{background:linear-gradient(180deg,var(--bg-panel) 0%,var(--bg-dark) 100%);border-bottom:4px solid var(--gold);padding:30px 60px 20px;position:sticky;top:0;z-index:100}
header h1{margin:0 0 6px;font-size:30px;color:var(--gold);letter-spacing:2px;text-transform:uppercase}
header .meta{color:var(--gold-dim);font-size:13px}
header .stats-bar{display:flex;gap:14px;margin-top:12px;flex-wrap:wrap}
header .stat-pill{background:var(--bg-dark);border:2px solid var(--gold-dim);padding:6px 12px;font-size:12px}
header .stat-pill strong{color:var(--gold-bright);font-size:15px;display:block}
main{padding:24px 60px;max-width:1400px;margin:0 auto}
.step{background:var(--bg-panel);border:2px solid var(--gold-dim);margin-bottom:14px;padding:16px 22px}
.step.phase-brain_check{border-color:var(--gold-bright)}
.step.phase-titles{border-color:var(--gold)}
.step.phase-player_pick{border-color:var(--violet)}
.step.phase-intro{border-color:var(--gold-bright)}
.step.phase-parchment{border-color:var(--gold-dim)}
.step.phase-skeleton{border-color:var(--cyan)}
.step.phase-card_gen{border-color:var(--gold)}
.step.phase-card_play{border-color:var(--violet)}
.step.phase-summary{border-color:var(--crimson)}
.step.phase-death{border-color:var(--crimson);background:#1a0d0d}
.step-head{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;gap:14px;flex-wrap:wrap}
.step-num{color:var(--gold-bright);font-weight:bold;font-size:12px;text-transform:uppercase;letter-spacing:2px}
.step-label{color:var(--gold-bright);font-size:17px;flex:1;min-width:300px}
.step-time{color:var(--gold-dim);font-size:11px;font-family:monospace}
.intro-block{background:#eaddad;color:#3a2710;padding:18px;margin:8px 0;font-style:italic;border:2px solid #4d3218;font-size:14.5px;line-height:1.7}
.intro-block::before{content:"« ";color:#4d3218;font-size:20px;font-weight:bold}
.intro-block::after{content:" »";color:#4d3218;font-size:20px;font-weight:bold}
.card-box{background:var(--bg-dark);border:1px solid var(--gold-dim);padding:12px;margin:6px 0}
.card-text{font-style:italic;color:var(--white);margin-bottom:8px;font-size:14px}
.options{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-top:8px}
.option{background:var(--bg-panel);border:1px solid var(--gold-dim);padding:8px;font-size:12.5px}
.option.chosen{border-color:var(--gold-bright);background:var(--bg-hover);box-shadow:0 0 0 1px var(--gold-bright)}
.option .label{color:var(--gold-bright);font-weight:bold;margin-bottom:4px}
.option .effects{font-size:10.5px;color:var(--gold-dim);font-family:monospace}
.rag-refs{font-size:11.5px;color:var(--cyan);font-style:italic;margin-top:6px}
table.beats{width:100%;border-collapse:collapse;font-size:12.5px;margin-top:8px}
table.beats th{background:var(--bg-dark);color:var(--gold);padding:6px 8px;text-align:left;border-bottom:2px solid var(--gold-dim);text-transform:uppercase;font-size:10.5px}
table.beats td{padding:6px 8px;border-bottom:1px solid var(--bg-hover)}
.faction-druides{color:var(--druides)}
.faction-anciens{color:var(--anciens)}
.faction-korrigans{color:var(--korrigans)}
.faction-niamh{color:var(--niamh)}
.faction-ankou{color:var(--ankou)}
.faction-neutre{color:var(--gold-dim)}
.rpg-bar{display:flex;gap:8px;flex-wrap:wrap;margin-top:8px}
.rpg-stat{background:var(--bg-dark);border-left:3px solid var(--gold);padding:5px 10px;font-size:11.5px;min-width:110px}
.rpg-stat .name{color:var(--gold-dim);text-transform:uppercase;font-size:9.5px}
.rpg-stat .value{color:var(--gold-bright);font-weight:bold;font-size:13px}
.life-bar{display:inline-block;width:110px;height:8px;background:var(--bg-dark);border:1px solid var(--gold-dim);vertical-align:middle;margin-left:6px}
.life-bar .fill{height:100%;background:linear-gradient(90deg,var(--crimson) 0%,var(--gold-bright) 50%,var(--green) 100%)}
.timeline-info{color:var(--gold-dim);font-size:10.5px;margin-bottom:4px;font-family:monospace}
footer{padding:20px 60px;text-align:center;color:var(--gold-dim);font-size:11px;border-top:1px solid var(--gold-dim);margin-top:30px}
</style></head><body>"""]

    final_rpg = trace.get("rpg_final", trace.get("rpg_initial", {}))
    total_steps = len(trace.get("steps", []))
    parts.append(f"""<header>
<h1>M.E.R.L.I.N. — Test humain run end-to-end</h1>
<div class="meta">Pipeline v7.7.23 (RAG-augmented) + v7.7.24 (strict mode + guardrails + persistence) · biome <strong>{html_escape(trace.get('biome','?'))}</strong> · démarré {html_escape(trace.get('started_at','?'))} · terminé {html_escape(trace.get('ended_at','?'))}</div>
<div class="stats-bar">
  <div class="stat-pill"><strong>{trace.get('total_duration_s', 0):.1f}s</strong>Durée totale</div>
  <div class="stat-pill"><strong>{total_steps}</strong>Étapes</div>
  <div class="stat-pill"><strong>{final_rpg.get('life', 0)}/100</strong>Vie finale</div>
  <div class="stat-pill"><strong>{final_rpg.get('anam', 0)}</strong>Anam</div>
  <div class="stat-pill"><strong>{html_escape(trace['models']['narrator'])}</strong>Narrator</div>
  <div class="stat-pill"><strong>{html_escape(trace['models']['gamemaster'])}</strong>GM</div>
</div>
</header>
<main>""")

    for s in trace.get("steps", []):
        phase = s.get("phase", "")
        parts.append(f'<div class="step phase-{html_escape(phase)}">')
        parts.append('<div class="step-head">')
        parts.append(f'<div class="step-num">Étape {s.get("step","?")}</div>')
        parts.append(f'<div class="step-label">{html_escape(s.get("label",""))}</div>')
        parts.append(f'<div class="step-time">t+{s.get("t_offset_s",0):.2f}s · durée {s.get("duration_s",0):.2f}s</div>')
        parts.append('</div>')

        if phase == "brain_check":
            r = s.get("result", {})
            status = "✓ OPÉRATIONNEL" if r.get("brain_ready") else "✗ INDISPONIBLE"
            color = "var(--green)" if r.get("brain_ready") else "var(--crimson)"
            parts.append(f'<div style="color:{color};font-weight:bold">{status}</div>')
            parts.append(f'<div class="rag-refs">Modèles présents : {html_escape(", ".join(r.get("models_present", [])))}</div>')

        elif phase == "titles":
            out = s.get("output", {})
            parts.append('<ol>')
            for t in out.get("titles", []):
                parts.append(f'<li><strong>« {html_escape(t)} »</strong></li>')
            parts.append('</ol>')
            parts.append(f'<div class="rag-refs">RAG few-shot : {html_escape(", ".join(s.get("rag_few_shot_used", [])))}</div>')

        elif phase == "player_pick":
            out = s.get("output", {})
            parts.append(f'<div style="color:var(--violet);font-size:15px">→ « {html_escape(out.get("chosen_title",""))} » <span style="color:var(--gold-dim)">(option {out.get("chosen_idx",0) + 1})</span></div>')

        elif phase == "intro":
            out = s.get("output", {})
            parts.append(f'<div class="intro-block">{html_escape(out.get("intro",""))}</div>')
            parts.append(f'<div class="rag-refs">RAG few-shot : {html_escape(", ".join(s.get("rag_few_shot_used", [])))} · {out.get("sentence_count",0)} phrases</div>')

        elif phase == "parchment":
            out = s.get("output", {})
            parts.append(f'<div style="color:var(--gold-dim);font-style:italic">📜 {html_escape(out.get("phases",""))}</div>')

        elif phase == "skeleton":
            out = s.get("output", {})
            parts.append(f'<div style="margin-bottom:6px"><strong>{html_escape(out.get("title",""))}</strong> — {out.get("beats_count",0)} beats</div>')
            parts.append('<table class="beats"><thead><tr><th>n</th><th>Emotion</th><th>Faction tilt</th><th>Summary</th></tr></thead><tbody>')
            for b in out.get("beats", []):
                tilt = b.get("faction_tilt", "neutre")
                parts.append(f'<tr><td>{b.get("n","?")}</td><td>{html_escape(b.get("emotion",""))}</td><td class="faction-{html_escape(tilt)}">{html_escape(tilt)}</td><td>{html_escape(b.get("summary",""))}</td></tr>')
            parts.append('</tbody></table>')
            parts.append(f'<div class="rag-refs">RAG few-shot : {html_escape(", ".join(s.get("rag_few_shot_used", [])))}</div>')

        elif phase == "card_gen":
            out = s.get("output", {})
            card = out.get("card", {})
            beat = out.get("beat", {})
            parts.append(f'<div class="timeline-info">Beat : {html_escape(beat.get("summary",""))} · emotion {html_escape(beat.get("emotion","?"))} · tilt {html_escape(beat.get("faction_tilt","?"))} · type <strong>{html_escape(s.get("act_type","?"))}</strong></div>')
            parts.append('<div class="card-box">')
            parts.append(f'<div class="card-text">{html_escape(card.get("text",""))}</div>')
            parts.append('<div class="options">')
            for opt in card.get("options", []):
                effs = ", ".join("%s:%s" % (e.get("type","?"), e.get("amount", e.get("faction","?"))) for e in opt.get("effects", []))
                parts.append(f'<div class="option"><div class="label">{html_escape(opt.get("label","?"))}</div><div class="effects">{html_escape(effs)}</div></div>')
            parts.append('</div></div>')
            parts.append(f'<div class="rag-refs">RAG cards : {html_escape(", ".join(s.get("rag_few_shot_used", [])))}</div>')

        elif phase == "card_play":
            out = s.get("output", {})
            delta = out.get("rpg_delta", {})
            snap = out.get("rpg_snapshot", {})
            parts.append(f'<div style="color:var(--violet);font-weight:bold;margin-bottom:6px">→ choix : « {html_escape(out.get("option_label",""))} »</div>')
            parts.append('<div class="rpg-bar">')
            life_pct = max(0, min(100, snap.get("life", 0)))
            parts.append(f'<div class="rpg-stat"><div class="name">Vie</div><div class="value">{snap.get("life",0)}/100<span class="life-bar"><span class="fill" style="width:{life_pct}%"></span></span></div></div>')
            if snap.get("anam", 0) != 0 or delta.get("anam", 0) != 0:
                parts.append(f'<div class="rpg-stat"><div class="name">Anam</div><div class="value">{snap.get("anam",0)}</div></div>')
            for fac, val in snap.get("factions", {}).items():
                d = delta.get("factions", {}).get(fac, 0)
                if d != 0 or val != 0:
                    sign = "+%d" % d if d > 0 else (str(d) if d < 0 else "")
                    parts.append(f'<div class="rpg-stat"><div class="name faction-{fac}">{fac}</div><div class="value">{val} <span style="color:var(--gold-bright);font-size:11px">{sign}</span></div></div>')
            for stat, val in snap.get("stats", {}).items():
                if delta.get("xp", {}).get(stat, 0) != 0:
                    parts.append(f'<div class="rpg-stat"><div class="name">{html_escape(stat)}</div><div class="value">{val} <span style="color:var(--green);font-size:11px">+1 XP</span></div></div>')
            parts.append('</div>')

        elif phase == "summary":
            out = s.get("output", {})
            final = out.get("final_rpg", {})
            dom = out.get("dominant_faction", ["",0])
            parts.append(f'<div style="font-size:15px;color:var(--gold-bright);margin-bottom:10px">Run terminé · {out.get("cards_played",0)} cartes jouées · {"VIVANT" if out.get("alive") else "MORT"}</div>')
            parts.append(f'<div>Faction dominante : <span class="faction-{html_escape(dom[0])}">{html_escape(dom[0])}</span> @ <strong>{dom[1]}</strong></div>')
            parts.append('<div class="rpg-bar" style="margin-top:10px">')
            parts.append(f'<div class="rpg-stat"><div class="name">Vie finale</div><div class="value">{final.get("life",0)}/100</div></div>')
            parts.append(f'<div class="rpg-stat"><div class="name">Anam total</div><div class="value">{final.get("anam",0)}</div></div>')
            for stat, val in final.get("stats", {}).items():
                parts.append(f'<div class="rpg-stat"><div class="name">{html_escape(stat)}</div><div class="value">{val}</div></div>')
            parts.append('</div>')

        elif phase == "death":
            out = s.get("output", {})
            parts.append(f'<div style="color:var(--crimson);font-weight:bold">💀 Le druide meurt — vie finale : {out.get("final_life",0)}/100</div>')

        parts.append('</div>')

    parts.append("""</main>
<footer>M.E.R.L.I.N. — simulate_human_run.py v7.7.25 — généré le %s</footer>
</body></html>""" % time.strftime("%Y-%m-%d %H:%M:%S"))

    return "".join(parts)


def main() -> int:
    print(f"[OK] Loading references from {REFERENCES_PATH.name}")
    trace = run_simulation()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    JSON_PATH.write_text(json.dumps(trace, ensure_ascii=False, indent=2), encoding="utf-8")
    HTML_PATH.write_text(render_html(trace), encoding="utf-8")
    print(f"[OK] Run duration : {trace.get('total_duration_s', 0):.1f}s · {len(trace.get('steps',[]))} steps")
    print(f"[OK] HTML : {HTML_PATH}")
    print(f"[OK] JSON : {JSON_PATH}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

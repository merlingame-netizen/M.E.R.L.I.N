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
HTML_PATH = OUT_DIR / "merlin_human_run_test_v7.7.29.html"
JSON_PATH = OUT_DIR / "merlin_human_run_test_v7.7.29.json"

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
    # v7.7.29 — Intro = SETUP-ONLY, ne révèle PAS le scénario.
    # Place le druide en contexte avant la marche ; aucune rencontre, aucun
    # événement, aucune révélation ; juste l'état d'esprit + le seuil franchi.
    matches = rag.query(f"{chosen_title} · {biome}", 3)
    refs_block = "\n\n".join(f"Exemple {i+1} :\n{m.get('intro', '')[:400]}"
                              for i, m in enumerate(matches[:2]))
    system = (
        "Tu rédiges l'INTRODUCTION d'une marche druidique en Brocéliande.\n"
        "POV : 2e personne, jeune druide en initiation.\n"
        "RÈGLE STRICTE : C'EST UN SETUP, PAS UN RÉSUMÉ DU SCÉNARIO.\n"
        "  - Ne révèle AUCUNE rencontre, AUCUN événement, AUCUNE créature.\n"
        "  - Décris uniquement : pourquoi le druide part, son état d'esprit, "
        "son arrivée au seuil de la forêt.\n"
        "  - Ne donne aucun indice sur ce qui va arriver dans la marche.\n"
        "FORMAT : EXACTEMENT 4 à 6 phrases ; français celtique ; pas d'anglicismes ; "
        "pas de méta-discours (jeu/joueur/simulation).\n"
        f"\nExemples :\n{refs_block}\n\n"
        f"Rédige le setup pour le titre : \"{chosen_title}\". "
        "Termine la dernière phrase au moment où le druide pose le pied sur la mousse."
    )
    raw, dur = generate(NARRATOR_MODEL, system,
                        "Setup 4-6 phrases. Ne révèle rien du scénario.",
                        {"temperature": 0.85, "num_predict": 280})
    return raw.strip(), {"duration_s": dur, "rag_matches": [m["title"] for m in matches]}


def llm_scenario_full(rag: RAG, biome: str, chosen_title: str,
                      acts: list, intro: str = "") -> tuple[str, dict]:
    """v7.7.29 — Scénario COMPLET, suite directe de l'intro. Chaque acte est une
    mini-histoire avec setup / complication / résolution. Arc narratif global.
    L'intro est passée au prompt système pour que le scénario commence là où
    l'intro se termine (le druide vient de poser le pied sur la mousse)."""
    matches = rag.query(f"{chosen_title} · scénario complet", 2)
    refs = "\n".join(f"- {m.get('title','?')} ({len(m.get('cards', []))} cartes)"
                     for m in matches[:2])
    act_outline = "\n".join(
        f"  Acte {a['id']} — « {a['name']} » : {a['theme']} "
        f"(faction {a.get('faction_tilt','neutre')}, {a.get('card_count', 3)} cartes, "
        f"emotion {a.get('emotion','?')})"
        for a in acts
    )
    intro_block = ""
    if intro:
        intro_block = (
            "INTRO (la marche commence à la dernière phrase de ce setup — "
            "ton premier paragraphe doit poursuivre directement) :\n«  " +
            intro[:600] + " »\n\n"
        )
    system = (
        "Tu es Merlin. Écris le SCÉNARIO COMPLET d'une marche druidique en "
        f"{len(acts)} paragraphes (un par acte). Titre : \"{chosen_title}\" "
        f"(biome : {biome}).\n\n"
        + intro_block +
        "CONTRAINTES :\n"
        "  - Le 1er paragraphe ENCHAÎNE directement à la fin de l'intro ci-dessus.\n"
        "  - Chaque paragraphe = UNE PETITE HISTOIRE avec setup → complication → résolution.\n"
        "    Pas un teaser, pas un résumé : un acte narratif complet en lui-même.\n"
        "  - Cohérence globale : les actes s'enchaînent en arc dramatique (curiosité → "
        "tension → climax → sagesse). Le dernier acte conclut la marche.\n"
        "  - Français celtique druidique, 2e personne, pas d'anglicismes, pas de méta.\n"
        f"\nActes à écrire :\n{act_outline}\n"
        f"Exemples canoniques :\n{refs}\n"
        "\nFORMAT :\n"
        "**Acte 1 — Le Seuil**\n"
        "[paragraphe complet : setup, complication, résolution de cet acte]\n\n"
        "**Acte 2 — La Rencontre**\n"
        "[paragraphe complet, qui poursuit l'acte 1]\n\n"
        "...\n"
        "Réponds UNIQUEMENT avec les paragraphes formatés, sans intro ni conclusion méta."
    )
    raw, dur = generate(NARRATOR_MODEL, system,
                        "Rédige le scénario complet, chaque acte = mini-histoire avec conclusion.",
                        {"temperature": 0.8, "num_predict": 900}, timeout=360)
    return raw.strip(), {"duration_s": dur, "rag_matches": [m["title"] for m in matches]}


def llm_skeleton(rag: RAG, biome: str, chosen_title: str) -> tuple[dict, dict]:
    """v7.7.28 — Skeleton now produces 4-5 ACTS (pans de scénario), each with a
    name + theme + faction_tilt + emotion + card_count. Total cards across all
    acts ∈ [11, 25] per user mandate. Cards within an act share the act's
    faction_tilt + emotion arc and can be distinguished by sub-beat summaries."""
    matches = rag.query(f"{chosen_title} · structure narrative", 2)
    refs = "\n".join(f"- {m.get('title','?')}" for m in matches[:2])
    system = (
        "Tu es le Gamemaster M.E.R.L.I.N.. Génère le DÉCOUPAGE en actes (JSON strict).\n"
        f"Titre : \"{chosen_title}\" (biome : {biome}).\n\n"
        "Structure : {\"title\": str, \"acts\": [4 ou 5 actes]}.\n"
        "Chaque acte = {id:1..N, name:str (3-5 mots), theme:str (10-15 mots), "
        "faction_tilt, emotion, card_count: int (entre 2 et 7), "
        "beats:[card_count entries] où chaque beat = {n, summary 8-15 mots, sub_emotion}}.\n\n"
        "RÈGLES :\n"
        "- TOTAL des card_count ∈ [11, 25] (somme).\n"
        "- Acte 1 (intro) : 2-3 cartes, emotion=curiosite, faction=neutre/druides.\n"
        "- Actes du milieu (2-3 actes) : 3-5 cartes chacun, tensions montantes.\n"
        "- Acte final (boss) : 2-4 cartes, climax, sub_emotion=sagesse/peur.\n"
        "- faction_tilt ∈ {druides, anciens, korrigans, niamh, ankou, neutre}.\n"
        "- emotion ∈ {curiosite, tension, peur, espoir, sagesse, fascination, melancolie, emerveillement}.\n"
        f"\nExemples canoniques :\n{refs}\n"
        "\nRéponds UNIQUEMENT le JSON, sans markdown ni explication."
    )
    raw, dur = generate(GM_MODEL, system, "Découpage en 4-5 actes (JSON).",
                       {"temperature": 0.8, "num_predict": 900}, timeout=240)
    skeleton = _parse_json_lax(raw)
    if not skeleton or not skeleton.get("acts"):
        skeleton = _fallback_acts(chosen_title)
    # Normalize : ensure each act has id + beats matching card_count + numbered beats
    total = 0
    for ai, act in enumerate(skeleton.get("acts", [])):
        act["id"] = act.get("id", ai + 1)
        if "card_count" not in act:
            act["card_count"] = max(2, min(5, len(act.get("beats", [])) or 3))
        # Pad beats if missing
        beats = act.get("beats", []) or []
        while len(beats) < act["card_count"]:
            beats.append({
                "n": len(beats) + 1,
                "summary": f"Beat {len(beats) + 1} de l'acte « {act.get('name','?')} »",
                "sub_emotion": act.get("emotion", "curiosite"),
            })
        act["beats"] = beats[:act["card_count"]]
        total += act["card_count"]
    skeleton["total_cards"] = total
    return skeleton, {"duration_s": dur, "rag_matches": [m["title"] for m in matches]}


def _fallback_acts(title: str) -> dict:
    return {"title": title, "acts": [
        {"id": 1, "name": "Le Seuil", "theme": "Tu poses le pied dans la forêt brumeuse",
         "faction_tilt": "neutre", "emotion": "curiosite", "card_count": 3,
         "beats": [
             {"n": 1, "summary": "La forêt te jauge, mousse sous tes pieds.", "sub_emotion": "curiosite"},
             {"n": 2, "summary": "Un sentier se révèle entre les hêtres.", "sub_emotion": "curiosite"},
             {"n": 3, "summary": "Tu entends un premier murmure.", "sub_emotion": "fascination"},
         ]},
        {"id": 2, "name": "La Rencontre", "theme": "Un esprit t'apparait sur le sentier",
         "faction_tilt": "druides", "emotion": "fascination", "card_count": 4,
         "beats": [
             {"n": 1, "summary": "Un vieil homme appuyé sur un bâton.", "sub_emotion": "fascination"},
             {"n": 2, "summary": "Il te jauge sans parler.", "sub_emotion": "tension"},
             {"n": 3, "summary": "Tu offres ou prends ou passes.", "sub_emotion": "tension"},
             {"n": 4, "summary": "La forêt approuve ou se referme.", "sub_emotion": "sagesse"},
         ]},
        {"id": 3, "name": "Le Cercle", "theme": "Tu fais face à un dilemme moral",
         "faction_tilt": "korrigans", "emotion": "tension", "card_count": 4,
         "beats": [
             {"n": 1, "summary": "Korrigans rieurs bordent le cercle.", "sub_emotion": "tension"},
             {"n": 2, "summary": "Ils te proposent un troc.", "sub_emotion": "tension"},
             {"n": 3, "summary": "Tu choisis entre garder ou donner.", "sub_emotion": "peur"},
             {"n": 4, "summary": "Le cercle se referme sur ta décision.", "sub_emotion": "fascination"},
         ]},
        {"id": 4, "name": "Le Chêne", "theme": "Le Chêne Ancien révèle la vérité",
         "faction_tilt": "niamh", "emotion": "sagesse", "card_count": 3,
         "beats": [
             {"n": 1, "summary": "Le Chêne s'élève devant toi.", "sub_emotion": "fascination"},
             {"n": 2, "summary": "Tu poses la paume sur l'écorce.", "sub_emotion": "sagesse"},
             {"n": 3, "summary": "Le Chêne te répond — passage ou refus.", "sub_emotion": "sagesse"},
         ]},
        {"id": 5, "name": "Le Retour", "theme": "Tu quittes le nemeton marqué",
         "faction_tilt": "ankou", "emotion": "sagesse", "card_count": 2,
         "beats": [
             {"n": 1, "summary": "La forêt te laisse repartir.", "sub_emotion": "melancolie"},
             {"n": 2, "summary": "Tu retrouves le seuil du clan.", "sub_emotion": "espoir"},
         ]},
    ], "total_cards": 16}


def llm_card(rag: RAG, biome: str, beat: dict, beat_idx: int, total: int,
             route_so_far: list | None = None) -> tuple[dict, dict]:
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
    # v7.7.29 — Personalize per route : compact history of last 3 choices.
    route_block = ""
    if route_so_far:
        recent = route_so_far[-3:]
        route_block = "Historique récent du druide (chemin emprunté) :\n" + "\n".join(
            f"  - Carte #{r.get('card_idx','?')} : « {r.get('option_label','?')[:60]} »"
            for r in recent
        ) + "\nLa carte suivante DOIT refléter ce parcours (continuité narrative).\n"
    system = (
        "Tu es le Gamemaster de M.E.R.L.I.N.. Produis UNE carte au format JSON strict.\n"
        "Format : {\"text\": str (2-3 phrases druidiques, contextualisées au chemin du druide), "
        "\"speaker\": \"merlin\", "
        "\"options\": [3 items {\"label\": str (action concise 3-7 mots), \"effects\": [{type, faction?, amount}]}]}.\n"
        "Effects : DAMAGE_LIFE/HEAL_LIFE/ADD_REPUTATION/ADD_ANAM. "
        "Factions : druides/anciens/korrigans/niamh/ankou.\n"
        f"Biome : {biome}. Type d'acte : {act_type}. "
        f"Faction tilt : {beat.get('faction_tilt','neutre')}. Emotion : {beat.get('emotion','')}.\n"
        f"Acte : {beat.get('act_name','?')}. Contexte beat : {beat.get('summary','')}\n"
        f"\n{route_block}"
        f"Exemples canoniques :\n{cards_block}\n"
        "\nRéponds UNIQUEMENT le JSON, sans markdown."
    )
    raw, dur = generate(GM_MODEL, system, "Génère la carte JSON.",
                       {"temperature": 0.7, "num_predict": 400}, timeout=120)
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


def llm_card_resolution(card: dict, chosen_option: dict, beat: dict,
                        route_so_far: list) -> tuple[str, dict]:
    """v7.7.29 — Résolution narrative LLM par carte. 2-3 phrases qui
    décrivent CE qui se passe APRÈS le choix du druide, en tenant compte du
    chemin parcouru. Personnalisée par carte/choix/chemin pour que chaque
    décision ait une conséquence narrative tangible."""
    route_block = ""
    if route_so_far[:-1]:
        recent = route_so_far[:-1][-2:]
        route_block = " Chemin récent : " + " → ".join(
            f"« {r.get('option_label','?')[:40]} »" for r in recent
        ) + "."
    system = (
        "Tu es Merlin narrateur. Le druide vient de faire un choix. "
        "Écris la CONSÉQUENCE narrative en 2 phrases (résolution immédiate).\n"
        "Français celtique, 2e personne, ton druidique. PAS d'anglicismes ; "
        "pas de méta sur le jeu ; pas de phrase d'intro/conclusion.\n"
        f"Carte : « {card.get('text','')[:200]} »\n"
        f"Choix : « {chosen_option.get('label','?')} »\n"
        f"Beat : {beat.get('summary','?')}.{route_block}"
    )
    raw, dur = generate(NARRATOR_MODEL, system,
                        "Décris la conséquence en 2 phrases.",
                        {"temperature": 0.85, "num_predict": 120}, timeout=90)
    return raw.strip(), {"duration_s": dur}


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

    # Step 5 : skeleton (acts/pans) — v7.7.28
    print("[Step 5] Generating skeleton (4-5 actes, 11-25 cartes total)…")
    skeleton, meta_skel = llm_skeleton(rag, BIOME, chosen_title)
    acts = skeleton.get("acts", [])
    total_cards = skeleton.get("total_cards", sum(a.get("card_count", 0) for a in acts))
    trace["steps"].append({
        "step": 5, "phase": "skeleton", "label": "LLM 3 — Découpage en actes (pans de scénario)",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": round(meta_skel["duration_s"], 2),
        "model": GM_MODEL,
        "rag_few_shot_used": meta_skel["rag_matches"],
        "output": {
            "title": skeleton.get("title"),
            "acts_count": len(acts),
            "total_cards": total_cards,
            "acts": acts,
        },
    })

    # Step 6 : scénario complet — passe l'intro pour suite directe + acts comme outline.
    print(f"[Step 6] Generating scenario complet ({len(acts)} actes / {total_cards} cards target)…")
    scenario_text, meta_scen = llm_scenario_full(rag, BIOME, chosen_title, acts, intro=intro)
    trace["steps"].append({
        "step": 6, "phase": "scenario_full",
        "label": f"LLM 4 — Scénario complet ({len(acts)} actes / {total_cards} cartes)",
        "t_offset_s": round(time.time() - t_run_start, 2),
        "duration_s": round(meta_scen["duration_s"], 2),
        "model": NARRATOR_MODEL,
        "rag_few_shot_used": meta_scen["rag_matches"],
        "output": {"scenario_text": scenario_text, "paragraph_count": scenario_text.count("\n\n") + 1},
    })

    # Step 7+ : actes × cartes — chaque acte génère N cartes (où N = act.card_count)
    step_n = 7
    global_card_idx = 0
    death_break = False
    route_so_far: list = []  # v7.7.29 — historique des choix pour personnalisation
    for act in acts:
        # Acte intro (header step)
        trace["steps"].append({
            "step": step_n, "phase": "act_intro",
            "label": f"Acte {act['id']} — « {act.get('name','?')} » ({act.get('card_count', 0)} cartes)",
            "t_offset_s": round(time.time() - t_run_start, 2),
            "duration_s": 0.5,
            "output": {
                "act_id": act["id"], "act_name": act.get("name", "?"),
                "theme": act.get("theme", ""),
                "faction_tilt": act.get("faction_tilt", "neutre"),
                "emotion": act.get("emotion", ""),
                "card_count": act.get("card_count", 0),
            },
        })
        step_n += 1
        for beat_idx_in_act, beat in enumerate(act.get("beats", [])):
            global_card_idx += 1
            print(f"[Step {step_n}] Act {act['id']} card {beat_idx_in_act+1}/{act['card_count']} (#{global_card_idx}/{total_cards})…")
            # Merge act-level metadata into beat for llm_card prompt context.
            beat_enriched = {
                **beat,
                "faction_tilt": act.get("faction_tilt", "neutre"),
                "emotion": beat.get("sub_emotion", act.get("emotion", "")),
                "act_name": act.get("name", ""),
            }
            card, meta_card = llm_card(rag, BIOME, beat_enriched, global_card_idx - 1, total_cards,
                                       route_so_far=route_so_far)
            trace["steps"].append({
                "step": step_n, "phase": "card_gen",
                "label": f"LLM 5 — Carte {global_card_idx}/{total_cards} (acte {act['id']}, {meta_card['act_type']})",
                "t_offset_s": round(time.time() - t_run_start, 2),
                "duration_s": round(meta_card["duration_s"], 2),
                "model": GM_MODEL,
                "rag_few_shot_used": meta_card["rag_matches"],
                "act_type": meta_card["act_type"],
                "act_id": act["id"],
                "act_name": act.get("name", ""),
                "card_global_idx": global_card_idx,
                "output": {"card": card, "beat": beat_enriched},
            })
            step_n += 1
            option_idx = pick_option_heuristic(card, beat_enriched, rng)
            options = card.get("options", [])
            chosen_opt = options[option_idx] if 0 <= option_idx < len(options) else {}
            delta = rpg.apply_card_choice(card, option_idx, global_card_idx - 1)
            trace["steps"].append({
                "step": step_n, "phase": "card_play",
                "label": "Joueur choisit « %s » → effets appliqués" % chosen_opt.get("label", "?"),
                "t_offset_s": round(time.time() - t_run_start, 2),
                "duration_s": 2.0,
                "act_id": act["id"],
                "card_global_idx": global_card_idx,
                "output": {
                    "option_idx": option_idx,
                    "option_label": chosen_opt.get("label", "?"),
                    "effects": chosen_opt.get("effects", []),
                    "rpg_delta": delta,
                    "rpg_snapshot": rpg.snapshot(),
                },
            })
            step_n += 1
            # v7.7.29 — Update route_so_far for downstream card personalization.
            route_so_far.append({
                "card_idx": global_card_idx,
                "act_id": act["id"],
                "option_idx": option_idx,
                "option_label": chosen_opt.get("label", "?"),
            })
            # v7.7.29 — NEW resolution narrative : 2-sentence LLM continuation
            # describing what happens AFTER the choice, contextualised to the route.
            resolution_text, meta_res = llm_card_resolution(
                card, chosen_opt, beat_enriched, route_so_far
            )
            trace["steps"].append({
                "step": step_n, "phase": "card_resolution",
                "label": "LLM 6 — Résolution narrative de la carte %d" % global_card_idx,
                "t_offset_s": round(time.time() - t_run_start, 2),
                "duration_s": round(meta_res["duration_s"], 2),
                "model": NARRATOR_MODEL,
                "act_id": act["id"],
                "card_global_idx": global_card_idx,
                "output": {
                    "resolution_text": resolution_text,
                    "chosen_label": chosen_opt.get("label", "?"),
                },
            })
            step_n += 1
            if rpg.life <= 0:
                trace["steps"].append({
                    "step": step_n, "phase": "death",
                    "label": "Le druide meurt avant la fin de l'acte",
                    "t_offset_s": round(time.time() - t_run_start, 2),
                    "duration_s": 0,
                    "output": {"final_life": rpg.life, "killed_in_act": act["id"]},
                })
                death_break = True
                break
        if death_break:
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
.step.phase-scenario_full{border-color:var(--gold-bright);background:#1a140d}
.step.phase-act_intro{border-color:var(--cyan);background:#0d1418;padding:10px 22px}
.step.phase-card_resolution{border-color:var(--green);background:#0d1a10;padding:12px 22px}
.resolution-block{background:#15201a;color:#cfdcc5;padding:12px 16px;border-left:3px solid var(--green);font-style:italic;font-size:13.5px;line-height:1.6;margin-top:6px}
.resolution-block::before{content:"✦ ";color:var(--green);font-weight:bold}
.act-header{display:flex;gap:14px;align-items:center;flex-wrap:wrap}
.act-id{background:var(--cyan);color:var(--bg-dark);width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:bold;font-size:18px;flex-shrink:0}
.act-meta{display:flex;gap:10px;flex-wrap:wrap;font-size:11.5px;color:var(--gold-dim);margin-top:6px}
.act-meta span{background:var(--bg-dark);padding:3px 8px;border:1px solid var(--gold-dim)}
.scenario-block{background:#eaddad;color:#3a2710;padding:22px;margin:8px 0;font-style:italic;border:2px solid #4d3218;font-size:14px;line-height:1.75}
.scenario-block strong{color:#5d2e0a;font-style:normal;display:block;margin:14px 0 6px;font-size:15.5px;letter-spacing:1px;border-bottom:1px solid #b59868;padding-bottom:2px}
.scenario-block::before{content:"📜 ";font-size:18px}
/* v7.7.28 — load-time badges */
.load-badge{display:inline-block;padding:2px 8px;font-size:11px;font-family:monospace;font-weight:bold;border-radius:3px;margin-left:8px;vertical-align:middle}
.load-badge.fast{background:rgba(90,138,77,0.25);color:var(--green);border:1px solid var(--green)}
.load-badge.medium{background:rgba(235,168,77,0.20);color:var(--gold);border:1px solid var(--gold)}
.load-badge.slow{background:rgba(199,41,41,0.20);color:var(--crimson);border:1px solid var(--crimson)}
.load-badge::before{content:"⏱ "}
/* v7.7.28 — Mermaid routes panel */
.routes-panel{background:var(--bg-panel);border:2px solid var(--gold-bright);padding:20px;margin-bottom:20px}
.routes-panel h2{color:var(--gold-bright);margin:0 0 12px;font-size:18px;letter-spacing:1.5px;text-transform:uppercase}
.routes-panel pre{background:var(--bg-dark);color:var(--white);padding:14px;font-family:monospace;font-size:11.5px;line-height:1.4;overflow-x:auto;border:1px solid var(--gold-dim);white-space:pre-wrap}
.routes-mermaid{font-family:monospace;font-size:12px;color:var(--cyan);background:var(--bg-dark);padding:14px;border:1px solid var(--gold-dim);overflow-x:auto;white-space:pre}
.routes-legend{font-size:11.5px;color:var(--gold-dim);margin-top:8px}
.routes-legend strong{color:var(--gold-bright)}
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
    # v7.7.28 — extract acts skeleton + total LLM load time for the routes panel
    acts: list = []
    total_cards = 0
    total_llm_load_s = 0.0
    chosen_route: list = []
    for s in trace.get("steps", []):
        if s.get("phase") == "skeleton":
            acts = s.get("output", {}).get("acts", [])
            total_cards = s.get("output", {}).get("total_cards", 0)
        if s.get("phase") in ("titles", "intro", "skeleton", "scenario_full", "card_gen", "card_resolution"):
            total_llm_load_s += float(s.get("duration_s", 0.0))
        if s.get("phase") == "card_play":
            out = s.get("output", {})
            chosen_route.append({
                "card_idx": s.get("card_global_idx", 0),
                "act_id": s.get("act_id", 0),
                "option_idx": out.get("option_idx", 0),
                "option_label": out.get("option_label", "?"),
            })
    parts.append(f"""<header>
<h1>M.E.R.L.I.N. — Test humain run end-to-end (v7.7.28)</h1>
<div class="meta">Pipeline v7.7.29 (Gemma 4 ONLY · intro setup-only · scénario = suite directe · cartes route-aware + résolution narrative LLM par carte · think:off) · biome <strong>{html_escape(trace.get('biome','?'))}</strong> · démarré {html_escape(trace.get('started_at','?'))} · terminé {html_escape(trace.get('ended_at','?'))}</div>
<div class="stats-bar">
  <div class="stat-pill"><strong>{trace.get('total_duration_s', 0):.1f}s</strong>Durée totale</div>
  <div class="stat-pill"><strong>{total_llm_load_s:.1f}s</strong>⏱ LLM load cumul</div>
  <div class="stat-pill"><strong>{total_steps}</strong>Étapes</div>
  <div class="stat-pill"><strong>{len(acts)}</strong>Actes</div>
  <div class="stat-pill"><strong>{total_cards}</strong>Cartes (cible)</div>
  <div class="stat-pill"><strong>{final_rpg.get('life', 0)}/100</strong>Vie finale</div>
  <div class="stat-pill"><strong>{final_rpg.get('anam', 0)}</strong>Anam</div>
  <div class="stat-pill"><strong>{html_escape(trace['models']['narrator'])}</strong>Narrator</div>
  <div class="stat-pill"><strong>{html_escape(trace['models']['gamemaster'])}</strong>GM</div>
</div>
</header>
<main>""")

    # v7.7.28 — Routes panel : ASCII tree of acts × cards × chosen-option, then
    # the chosen path summarised. Mermaid syntax kept inline for portability.
    if acts:
        parts.append('<div class="routes-panel">')
        parts.append('<h2>🗺  Pans de scénario → cartes → routes possibles</h2>')
        ascii_lines = [f"  ▶ « {trace.get('chosen_title', '')} »"]
        for ai, act in enumerate(acts):
            connector = "└─" if ai == len(acts) - 1 else "├─"
            ascii_lines.append(f"  {connector} Acte {act['id']} — {act.get('name','?')}  [{act.get('faction_tilt','neutre')} / {act.get('emotion','?')} / {act.get('card_count',0)} cartes]")
            for bi, b in enumerate(act.get("beats", [])):
                vert = "   " if ai == len(acts) - 1 else "│  "
                c_idx = sum(a.get("card_count", 0) for a in acts[:ai]) + bi + 1
                chosen_for_card = next((r for r in chosen_route if r["card_idx"] == c_idx), None)
                arrow_choice = ""
                if chosen_for_card:
                    arrow_choice = f"  → option {chosen_for_card['option_idx']+1} : « {chosen_for_card['option_label']} »"
                ascii_lines.append(f"  {vert} ├ Carte #{c_idx} : {b.get('summary','?')[:55]}{arrow_choice}")
        parts.append(f'<pre class="routes-mermaid">{html_escape(chr(10).join(ascii_lines))}</pre>')
        # Mermaid flowchart for visual route
        m = ["```mermaid", "flowchart TD"]
        m.append(f'  T["📖 {trace.get("chosen_title","")}"]:::title')
        prev = "T"
        for act in acts:
            anode = f'A{act["id"]}'
            m.append(f'  {anode}["🎭 Acte {act["id"]} : {act.get("name","?")}<br/>{act.get("card_count",0)} cartes · {act.get("faction_tilt","neutre")}"]:::act')
            m.append(f'  {prev} --> {anode}')
            prev_card = anode
            for bi, b in enumerate(act.get("beats", [])):
                c_idx = sum(a.get("card_count", 0) for a in acts[:acts.index(act)]) + bi + 1
                cnode = f'C{c_idx}'
                m.append(f'  {cnode}["🃏 #{c_idx} {b.get("summary","?")[:30]}…"]:::card')
                m.append(f'  {prev_card} --> {cnode}')
                prev_card = cnode
            prev = prev_card
        m.append('  classDef title fill:#1a140d,stroke:#ffd76b,color:#ffd76b')
        m.append('  classDef act fill:#0d1418,stroke:#5a8aa8,color:#5a8aa8')
        m.append('  classDef card fill:#1a1612,stroke:#eba84d,color:#eba84d')
        m.append("```")
        parts.append('<details><summary style="color:var(--gold-bright);cursor:pointer;margin-top:14px">📊 Schéma Mermaid (déplier)</summary>')
        parts.append(f'<pre class="routes-mermaid">{html_escape(chr(10).join(m))}</pre>')
        parts.append('</details>')
        parts.append('<div class="routes-legend">Le druide a parcouru <strong>' + str(len(chosen_route)) + ' cartes</strong> à travers <strong>' + str(len(acts)) + ' actes</strong>. Chaque carte propose 3 options (3 routes possibles) ; le chemin parcouru est marqué par l\'option choisie en bas de chaque carte.</div>')
        parts.append('</div>')

        # v7.7.29 — Architecture async : recommandations pour rendre le LLM
        # transparent en jeu. Chiffres réels du run pour cadrer le budget.
        cards_count_actual = len(chosen_route)
        avg_card_s = (sum(float(s.get("duration_s", 0)) for s in trace.get("steps", []) if s.get("phase") == "card_gen") / max(cards_count_actual, 1)) if cards_count_actual else 0
        avg_res_s = (sum(float(s.get("duration_s", 0)) for s in trace.get("steps", []) if s.get("phase") == "card_resolution") / max(cards_count_actual, 1)) if cards_count_actual else 0
        parts.append('<div class="routes-panel" style="border-color:var(--green)">')
        parts.append('<h2 style="color:#7eb56b">⚙️  Architecture async — chargement transparent en jeu</h2>')
        parts.append(
            f'<div style="font-size:13px;color:var(--white);line-height:1.65">'
            f'Le run en mode "rapport" prend <strong>{trace.get("total_duration_s", 0):.0f}s</strong> '
            f'(dont <strong>{total_llm_load_s:.0f}s</strong> de LLM cumulé : '
            f'≈ {avg_card_s:.0f}s/carte gen + {avg_res_s:.0f}s/résolution). '
            f'En jeu, pour que ça reste invisible au joueur :'
            f'<ol style="margin:8px 0 0 24px;color:var(--gold-dim)">'
            f'<li><strong>Warmup au boot</strong> : 5-10s pendant le splash screen (modèles primés en RAM avant le menu).</li>'
            f'<li><strong>Pré-génération en cascade pendant l\'intro</strong> : pendant que le parchemin se déroule (~37s typewriter), '
            f'générer en background : titres déjà faits, intro affichée, skeleton + scenario_full + 2 premières cartes en parallèle.</li>'
            f'<li><strong>Lookahead N+2 sur les cartes</strong> : quand le joueur joue la carte N, le moteur génère N+1 et N+2 en background. '
            f'À ~30s/carte et un temps de lecture+choix joueur ~15-30s, le buffer reste plein.</li>'
            f'<li><strong>Résolution narrative inline</strong> : générée pendant l\'animation de transition entre la carte et la suivante (~3-5s visibles), '
            f'plus 25s en background masquées par le polish UI / changement de fond.</li>'
            f'<li><strong>Mécaniques de masquage</strong> : animations diégétiques (vent dans les feuilles, brume qui se forme), '
            f'voix off pré-enregistrée (Merlin commente en attendant), micro-interactions joueur (UI parle pendant le pré-chargement).</li>'
            f'<li><strong>Profil hardware fallback</strong> : sur poste lent, basculer sur le pool FastRoute (cartes pré-écrites) si le buffer s\'épuise, '
            f'avec un rattrapage LLM dès la prochaine pause.</li>'
            f'</ol>'
            f'<div style="margin-top:10px;padding:8px 12px;border:1px dashed var(--green);background:rgba(126,181,107,0.10);font-size:12px">'
            f'<strong>Budget runtime cible</strong> : 0s perçu par le joueur pour les LLM (sauf le warmup boot 5-10s). '
            f'Le rapport HTML montre <em>tous</em> les temps en série pour debug — en jeu, ils sont parallélisés derrière l\'animation.'
            f'</div>'
            f'</div>'
        )
        parts.append('</div>')

    for s in trace.get("steps", []):
        phase = s.get("phase", "")
        parts.append(f'<div class="step phase-{html_escape(phase)}">')
        parts.append('<div class="step-head">')
        parts.append(f'<div class="step-num">Étape {s.get("step","?")}</div>')
        parts.append(f'<div class="step-label">{html_escape(s.get("label",""))}</div>')
        # v7.7.28 — color-coded duration badge for LLM-heavy phases.
        dur = float(s.get("duration_s", 0))
        is_llm = phase in ("titles", "intro", "skeleton", "scenario_full", "card_gen", "card_resolution")
        badge = ""
        if is_llm and dur > 0:
            klass = "fast" if dur < 20 else ("medium" if dur < 60 else "slow")
            badge = f' <span class="load-badge {klass}">{dur:.1f}s LLM</span>'
        parts.append(f'<div class="step-time">t+{s.get("t_offset_s",0):.2f}s · durée {dur:.2f}s{badge}</div>')
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
            acts_local = out.get("acts", [])
            parts.append(f'<div style="margin-bottom:8px"><strong>{html_escape(out.get("title",""))}</strong> — {out.get("acts_count",0)} actes / {out.get("total_cards",0)} cartes</div>')
            parts.append('<table class="beats"><thead><tr><th>Acte</th><th>Nom</th><th>Emotion</th><th>Faction</th><th>Cartes</th><th>Thème</th></tr></thead><tbody>')
            for a in acts_local:
                tilt = a.get("faction_tilt", "neutre")
                parts.append(f'<tr><td><strong>{a.get("id","?")}</strong></td><td><strong>{html_escape(a.get("name","?"))}</strong></td><td>{html_escape(a.get("emotion",""))}</td><td class="faction-{html_escape(tilt)}">{html_escape(tilt)}</td><td>{a.get("card_count",0)}</td><td>{html_escape(a.get("theme",""))}</td></tr>')
            parts.append('</tbody></table>')
            parts.append(f'<div class="rag-refs">RAG few-shot : {html_escape(", ".join(s.get("rag_few_shot_used", [])))}</div>')

        elif phase == "scenario_full":
            out = s.get("output", {})
            # Render scenario with **act bold** markers converted to <strong>.
            txt = out.get("scenario_text", "")
            import re as _re
            html_scen = _re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>",
                                html_escape(txt)).replace("\n\n", "<br/><br/>")
            parts.append(f'<div class="scenario-block">{html_scen}</div>')
            parts.append(f'<div class="rag-refs">RAG few-shot : {html_escape(", ".join(s.get("rag_few_shot_used", [])))} · {out.get("paragraph_count",0)} paragraphes</div>')

        elif phase == "card_resolution":
            out = s.get("output", {})
            parts.append(f'<div class="resolution-block">Conséquence du choix « <strong>{html_escape(out.get("chosen_label","?"))}</strong> » : {html_escape(out.get("resolution_text",""))}</div>')

        elif phase == "act_intro":
            out = s.get("output", {})
            tilt = out.get("faction_tilt", "neutre")
            parts.append('<div class="act-header">')
            parts.append(f'<div class="act-id">{out.get("act_id","?")}</div>')
            parts.append(f'<div style="flex:1"><div style="color:var(--gold-bright);font-size:16px;font-weight:bold">« {html_escape(out.get("act_name","?"))} »</div>')
            parts.append(f'<div style="color:var(--white);font-size:13.5px;margin-top:2px">{html_escape(out.get("theme",""))}</div></div>')
            parts.append('</div>')
            parts.append('<div class="act-meta">')
            parts.append(f'<span>📍 {out.get("card_count",0)} cartes</span>')
            parts.append(f'<span class="faction-{html_escape(tilt)}">⚔️ {html_escape(tilt)}</span>')
            parts.append(f'<span>💭 {html_escape(out.get("emotion",""))}</span>')
            parts.append('</div>')

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
<footer>M.E.R.L.I.N. — simulate_human_run.py v7.7.29 (Gemma 4 · intro setup + scenario suite + cards route-aware + per-card resolution narrative) — généré le %s</footer>
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

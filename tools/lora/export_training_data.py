#!/usr/bin/env python3
"""
Export M.E.R.L.I.N. narrative data into ChatML training format for LoRA fine-tuning.

By default the training data is GAME-WIDE (scene-agnostic).
With --scene-aware, scene contracts are injected so Merlin learns strict
per-scene constraints in addition to global style.

Reads:
  - data/post_intro_dialogues.json (biome texts + Merlin reactions)
  - data/intro_dialogue.json (Merlin dialogue + player choices)
  - data/ai/examples/narrator_examples.json (card text + voice examples)
  - data/ai/training/tone_mapping.json (mood -> tone mapping)

Outputs:
  - data/ai/training/merlin_narrator_dataset.json (ChatML conversation pairs)

Usage:
  python tools/lora/export_training_data.py
  python tools/lora/export_training_data.py --scene-aware
"""

import json
import os
import random
import argparse

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Input paths
POST_INTRO = os.path.join(PROJECT_ROOT, "data", "post_intro_dialogues.json")
INTRO_DLG = os.path.join(PROJECT_ROOT, "data", "intro_dialogue.json")
NARRATOR_EX = os.path.join(PROJECT_ROOT, "data", "ai", "examples", "narrator_examples.json")
TONE_MAP = os.path.join(PROJECT_ROOT, "data", "ai", "training", "tone_mapping.json")
SCENE_PROFILES_PATH = os.path.join(PROJECT_ROOT, "data", "ai", "config", "scene_profiles.json")

# Output
OUTPUT = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_narrator_dataset.json")
OUTPUT_SCENE_AWARE = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_narrator_dataset_scene_aware.json")

SCENE_AWARE = False
SCENE_PROFILES = {}

# ═══════════════════════════════════════════════════════════════════════════════
# GAME-WIDE SYSTEM PROMPTS — No scene references
# ═══════════════════════════════════════════════════════════════════════════════

# Base identity prompt — used for all Merlin dialogue samples
MERLIN_IDENTITY = (
    "Tu es Merlin l'Enchanteur, druide ancestral des forets de Broceliande. "
    "Tu guides le Voyageur a travers un monde celtique ou 5 factions "
    "(Druides, Anciens, Korrigans, Niamh, Ankou) se disputent son allegiance. "
    "Le Voyageur a une barre de vie, collecte des Anam et tient des Promesses. "
    "Vocabulaire: nemeton, ogham, sidhe, dolmen, korrigans, brume, mousse, pierre dressee."
)

# Base identity for narration (environment descriptions, atmosphere)
NARRATOR_IDENTITY = (
    "Tu es le narrateur d'un jeu de cartes celtique. "
    "Tu decris des paysages, atmospheres et evenements dans un monde druidique. "
    "Style: poetique, immersif, 2-3 phrases. "
    "Tu integres les PNJ recurrents du biome et les arcs narratifs. "
    "Vocabulaire: nemeton, ogham, sidhe, dolmen, korrigans, brume, mousse, pierre dressee."
)

# Faction reputation states for game-wide context (replaces old Triade aspects)
FACTION_CONTEXTS = {
    "neutral": "Druides=50 Anciens=50 Korrigans=50 Niamh=50 Ankou=50",
    "druides_high": "Druides=80 Anciens=40 Korrigans=50 Niamh=50 Ankou=30",
    "korrigans_high": "Druides=40 Korrigans=80 Niamh=50 Anciens=50 Ankou=50",
    "ankou_high": "Ankou=80 Druides=30 Niamh=40 Anciens=50 Korrigans=30",
    "niamh_high": "Niamh=80 Druides=50 Anciens=50 Korrigans=40 Ankou=30",
    "anciens_high": "Anciens=80 Druides=60 Korrigans=40 Niamh=50 Ankou=40",
}

# Random game states for context variation (v2.2: factions, vie, tension)
GAME_STATE_TEMPLATES = [
    "Carte {card}. Vie: {vie}/100. {factions}.",
    "{factions}. Vie: {vie}. Carte {card}. Tension: {tension}.",
    "Carte {card}. {factions}. Promesses actives: {promesses}.",
]


def load_json(path: str):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def map_mood_to_tone(mood: str, mapping: dict) -> str:
    return mapping.get(mood, "neutral")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Export LoRA training dataset for Merlin.")
    parser.add_argument(
        "--scene-aware",
        action="store_true",
        help="Inject scene contracts from data/ai/config/scene_profiles.json into training prompts.",
    )
    return parser.parse_args()


def deep_merge_dict(base: dict, overlay: dict) -> dict:
    merged = dict(base)
    for key, value in overlay.items():
        if isinstance(merged.get(key), dict) and isinstance(value, dict):
            merged[key] = deep_merge_dict(merged[key], value)
        else:
            merged[key] = value
    return merged


def resolve_scene_contract(scene_id: str, channel: str = "narrative") -> dict:
    if not SCENE_AWARE or not SCENE_PROFILES or not scene_id:
        return {}
    merged = {}
    default_profile = SCENE_PROFILES.get("default", {})
    scene_profile = SCENE_PROFILES.get(scene_id, {})
    if isinstance(default_profile, dict):
        merged = deep_merge_dict(merged, default_profile)
    if isinstance(scene_profile, dict):
        merged = deep_merge_dict(merged, scene_profile)
        channel_profiles = scene_profile.get("channels", {})
        if isinstance(channel_profiles, dict):
            channel_profile = channel_profiles.get(channel, {})
            if isinstance(channel_profile, dict):
                merged = deep_merge_dict(merged, channel_profile)
    merged["scene_id"] = scene_id
    return merged


def append_scene_contract(system_prompt: str, scene_id: str, channel: str) -> str:
    contract = resolve_scene_contract(scene_id, channel)
    if not contract:
        return system_prompt
    lines = [f"Scene active: {contract.get('scene_id', scene_id)}"]
    if contract.get("phase"):
        lines.append(f"Phase: {contract['phase']}")
    if contract.get("intent"):
        lines.append(f"Intent: {contract['intent']}")
    if contract.get("tone_target"):
        lines.append(f"Tone target: {contract['tone_target']}")
    allowed = contract.get("allowed_topics", [])
    if isinstance(allowed, list) and allowed:
        lines.append("Allowed: " + ", ".join(str(x) for x in allowed[:6]))
    required = contract.get("must_reference", [])
    if isinstance(required, list) and required:
        lines.append("Must reference: " + ", ".join(str(x) for x in required[:6]))
    forbidden = contract.get("forbidden_topics", [])
    if isinstance(forbidden, list) and forbidden:
        lines.append("Forbidden: " + ", ".join(str(x) for x in forbidden[:6]))
    limits = contract.get("response_limits", {})
    if isinstance(limits, dict):
        max_sentences = int(limits.get("max_sentences", 0) or 0)
        if max_sentences > 0:
            lines.append(f"Limit: {max_sentences} sentences max.")
        max_words = int(limits.get("max_words", 0) or 0)
        if max_words > 0:
            lines.append(f"Limit: {max_words} words max.")
    contract_block = "\n".join(lines)
    return f"{system_prompt}\n\n[SCENE_CONTRACT]\n{contract_block}\nStay strictly in scene."


def make_conversation(system: str, user: str, assistant: str, scene_id: str = "", channel: str = "narrative") -> dict:
    final_system = append_scene_contract(system, scene_id, channel)
    sample = {
        "conversations": [
            {"role": "system", "content": final_system},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ]
    }
    if SCENE_AWARE and scene_id:
        sample["metadata"] = {"scene_id": scene_id, "channel": channel}
    return sample


def random_game_state(factions_desc: str = "") -> str:
    """Generate a random game state context string (v2.2: factions, vie, tension)."""
    if not factions_desc:
        factions_desc = random.choice(list(FACTION_CONTEXTS.values()))
    tmpl = random.choice(GAME_STATE_TEMPLATES)
    return tmpl.format(
        card=random.randint(1, 50),
        vie=random.randint(20, 100),
        factions=factions_desc,
        tension=random.choice(["basse", "moyenne", "haute"]),
        promesses=random.randint(0, 2),
    )


def merlin_system(tone: str) -> str:
    """Build a Merlin system prompt with tone, no scene reference."""
    if tone and tone != "neutral":
        return f"{MERLIN_IDENTITY} Ton: {tone}."
    return MERLIN_IDENTITY


def narrator_system(biome: str = "", atmosphere: str = "") -> str:
    """Build a narrator system prompt with optional biome, no scene reference."""
    base = NARRATOR_IDENTITY
    if biome:
        base += f" Environnement: {biome}."
    if atmosphere:
        base += f" Ambiance: {atmosphere}."
    return base


# ═══════════════════════════════════════════════════════════════════════════════
# EXTRACTORS — Game-wide, no scene dependencies
# ═══════════════════════════════════════════════════════════════════════════════

def extract_merlin_dialogues(post_intro: dict, intro: list, mood_map: dict) -> list:
    """Extract ALL Merlin dialogue as game-wide character voice samples."""
    samples = []

    # --- From post_intro: Merlin's lines (eveil, antre, biome reactions) ---
    # These are Merlin's character voice — extracted without scene context

    # Eveil lines: Merlin greeting the Voyageur (general dialogue)
    for line in post_intro.get("eveil", {}).get("lines", []):
        text = line.get("text", "")
        mood = line.get("mood", "neutral")
        tone = map_mood_to_tone(mood, mood_map)
        if text:
            samples.append(make_conversation(
                merlin_system(tone),
                f"{random_game_state()} Merlin parle au Voyageur.",
                text,
                scene_id="scene_rencontre_merlin_intro",
                channel="voice",
            ))

    # Antre: Merlin dialogue lines (general Merlin voice)
    for line in post_intro.get("antre", {}).get("bestiole_intro", []):
        text = line.get("text", "")
        mood = line.get("mood", "neutral")
        tone = map_mood_to_tone(mood, mood_map)
        if text and line.get("type", "merlin") == "merlin":
            samples.append(make_conversation(
                merlin_system(tone),
                f"{random_game_state()} Merlin commente un evenement.",
                text,
                scene_id="scene_rencontre_merlin_bestiole",
                channel="voice",
            ))

    # Mission briefing: Merlin explaining game mechanics (general voice)
    for line in post_intro.get("antre", {}).get("mission_briefing", []):
        text = line.get("text", "")
        mood = line.get("mood", "neutral")
        tone = map_mood_to_tone(mood, mood_map)
        if text:
            samples.append(make_conversation(
                merlin_system(tone),
                f"{random_game_state()} Merlin donne des conseils au Voyageur.",
                text,
                scene_id="scene_rencontre_merlin_mission",
                channel="voice",
            ))

    # Biome suggestions: Merlin advising (general advice voice)
    for archetype, info in post_intro.get("antre", {}).get("biome_suggestions", {}).items():
        text = info.get("text", "").replace("{name}", "Voyageur")
        mood = info.get("mood", "neutral")
        tone = map_mood_to_tone(mood, mood_map)
        if text:
            samples.append(make_conversation(
                merlin_system(tone),
                f"{random_game_state()} Merlin conseille le Voyageur sur son chemin.",
                text,
                scene_id="scene_rencontre_merlin_mission",
                channel="voice",
            ))

    # Biome reactions: short Merlin comments on game state
    reactions = post_intro.get("antre", {}).get("biome_reactions", {})
    for reaction_type, text in reactions.items():
        if text:
            tone = "playful" if reaction_type == "rejected" else "warm"
            samples.append(make_conversation(
                merlin_system(tone),
                f"{random_game_state()} Merlin reagit au choix du Voyageur.",
                text,
                scene_id="scene_rencontre_merlin_mission",
                channel="voice",
            ))

    # --- From intro: Merlin's personality voice ---
    for entry in intro:
        merlin_text = entry.get("merlin", "")
        if not merlin_text:
            continue
        # Classify tone from text content
        tone = "mysterious"
        if "?" in merlin_text:
            tone = "cryptic"
        elif "!" in merlin_text:
            tone = "playful"
        clean_text = merlin_text.replace("\\n", "\n")
        samples.append(make_conversation(
            merlin_system(tone),
            f"{random_game_state()} Merlin s'adresse au Voyageur.",
            clean_text,
            scene_id="scene_rencontre_merlin_intro",
            channel="voice",
        ))

    return samples


def extract_narration_samples(post_intro: dict, mood_map: dict) -> list:
    """Extract environment/atmosphere descriptions as game-wide narration samples."""
    samples = []

    # Narration lines (bestiole intro narration = general atmosphere)
    for line in post_intro.get("antre", {}).get("bestiole_intro", []):
        text = line.get("text", "")
        mood = line.get("mood", "neutral")
        if text and line.get("type", "") == "narration":
            tone = map_mood_to_tone(mood, mood_map)
            samples.append(make_conversation(
                narrator_system(),
                f"{random_game_state()} Decris l'atmosphere.",
                text,
                scene_id="scene_rencontre_merlin_bestiole",
                channel="narrative",
            ))

    # Biome arrival texts: learn to describe environments for any game state
    for biome_key, biome_data in post_intro.get("biomes", {}).items():
        biome_name = biome_data.get("name", biome_key)
        atmosphere = biome_data.get("atmosphere", {})
        atmo_desc = atmosphere.get("mood", "")
        atmo_sounds = atmosphere.get("sounds", "")
        atmo_smell = atmosphere.get("smell", "")
        atmo_str = ", ".join(filter(None, [atmo_desc, atmo_sounds, atmo_smell]))

        # Main arrival text
        arrival = biome_data.get("arrival_text", "")
        if arrival:
            samples.append(make_conversation(
                narrator_system(biome_name, atmo_str),
                f"{random_game_state(FACTION_CONTEXTS['neutral'])} Decris le paysage.",
                arrival,
                scene_id="transition_biome_arrival",
                channel="narrative",
            ))

        # Merlin comment on environment
        merlin_comment = biome_data.get("merlin_comment", "")
        if merlin_comment:
            samples.append(make_conversation(
                merlin_system("playful"),
                f"{random_game_state(FACTION_CONTEXTS['neutral'])} Commente l'environnement.",
                merlin_comment,
                scene_id="transition_biome_merlin",
                channel="voice",
            ))

        # Variants by faction state — the core of game-state-aware narration
        for state_key, variants in biome_data.get("variants", {}).items():
            factions_desc = FACTION_CONTEXTS.get(state_key, state_key)

            # Determine tone from game state (not scene)
            tone_for_state = {
                "neutral": "neutral",
                "druides_high": "mysterious",
                "korrigans_high": "playful",
                "ankou_high": "warning",
                "niamh_high": "ethereal",
                "anciens_high": "solemn",
            }.get(state_key, "neutral")

            for variant in variants:
                v_arrival = variant.get("arrival", "")
                v_merlin = variant.get("merlin", "")

                if v_arrival:
                    samples.append(make_conversation(
                        narrator_system(biome_name, atmo_str),
                        f"{random_game_state(factions_desc)} Decris le paysage.",
                        v_arrival,
                        scene_id="transition_biome_arrival",
                        channel="narrative",
                    ))
                if v_merlin:
                    samples.append(make_conversation(
                        merlin_system(tone_for_state),
                        f"{random_game_state(factions_desc)} Commente la situation.",
                        v_merlin,
                        scene_id="transition_biome_merlin",
                        channel="voice",
                    ))

    return samples


def extract_card_generation_samples(narrator_data: dict) -> list:
    """Extract card text examples — the primary gameplay generation task."""
    samples = []

    # Card scenarios (game loop: generate narrative for card)
    for ex in narrator_data.get("card_text_examples", []):
        context = ex.get("context", "")
        output = ex.get("output", "")
        if output:
            samples.append(make_conversation(
                f"{MERLIN_IDENTITY} Ecris un scenario immersif pour une carte. 2-3 phrases poetiques.",
                f"{context}. Genere le scenario de la carte.",
                output
            ))

    # Choice labels (game loop: propose 3 choices per card)
    for ex in narrator_data.get("choice_label_examples", []):
        scenario = ex.get("scenario", "")
        choices = ex.get("choices", [])
        if scenario and choices:
            choices_text = "\n".join(f"{chr(65+i)}) {c}" for i, c in enumerate(choices))
            samples.append(make_conversation(
                f"{MERLIN_IDENTITY} Propose exactement 3 choix courts (max 8 mots). A) prudent B) mystique C) audacieux.",
                f"Scenario: {scenario}\n{random_game_state()} Propose 3 choix.",
                choices_text
            ))

    # Merlin voice per tone (game-wide: commentary during gameplay)
    for ex in narrator_data.get("merlin_voice_examples", []):
        tone = ex.get("tone", "neutral")
        output = ex.get("output", "")
        if output:
            samples.append(make_conversation(
                merlin_system(tone),
                f"{random_game_state()} Commente le choix du Voyageur. 1-2 phrases.",
                output
            ))

    return samples


def extract_player_choice_samples(intro: list) -> list:
    """Extract player choice labels as concise gameplay options."""
    samples = []
    for entry in intro:
        choices = entry.get("choices", {})
        for category, options in choices.items():
            for opt in options:
                choice_text = opt.get("text", "")
                if choice_text:
                    samples.append(make_conversation(
                        f"{MERLIN_IDENTITY} Propose un choix concis et actionnable pour le Voyageur.",
                        f"{random_game_state()} Categorie: {category.lower()}. Propose un choix.",
                        choice_text
                    ))
    return samples


def extract_fallback_comments() -> list:
    """Merlin's tone-specific comments (game-wide short reactions)."""
    fallbacks = {
        "playful": [
            "Interessant choix...",
            "Tu me surprends, voyageur.",
            "Ah, je n'aurais pas fait ca. Mais bon.",
        ],
        "mysterious": [
            "Le chemin se revele...",
            "Les fils du destin s'entrelacent.",
            "Certaines portes ne s'ouvrent qu'une fois.",
        ],
        "warning": [
            "Attention au chemin que tu prends.",
            "Reflechis bien avant d'agir.",
            "Les consequences arrivent toujours.",
        ],
        "melancholy": [
            "...parfois, je me demande...",
            "Le temps passe si vite.",
            "Certaines choses ne reviennent jamais.",
        ],
        "warm": [
            "Tu avances bien, Voyageur.",
            "L'equilibre revient. Continue.",
            "Je suis la, ne l'oublie pas.",
        ],
        "cryptic": [
            "Le vent murmure ce que les pierres taisent.",
            "Trois chemins, une seule verite.",
            "Ce que tu cherches te cherche aussi.",
        ],
    }

    samples = []
    for tone, comments in fallbacks.items():
        for comment in comments:
            samples.append(make_conversation(
                merlin_system(tone),
                f"{random_game_state()} Commente brievement. 1-2 phrases.",
                comment
            ))
    return samples


def main():
    global SCENE_AWARE, SCENE_PROFILES
    args = parse_args()
    SCENE_AWARE = bool(args.scene_aware)
    print("[export] Loading source files...")
    if SCENE_AWARE:
        if os.path.exists(SCENE_PROFILES_PATH):
            SCENE_PROFILES = load_json(SCENE_PROFILES_PATH)
            print(f"  Scene-aware mode: ON ({len(SCENE_PROFILES)} profiles)")
        else:
            print("  Scene-aware mode requested but scene_profiles.json not found. Continuing without contracts.")
            SCENE_AWARE = False
            SCENE_PROFILES = {}

    tone_data = load_json(TONE_MAP)
    mood_map = tone_data.get("mood_to_tone", {})

    post_intro = load_json(POST_INTRO)
    intro = load_json(INTRO_DLG)
    narrator = load_json(NARRATOR_EX)

    all_samples = []

    # 1. Merlin dialogue voice (game-wide character)
    merlin_samples = extract_merlin_dialogues(post_intro, intro, mood_map)
    print(f"  Merlin dialogue (game-wide): {len(merlin_samples)} samples")
    all_samples.extend(merlin_samples)

    # 2. Narration / environment descriptions (game-wide atmosphere)
    narration_samples = extract_narration_samples(post_intro, mood_map)
    print(f"  Narration / atmosphere:      {len(narration_samples)} samples")
    all_samples.extend(narration_samples)

    # 3. Card generation (core gameplay loop)
    card_samples = extract_card_generation_samples(narrator)
    print(f"  Card generation (gameplay):  {len(card_samples)} samples")
    all_samples.extend(card_samples)

    # 4. Player choice labels
    choice_samples = extract_player_choice_samples(intro)
    print(f"  Player choice labels:        {len(choice_samples)} samples")
    all_samples.extend(choice_samples)

    # 5. Tone-specific short reactions
    fallback_samples = extract_fallback_comments()
    print(f"  Tone reactions (gameplay):   {len(fallback_samples)} samples")
    all_samples.extend(fallback_samples)
    output_path = OUTPUT_SCENE_AWARE if SCENE_AWARE else OUTPUT

    # Write output
    output_data = {
        "_meta": {
            "version": "2.1.0",
            "description": "M.E.R.L.I.N. narrator dataset for LoRA fine-tuning (optionally scene-aware).",
            "format": "ChatML conversations (system/user/assistant)",
            "base_model": "Qwen/Qwen3.5-4B",
            "total_samples": len(all_samples),
            "scene_aware_mode": SCENE_AWARE,
            "design_principle": (
                "Scene-aware contracts + game-wide voice/style transfer."
                if SCENE_AWARE
                else "Game-wide, not scene-specific. Model learns character voice + narrative style + tone registers across the gameplay loop."
            ),
            "sources": [
                "data/post_intro_dialogues.json",
                "data/intro_dialogue.json",
                "data/ai/examples/narrator_examples.json",
                "merlin_omniscient.gd fallback comments",
            ],
        },
        "samples": all_samples,
    }

    if SCENE_AWARE:
        output_data["_meta"]["sources"].append("data/ai/config/scene_profiles.json")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"\n[export] Done! {len(all_samples)} samples written to:")
    print(f"  {output_path}")

    # Stats
    tones = {}
    categories = {"merlin_voice": 0, "narration": 0, "card_gen": 0, "choices": 0, "reactions": 0}
    for s in all_samples:
        sys_msg = s["conversations"][0]["content"]
        # Tone stats
        for tone in ["playful", "mysterious", "warning", "melancholy", "warm", "cryptic", "neutral"]:
            if f"Ton: {tone}" in sys_msg:
                tones[tone] = tones.get(tone, 0) + 1
                break
        else:
            tones["implicit"] = tones.get("implicit", 0) + 1
        # Category stats
        if "narrateur" in sys_msg:
            categories["narration"] += 1
        elif "scenario" in sys_msg.lower() or "carte" in sys_msg.lower():
            categories["card_gen"] += 1
        elif "choix" in sys_msg.lower():
            categories["choices"] += 1
        else:
            categories["merlin_voice"] += 1

    print("\n  Tone distribution:")
    for tone, count in sorted(tones.items(), key=lambda x: -x[1]):
        print(f"    {tone}: {count}")

    print("\n  Category distribution:")
    for cat, count in sorted(categories.items(), key=lambda x: -x[1]):
        print(f"    {cat}: {count}")


if __name__ == "__main__":
    main()

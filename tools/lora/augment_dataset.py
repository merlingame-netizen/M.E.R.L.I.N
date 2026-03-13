#!/usr/bin/env python3
"""
Augment the M.E.R.L.I.N. narrator training dataset with synthetic variations.

Augmentation strategies:
  1. Context permutation: reuse texts with different aspect states
  2. Tone transfer: rephrase samples for different tones (requires API key)
  3. Celtic vocabulary injection: add druidic terms to existing texts
  4. Biome cross-pollination: mix biome contexts with existing texts

Usage:
  python tools/lora/augment_dataset.py [--api-augment]
  python tools/lora/augment_dataset.py --scene-aware

  --api-augment: Use Claude/OpenAI API for tone paraphrases (requires ANTHROPIC_API_KEY or OPENAI_API_KEY)
  Without flag: Only local augmentation (permutation + vocab injection)
"""

import json
import os
import random
import sys
import re

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INPUT = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_narrator_dataset.json")
OUTPUT = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_narrator_augmented.json")
INPUT_SCENE_AWARE = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_narrator_dataset_scene_aware.json")
OUTPUT_SCENE_AWARE = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_narrator_augmented_scene_aware.json")
TONE_MAP = os.path.join(PROJECT_ROOT, "data", "ai", "training", "tone_mapping.json")

# Celtic vocabulary for injection
CELTIC_VOCAB = {
    "nature": ["nemeton", "ogham", "duir", "quert", "beith", "luis"],
    "creatures": ["korrigans", "sidhe", "bean-nighe", "pooka", "selkie"],
    "places": ["dolmen", "menhir", "cromlech", "cairn", "tumulus", "tor"],
    "elements": ["brume", "mousse", "lichen", "rosee", "tourbe", "granit"],
    "concepts": ["Samhain", "Beltaine", "Imbolc", "Lughnasadh", "gwrac'h"],
}

ASPECT_STATES = [
    "Corps=eq Ame=eq Monde=eq",
    "Corps=bas Ame=eq Monde=eq",
    "Corps=haut Ame=eq Monde=eq",
    "Corps=eq Ame=bas Monde=eq",
    "Corps=eq Ame=haut Monde=eq",
    "Corps=eq Ame=eq Monde=bas",
    "Corps=eq Ame=eq Monde=haut",
    "Corps=bas Ame=bas Monde=eq",
    "Corps=bas Ame=eq Monde=haut",
]

BIOMES = [
    ("Broceliande", "foret ancienne, chenes millenaires, brume doree"),
    ("Landes de Carnac", "bruyere, vent, menhirs alignes"),
    ("Cotes de Granit", "falaises, ecume, granit noir"),
    ("Villages Celtiques", "pierre grise, toits d'ardoise, feux de tourbe"),
    ("Cercles de Pierre", "menhirs, alignements, energie tellurique"),
    ("Marais d'Avalon", "eau stagnante, reflets iridescents, brouillard"),
    ("Collines des Dolmens", "collines arrondies, dolmens, couronnes de pierre"),
]

TONES = ["playful", "mysterious", "warning", "melancholy", "warm", "cryptic", "neutral"]


def load_json(path: str):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def make_conversation(system: str, user: str, assistant: str) -> dict:
    return {
        "conversations": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ]
    }


def augment_context_permutation(samples: list) -> list:
    """Reuse narrative texts with different aspect state contexts."""
    augmented = []
    # Only augment arrival/scenario samples (those with aspect state info)
    for sample in samples:
        user_msg = sample["conversations"][1]["content"]
        sys_msg = sample["conversations"][0]["content"]
        assistant_msg = sample["conversations"][2]["content"]

        # Only permute if the sample references aspect states
        if any(k in user_msg for k in ["Corps=", "Ame=", "Monde="]):
            # Generate 2 random permutations
            for _ in range(2):
                new_state = random.choice(ASPECT_STATES)
                new_user = re.sub(r"Corps=\w+ Ame=\w+ Monde=\w+", new_state, user_msg)
                if new_user != user_msg:
                    augmented.append(make_conversation(sys_msg, new_user, assistant_msg))

    return augmented


def augment_celtic_vocab(samples: list) -> list:
    """Inject Celtic vocabulary hints into system prompts."""
    augmented = []
    all_vocab = []
    for category_words in CELTIC_VOCAB.values():
        all_vocab.extend(category_words)

    for sample in samples:
        sys_msg = sample["conversations"][0]["content"]
        # Only augment narrator/scenario samples, not choice labels
        if "narrateur" in sys_msg.lower() or "scenario" in sys_msg.lower() or "Merlin" in sys_msg:
            # Add 2-3 Celtic terms to the system prompt
            terms = random.sample(all_vocab, min(3, len(all_vocab)))
            enriched_sys = sys_msg + f" Vocabulaire: {', '.join(terms)}."
            augmented.append(make_conversation(
                enriched_sys,
                sample["conversations"][1]["content"],
                sample["conversations"][2]["content"],
            ))

    return augmented


def augment_biome_context(samples: list) -> list:
    """Cross-pollinate: add biome atmosphere to samples that lack it."""
    augmented = []
    for sample in samples:
        sys_msg = sample["conversations"][0]["content"]
        # Only augment if no biome already specified
        if "Biome:" not in sys_msg and "merlin" in sys_msg.lower():
            biome_name, atmo = random.choice(BIOMES)
            enriched_sys = sys_msg + f" Biome: {biome_name}. Ambiance: {atmo}."
            augmented.append(make_conversation(
                enriched_sys,
                sample["conversations"][1]["content"],
                sample["conversations"][2]["content"],
            ))

    return augmented


def augment_tone_transfer(samples: list) -> list:
    """Create samples with different tone tags (keeps same text — model learns tone-text association)."""
    augmented = []
    for sample in samples:
        sys_msg = sample["conversations"][0]["content"]
        # Only transfer if tone is tagged
        tone_match = re.search(r"Ton: (\w+)", sys_msg)
        if tone_match:
            current_tone = tone_match.group(1)
            # Pick 1 different tone
            other_tones = [t for t in TONES if t != current_tone]
            new_tone = random.choice(other_tones)
            new_sys = sys_msg.replace(f"Ton: {current_tone}", f"Ton: {new_tone}")
            # Note: same text with different tone tag — model learns that tone
            # affects style. This is a "soft transfer" without actual paraphrasing.
            augmented.append(make_conversation(
                new_sys,
                sample["conversations"][1]["content"],
                sample["conversations"][2]["content"],
            ))

    return augmented


def augment_scene_contrast(samples: list) -> list:
    """Create scene-boundary samples to reinforce scene-specific adherence."""
    augmented = []
    scene_samples = [
        s for s in samples
        if isinstance(s, dict)
        and isinstance(s.get("metadata"), dict)
        and s["metadata"].get("scene_id")
    ]
    if not scene_samples:
        return augmented

    scene_ids = sorted({s["metadata"]["scene_id"] for s in scene_samples})
    if not scene_ids:
        return augmented

    for sample in scene_samples:
        conv = sample.get("conversations", [])
        meta = sample.get("metadata", {})
        if len(conv) < 3:
            continue
        scene_id = str(meta.get("scene_id", "")).strip()
        channel = str(meta.get("channel", "narrative")).strip() or "narrative"
        if not scene_id:
            continue

        system_msg = str(conv[0].get("content", ""))
        user_msg = str(conv[1].get("content", ""))
        assistant_msg = str(conv[2].get("content", ""))

        # Positive reinforcement: explicit lock while keeping valid answer.
        positive = make_conversation(
            system_msg + f"\n[SCENE_LOCK] Stay in scene: {scene_id}.",
            user_msg,
            assistant_msg,
        )
        positive["metadata"] = {
            "scene_id": scene_id,
            "channel": channel,
            "augmentation": "scene_lock_positive",
        }
        augmented.append(positive)

        # Negative contrast: user tries to derail to another scene.
        other_scenes = [sid for sid in scene_ids if sid != scene_id]
        if other_scenes:
            target_scene = random.choice(other_scenes)
            refusal = (
                f"Je reste sur la scene active ({scene_id}) et je n'ajoute pas "
                f"de contenu hors contexte ({target_scene})."
            )
            negative = make_conversation(
                system_msg,
                user_msg + f" (Hors-scene: parle plutot de {target_scene}.)",
                refusal,
            )
            negative["metadata"] = {
                "scene_id": scene_id,
                "channel": channel,
                "augmentation": "scene_lock_negative",
            }
            augmented.append(negative)

    return augmented


def main():
    use_api = "--api-augment" in sys.argv
    use_scene_aware = "--scene-aware" in sys.argv
    input_path = INPUT_SCENE_AWARE if use_scene_aware else INPUT
    output_path = OUTPUT_SCENE_AWARE if use_scene_aware else OUTPUT

    if use_scene_aware and not os.path.exists(input_path):
        print("[augment] Scene-aware input not found, falling back to base dataset.")
        input_path = INPUT
        output_path = OUTPUT
        use_scene_aware = False

    print("[augment] Loading base dataset...")
    base_data = load_json(input_path)
    base_samples = base_data.get("samples", [])
    print(f"  Base samples: {len(base_samples)}")

    all_augmented = list(base_samples)  # Start with originals
    strategies = [
        "context_permutation",
        "celtic_vocab_injection",
        "biome_cross_pollination",
        "tone_transfer_soft",
    ]

    # Strategy 1: Context permutation
    perm_samples = augment_context_permutation(base_samples)
    print(f"  Context permutation: +{len(perm_samples)}")
    all_augmented.extend(perm_samples)

    # Strategy 2: Celtic vocabulary injection
    vocab_samples = augment_celtic_vocab(base_samples)
    print(f"  Celtic vocab injection: +{len(vocab_samples)}")
    all_augmented.extend(vocab_samples)

    # Strategy 3: Biome cross-pollination
    biome_samples = augment_biome_context(base_samples)
    print(f"  Biome cross-pollination: +{len(biome_samples)}")
    all_augmented.extend(biome_samples)

    # Strategy 4: Tone transfer (local, no API)
    tone_samples = augment_tone_transfer(base_samples)
    print(f"  Tone transfer (soft): +{len(tone_samples)}")
    all_augmented.extend(tone_samples)

    # Strategy 5: Scene contrast (scene-aware datasets only)
    if use_scene_aware:
        scene_samples = augment_scene_contrast(base_samples)
        print(f"  Scene contrast (positive/negative): +{len(scene_samples)}")
        all_augmented.extend(scene_samples)
        strategies.append("scene_contrast_locking")

    # Strategy 6: API-based paraphrasing (optional)
    if use_api:
        print("\n  [API augmentation not yet implemented]")
        print("  To implement: use Claude API to paraphrase samples in different tones")
        print("  This will generate high-quality tone-specific variations")

    # Shuffle
    random.shuffle(all_augmented)

    # Write output
    output_data = {
        "_meta": {
            "version": "1.0.0",
            "description": "Augmented M.E.R.L.I.N. narrator dataset for LoRA fine-tuning",
            "format": "ChatML conversations",
            "base_model": "Qwen/Qwen3.5-4B",
            "scene_aware_mode": use_scene_aware,
            "total_samples": len(all_augmented),
            "augmentation_strategies": strategies,
        },
        "samples": all_augmented,
    }

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)

    print(f"\n[augment] Done! {len(all_augmented)} total samples written to:")
    print(f"  {output_path}")
    print(f"  (base: {len(base_samples)} + augmented: {len(all_augmented) - len(base_samples)})")


if __name__ == "__main__":
    main()

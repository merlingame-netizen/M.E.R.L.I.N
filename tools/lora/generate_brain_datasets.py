#!/usr/bin/env python3
"""
Generate per-brain LoRA training datasets for Qwen 3.5 multi-brain architecture.

Splits existing merlin_full_v*.jsonl into role-specific datasets and generates
synthetic examples for under-represented brains (Game Master, Worker/Judge).

Usage:
    python generate_brain_datasets.py --workspace C:/Users/PGNK2128/Godot-MCP
    python generate_brain_datasets.py --workspace . --version 1
"""

from __future__ import annotations

import argparse
import json
import random
import re
import sys
from pathlib import Path
from typing import Optional


def log(msg: str) -> None:
    print(f"[BRAIN-DATASET] {msg}")


def fail(msg: str) -> None:
    print(f"[BRAIN-DATASET][ERROR] {msg}", file=sys.stderr)
    raise SystemExit(1)


# ── Classification ────────────────────────────────────────────────────────────

NARRATOR_MARKERS = [
    "Merlin", "narrateur", "druide", "poetique", "scenario",
    "Voyageur", "Broceliande", "celtique", "ogham", "nemeton",
]

GM_MARKERS = [
    "Maitre du Jeu", "effets mecaniques", "JSON", "SHIFT_ASPECT",
    "equilibrage", "mini-jeu", "ajustement", "regle",
]

JUDGE_MARKERS = [
    "score", "qualite", "note sur", "evalue", "GO/NO-GO",
]


def classify_example(system_content: str) -> str:
    """Classify a training example by brain role based on system prompt."""
    lower = system_content.lower()
    if "maitre du jeu" in lower:
        return "gamemaster"
    if "json" in lower and ("effet" in lower or "equilibr" in lower):
        return "gamemaster"
    for marker in JUDGE_MARKERS:
        if marker.lower() in lower:
            return "worker"
    for marker in NARRATOR_MARKERS:
        if marker.lower() in lower:
            return "narrator"
    return "other"


# ── Synthetic Example Generators ──────────────────────────────────────────────

def load_prompt_templates(workspace: Path) -> dict:
    """Load prompt_templates.json for synthetic generation."""
    path = workspace / "data" / "ai" / "config" / "prompt_templates.json"
    if not path.exists():
        log(f"Warning: prompt_templates.json not found at {path}")
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


# ── Game Master Synthetic Examples ────────────────────────────────────────────

BIOMES = ["foret_broceliande", "marais_avalon", "landes_carmac", "cercles_pierres", "cotes_sauvages"]
SEASONS = ["printemps", "ete", "automne", "hiver"]
STATES = ["bas", "equilibre", "haut"]
ASPECTS = ["Corps", "Ame", "Monde"]

EFFECT_TYPES = [
    {"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"},
    {"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "down"},
    {"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"},
    {"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "down"},
    {"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "up"},
    {"type": "SHIFT_ASPECT", "aspect": "Monde", "direction": "down"},
    {"type": "DAMAGE_LIFE", "amount": 5},
    {"type": "DAMAGE_LIFE", "amount": 10},
    {"type": "HEAL_LIFE", "amount": 5},
    {"type": "ADD_KARMA", "amount": 1},
    {"type": "ADD_KARMA", "amount": -1},
    {"type": "ADD_SOUFFLE", "amount": 1},
    {"type": "USE_SOUFFLE", "amount": 1},
]

SCENARIO_THEMES = [
    ("Un cercle de menhirs vibre sous la lune.", "MEDITER", "TOUCHER", "CONTOURNER"),
    ("La riviere charrie des runes d'ogham luminescentes.", "PECHER", "LIRE", "TRAVERSER"),
    ("Un korrigan propose un marche etrange.", "ACCEPTER", "REFUSER", "NEGOCIER"),
    ("La brume se leve, revelant un dolmen inconnu.", "EXPLORER", "OBSERVER", "FUIR"),
    ("Bestiole grogne face a une source d'eau noire.", "GOUTER", "PURIFIER", "EVITER"),
    ("Un cerf blanc apparait entre les arbres.", "SUIVRE", "SALUER", "IGNORER"),
    ("Les korrigans dansent autour d'un feu de sidhe.", "DANSER", "REGARDER", "DISPERSER"),
    ("Une voix murmure depuis le nemeton sacre.", "ECOUTER", "REPONDRE", "BLOQUER"),
    ("Le sol tremble, les pierres dressees s'inclinent.", "STABILISER", "CREUSER", "PROTEGER"),
    ("Un loup solitaire s'approche, blessé.", "SOIGNER", "APPRIVOISER", "REPOUSSER"),
    ("Les ronces enchantees bloquent le sentier.", "COUPER", "BRULER", "CONTOURNER"),
    ("Un esprit des eaux emerge du lac.", "PARLER", "OFFRIR", "PLONGER"),
    ("La pierre d'ogham revele une prophetie.", "DECHIFFRER", "COPIER", "BRISER"),
    ("Un orage magique frappe la foret.", "ABRITER", "CANALISER", "TRAVERSER"),
    ("Les racines de l'arbre-monde bougent.", "TOUCHER", "CREUSER", "RECULER"),
]


def generate_gm_effects_example() -> dict:
    """Generate a synthetic GM effects example (JSON output)."""
    theme = random.choice(SCENARIO_THEMES)
    scenario, label_a, label_b, label_c = theme

    corps = random.choice(STATES)
    ame = random.choice(STATES)
    monde = random.choice(STATES)
    souffle = random.randint(1, 7)
    vie = random.randint(20, 100)
    danger = random.randint(0, 3)

    # Generate balanced effects: A=prudent, B=balanced, C=audacious
    def pick_effects(archetype: str) -> list:
        if archetype == "prudent":
            pool = [e for e in EFFECT_TYPES if e["type"] in ("HEAL_LIFE", "ADD_SOUFFLE") or
                    (e["type"] == "SHIFT_ASPECT" and e["direction"] == "up")]
            return random.sample(pool, min(2, len(pool)))
        elif archetype == "audacious":
            pool = [e for e in EFFECT_TYPES if e["type"] in ("DAMAGE_LIFE", "USE_SOUFFLE", "ADD_KARMA") or
                    (e["type"] == "SHIFT_ASPECT")]
            effects = random.sample(pool, min(3, len(pool)))
            return effects
        else:  # balanced
            return random.sample(EFFECT_TYPES, min(2, len(EFFECT_TYPES)))

    effects_a = pick_effects("prudent")
    effects_b = pick_effects("balanced")
    effects_c = pick_effects("audacious")

    system = (
        "Tu es le Maitre du Jeu. Pour le scenario ci-dessous, genere les effets mecaniques "
        "des 3 options. Option A: prudente. Option B: equilibree. Option C: audacieuse. "
        "Reponds UNIQUEMENT en JSON: [[effets_A], [effets_B], [effets_C]]. "
        "Effets autorises: SHIFT_ASPECT (aspect=Corps/Ame/Monde, direction=up/down), "
        "DAMAGE_LIFE (amount 1-10), HEAL_LIFE (amount 1-10), ADD_KARMA (amount), "
        "ADD_SOUFFLE (amount 1), USE_SOUFFLE (amount 1)."
    )

    user = (
        f"Scenario: {scenario}\n"
        f"Choix: A) {label_a} B) {label_b} C) {label_c}\n"
        f"Etat: Corps={corps} Ame={ame} Monde={monde}. Souffle={souffle}. "
        f"Vie={vie}. Danger={danger}.\n"
        f"Genere les effets JSON."
    )

    assistant = json.dumps([effects_a, effects_b, effects_c], ensure_ascii=False)

    return {
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ]
    }


def generate_gm_balance_example() -> dict:
    """Generate a synthetic GM balance evaluation example."""
    corps = random.choice(STATES)
    ame = random.choice(STATES)
    monde = random.choice(STATES)
    souffle = random.randint(0, 7)
    day = random.randint(1, 30)
    karma = random.randint(-5, 10)
    tension = random.randint(0, 100)
    cards = random.randint(1, 20)

    extremes = sum(1 for s in [corps, ame, monde] if s != "equilibre")
    balance_score = max(0, 100 - extremes * 25 - max(0, tension - 50))
    risk = random.choice(ASPECTS) if extremes > 0 else "aucun"

    suggestions = [
        "Proposer une carte de recuperation",
        "Reduire la tension narrative",
        "Offrir un choix de repos",
        "Augmenter les recompenses",
        "Introduire un allie temporaire",
    ]

    system = (
        'Tu es le Maitre du Jeu. Evalue l\'equilibre du jeu. Reponds en JSON: '
        '{"balance_score": 0-100, "risk_aspect": "...", "suggestion": "..."}'
    )

    user = (
        f"Corps={corps} Ame={ame} Monde={monde}. Souffle: {souffle}/7. "
        f"Jour: {day}. Cartes jouees: {cards}. Karma: {karma}. Tension: {tension}."
    )

    result = {
        "balance_score": balance_score,
        "risk_aspect": risk,
        "suggestion": random.choice(suggestions),
    }

    return {
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
            {"role": "assistant", "content": json.dumps(result, ensure_ascii=False)},
        ]
    }


def generate_gm_choices_example() -> dict:
    """Generate a synthetic GM choices example (labels + minigame + effects)."""
    theme = random.choice(SCENARIO_THEMES)
    scenario, label_a, label_b, label_c = theme

    corps = random.choice(STATES)
    ame = random.choice(STATES)
    monde = random.choice(STATES)
    souffle = random.randint(1, 7)

    minigame_types = ["timing", "memory", "reflex", "none"]

    system = (
        "Tu es le Maitre du Jeu. Genere 3 choix contextuels adaptes au scenario "
        "(prudent, equilibre, audacieux). Chaque label: 2-6 mots, action concrete "
        "liee au texte. Choisis un type de mini-jeu adapte au contexte. "
        "Reponds UNIQUEMENT en JSON valide."
    )

    user = (
        f"Scenario: {scenario}\n"
        f"Etat: Corps={corps} Ame={ame} Monde={monde} Souffle={souffle}\n"
        f"Genere 3 choix + effets + type mini-jeu."
    )

    result = {
        "choices": [
            {"label": label_a, "archetype": "prudent"},
            {"label": label_b, "archetype": "equilibre"},
            {"label": label_c, "archetype": "audacieux"},
        ],
        "minigame": random.choice(minigame_types),
    }

    return {
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
            {"role": "assistant", "content": json.dumps(result, ensure_ascii=False)},
        ]
    }


# ── Worker/Judge Synthetic Examples ───────────────────────────────────────────

SAMPLE_TEXTS = [
    "Les pierres se dressent en silence. Les korrigans murmurent dans la brume.",
    "La brume enveloppe le nemeton sacre. Tu sens le souffle des anciens.",
    "Un cerf blanc traverse la clairiere. Ses bois portent des runes oghams.",
    "L'eau du ruisseau chante. Les pierres dressees vibrent au clair de lune.",
    "Le dolmen tremble. Une fissure s'ouvre, revelant un passage secret.",
    "Les korrigans dansent en cercle. Leur rire resonne dans la nuit.",
    "La mousse recouvre les menhirs. Le temps semble s'etre arrete ici.",
    "Un feu de sidhe brule sans chaleur. Les ombres racontent des histoires.",
    "Le vent porte l'odeur de la terre humide et des fougeres anciennes.",
    "Les racines de l'arbre-monde plongent dans les profondeurs du nemeton.",
]


def generate_worker_quality_example() -> dict:
    """Generate a quality scoring example for the worker/judge brain."""
    text = random.choice(SAMPLE_TEXTS)

    # Count celtic vocabulary
    celtic_words = ["ogham", "nemeton", "sidhe", "dolmen", "korrigan", "brume",
                    "pierre", "rune", "souffle", "menhir", "druide", "mousse",
                    "cerf", "sanglier", "corbeau"]
    text_lower = text.lower()
    celtic_count = sum(1 for w in celtic_words if w in text_lower)
    word_count = len(text.split())
    celtic_density = round(celtic_count / max(word_count, 1), 2)

    is_french = 1 if not any(w in text_lower for w in ["the", "and", "this", "that"]) else 0
    has_format = 1 if any(p in text for p in ["A)", "B)", "C)"]) else 0
    coherence = random.uniform(0.6, 1.0)

    score = round(min(10, celtic_density * 20 + is_french * 3 + coherence * 4 + has_format * 1), 1)

    system = (
        "Tu es le Juge de Qualite. Evalue le texte genere par le Narrateur. "
        "Reponds en JSON: {\"score\": 0-10, \"celtic_density\": float, "
        "\"is_french\": 0|1, \"coherence\": float, \"verdict\": \"GO|NO-GO\"}"
    )

    user = f"Texte a evaluer:\n{text}"

    result = {
        "score": score,
        "celtic_density": celtic_density,
        "is_french": is_french,
        "coherence": round(coherence, 2),
        "verdict": "GO" if score >= 5.0 else "NO-GO",
    }

    return {
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
            {"role": "assistant", "content": json.dumps(result, ensure_ascii=False)},
        ]
    }


def generate_worker_summary_example() -> dict:
    """Generate a quick summary/extraction example for workers."""
    text = random.choice(SAMPLE_TEXTS)
    words = text.split()
    keywords = random.sample(words, min(3, len(words)))

    system = (
        "Tu es un Worker rapide. Extrais les mots-cles et le ton du texte. "
        "Reponds en JSON: {\"keywords\": [...], \"tone\": \"...\", \"word_count\": int}"
    )

    tones = ["poetique", "grave", "mystique", "chaleureux", "inquietant", "espiegle"]

    result = {
        "keywords": [w.strip(".,!?") for w in keywords],
        "tone": random.choice(tones),
        "word_count": len(words),
    }

    return {
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": f"Analyse:\n{text}"},
            {"role": "assistant", "content": json.dumps(result, ensure_ascii=False)},
        ]
    }


# ── Main Pipeline ─────────────────────────────────────────────────────────────

def split_existing_dataset(dataset_path: Path) -> dict[str, list]:
    """Split an existing JSONL into per-brain buckets."""
    buckets: dict[str, list] = {"narrator": [], "gamemaster": [], "worker": []}

    with open(dataset_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            obj = json.loads(line)
            msgs = obj.get("messages", [])
            sys_content = ""
            for m in msgs:
                if m.get("role") == "system":
                    sys_content = m.get("content", "")
                    break

            role = classify_example(sys_content)
            if role in buckets:
                buckets[role].append(obj)
            else:
                # Default unclassified to narrator
                buckets["narrator"].append(obj)

    return buckets


def generate_synthetic(brain: str, count: int) -> list[dict]:
    """Generate synthetic training examples for a given brain."""
    examples = []
    for _ in range(count):
        if brain == "gamemaster":
            gen = random.choice([
                generate_gm_effects_example,
                generate_gm_balance_example,
                generate_gm_choices_example,
            ])
            examples.append(gen())
        elif brain == "worker":
            gen = random.choice([
                generate_worker_quality_example,
                generate_worker_summary_example,
            ])
            examples.append(gen())
    return examples


def write_jsonl(path: Path, examples: list[dict]) -> None:
    """Write examples to a JSONL file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for ex in examples:
            f.write(json.dumps(ex, ensure_ascii=False) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate per-brain LoRA datasets")
    parser.add_argument("--workspace", required=True, help="Project root (containing project.godot)")
    parser.add_argument("--version", type=int, default=1, help="Dataset version number")
    parser.add_argument("--min-narrator", type=int, default=500, help="Min narrator examples")
    parser.add_argument("--min-gm", type=int, default=300, help="Min gamemaster examples")
    parser.add_argument("--min-worker", type=int, default=200, help="Min worker examples")
    args = parser.parse_args()

    root = Path(args.workspace).resolve()
    if not (root / "project.godot").exists():
        fail(f"Invalid workspace: {root}")

    # Find latest dataset
    train_dir = root / "data" / "ai" / "training"
    candidates = sorted(train_dir.glob("merlin_full_v*.jsonl"), reverse=True)
    if not candidates:
        fail(f"No merlin_full_v*.jsonl found in {train_dir}")
    source = candidates[0]
    log(f"Source dataset: {source.name}")

    # Split existing
    buckets = split_existing_dataset(source)
    for brain, examples in buckets.items():
        log(f"  {brain}: {len(examples)} existing examples")

    # Generate synthetic to meet minimums
    targets = {
        "narrator": args.min_narrator,
        "gamemaster": args.min_gm,
        "worker": args.min_worker,
    }

    for brain, target in targets.items():
        existing = len(buckets[brain])
        if existing < target and brain != "narrator":
            needed = target - existing
            log(f"  Generating {needed} synthetic {brain} examples...")
            synthetic = generate_synthetic(brain, needed)
            buckets[brain].extend(synthetic)

    # Shuffle each bucket
    for brain in buckets:
        random.shuffle(buckets[brain])

    # Write per-brain datasets
    out_dir = train_dir / "brains"
    v = args.version
    for brain, examples in buckets.items():
        out_path = out_dir / f"{brain}_v{v}.jsonl"
        write_jsonl(out_path, examples)
        log(f"  Wrote {out_path.name}: {len(examples)} examples")

    # Write manifest
    manifest = {
        "version": v,
        "source": source.name,
        "brains": {
            brain: {
                "file": f"{brain}_v{v}.jsonl",
                "total": len(examples),
                "existing": len(split_existing_dataset(source).get(brain, [])),
                "synthetic": len(examples) - len(split_existing_dataset(source).get(brain, [])),
            }
            for brain, examples in buckets.items()
        },
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8")
    log(f"  Manifest: {manifest_path}")
    log("Done.")


if __name__ == "__main__":
    main()

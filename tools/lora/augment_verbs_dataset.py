#!/usr/bin/env python3
"""
Augment the M.E.R.L.I.N. gold verbs dataset (VERBE — description format).

Reads:  data/ai/training/gold_verbs_v4.jsonl  (20 golden examples)
Writes: data/ai/training/merlin_verbs_augmented.jsonl  (500+ augmented)

Augmentation strategies (all local, no API):
  1. Verb synonym swap — replace verbs with thematic synonyms
  2. Biome rotation — swap location/theme context in user prompt
  3. Aspect state permutation — change Corps/Ame/Monde states
  4. Scenario variant — swap scenario names and tension levels
  5. System prompt variation — rephrase system instructions
  6. Celtic vocabulary enrichment — add druidic terms to narrative

Usage:
  python tools/lora/augment_verbs_dataset.py
  python tools/lora/augment_verbs_dataset.py --target 800
"""

import json
import os
import random
import re
import sys
import copy
from typing import Optional

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INPUT = os.path.join(PROJECT_ROOT, "data", "ai", "training", "gold_verbs_v4.jsonl")
OUTPUT = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_verbs_augmented.jsonl")

# ── Verb synonym groups ──────────────────────────────────────────────────────
VERB_SYNONYMS = {
    "ECOUTER": ["ENTENDRE", "PERCEVOIR", "TENDRE L'OREILLE"],
    "TOUCHER": ["EFFLEURER", "PALPER", "CARESSER"],
    "CONTOURNER": ["EVITER", "ESQUIVER", "LONGER"],
    "PISTER": ["TRAQUER", "SUIVRE LA PISTE", "FILER"],
    "EXAMINER": ["INSPECTER", "SCRUTER", "ANALYSER"],
    "APPELER": ["CRIER", "INTERPELLER", "HELER"],
    "TRAVERSER": ["FRANCHIR", "ENJAMBER", "PASSER"],
    "HELER": ["INTERPELLER", "APOSTROPHER", "APPELER"],
    "PLONGER": ["S'IMMERGER", "SE JETER", "FONCER"],
    "CREUSER": ["FOUILLER", "EXCAVER", "GRATTER"],
    "GUETTER": ["EPIER", "SURVEILLER", "OBSERVER"],
    "INVOQUER": ["APPELER", "CONJURER", "IMPLORER"],
    "INTERROGER": ["QUESTIONNER", "DEMANDER", "SONDER"],
    "SUIVRE": ["EMBOITER LE PAS", "ACCOMPAGNER", "FILER"],
    "REFUSER": ["DECLINER", "REPOUSSER", "REJETER"],
    "NAGER": ["PLONGER", "S'IMMERGER", "FENDRE L'EAU"],
    "PRIER": ["IMPLORER", "SUPPLIER", "MEDITER"],
    "BRULER": ["ENFLAMMER", "EMBRASER", "INCENDIER"],
    "DECHIFFRER": ["DECODER", "LIRE", "INTERPRETER"],
    "MEDITER": ["CONTEMPLER", "REFLECHIR", "SE RECUEILLIR"],
    "ESCALADER": ["GRIMPER", "GRAVIR", "MONTER"],
    "MARCHANDER": ["NEGOCIER", "TROQUER", "ECHANGER"],
    "CONFRONTER": ["AFFRONTER", "DEFIER", "INTERPELLER"],
    "SOIGNER": ["GUERIR", "PANSER", "SOULAGER"],
    "OBSERVER": ["REGARDER", "CONTEMPLER", "SCRUTER"],
    "DEFIER": ["AFFRONTER", "PROVOQUER", "BRAVER"],
    "PECHER": ["ATTRAPER", "CAPTURER", "HARPONNER"],
    "BOIRE": ["S'ABREUVER", "GOUTER", "SAVOURER"],
    "PARLER": ["S'ADRESSER", "MURMURER", "CONVERSER"],
    "APPROCHER": ["S'AVANCER", "SE RAPPROCHER", "ALLER VERS"],
    "ATTENDRE": ["PATIENTER", "RESTER", "DEMEURER"],
    "CHANTER": ["ENTONNER", "FREDONNER", "PSALMODIER"],
    "DESCENDRE": ["GLISSER", "DEVALER", "S'ENFONCER"],
    "TRESSER": ["TISSER", "NOUER", "ENTRELACER"],
    "RAMENER": ["RECONDUIRE", "PORTER", "EMPORTER"],
    "LIBERER": ["RELACHER", "LAISSER PARTIR", "AFFRANCHIR"],
    "RESTER": ["DEMEURER", "S'ARRETER", "PERSISTER"],
    "GRAVER": ["INSCRIRE", "TAILLER", "MARQUER"],
    "DORMIR": ["S'ENDORMIR", "SE REPOSER", "SOMMEILLER"],
    "ENTRER": ["PENETRER", "FRANCHIR", "S'ENGAGER"],
    "QUESTIONNER": ["INTERROGER", "DEMANDER", "SONDER"],
    "PROTEGER": ["PRESERVER", "DEFENDRE", "ABRITER"],
    "ANCRER": ["S'ACCROCHER", "S'ARRIMER", "SE FIXER"],
    "DANSER": ["TOURNOYER", "VIREVOLTER", "S'ELANCER"],
    "VEILLER": ["SURVEILLER", "MONTER LA GARDE", "RESTER EVEILLE"],
    "SALUER": ["S'INCLINER", "RENDRE HOMMAGE", "HONORER"],
    "CAPTURER": ["SAISIR", "ATTRAPER", "AGRIPPER"],
    "AVANCER": ["PROGRESSER", "MARCHER", "POURSUIVRE"],
    "FONCER": ["CHARGER", "SE RUER", "SE PRECIPITER"],
}

# ── Biome contexts ───────────────────────────────────────────────────────────
BIOMES = [
    {"lieu": "foret_broceliande", "themes": ["brume matinale", "chene centenaire", "clairiere secrete", "sentier des fees", "racines du monde"]},
    {"lieu": "landes_bruyere", "themes": ["cotes sauvages", "vent de sel", "falaises de granit", "lande deserte"]},
    {"lieu": "cercles_pierres", "themes": ["aurore druidique", "alignement lunaire", "menhirs chantants", "solstice"]},
    {"lieu": "villages_celtes", "themes": ["marche celtique", "forge du village", "feu de veille", "puits sacre"]},
    {"lieu": "marais_korrigans", "themes": ["nuit de Samhain", "feux follets", "eau noire", "brouillard epais"]},
    {"lieu": "collines_dolmens", "themes": ["tonnerre lointain", "nemeton cache", "colline ventee", "dolmen solitaire"]},
    {"lieu": "cotes_granit", "themes": ["tempete marine", "grotte cotiere", "ile invisible", "ecume et sel"]},
]

# ── Scenarios ────────────────────────────────────────────────────────────────
SCENARIOS = [
    "La Fille Perdue",
    "Le Sanglier d'Or",
    "La Source Empoisonnee",
    "Le Korrigan Menteur",
    "L'Epee dans le Chene",
    "La Nuit des Feux",
    "Le Passage d'Avalon",
    "Le Cerf Blanc",
    "La Pierre Qui Parle",
    "Le Pacte des Sidhe",
]

# ── Aspect states ────────────────────────────────────────────────────────────
ASPECT_COMBOS = [
    "Corps=equilibre Ame=equilibre Monde=equilibre",
    "Corps=bas Ame=equilibre Monde=equilibre",
    "Corps=haut Ame=equilibre Monde=equilibre",
    "Corps=equilibre Ame=bas Monde=equilibre",
    "Corps=equilibre Ame=haut Monde=equilibre",
    "Corps=equilibre Ame=equilibre Monde=bas",
    "Corps=equilibre Ame=equilibre Monde=haut",
    "Corps=bas Ame=bas Monde=equilibre",
    "Corps=bas Ame=equilibre Monde=bas",
    "Corps=equilibre Ame=bas Monde=bas",
    "Corps=bas Ame=bas Monde=bas",
    "Corps=haut Ame=haut Monde=equilibre",
    "Corps=bas Ame=haut Monde=bas",
]

# ── Actes ────────────────────────────────────────────────────────────────────
ACTES = ["Acte I: Decouverte", "Acte II: Tension", "Acte III: Resolution", "Epilogue"]

# ── System prompt variants ───────────────────────────────────────────────────
SYSTEM_VARIANTS = [
    "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Tu contes au present, a la deuxieme personne (tu). FORMAT: VERBE EN MAJUSCULES — description d'action concrete. Pas de meta-commentaire. Pas d'anglais.",
    "Tu es Merlin l'Enchanteur. Tu contes au present, a la deuxieme personne (tu). STYLE: Decris les sensations (odeurs, sons, lumiere, textures). FORMAT: 3 choix avec VERBE — description. Vocabulaire celtique.",
    "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Tu contes au present, a la deuxieme personne (tu). STYLE: Decris les sensations. FORMAT: 3 choix avec VERBE EN MAJUSCULES + description. Pas de meta-commentaire.",
    "Tu es Merlin l'Enchanteur. FORMAT: VERBE — description concrete a la 2e personne. Vocabulaire celtique.",
    "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Tu contes au present, a la deuxieme personne (tu). FORMAT: VERBE EN MAJUSCULES — Description concrete. Vocabulaire celtique.",
    "Tu es Merlin l'Enchanteur. FORMAT: VERBE — description. Style sensoriel.",
    "Tu es Merlin l'Enchanteur. FORMAT: VERBE — description. Ton urgent, enjeux eleves.",
    "Tu es Merlin l'Enchanteur. FORMAT: VERBE — description. Equilibre fragile.",
    "Tu es Merlin l'Enchanteur, druide de Broceliande. FORMAT: VERBE — description concrete de l'action en 1 phrase. Le verbe en MAJUSCULES, suivi d'un tiret long et d'une description concrete a la 2e personne.",
]

# ── Celtic terms for enrichment ──────────────────────────────────────────────
CELTIC_INSERTS = [
    "Vocabulaire: nemeton, ogham, sidhe.",
    "Ambiance: brume, mousse, lichen.",
    "References: Samhain, Beltaine, korrigans.",
    "Atmospherique: tourbe, granit, racines anciennes.",
    "Monde: dolmen, menhir, cromlech, cairn.",
]

# ── Minigame tags ────────────────────────────────────────────────────────────
MINIGAMES = [
    "MINI-JEU: Traces (suivre une sequence d'empreintes sans s'egarer)",
    "MINI-JEU: Runes (dechiffrer les symboles graves dans la pierre)",
    "MINI-JEU: Equilibre (maintenir l'equilibre sur un passage instable)",
    "MINI-JEU: Herboristerie (identifier la bonne plante parmi les toxiques)",
    "MINI-JEU: Negociation (convaincre un esprit par les mots justes)",
    "MINI-JEU: Combat Rituel (esquiver dans un cercle sacre)",
]


def load_jsonl(path: str) -> list:
    samples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                samples.append(json.loads(line))
    return samples


def write_jsonl(path: str, samples: list):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for sample in samples:
            f.write(json.dumps(sample, ensure_ascii=False) + "\n")


def deep_copy_sample(sample: dict) -> dict:
    return json.loads(json.dumps(sample))


def get_assistant_text(sample: dict) -> str:
    convs = sample.get("conversations", [])
    if len(convs) >= 3:
        return convs[2].get("content", "")
    return ""


def set_assistant_text(sample: dict, text: str) -> dict:
    new_sample = deep_copy_sample(sample)
    new_sample["conversations"][2]["content"] = text
    return new_sample


def get_user_text(sample: dict) -> str:
    convs = sample.get("conversations", [])
    if len(convs) >= 2:
        return convs[1].get("content", "")
    return ""


def set_user_text(sample: dict, text: str) -> dict:
    new_sample = deep_copy_sample(sample)
    new_sample["conversations"][1]["content"] = text
    return new_sample


def set_system_text(sample: dict, text: str) -> dict:
    new_sample = deep_copy_sample(sample)
    new_sample["conversations"][0]["content"] = text
    return new_sample


def extract_verb_lines(text: str) -> list:
    """Extract A) VERB — desc lines from assistant text."""
    pattern = r"^([A-D])\)\s*([A-ZÀ-Ü\s']+?)\s*[—–\-:]\s*(.+)$"
    matches = []
    for line in text.split("\n"):
        m = re.match(pattern, line.strip())
        if m:
            matches.append({"letter": m.group(1), "verb": m.group(2).strip(), "desc": m.group(3).strip()})
    return matches


def replace_verb_in_line(line: str, old_verb: str, new_verb: str) -> str:
    """Replace a verb in a choice line."""
    return line.replace(old_verb, new_verb, 1)


# ── Strategy 1: Verb synonym swap ───────────────────────────────────────────
def augment_verb_swap(samples: list) -> list:
    augmented = []
    for sample in samples:
        text = get_assistant_text(sample)
        verb_lines = extract_verb_lines(text)
        if not verb_lines:
            continue

        # Try 3 swaps per sample
        for _ in range(3):
            new_text = text
            swapped = False
            for vl in verb_lines:
                verb = vl["verb"]
                synonyms = VERB_SYNONYMS.get(verb, [])
                if synonyms:
                    new_verb = random.choice(synonyms)
                    new_text = replace_verb_in_line(new_text, verb, new_verb)
                    swapped = True
            if swapped and new_text != text:
                augmented.append(set_assistant_text(sample, new_text))
    return augmented


# ── Strategy 2: Biome rotation ──────────────────────────────────────────────
def augment_biome_rotation(samples: list) -> list:
    augmented = []
    for sample in samples:
        user_text = get_user_text(sample)
        # Try 2 biome swaps
        for _ in range(2):
            biome = random.choice(BIOMES)
            theme = random.choice(biome["themes"])
            # Replace lieu and theme in user prompt
            new_user = re.sub(r"Lieu:\s*\S+", f"Lieu: {biome['lieu']}", user_text)
            new_user = re.sub(r"Theme:\s*[^.]+", f"Theme: {theme}", new_user)
            if new_user != user_text:
                augmented.append(set_user_text(sample, new_user))
    return augmented


# ── Strategy 3: Aspect state permutation ────────────────────────────────────
def augment_aspect_state(samples: list) -> list:
    augmented = []
    for sample in samples:
        user_text = get_user_text(sample)
        if "Corps=" in user_text:
            for _ in range(2):
                new_state = random.choice(ASPECT_COMBOS)
                new_user = re.sub(r"Corps=\w+\s+Ame=\w+\s+Monde=\w+", new_state, user_text)
                if new_user != user_text:
                    augmented.append(set_user_text(sample, new_user))
    return augmented


# ── Strategy 4: Scenario variant ────────────────────────────────────────────
def augment_scenario_variant(samples: list) -> list:
    augmented = []
    for sample in samples:
        user_text = get_user_text(sample)
        if "Scenario:" in user_text:
            for _ in range(2):
                new_scenario = random.choice(SCENARIOS)
                new_user = re.sub(r"Scenario:\s*[^.]+", f"Scenario: {new_scenario}", user_text)
                if new_user != user_text:
                    augmented.append(set_user_text(sample, new_user))
    return augmented


# ── Strategy 5: System prompt variation ─────────────────────────────────────
def augment_system_variant(samples: list) -> list:
    augmented = []
    for sample in samples:
        for _ in range(2):
            new_sys = random.choice(SYSTEM_VARIANTS)
            # Optionally add Celtic terms
            if random.random() < 0.4:
                new_sys += " " + random.choice(CELTIC_INSERTS)
            new_sample = set_system_text(sample, new_sys)
            augmented.append(new_sample)
    return augmented


# ── Strategy 6: Add/remove minigame tag ─────────────────────────────────────
def augment_minigame_toggle(samples: list) -> list:
    augmented = []
    for sample in samples:
        text = get_assistant_text(sample)
        has_minigame = "MINI-JEU:" in text

        if has_minigame:
            # Create a version without minigame
            cleaned = re.sub(r"\n\nMINI-JEU:.*$", "", text, flags=re.MULTILINE)
            if cleaned != text:
                augmented.append(set_assistant_text(sample, cleaned))
        else:
            # Add a random minigame to ~40% of samples
            if random.random() < 0.4:
                mg = random.choice(MINIGAMES)
                new_text = text.rstrip() + "\n\n" + mg
                augmented.append(set_assistant_text(sample, new_text))

    return augmented


# ── Strategy 7: Card number and acte variation ──────────────────────────────
def augment_card_acte(samples: list) -> list:
    augmented = []
    for sample in samples:
        user_text = get_user_text(sample)
        if "Carte" in user_text:
            for _ in range(2):
                new_card = random.randint(1, 20)
                new_acte = random.choice(ACTES)
                new_user = re.sub(r"Carte\s+\d+", f"Carte {new_card}", user_text)
                # Add or replace acte
                if "Acte" in new_user:
                    new_user = re.sub(r"Acte\s+\w+:?\s*\w*", new_acte, new_user)
                else:
                    new_user = new_user.rstrip(".") + f". {new_acte}."

                # Add souffle if not present
                if "Souffle" not in new_user and random.random() < 0.5:
                    souffle = random.randint(0, 7)
                    new_user = new_user.rstrip(".") + f". Souffle={souffle}."

                if new_user != user_text:
                    augmented.append(set_user_text(sample, new_user))
    return augmented


def main():
    target = 500
    if "--target" in sys.argv:
        idx = sys.argv.index("--target")
        if idx + 1 < len(sys.argv):
            target = int(sys.argv[idx + 1])

    print(f"[augment-verbs] Loading gold dataset: {INPUT}")
    base_samples = load_jsonl(INPUT)
    print(f"  Base samples: {len(base_samples)}")

    all_samples = list(base_samples)

    # Strategy 1: Verb synonym swap
    verb_aug = augment_verb_swap(base_samples)
    print(f"  Verb synonym swap: +{len(verb_aug)}")
    all_samples.extend(verb_aug)

    # Strategy 2: Biome rotation
    biome_aug = augment_biome_rotation(base_samples)
    print(f"  Biome rotation: +{len(biome_aug)}")
    all_samples.extend(biome_aug)

    # Strategy 3: Aspect state permutation
    aspect_aug = augment_aspect_state(base_samples)
    print(f"  Aspect state permutation: +{len(aspect_aug)}")
    all_samples.extend(aspect_aug)

    # Strategy 4: Scenario variant
    scenario_aug = augment_scenario_variant(base_samples)
    print(f"  Scenario variant: +{len(scenario_aug)}")
    all_samples.extend(scenario_aug)

    # Strategy 5: System prompt variation
    system_aug = augment_system_variant(base_samples)
    print(f"  System prompt variation: +{len(system_aug)}")
    all_samples.extend(system_aug)

    # Strategy 6: Minigame toggle
    minigame_aug = augment_minigame_toggle(base_samples)
    print(f"  Minigame toggle: +{len(minigame_aug)}")
    all_samples.extend(minigame_aug)

    # Strategy 7: Card/acte variation
    card_aug = augment_card_acte(base_samples)
    print(f"  Card/acte variation: +{len(card_aug)}")
    all_samples.extend(card_aug)

    print(f"\n  Total before padding: {len(all_samples)}")

    # If still below target, repeat augmentations with different seeds
    round_num = 2
    while len(all_samples) < target:
        print(f"  Round {round_num}: padding to reach {target}...")
        random.seed(round_num * 42)
        extra = []
        extra.extend(augment_verb_swap(base_samples))
        extra.extend(augment_system_variant(base_samples))
        extra.extend(augment_biome_rotation(base_samples))
        extra.extend(augment_card_acte(base_samples))
        random.shuffle(extra)
        needed = target - len(all_samples)
        all_samples.extend(extra[:needed])
        round_num += 1
        if round_num > 10:
            break

    # Shuffle final dataset
    random.shuffle(all_samples)

    # Stats
    verb_count = {}
    total_verbs = 0
    for sample in all_samples:
        text = get_assistant_text(sample)
        for vl in extract_verb_lines(text):
            verb = vl["verb"]
            verb_count[verb] = verb_count.get(verb, 0) + 1
            total_verbs += 1

    print(f"\n  Final dataset: {len(all_samples)} samples")
    print(f"  Unique verbs: {len(verb_count)}")
    print(f"  Total verb instances: {total_verbs}")
    print(f"  Top 10 verbs:")
    for verb, count in sorted(verb_count.items(), key=lambda x: -x[1])[:10]:
        print(f"    {verb}: {count}")

    # Write output
    write_jsonl(OUTPUT, all_samples)
    print(f"\n[augment-verbs] Done! {len(all_samples)} samples written to:")
    print(f"  {OUTPUT}")


if __name__ == "__main__":
    main()

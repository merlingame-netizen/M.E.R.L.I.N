#!/usr/bin/env python3
"""
Augment LoRA v5 gold dataset (20 samples) to 1500+ training samples.

Input:  data/ai/training/gold_verbs_v5.jsonl (20 gold VERBE + description)
Output: data/ai/training/merlin_verbs_v5_augmented.jsonl (1500+ ChatML JSONL)

Strategies:
  1. Biome transfer (7 biomes x 20 = 120 new)
  2. Aspect state permutation (8 states x 20 = 160 new)
  3. Tension level variation (5 themes x 20 = 100 new)
  4. Celtic vocabulary injection (3 combos x 20 = 60 new)
  5. Combined: biome x tension (7 x 5 x 20 = 700 but capped)
  6. Verb synonym swap (enrich verb variety)
  7. System prompt variation (short/medium/long)

Total target: 1500+ unique samples, all in VERBE -- description format.
"""

import json
import os
import random
import re
import sys
import hashlib

random.seed(42)

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
INPUT = os.path.join(PROJECT_ROOT, "data", "ai", "training", "gold_verbs_v5.jsonl")
OUTPUT = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_verbs_v5_augmented.jsonl")

# --- Constants ---

SYSTEM_PROMPTS = {
    "full": (
        "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. "
        "Tu contes au present, a la deuxieme personne (tu). "
        "FORMAT: 4-6 phrases sensorielles puis EXACTEMENT 3 choix:\n"
        "A) VERBE \u2014 Description d'action en 1 phrase\n"
        "B) VERBE \u2014 Description d'action en 1 phrase\n"
        "C) VERBE \u2014 Description d'action en 1 phrase"
    ),
    "short": (
        "Tu es Merlin l'Enchanteur. "
        "FORMAT: VERBE \u2014 description concrete."
    ),
    "urgence": (
        "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. "
        "Tu contes au present, a la deuxieme personne (tu). "
        "URGENCE: L'equilibre vacille. "
        "FORMAT: 4-6 phrases sensorielles puis EXACTEMENT 3 choix:\n"
        "A) VERBE \u2014 Description d'action en 1 phrase\n"
        "B) VERBE \u2014 Description d'action en 1 phrase\n"
        "C) VERBE \u2014 Description d'action en 1 phrase"
    ),
    "biome": (
        "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. "
        "Tu contes au present, a la deuxieme personne (tu). "
        "Biome: {biome}. Ambiance: {ambiance}. "
        "FORMAT: 4-6 phrases sensorielles puis EXACTEMENT 3 choix:\n"
        "A) VERBE \u2014 Description d'action en 1 phrase\n"
        "B) VERBE \u2014 Description d'action en 1 phrase\n"
        "C) VERBE \u2014 Description d'action en 1 phrase"
    ),
    "celtic": (
        "Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. "
        "Tu contes au present, a la deuxieme personne (tu). "
        "Vocabulaire celtique: {terms}. "
        "FORMAT: 4-6 phrases sensorielles puis EXACTEMENT 3 choix:\n"
        "A) VERBE \u2014 Description d'action en 1 phrase\n"
        "B) VERBE \u2014 Description d'action en 1 phrase\n"
        "C) VERBE \u2014 Description d'action en 1 phrase"
    ),
}

BIOMES = [
    ("foret_broceliande", "foret ancienne, chenes millenaires, brume doree"),
    ("landes_carnac", "bruyere, vent salant, menhirs alignes a perte de vue"),
    ("cotes_granit", "falaises, ecume, granit noir, cris de mouettes"),
    ("villages_celtiques", "pierre grise, toits d'ardoise, feux de tourbe"),
    ("cercles_pierre", "menhirs, alignements, energie tellurique vibrante"),
    ("marais_avalon", "eau stagnante, reflets iridescents, brouillard epais"),
    ("collines_dolmens", "collines arrondies, dolmens, couronnes de pierre"),
]

ASPECT_STATES = [
    ("stable", "Equilibre stable."),
    ("corps_bas", "Corps affaibli (Epuise). Ame et Monde stables."),
    ("corps_haut", "Corps excessif (Surmene). Ame et Monde stables."),
    ("ame_basse", "Ame fragile (Perdue). Corps et Monde stables."),
    ("ame_haute", "Ame excessive (Possedee). Corps et Monde stables."),
    ("monde_bas", "Monde fragile (Exile). Corps et Ame stables."),
    ("monde_haut", "Monde excessif (Tyran). Corps et Ame stables."),
    ("fragile", "Equilibre fragile."),
    ("critique", "Equilibre critique."),
]

THEMES = [
    "exploration",
    "mystere",
    "confrontation",
    "sauvetage",
    "magie",
    "rencontre",
    "survie",
]

CELTIC_VOCAB = [
    "nemeton", "ogham", "duir", "quert", "beith", "luis",
    "korrigans", "sidhe", "bean-nighe", "pooka", "selkie",
    "dolmen", "menhir", "cromlech", "cairn", "tumulus",
    "brume", "mousse", "lichen", "rosee", "tourbe",
    "Samhain", "Beltaine", "Imbolc", "Lughnasadh",
]

VERB_SYNONYMS = {
    "ECOUTER": ["ENTENDRE", "TENDRE L'OREILLE", "GUETTER"],
    "PISTER": ["TRAQUER", "SUIVRE LA TRACE", "FILER"],
    "PRIER": ["INVOQUER", "IMPLORER", "SUPPLIER"],
    "SUIVRE": ["POURSUIVRE", "EMBOITER LE PAS", "FILER"],
    "MARQUER": ["GRAVER", "INSCRIRE", "BALISER"],
    "FORCER": ["BRISER", "ENFONCER", "FRACASSER"],
    "POURCHASSER": ["TRAQUER", "COURSER", "POURSUIVRE"],
    "APPELER": ["HELER", "INTERPELER", "CRIER"],
    "SE CACHER": ["SE DISSIMULER", "SE TAPIR", "S'EMBUSQUER"],
    "COMBATTRE": ["AFFRONTER", "LUTTER", "DEFIER"],
    "APAISER": ["CALMER", "ADOUCIR", "PACIFIER"],
    "FUIR": ["S'ENFUIR", "DETALER", "DECAMPER"],
    "DESARMER": ["NEUTRALISER", "DESAMORCER", "DEFAIRE"],
    "DECHIFFRER": ["DECODER", "INTERPRETER", "TRADUIRE"],
    "TRAVERSER": ["FRANCHIR", "ENJAMBER", "PASSER"],
    "OBSERVER": ["SCRUTER", "EXAMINER", "CONTEMPLER"],
    "TOUCHER": ["EFFLEURER", "PALPER", "TATER"],
    "QUESTIONNER": ["INTERROGER", "DEMANDER", "SONDER"],
    "MENACER": ["INTIMIDER", "DEFIER", "PROVOQUER"],
    "MARCHANDER": ["NEGOCIER", "TROQUER", "PARLEMENTER"],
    "REVENIR": ["REBROUSSER", "RECULER", "RETOURNER"],
    "CAMPER": ["BIVOUAQUER", "S'INSTALLER", "SE POSER"],
    "S'ENGOUFFRER": ["PLONGER", "SE RUER", "FONCER"],
    "MEDITER": ["REFLECHIR", "CONTEMPLER", "SONGER"],
    "DORMIR": ["SE REPOSER", "SOMMEILLER", "S'ASSOUPIR"],
    "DOUTER": ["HESITER", "QUESTIONNER", "VACILLER"],
    "RESISTER": ["TENIR BON", "S'ACCROCHER", "ENDURER"],
    "AFFRONTER": ["COMBATTRE", "DEFIER", "FAIRE FACE"],
    "EXPLORER": ["FOUILLER", "PROSPECTER", "INSPECTER"],
    "ESCALADER": ["GRIMPER", "GRAVIR", "MONTER"],
    "BOIRE": ["GOUTER", "SIROTER", "ABSORBER"],
    "SE TAIRE": ["GARDER LE SILENCE", "SE MURER", "TAIRE"],
    "NEGOCIER": ["MARCHANDER", "PARLEMENTER", "DISCUTER"],
    "COUPER": ["TRANCHER", "TAILLER", "FENDRE"],
    "RECONSTITUER": ["RASSEMBLER", "ASSEMBLER", "RECONSTRUIRE"],
    "ACCUSER": ["DENONCER", "INCRIMINER", "POINTER"],
    "RASSURER": ["RECONFORTER", "APAISER", "CONSOLER"],
    "SAISIR": ["AGRIPPER", "ATTRAPER", "EMPOIGNER"],
    "PROTEGER": ["DEFENDRE", "ABRITER", "COUVRIR"],
    "SORTIR": ["QUITTER", "PARTIR", "S'EXTRAIRE"],
    "BRISER": ["CASSER", "FRACASSER", "DETRUIRE"],
    "JURER": ["PROMETTRE", "S'ENGAGER", "VOUER"],
    "CONTOURNER": ["EVITER", "ESQUIVER", "DEVIER"],
    "ECLAIRER": ["ILLUMINER", "BRILLER", "LUIRE"],
    "RECUEILLIR": ["RAMASSER", "COLLECTER", "RASSEMBLER"],
    "IGNORER": ["DEDAIGNER", "MEPRISER", "PASSER OUTRE"],
    "APPROCHER": ["S'AVANCER", "SE RAPPROCHER", "ABORDER"],
    "AVANCER": ["PROGRESSER", "MARCHER", "ALLER DE L'AVANT"],
    "SCELLER": ["FERMER", "VERROUILLER", "CONDAMNER"],
    "POURSUIVRE": ["CONTINUER", "PERSEVERER", "MAINTENIR"],
    "SE REPOSER": ["REPRENDRE SOUFFLE", "SOUFFLER", "FAIRE HALTE"],
}


def load_jsonl(path):
    """Load JSONL file, return list of dicts."""
    samples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                samples.append(json.loads(line))
    return samples


def make_sample(system, user, assistant):
    """Create a ChatML sample dict."""
    return {
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ]
    }


def sample_hash(sample):
    """Deduplicate by content hash."""
    content = json.dumps(sample, sort_keys=True, ensure_ascii=False)
    return hashlib.md5(content.encode()).hexdigest()


def extract_parts(sample):
    """Extract system, user, assistant from a sample."""
    msgs = sample["messages"]
    return msgs[0]["content"], msgs[1]["content"], msgs[2]["content"]


def replace_verb_in_text(text, old_verb, new_verb):
    """Replace a verb in the assistant response (both in choice line and within text)."""
    # Replace in choice line: A) OLD_VERB -- desc
    pattern = re.compile(
        r"([A-C]\)\s*)" + re.escape(old_verb) + r"(\s*[\u2014\u2013\-:])",
        re.IGNORECASE
    )
    return pattern.sub(r"\g<1>" + new_verb + r"\g<2>", text)


def swap_verbs(assistant_text):
    """Randomly swap 1-2 verbs with synonyms in the assistant text."""
    lines = assistant_text.split("\n")
    modified = False
    new_lines = []
    for line in lines:
        m = re.match(r"([A-C]\)\s*)([A-Z\s']+?)(\s*[\u2014\u2013\-:]\s*.+)", line)
        if m:
            prefix, verb, rest = m.group(1), m.group(2).strip(), m.group(3)
            if verb in VERB_SYNONYMS and random.random() < 0.6:
                new_verb = random.choice(VERB_SYNONYMS[verb])
                new_lines.append(f"{prefix}{new_verb}{rest}")
                modified = True
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)
    return "\n".join(new_lines) if modified else None


def augment_biome(samples):
    """Change biome in user prompt, keep assistant text (teaches FORMAT not content)."""
    augmented = []
    for sample in samples:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for biome_id, ambiance in BIOMES:
            # Skip if same biome already
            if biome_id in user_msg:
                continue
            new_user = re.sub(
                r"Lieu:\s*\S+",
                f"Lieu: {biome_id}",
                user_msg
            )
            if new_user == user_msg:
                # No lieu found, add it
                new_user = user_msg + f" Lieu: {biome_id}."
            # Use biome-aware system prompt
            new_sys = SYSTEM_PROMPTS["biome"].format(
                biome=biome_id.replace("_", " ").title(),
                ambiance=ambiance
            )
            augmented.append(make_sample(new_sys, new_user, asst_msg))
    return augmented


def augment_aspect_state(samples):
    """Vary aspect state in user prompt."""
    augmented = []
    for sample in samples:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for state_id, state_desc in ASPECT_STATES:
            # Replace equilibre description
            new_user = re.sub(
                r"Equilibre\s+\w+\.?",
                state_desc,
                user_msg
            )
            if new_user == user_msg:
                new_user = user_msg.rstrip(".") + f". {state_desc}"
            # Use urgence system prompt for critical states
            if state_id == "critique":
                new_sys = SYSTEM_PROMPTS["urgence"]
            else:
                new_sys = sys_msg
            augmented.append(make_sample(new_sys, new_user, asst_msg))
    return augmented


def augment_theme(samples):
    """Vary theme in user prompt."""
    augmented = []
    for sample in samples:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for theme in THEMES:
            if f"Theme: {theme}" in user_msg:
                continue
            new_user = re.sub(
                r"Theme:\s*\w+",
                f"Theme: {theme}",
                user_msg
            )
            if new_user == user_msg:
                new_user = user_msg.rstrip(".") + f". Theme: {theme}."
            augmented.append(make_sample(sys_msg, new_user, asst_msg))
    return augmented


def augment_celtic(samples):
    """Add Celtic vocabulary hints to system prompt."""
    augmented = []
    for sample in samples:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for _ in range(3):
            terms = random.sample(CELTIC_VOCAB, 3)
            new_sys = SYSTEM_PROMPTS["celtic"].format(terms=", ".join(terms))
            augmented.append(make_sample(new_sys, user_msg, asst_msg))
    return augmented


def augment_verb_synonyms(samples):
    """Swap verbs in assistant text with synonyms."""
    augmented = []
    for sample in samples:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for _ in range(5):
            swapped = swap_verbs(asst_msg)
            if swapped and swapped != asst_msg:
                augmented.append(make_sample(sys_msg, user_msg, swapped))
    return augmented


def augment_system_prompt_variation(samples):
    """Use different system prompt lengths (short/full/urgence)."""
    augmented = []
    variants = ["short", "urgence"]
    for sample in samples:
        _, user_msg, asst_msg = extract_parts(sample)
        for variant in variants:
            new_sys = SYSTEM_PROMPTS[variant]
            augmented.append(make_sample(new_sys, user_msg, asst_msg))
    return augmented


def augment_card_number(samples):
    """Vary card number in user prompt (1-20 original, expand to 1-50)."""
    augmented = []
    for sample in samples:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for card_num in range(21, 41):
            new_user = re.sub(r"Carte\s+\d+", f"Carte {card_num}", user_msg)
            if new_user != user_msg:
                augmented.append(make_sample(sys_msg, new_user, asst_msg))
    return augmented


def deduplicate(samples):
    """Remove exact duplicates by content hash."""
    seen = set()
    unique = []
    for s in samples:
        h = sample_hash(s)
        if h not in seen:
            seen.add(h)
            unique.append(s)
    return unique


V1_AUGMENTED = os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_verbs_augmented.jsonl")


def load_v1_as_v5(path):
    """Load v1 JSONL (conversations key) and convert to v5 format (messages key)."""
    samples = []
    if not os.path.exists(path):
        return samples
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            data = json.loads(line)
            convs = data.get("conversations", [])
            if len(convs) >= 3:
                # Convert key name
                samples.append({
                    "messages": [
                        {"role": convs[0]["role"], "content": convs[0]["content"]},
                        {"role": convs[1]["role"], "content": convs[1]["content"]},
                        {"role": convs[2]["role"], "content": convs[2]["content"]},
                    ]
                })
    return samples


def main():
    print("[augment_v5] Loading gold dataset...")
    gold = load_jsonl(INPUT)
    print(f"  Gold samples: {len(gold)}")

    if len(gold) == 0:
        print("ERROR: No gold samples found!")
        sys.exit(1)

    all_samples = list(gold)  # Start with originals

    # Strategy 1: Biome transfer
    biome_aug = augment_biome(gold)
    print(f"  [1] Biome transfer: +{len(biome_aug)}")
    all_samples.extend(biome_aug)

    # Strategy 2: Aspect state permutation
    aspect_aug = augment_aspect_state(gold)
    print(f"  [2] Aspect state: +{len(aspect_aug)}")
    all_samples.extend(aspect_aug)

    # Strategy 3: Theme variation
    theme_aug = augment_theme(gold)
    print(f"  [3] Theme variation: +{len(theme_aug)}")
    all_samples.extend(theme_aug)

    # Strategy 4: Celtic vocabulary injection
    celtic_aug = augment_celtic(gold)
    print(f"  [4] Celtic vocab: +{len(celtic_aug)}")
    all_samples.extend(celtic_aug)

    # Strategy 5: Verb synonym swap
    verb_aug = augment_verb_synonyms(gold)
    print(f"  [5] Verb synonyms: +{len(verb_aug)}")
    all_samples.extend(verb_aug)

    # Strategy 6: System prompt variation
    sysprompt_aug = augment_system_prompt_variation(gold)
    print(f"  [6] System prompt variations: +{len(sysprompt_aug)}")
    all_samples.extend(sysprompt_aug)

    # Strategy 7: Card number expansion
    card_aug = augment_card_number(gold)
    print(f"  [7] Card number expansion: +{len(card_aug)}")
    all_samples.extend(card_aug)

    # Strategy 8: Combined — biome + verb swap (cross-pollination)
    combined_aug = []
    for sample in gold:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for biome_id, ambiance in random.sample(BIOMES, min(4, len(BIOMES))):
            if biome_id in user_msg:
                continue
            swapped = swap_verbs(asst_msg)
            if swapped is None:
                swapped = asst_msg
            new_user = re.sub(r"Lieu:\s*\S+", f"Lieu: {biome_id}", user_msg)
            if new_user == user_msg:
                new_user = user_msg + f" Lieu: {biome_id}."
            new_sys = SYSTEM_PROMPTS["biome"].format(
                biome=biome_id.replace("_", " ").title(),
                ambiance=ambiance
            )
            combined_aug.append(make_sample(new_sys, new_user, swapped))
    print(f"  [8] Combined biome+verb: +{len(combined_aug)}")
    all_samples.extend(combined_aug)

    # Strategy 9: Merge v1 augmented data (550 samples, already VERBE — description)
    v1_data = load_v1_as_v5(V1_AUGMENTED)
    # Filter: keep only samples with VERBE — description format
    v1_valid = [s for s in v1_data if re.search(r"[A-C]\)\s*[A-Z].*[\u2014\u2013\-:]", s["messages"][2]["content"])]
    print(f"  [9] V1 merge (VERBE-desc only): +{len(v1_valid)}")
    all_samples.extend(v1_valid)

    # Strategy 10: Combined — aspect + theme (cross-condition)
    cross_aug = []
    for sample in gold:
        sys_msg, user_msg, asst_msg = extract_parts(sample)
        for _ in range(10):
            state_id, state_desc = random.choice(ASPECT_STATES)
            theme = random.choice(THEMES)
            new_user = re.sub(r"Equilibre\s+\w+\.?", state_desc, user_msg)
            new_user = re.sub(r"Theme:\s*\w+", f"Theme: {theme}", new_user)
            new_sys = SYSTEM_PROMPTS["urgence"] if state_id == "critique" else sys_msg
            cross_aug.append(make_sample(new_sys, new_user, asst_msg))
    print(f"  [9] Combined aspect+theme: +{len(cross_aug)}")
    all_samples.extend(cross_aug)

    # Deduplicate
    before_dedup = len(all_samples)
    all_samples = deduplicate(all_samples)
    print(f"\n  Dedup: {before_dedup} -> {len(all_samples)}")

    # Cap at a reasonable size if way too many
    if len(all_samples) > 2500:
        print(f"  Capping from {len(all_samples)} to 2000 (keeping gold + random sample)")
        # Always keep gold
        rest = all_samples[len(gold):]
        random.shuffle(rest)
        all_samples = list(gold) + rest[:2000 - len(gold)]

    # Shuffle (keep gold at front for validation)
    gold_set = set(sample_hash(g) for g in gold)
    non_gold = [s for s in all_samples if sample_hash(s) not in gold_set]
    random.shuffle(non_gold)
    all_samples = list(gold) + non_gold

    # Write JSONL output
    with open(OUTPUT, "w", encoding="utf-8") as f:
        for sample in all_samples:
            f.write(json.dumps(sample, ensure_ascii=False) + "\n")

    print(f"\n[augment_v5] Done! {len(all_samples)} samples -> {OUTPUT}")
    print(f"  Gold (original): {len(gold)}")
    print(f"  Augmented: {len(all_samples) - len(gold)}")

    # Quick format validation
    valid = 0
    for s in all_samples:
        asst = s["messages"][2]["content"]
        if re.search(r"[A-C]\)\s*[A-Z]", asst):
            valid += 1
    pct = round(valid * 100 / len(all_samples), 1)
    print(f"  Format compliance: {valid}/{len(all_samples)} ({pct}%)")


if __name__ == "__main__":
    main()

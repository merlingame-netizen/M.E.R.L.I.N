#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Extract gold training examples from reference document.
Generates gold_verbs_v5.jsonl in ChatML format for LoRA fine-tuning.

Input: C:/Users/PGNK2128/Downloads/ref_doc_text.txt (20 cards from LLM test run)
Output: c:/Users/PGNK2128/Godot-MCP/data/ai/training/gold_verbs_v5.jsonl
"""

import re
import json
from pathlib import Path
from typing import List, Dict, Tuple

# Paths
INPUT_FILE = Path("C:/Users/PGNK2128/Downloads/ref_doc_text.txt")
OUTPUT_FILE = Path("c:/Users/PGNK2128/Godot-MCP/data/ai/training/gold_verbs_v5.jsonl")

# System prompt variations
SYSTEM_PROMPTS = [
    # Full format (60% of cards)
    """Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Tu contes au present, a la deuxieme personne (tu). FORMAT: 4-6 phrases sensorielles puis EXACTEMENT 3 choix:
A) VERBE — Description d'action en 1 phrase
B) VERBE — Description d'action en 1 phrase
C) VERBE — Description d'action en 1 phrase""",

    # Shortened format (30% of cards)
    """Tu es Merlin l'Enchanteur. FORMAT: VERBE — description concrete.""",

    # With urgency tag (10% of cards, when balance < 50)
    """Tu es Merlin l'Enchanteur, druide ancestral de Broceliande. Tu contes au present, a la deuxieme personne (tu). URGENCE: L'equilibre vacille. FORMAT: 4-6 phrases sensorielles puis EXACTEMENT 3 choix:
A) VERBE — Description d'action en 1 phrase
B) VERBE — Description d'action en 1 phrase
C) VERBE — Description d'action en 1 phrase"""
]

# Verb action descriptions mapping (default fallbacks)
VERB_ACTION_DEFAULTS = {
    "ECOUTER": "Tu tends l'oreille vers les bruits de la foret, cherchant un indice dans le silence.",
    "PISTER": "Tu cherches des traces au sol, suivant la logique des empreintes.",
    "PRIER": "Tu invoques les forces anciennes, esperant qu'elles te guident.",
    "SUIVRE": "Tu suis la piste visible, patient et methodique.",
    "MARQUER": "Tu graves un signe sur l'ecorce pour ne pas perdre le chemin.",
    "FORCER": "Tu passes en force, quitte a dechirer les branches.",
    "POURCHASSER": "Tu te lances a la poursuite, pariant sur la vitesse.",
    "APPELER": "Tu appelles a voix haute, esperant une reponse.",
    "SE CACHER": "Tu te dissimules dans l'ombre, attendant le bon moment.",
    "RECUEILLIR": "Tu ramasses l'objet avec soin, comme une relique.",
    "COUPER": "Tu tranches net ce qui te barre la route.",
    "IGNORER": "Tu passes sans t'arreter, refusant la distraction.",
    "APPROCHER": "Tu avances prudemment vers l'inconnu.",
    "CONTOURNER": "Tu evites l'obstacle en prenant un autre chemin.",
    "ECLAIRER": "Tu leves ta lumiere pour percer les tenebres.",
    "COMBATTRE": "Tu te prepares a affronter la menace de front.",
    "APAISER": "Tu tentes de calmer la creature par des gestes doux.",
    "FUIR": "Tu t'enfuis rapidement, choisissant la survie.",
    "DESARMER": "Tu defais le piege avec precision.",
    "DECHIFFRER": "Tu lis les runes, cherchant leur signification.",
    "TRAVERSER": "Tu traverses l'obstacle sans hesiter.",
    "OBSERVER": "Tu observes attentivement avant d'agir.",
    "TOUCHER": "Tu poses la main, acceptant le contact.",
    "QUESTIONNER": "Tu poses des questions directes, exigeant la verite.",
    "MENACER": "Tu uses de menaces pour obtenir ce que tu veux.",
    "MARCHANDER": "Tu negocies, echangeant quelque chose de valeur.",
    "REVENIR": "Tu rebrousses chemin, refusant d'avancer.",
    "CAMPER": "Tu t'installes pour la nuit, reprenant des forces.",
    "S'ENGOUFFRER": "Tu te precipites dans l'ouverture sans reflexion.",
    "MEDITER": "Tu fermes les yeux et cherches la reponse en toi.",
    "DORMIR": "Tu t'abandonnes au sommeil, esperant que demain sera meilleur.",
    "DOUTER": "Tu laisses le doute t'envahir, questionnant tes choix.",
    "FERMER": "Tu fermes tes sens au monde exterieur.",
    "AVANCER": "Tu avances resolument, pas apres pas.",
    "RESISTER": "Tu resistes a la pression, tenant bon.",
    "AFFRONTER": "Tu affrontes la menace sans ciller.",
    "EXPLORER": "Tu explores les environs methodiquement.",
    "ESCALADER": "Tu grimpes pour obtenir un meilleur point de vue.",
    "BOIRE": "Tu bois l'eau offerte, acceptant le risque.",
    "SE TAIRE": "Tu restes silencieux, gardant tes pensees pour toi.",
    "NEGOCIER": "Tu proposes un accord, cherchant un terrain d'entente.",
    "POURSUIVRE": "Tu continues ton chemin sans te retourner.",
    "SE REPOSER": "Tu prends un moment de repos, recuperant tes forces.",
    "SCELLER": "Tu scelles le passage derriere toi.",
    "RECONSTITUER": "Tu rassembles les pieces du puzzle mental.",
    "ACCUSER": "Tu pointes du doigt le coupable.",
    "RASSURER": "Tu parles doucement pour calmer la peur.",
    "SAISIR": "Tu saisis fermement ce qui est devant toi.",
    "PROTEGER": "Tu te places en bouclier contre le danger.",
    "SORTIR": "Tu te diriges vers la sortie sans regarder en arriere.",
    "BRISER": "Tu brises ce qui te retient.",
    "JURER": "Tu fais un serment solennel."
}


def extract_cards(text: str) -> List[Dict]:
    """Extract all 20 cards from the reference document."""
    cards = []

    # Split by card numbers
    # Cards are between "╠══ ACTE I" and end of document
    lines = text.split('\n')

    current_card = None
    narrative = None
    verbs = None
    action = None
    balance = None
    dc_offset = None

    for i, line in enumerate(lines):
        # Clean line (remove line number prefix if present: "123| " or "123→456| ")
        clean_line = re.sub(r'^\s*\d+(?:→\d+)?\|\s*', '', line)

        # Match card header: "Carte N  [STATE bal=XX]  DC±X  XXs"
        # Note: ± may be mangled as � in some encodings, so match both
        card_match = re.match(r'Carte (\d+)\s+\[(\w+)\s+bal=(\d+)\]\s+DC[±�\-+]?(-?\d+)', clean_line)
        if card_match:
            # Save previous card if exists
            if current_card and narrative and verbs:
                cards.append({
                    'number': current_card,
                    'narrative': narrative,
                    'verbs': verbs,
                    'action': action,
                    'balance': balance,
                    'dc_offset': dc_offset
                })

            current_card = int(card_match.group(1))
            balance = int(card_match.group(3))
            dc_offset = card_match.group(4)
            narrative = None
            verbs = None
            action = None

            # Next line should be the narrative (quoted text)
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                clean_next = re.sub(r'^\s*\d+(?:→\d+)?\|\s*', '', next_line)
                narrative_match = re.match(r'"(.+)"', clean_next)
                if narrative_match:
                    narrative = narrative_match.group(1)

        # Match verbs line: "Verbes: VERB1 | VERB2 | VERB3"
        verbs_match = re.match(r'Verbes:\s+(.+)', clean_line)
        if verbs_match and current_card:
            verb_list = [v.strip() for v in verbs_match.group(1).split('|')]
            verbs = verb_list

        # Match action line: "Action entreprise: VERB - description..."
        action_match = re.match(r'Action entreprise:\s+(\w+)\s+-\s+(.+)', clean_line)
        if action_match and current_card:
            verb = action_match.group(1)
            desc = action_match.group(2)
            action = {'verb': verb, 'description': desc}

    # Don't forget the last card
    if current_card and narrative and verbs:
        cards.append({
            'number': current_card,
            'narrative': narrative,
            'verbs': verbs,
            'action': action,
            'balance': balance,
            'dc_offset': dc_offset
        })

    return cards


def generate_action_description(verb: str, narrative: str, actual_action: Dict = None) -> str:
    """Generate or retrieve action description for a verb."""
    if actual_action and actual_action['verb'] == verb:
        return actual_action['description']

    # Use default if available
    if verb in VERB_ACTION_DEFAULTS:
        return VERB_ACTION_DEFAULTS[verb]

    # Generate a simple fallback
    return f"Tu {verb.lower()} avec determination."


def select_system_prompt(card_number: int, balance: int) -> str:
    """Select appropriate system prompt based on card and balance."""
    if balance < 50:
        # Urgency prompt (10%)
        return SYSTEM_PROMPTS[2]
    elif card_number % 3 == 0:
        # Shortened format (30%)
        return SYSTEM_PROMPTS[1]
    else:
        # Full format (60%)
        return SYSTEM_PROMPTS[0]


def card_to_chatmml(card: Dict) -> Dict:
    """Convert card to ChatML format."""
    number = card['number']
    balance = card['balance']
    narrative = card['narrative']
    verbs = card['verbs']
    action = card['action']

    # Determine theme based on narrative content
    theme_keywords = {
        'foret': 'exploration',
        'gardien': 'confrontation',
        'pierre': 'mystere',
        'serment': 'pacte',
        'enfant': 'sauvetage',
        'ogham': 'magie'
    }
    theme = 'exploration'  # default
    narrative_lower = narrative.lower()
    for keyword, t in theme_keywords.items():
        if keyword in narrative_lower:
            theme = t
            break

    # Balance state
    if balance >= 75:
        balance_state = "Equilibre stable"
    elif balance >= 50:
        balance_state = "Equilibre fragile"
    else:
        balance_state = "Equilibre critique"

    # Select system prompt
    system_prompt = select_system_prompt(number, balance)

    # User prompt
    user_prompt = f"Carte {number}. Lieu: foret_broceliande. Theme: {theme}. {balance_state}."

    # Assistant response: narrative + 3 choices
    choices = []
    for i, verb in enumerate(verbs):
        letter = chr(65 + i)  # A, B, C
        desc = generate_action_description(verb, narrative, action if i == 1 else None)
        choices.append(f"{letter}) {verb} — {desc}")

    assistant_response = narrative + "\n" + "\n".join(choices)

    return {
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
            {"role": "assistant", "content": assistant_response}
        ]
    }


def main():
    print("=" * 80)
    print("Extract Gold Examples from Reference Document")
    print("=" * 80)

    # Read input
    print(f"\n[1/4] Reading input: {INPUT_FILE}")
    if not INPUT_FILE.exists():
        print(f"ERROR: Input file not found: {INPUT_FILE}")
        return 1

    text = INPUT_FILE.read_text(encoding='utf-8')
    print(f"  - Loaded {len(text)} characters")

    # Extract cards
    print(f"\n[2/4] Extracting cards from document...")
    cards = extract_cards(text)
    print(f"  - Extracted {len(cards)} cards")

    if len(cards) == 0:
        print("ERROR: No cards found in document")
        return 1

    # Convert to ChatML
    print(f"\n[3/4] Converting to ChatML format...")
    chatmml_examples = []
    for card in cards:
        try:
            example = card_to_chatmml(card)
            chatmml_examples.append(example)
            print(f"  - Card {card['number']:2d}: {len(card['narrative'])} chars, {len(card['verbs'])} verbs")
        except Exception as e:
            print(f"  - ERROR Card {card.get('number', '?')}: {e}")

    # Write output
    print(f"\n[4/4] Writing output: {OUTPUT_FILE}")
    OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)

    with OUTPUT_FILE.open('w', encoding='utf-8') as f:
        for example in chatmml_examples:
            f.write(json.dumps(example, ensure_ascii=False) + '\n')

    print(f"  - Wrote {len(chatmml_examples)} examples to {OUTPUT_FILE}")

    # Summary statistics
    print("\n" + "=" * 80)
    print("Summary Statistics")
    print("=" * 80)
    print(f"Total cards extracted: {len(cards)}")
    print(f"Total ChatML examples: {len(chatmml_examples)}")

    # Analyze verb distribution
    all_verbs = []
    for card in cards:
        all_verbs.extend(card['verbs'])
    unique_verbs = set(all_verbs)
    print(f"Unique verbs: {len(unique_verbs)}")
    print(f"Total verb instances: {len(all_verbs)}")

    # System prompt distribution
    prompt_counts = {'full': 0, 'short': 0, 'urgent': 0}
    for card in cards:
        prompt = select_system_prompt(card['number'], card['balance'])
        if 'URGENCE' in prompt:
            prompt_counts['urgent'] += 1
        elif len(prompt) < 100:
            prompt_counts['short'] += 1
        else:
            prompt_counts['full'] += 1

    print(f"\nSystem prompt distribution:")
    print(f"  - Full format:  {prompt_counts['full']:2d} ({prompt_counts['full']/len(cards)*100:.0f}%)")
    print(f"  - Short format: {prompt_counts['short']:2d} ({prompt_counts['short']/len(cards)*100:.0f}%)")
    print(f"  - Urgent:       {prompt_counts['urgent']:2d} ({prompt_counts['urgent']/len(cards)*100:.0f}%)")

    # Balance distribution
    balance_ranges = {'stable': 0, 'fragile': 0, 'critical': 0}
    for card in cards:
        if card['balance'] >= 75:
            balance_ranges['stable'] += 1
        elif card['balance'] >= 50:
            balance_ranges['fragile'] += 1
        else:
            balance_ranges['critical'] += 1

    print(f"\nBalance distribution:")
    print(f"  - Stable (>=75):   {balance_ranges['stable']:2d}")
    print(f"  - Fragile (50-74): {balance_ranges['fragile']:2d}")
    print(f"  - Critical (<50):  {balance_ranges['critical']:2d}")

    print("\n" + "=" * 80)
    print(f"SUCCESS: Gold examples written to {OUTPUT_FILE}")
    print("=" * 80)

    return 0


if __name__ == "__main__":
    exit(main())

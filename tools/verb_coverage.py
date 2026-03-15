"""Verb coverage analyzer — checks verb usage across all card JSON files.

Compares verbs used in data/cards/*.json against the 45 approved verbs
defined in merlin_constants.gd (ACTION_VERBS), grouped by lexical field.

Usage: python tools/verb_coverage.py
"""

import json
import re
from collections import Counter
from pathlib import Path

# ── Approved verbs by lexical field (from merlin_constants.gd ACTION_VERBS) ──

ACTION_VERBS = {
    "chance": ["cueillir", "chercher au hasard", "tenter sa chance", "deviner", "fouiller a l'aveugle"],
    "bluff": ["marchander", "convaincre", "mentir", "negocier", "charmer", "amadouer"],
    "observation": ["observer", "scruter", "memoriser", "examiner", "fixer", "inspecter"],
    "logique": ["dechiffrer", "analyser", "resoudre", "decoder", "interpreter", "etudier"],
    "finesse": ["se faufiler", "esquiver", "contourner", "se cacher", "escalader", "traverser"],
    "vigueur": ["combattre", "courir", "fuir", "forcer", "pousser", "resister physiquement"],
    "esprit": ["calmer", "apaiser", "mediter", "resister mentalement", "se concentrer", "endurer",
               "parler", "accepter", "refuser", "attendre", "s'approcher"],
    "perception": ["ecouter", "suivre", "pister", "sentir", "flairer", "tendre l'oreille"],
}

# Build reverse map: verb -> lexical field
VERB_TO_FIELD = {}
for field, verbs in ACTION_VERBS.items():
    for v in verbs:
        VERB_TO_FIELD[v] = field

ALL_APPROVED = set(VERB_TO_FIELD.keys())


def extract_verbs_from_card(card: dict) -> list[str]:
    """Extract verb values from a card's options."""
    verbs = []
    for option in card.get("options", []):
        verb = option.get("verb", "")
        if verb:
            verbs.append(verb)
    return verbs


def load_all_cards(cards_dir: Path) -> tuple[list[str], int, int]:
    """Load all cards from JSON files, return (verbs_list, card_count, file_count)."""
    all_verbs = []
    card_count = 0
    file_count = 0

    for json_file in sorted(cards_dir.glob("*.json")):
        try:
            data = json.loads(json_file.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            print(f"  WARN: skipping {json_file.name}: {e}")
            continue

        file_count += 1
        cards = []

        # Handle different JSON structures
        if isinstance(data, list):
            cards = [item for item in data if isinstance(item, dict) and "options" in item]
        elif isinstance(data, dict):
            # Cards may be nested under a key (e.g. "faction_cards", "cards")
            for key, val in data.items():
                if isinstance(val, list):
                    cards.extend(item for item in val if isinstance(item, dict) and "options" in item)
            # Or the dict itself is a card
            if "options" in data:
                cards.append(data)

        for card in cards:
            card_count += 1
            all_verbs.extend(extract_verbs_from_card(card))

    return all_verbs, card_count, file_count


def main():
    project_root = Path(__file__).resolve().parent.parent
    cards_dir = project_root / "data" / "cards"

    if not cards_dir.is_dir():
        print(f"ERROR: cards directory not found: {cards_dir}")
        return

    print(f"Scanning {cards_dir} ...\n")
    verb_list, card_count, file_count = load_all_cards(cards_dir)
    verb_counts = Counter(verb_list)

    print(f"Files: {file_count} | Cards: {card_count} | Verb occurrences: {len(verb_list)}")
    print(f"Approved verbs: {len(ALL_APPROVED)} across {len(ACTION_VERBS)} lexical fields\n")

    # ── Unknown verbs (not in approved list) ──
    used_verbs = set(verb_counts.keys())
    unknown = used_verbs - ALL_APPROVED
    if unknown:
        print(f"UNKNOWN verbs ({len(unknown)}) — used in cards but not approved:")
        for v in sorted(unknown):
            print(f"  - {v!r} (x{verb_counts[v]})")
        print()

    # ── Unused verbs (approved but never used) ──
    unused = ALL_APPROVED - used_verbs
    if unused:
        print(f"UNUSED verbs ({len(unused)}) — approved but never in cards:")
        for v in sorted(unused):
            print(f"  - {v!r}  [{VERB_TO_FIELD[v]}]")
        print()

    # ── Top 10 most used ──
    print("TOP 10 most-used verbs:")
    for verb, count in verb_counts.most_common(10):
        field = VERB_TO_FIELD.get(verb, "???")
        print(f"  {count:4d}x  {verb:<25s}  [{field}]")
    print()

    # ── 10 least used (among those actually used) ──
    least = verb_counts.most_common()[-10:]
    least.reverse()
    print("10 least-used verbs (among used):")
    for verb, count in least:
        field = VERB_TO_FIELD.get(verb, "???")
        print(f"  {count:4d}x  {verb:<25s}  [{field}]")
    print()

    # ── Lexical field distribution ──
    field_counts = Counter()
    for verb, count in verb_counts.items():
        field = VERB_TO_FIELD.get(verb, "unknown")
        field_counts[field] += count

    total = sum(field_counts.values()) or 1
    print("Lexical field distribution:")
    for field in list(ACTION_VERBS.keys()) + (["unknown"] if "unknown" in field_counts else []):
        count = field_counts.get(field, 0)
        pct = count * 100.0 / total
        bar = "#" * int(pct / 2)
        approved_count = len(ACTION_VERBS.get(field, []))
        used_count = sum(1 for v in ACTION_VERBS.get(field, []) if v in used_verbs)
        print(f"  {field:<12s}  {count:4d} ({pct:5.1f}%)  {bar:<30s}  verbs: {used_count}/{approved_count}")

    # ── Summary ──
    coverage = len(used_verbs & ALL_APPROVED)
    print(f"\nCoverage: {coverage}/{len(ALL_APPROVED)} approved verbs used ({coverage*100//len(ALL_APPROVED)}%)")
    if unknown:
        print(f"Action needed: {len(unknown)} unknown verb(s) should be added to ACTION_VERBS or replaced.")
    if unused:
        print(f"Action needed: {len(unused)} approved verb(s) never appear in any card.")


if __name__ == "__main__":
    main()

"""verb_fixer.py — Fix unknown verbs in card JSON files.

Checks option verbs against the approved ACTION_VERBS list from
merlin_constants.gd and maps unknown verbs to their closest match.

Usage:
    python tools/verb_fixer.py            # dry-run (report only)
    python tools/verb_fixer.py --apply    # write changes to files
"""

import argparse
import json
import unicodedata
from pathlib import Path

# ── Approved verbs (from merlin_constants.gd ACTION_VERBS) ──────────────────

ACTION_VERBS: dict[str, list[str]] = {
    "chance": ["cueillir", "chercher au hasard", "tenter sa chance", "deviner", "fouiller a l'aveugle"],
    "bluff": ["marchander", "convaincre", "mentir", "negocier", "charmer", "amadouer"],
    "observation": ["observer", "scruter", "memoriser", "examiner", "fixer", "inspecter"],
    "logique": ["dechiffrer", "analyser", "resoudre", "decoder", "interpreter", "etudier"],
    "finesse": ["se faufiler", "esquiver", "contourner", "se cacher", "escalader", "traverser"],
    "vigueur": ["combattre", "courir", "fuir", "forcer", "pousser", "resister physiquement"],
    "esprit": [
        "calmer", "apaiser", "mediter", "resister mentalement", "se concentrer", "endurer",
        "parler", "accepter", "refuser", "attendre", "s'approcher",
    ],
    "perception": ["ecouter", "suivre", "pister", "sentir", "flairer", "tendre l'oreille"],
}

APPROVED: set[str] = set()
for verbs in ACTION_VERBS.values():
    APPROVED.update(verbs)

# ── Manual mapping for common unknown verbs ─────────────────────────────────

MANUAL_MAP: dict[str, str] = {
    "decouvrir": "explorer",  # no approved "explorer" — will fall through
    "découvrir": "observer",
    "contempler": "observer",
    "prier": "mediter",
    "guerir": "apaiser",
    "guérir": "apaiser",
    "explorer": "scruter",
    "combattre a mains nues": "combattre",
    "se battre": "combattre",
    "lutter": "combattre",
    "soigner": "apaiser",
    "invoquer": "se concentrer",
    "supplier": "convaincre",
    "implorer": "convaincre",
    "negocier un passage": "negocier",
    "chanter": "apaiser",
    "reciter": "dechiffrer",
    "lire": "dechiffrer",
    "toucher": "examiner",
    "ramasser": "cueillir",
    "collecter": "cueillir",
    "regarder": "observer",
    "voir": "observer",
    "fuir en courant": "fuir",
    "courir vite": "courir",
    "foncer": "courir",
    "grimper": "escalader",
    "sauter": "esquiver",
    "plonger": "se faufiler",
    "ecouter attentivement": "ecouter",
    "renifler": "flairer",
    "humer": "flairer",
    "deviner la reponse": "deviner",
}


def strip_accents(text: str) -> str:
    """Remove diacritics for fuzzy matching."""
    nfkd = unicodedata.normalize("NFKD", text)
    return "".join(c for c in nfkd if not unicodedata.combining(c))


def find_closest(verb: str) -> str:
    """Find the closest approved verb via manual map, prefix, or containment."""
    normalized = strip_accents(verb.lower().strip())

    # 1. Manual mapping (original then normalized)
    for candidate in (verb.lower().strip(), normalized):
        if candidate in MANUAL_MAP:
            target = MANUAL_MAP[candidate]
            if target in APPROVED:
                return target
            # Manual target not in approved — try to find it
            for v in APPROVED:
                if strip_accents(v) == strip_accents(target):
                    return v

    # 2. Accent-stripped exact match
    for v in APPROVED:
        if strip_accents(v) == normalized:
            return v

    # 3. Starts-with (first 3+ chars)
    prefix = normalized[:3]
    for length in (len(normalized), max(len(normalized) - 1, 4), max(len(normalized) - 2, 3), 3):
        sub = normalized[:length]
        for v in sorted(APPROVED):
            if strip_accents(v).startswith(sub):
                return v

    # 4. Contains
    for v in sorted(APPROVED):
        if normalized in strip_accents(v) or strip_accents(v) in normalized:
            return v

    # 5. Fallback to "esprit" field default (per merlin_constants.gd)
    return "accepter"


def _extract_cards(data: object) -> list[dict]:
    """Extract card dicts from either a plain list or a dict with card arrays."""
    if isinstance(data, list):
        return [item for item in data if isinstance(item, dict)]
    if isinstance(data, dict):
        cards: list[dict] = []
        for val in data.values():
            if isinstance(val, list):
                cards.extend(item for item in val if isinstance(item, dict))
        return cards
    return []


def process_card_file(path: Path, apply: bool) -> list[str]:
    """Process a single card JSON file. Returns list of change descriptions."""
    data = json.loads(path.read_text(encoding="utf-8"))
    changes: list[str] = []

    for card in _extract_cards(data):
        card_id = card.get("id", "?")
        options = card.get("options", [])
        for i, opt in enumerate(options):
            if not isinstance(opt, dict):
                continue
            verb = opt.get("verb", "")
            if not verb or verb in APPROVED:
                continue
            replacement = find_closest(verb)
            changes.append(
                f"  {card_id} opt[{i}]: \"{verb}\" -> \"{replacement}\""
            )
            if apply:
                opt["verb"] = replacement

    if apply and changes:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    return changes


def main() -> None:
    parser = argparse.ArgumentParser(description="Fix unknown verbs in card files")
    parser.add_argument("--apply", action="store_true", help="Write changes (default: dry-run)")
    args = parser.parse_args()

    cards_dir = Path(__file__).resolve().parent.parent / "data" / "cards"
    if not cards_dir.is_dir():
        print(f"ERROR: cards directory not found: {cards_dir}")
        return

    files = sorted(cards_dir.glob("*.json"))
    total_changes = 0

    for f in files:
        changes = process_card_file(f, args.apply)
        if changes:
            mode = "FIXED" if args.apply else "WOULD FIX"
            print(f"[{mode}] {f.name} ({len(changes)} verbs):")
            for c in changes:
                print(c)
            total_changes += len(changes)

    if total_changes == 0:
        print("All verbs are approved. Nothing to fix.")
    else:
        verb = "Fixed" if args.apply else "Would fix"
        print(f"\n{verb} {total_changes} verb(s) across {len(files)} file(s).")
        if not args.apply:
            print("Run with --apply to write changes.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Harmonize card biome names to canonical MerlinConstants.BIOMES keys.

Usage:
    python biome_harmonizer.py              # dry-run: report changes
    python biome_harmonizer.py --apply      # rewrite JSON files in place
"""

import argparse
import json
import sys
from pathlib import Path

# Canonical biome keys from scripts/merlin/merlin_constants.gd BIOMES dict
CANONICAL_BIOMES = {
    "foret_broceliande",
    "landes_bruyere",
    "cotes_sauvages",
    "villages_celtes",
    "cercles_pierres",
    "marais_korrigans",
    "collines_dolmens",
    "iles_mystiques",
}

# Old/variant biome names → canonical key
BIOME_MAP = {
    "landes_carnac": "landes_bruyere",
    "marais_yeun": "marais_korrigans",
    "cercle_pierres": "cercles_pierres",
    "monts_arree": "villages_celtes",
    "cotes_armor": "cotes_sauvages",
    "grotte_merlin": "collines_dolmens",
    "ile_avalon": "iles_mystiques",
    # Short/partial names
    "cotes": "cotes_sauvages",
    "landes": "landes_bruyere",
    "marais": "marais_korrigans",
    "foret": "foret_broceliande",
    "iles": "iles_mystiques",
    "villages": "villages_celtes",
    "collines": "collines_dolmens",
    "cercles": "cercles_pierres",
}


def scan_cards(cards_dir: Path) -> dict[Path, list[tuple[int, str, str]]]:
    """Return {filepath: [(card_index, old_biome, new_biome), ...]} for all fixable cards."""
    results: dict[Path, list[tuple[int, str, str]]] = {}

    for json_path in sorted(cards_dir.glob("*.json")):
        with json_path.open("r", encoding="utf-8") as f:
            data = json.load(f)

        cards = data if isinstance(data, list) else data.get("cards", [])
        fixes = []
        for i, card in enumerate(cards):
            biome = card.get("biome", "")
            if biome and biome not in CANONICAL_BIOMES:
                new_biome = BIOME_MAP.get(biome)
                if new_biome:
                    fixes.append((i, biome, new_biome))
                else:
                    print(f"  WARNING: unknown biome '{biome}' in {json_path.name} card {i} — no mapping defined")
        if fixes:
            results[json_path] = fixes

    return results


def apply_fixes(cards_dir: Path, changes: dict[Path, list[tuple[int, str, str]]]) -> None:
    """Rewrite JSON files with corrected biome names."""
    for json_path, fixes in changes.items():
        with json_path.open("r", encoding="utf-8") as f:
            data = json.load(f)

        cards = data if isinstance(data, list) else data.get("cards", [])
        for idx, _old, new in fixes:
            cards[idx]["biome"] = new

        with json_path.open("w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")

        print(f"  WROTE {json_path.name} ({len(fixes)} fix(es))")


def main() -> None:
    parser = argparse.ArgumentParser(description="Harmonize card biome names to canonical constants.")
    parser.add_argument("--apply", action="store_true", help="Rewrite JSON files (default: dry-run)")
    parser.add_argument("--cards-dir", type=Path, default=None, help="Path to cards directory")
    args = parser.parse_args()

    cards_dir = args.cards_dir or Path(__file__).resolve().parent.parent / "data" / "cards"
    if not cards_dir.is_dir():
        print(f"ERROR: cards directory not found: {cards_dir}")
        sys.exit(1)

    print(f"Scanning {cards_dir} ...")
    print(f"Canonical biomes: {sorted(CANONICAL_BIOMES)}")
    print(f"Known mappings: {BIOME_MAP}\n")

    changes = scan_cards(cards_dir)

    if not changes:
        print("No biome fixes needed — all cards use canonical names.")
        return

    total = sum(len(fixes) for fixes in changes.values())
    print(f"Found {total} card(s) to fix across {len(changes)} file(s):\n")
    for json_path, fixes in changes.items():
        print(f"  {json_path.name}:")
        for idx, old, new in fixes:
            print(f"    card[{idx}]: {old} -> {new}")
    print()

    if args.apply:
        print("Applying fixes ...")
        apply_fixes(cards_dir, changes)
        print(f"\nDone. {total} card(s) updated.")
    else:
        print("Dry run — no files modified. Use --apply to write changes.")


if __name__ == "__main__":
    main()

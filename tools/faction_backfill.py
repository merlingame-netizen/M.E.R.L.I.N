#!/usr/bin/env python3
"""Backfill missing/unknown factions and trust_tier on card JSON files.

Usage:
    python tools/faction_backfill.py          # dry-run (report only)
    python tools/faction_backfill.py --apply  # rewrite JSON files
"""

import argparse
import json
from pathlib import Path

CARDS_DIR = Path(__file__).resolve().parent.parent / "data" / "cards"

FACTIONS = {"druides", "anciens", "korrigans", "niamh", "ankou"}

BIOME_FACTION = {
    "foret_broceliande": "druides",
    "landes_carnac": "korrigans",
    "cotes_armor": "niamh",
    "marais_yeun": "korrigans",
    "monts_arree": "anciens",
    "ile_avalon": "niamh",
    "grotte_merlin": "druides",
    "cercle_pierres": "anciens",
    "cercles_pierres": "anciens",
    "landes_bruyere": "korrigans",
}


def _faction_field(card: dict) -> str:
    """Return the key used for faction in this card ('faction_primaire' or 'faction')."""
    if "faction_primaire" in card:
        return "faction_primaire"
    return "faction"


def _is_unknown(card: dict) -> bool:
    field = _faction_field(card)
    val = card.get(field, "")
    return val in ("unknown", "", None)


def _infer_from_effects(card: dict) -> str | None:
    """Priority 1: most-repeated ADD_REPUTATION faction across all options."""
    counts: dict[str, int] = {}
    for opt in card.get("options", []):
        for eff in opt.get("effects", []):
            if eff.get("type") == "ADD_REPUTATION":
                fac = eff.get("faction", "")
                amt = eff.get("amount") or eff.get("value") or 0
                if fac in FACTIONS and amt > 0:
                    counts[fac] = counts.get(fac, 0) + amt
    if counts:
        return max(counts, key=counts.get)
    return None


def _infer_from_tags(card: dict) -> str | None:
    """Priority 2: first faction name found in tags."""
    for tag in card.get("tags", []):
        tag_lower = tag.lower()
        for fac in FACTIONS:
            if fac in tag_lower:
                return fac
    return None


def _infer_from_biome(card: dict) -> str | None:
    """Priority 3: biome→faction affinity mapping."""
    biome = card.get("biome", "")
    return BIOME_FACTION.get(biome)


def infer_faction(card: dict) -> str | None:
    """Infer faction: effects > tags > biome."""
    return (
        _infer_from_effects(card)
        or _infer_from_tags(card)
        or _infer_from_biome(card)
    )


def _extract_cards(data):
    """Return (cards_list, wrapper_key_or_None)."""
    if isinstance(data, list):
        return data, None
    for key in ("faction_cards", "cards"):
        if key in data and isinstance(data[key], list):
            return data[key], key
    return [], None


def process_file(path: Path, apply: bool) -> dict:
    """Process one JSON file. Returns stats dict."""
    raw = path.read_text(encoding="utf-8")
    data = json.loads(raw)
    cards, wrapper_key = _extract_cards(data)

    stats = {"file": path.name, "total": 0, "faction_fixed": 0, "trust_fixed": 0, "unresolved": 0}
    changed = False

    for card in cards:
        if not isinstance(card, dict) or "id" not in card:
            continue
        stats["total"] += 1
        card_id = card["id"]

        # --- Faction backfill ---
        if _is_unknown(card):
            faction = infer_faction(card)
            field = _faction_field(card)
            if faction:
                print(f"  {card_id}: {field} '{card.get(field)}' -> '{faction}'")
                card[field] = faction
                stats["faction_fixed"] += 1
                changed = True
            else:
                print(f"  {card_id}: UNRESOLVED (no signal)")
                stats["unresolved"] += 1

        # --- Trust tier backfill ---
        if "trust_tier" not in card:
            card["trust_tier"] = "T0"
            stats["trust_fixed"] += 1
            changed = True

    if changed and apply:
        out = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
        path.write_text(out, encoding="utf-8")
        print(f"  -> WRITTEN {path.name}")

    return stats


def main():
    parser = argparse.ArgumentParser(description="Backfill card factions & trust_tier")
    parser.add_argument("--apply", action="store_true", help="Rewrite JSON files (default: dry-run)")
    args = parser.parse_args()

    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"=== Faction Backfill ({mode}) ===\n")

    files = sorted(CARDS_DIR.glob("*.json"))
    if not files:
        print(f"No JSON files found in {CARDS_DIR}")
        return

    totals = {"total": 0, "faction_fixed": 0, "trust_fixed": 0, "unresolved": 0}
    for path in files:
        print(f"[{path.name}]")
        stats = process_file(path, args.apply)
        for k in totals:
            totals[k] += stats.get(k, 0)

    print(f"\n=== Summary ===")
    print(f"Cards scanned:    {totals['total']}")
    print(f"Factions fixed:   {totals['faction_fixed']}")
    print(f"Trust tier added: {totals['trust_fixed']}")
    print(f"Unresolved:       {totals['unresolved']}")
    if not args.apply and (totals["faction_fixed"] or totals["trust_fixed"]):
        print("\nRe-run with --apply to write changes.")


if __name__ == "__main__":
    main()

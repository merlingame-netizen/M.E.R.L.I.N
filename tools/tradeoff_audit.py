"""Cross-faction trade-off audit for M.E.R.L.I.N. card pool.

Checks that ~10% of cards have cross-faction trade-offs (helping one faction
hurts another). Scans all fastroute_sprint*.json card files.

Usage: python tools/tradeoff_audit.py
"""

import json
import sys
from collections import defaultdict
from itertools import combinations
from pathlib import Path

CARDS_DIR = Path(__file__).resolve().parent.parent / "data" / "cards"
TARGET_PCT = 10.0
FACTIONS = ["druides", "niamh", "korrigans", "ankou", "anciens"]


def load_all_cards() -> list[dict]:
    """Load cards from all fastroute_sprint*.json files."""
    cards = []
    for path in sorted(CARDS_DIR.glob("fastroute_sprint*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, list):
                cards.extend(data)
        except (json.JSONDecodeError, OSError) as e:
            print(f"WARNING: failed to load {path.name}: {e}", file=sys.stderr)
    return cards


def get_rep_effects(option: dict) -> list[tuple[str, int]]:
    """Extract (faction, amount) pairs from an option's effects."""
    return [
        (e["faction"], e["amount"])
        for e in option.get("effects", [])
        if e.get("type") == "ADD_REPUTATION" and "faction" in e and "amount" in e
    ]


def find_intra_option_pairs(option: dict) -> set[tuple[str, str]]:
    """Find faction pairs where one goes up and another down in same option."""
    effects = get_rep_effects(option)
    ups = {f for f, a in effects if a > 0}
    downs = {f for f, a in effects if a < 0}
    pairs = set()
    for u in ups:
        for d in downs:
            if u != d:
                pairs.add((min(u, d), max(u, d)))
    return pairs


def find_cross_option_pairs(options: list[dict]) -> set[tuple[str, str]]:
    """Find faction pairs favored by different options across the card."""
    option_top_factions = []
    for opt in options:
        effects = get_rep_effects(opt)
        if not effects:
            continue
        best = max(effects, key=lambda x: x[1])
        if best[1] > 0:
            option_top_factions.append(best[0])

    pairs = set()
    unique = set(option_top_factions)
    if len(unique) >= 2:
        for a, b in combinations(unique, 2):
            pairs.add((min(a, b), max(a, b)))
    return pairs


def analyze_card(card: dict) -> set[tuple[str, str]]:
    """Return trade-off faction pairs for a card (empty if none)."""
    options = card.get("options", [])
    pairs = set()
    for opt in options:
        pairs |= find_intra_option_pairs(opt)
    pairs |= find_cross_option_pairs(options)
    return pairs


def main() -> None:
    cards = load_all_cards()
    if not cards:
        print("ERROR: no cards found in", CARDS_DIR)
        sys.exit(1)

    total = len(cards)
    tradeoff_cards = []
    pair_counts: dict[tuple[str, str], int] = defaultdict(int)

    for card in cards:
        pairs = analyze_card(card)
        if pairs:
            tradeoff_cards.append((card.get("id", "?"), pairs))
            for p in pairs:
                pair_counts[p] += 1

    tradeoff_count = len(tradeoff_cards)
    pct = (tradeoff_count / total * 100) if total else 0.0

    # Summary
    print("=" * 60)
    print("CROSS-FACTION TRADE-OFF AUDIT")
    print("=" * 60)
    print(f"Total cards:      {total}")
    print(f"Trade-off cards:  {tradeoff_count}")
    print(f"Coverage:         {pct:.1f}%")
    print(f"Target:           {TARGET_PCT:.0f}%")
    status = "OK" if pct >= TARGET_PCT else "BELOW TARGET"
    print(f"Status:           {status}")

    # Pair breakdown
    print()
    print("FACTION PAIR COVERAGE")
    print("-" * 40)
    all_pairs = list(combinations(sorted(FACTIONS), 2))
    covered = set(pair_counts.keys())
    for pair in sorted(all_pairs, key=lambda p: pair_counts.get(p, 0), reverse=True):
        count = pair_counts.get(pair, 0)
        bar = "#" * min(count, 30)
        print(f"  {pair[0]:>10} <-> {pair[1]:<10} {count:3d}  {bar}")

    # Underrepresented pairs
    missing = [p for p in all_pairs if p not in covered]
    low = [p for p in all_pairs if 0 < pair_counts.get(p, 0) <= 2]

    if missing or low:
        print()
        print("UNDERREPRESENTED PAIRS")
        print("-" * 40)
        for p in missing:
            print(f"  {p[0]} <-> {p[1]}: NONE")
        for p in low:
            print(f"  {p[0]} <-> {p[1]}: only {pair_counts[p]}")

    # Gap to target
    if pct < TARGET_PCT:
        needed = max(0, int(total * TARGET_PCT / 100) - tradeoff_count)
        print()
        print(f"Need ~{needed} more trade-off cards to reach {TARGET_PCT:.0f}% target.")

    print()


if __name__ == "__main__":
    main()

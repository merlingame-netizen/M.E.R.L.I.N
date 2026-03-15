"""Analyze card difficulty curves across the card pool.

Loads all cards from data/cards/*.json and computes per-card net impact
(benefit vs cost) to verify balanced difficulty progression.

Usage: python tools/difficulty_curve.py
"""

from pathlib import Path
import json
from collections import defaultdict

CARDS_DIR = Path(__file__).resolve().parent.parent / "data" / "cards"

OUTLIER_HIGH = 30
OUTLIER_LOW = -20


def load_all_cards() -> list[dict]:
    """Load cards from all JSON files, normalizing both formats."""
    cards = []
    for path in sorted(CARDS_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        if isinstance(data, list):
            raw = data
        elif isinstance(data, dict) and "faction_cards" in data:
            raw = data["faction_cards"]
        else:
            continue
        for card in raw:
            card.setdefault("trust_tier", "unknown")
            if "faction" in card and "faction_primaire" not in card:
                card["faction_primaire"] = card["faction"]
            card["_source"] = path.name
            cards.append(card)
    return cards


def compute_net_impact(card: dict) -> tuple[float, float, float]:
    """Return (benefit, cost, net) for a card averaged across its options."""
    option_nets = []
    for option in card.get("options", []):
        benefit = 0.0
        cost = 0.0
        for eff in option.get("effects", []):
            etype = eff.get("type", "")
            amount = eff.get("amount", 0)
            if etype == "HEAL_LIFE":
                benefit += amount
            elif etype == "DAMAGE_LIFE":
                cost -= amount
            elif etype == "ADD_REPUTATION":
                if amount >= 0:
                    benefit += amount
                else:
                    cost += amount
        option_nets.append((benefit, cost))
    if not option_nets:
        return (0.0, 0.0, 0.0)
    avg_benefit = sum(b for b, _ in option_nets) / len(option_nets)
    avg_cost = sum(c for _, c in option_nets) / len(option_nets)
    return (avg_benefit, avg_cost, avg_benefit + avg_cost)


def ascii_histogram(values: list[float], bins: int = 15, width: int = 50) -> str:
    """Build an ASCII histogram string."""
    if not values:
        return "  (no data)\n"
    lo, hi = min(values), max(values)
    if lo == hi:
        return f"  All values = {lo:.1f}\n"
    step = (hi - lo) / bins
    counts = [0] * bins
    for v in values:
        idx = min(int((v - lo) / step), bins - 1)
        counts[idx] += 1
    max_count = max(counts)
    lines = []
    for i, c in enumerate(counts):
        edge = lo + i * step
        bar_len = int(c / max_count * width) if max_count > 0 else 0
        lines.append(f"  {edge:+7.1f} | {'#' * bar_len} {c}")
    return "\n".join(lines) + "\n"


def main() -> None:
    cards = load_all_cards()
    if not cards:
        print("No cards found in", CARDS_DIR)
        return

    print(f"=== Difficulty Curve Analysis ===")
    print(f"Cards loaded: {len(cards)} from {CARDS_DIR.name}/\n")

    # Per-card net impact
    results = []
    for card in cards:
        benefit, cost, net = compute_net_impact(card)
        results.append({
            "id": card.get("id", "?"),
            "biome": card.get("biome", "unknown"),
            "tier": card.get("trust_tier", "unknown"),
            "benefit": benefit,
            "cost": cost,
            "net": net,
        })

    nets = [r["net"] for r in results]

    # Distribution
    pos = sum(1 for n in nets if n > 0.5)
    neg = sum(1 for n in nets if n < -0.5)
    neutral = len(nets) - pos - neg
    print("--- Distribution ---")
    print(f"  Net-positive (>+0.5):  {pos:4d}  ({100*pos/len(nets):.1f}%)")
    print(f"  Net-neutral:           {neutral:4d}  ({100*neutral/len(nets):.1f}%)")
    print(f"  Net-negative (<-0.5):  {neg:4d}  ({100*neg/len(nets):.1f}%)")
    print()

    # Per-biome average
    biome_impacts = defaultdict(list)
    for r in results:
        biome_impacts[r["biome"]].append(r["net"])

    print("--- Per-Biome Average Net Impact ---")
    for biome in sorted(biome_impacts):
        vals = biome_impacts[biome]
        avg = sum(vals) / len(vals)
        print(f"  {biome:30s}  avg={avg:+6.1f}  (n={len(vals)})")
    print()

    # Per trust-tier average
    tier_impacts = defaultdict(list)
    for r in results:
        tier_impacts[r["tier"]].append(r["net"])

    print("--- Per-Trust-Tier Average Net Impact ---")
    print("  (T0 should be near-neutral, T3 should be more extreme)")
    for tier in sorted(tier_impacts):
        vals = tier_impacts[tier]
        avg = sum(vals) / len(vals)
        mn, mx = min(vals), max(vals)
        print(f"  {tier:10s}  avg={avg:+6.1f}  range=[{mn:+.1f}, {mx:+.1f}]  (n={len(vals)})")
    print()

    # Outliers
    outliers = [r for r in results if r["net"] > OUTLIER_HIGH or r["net"] < OUTLIER_LOW]
    print(f"--- Outlier Cards (net > +{OUTLIER_HIGH} or < {OUTLIER_LOW}) ---")
    if outliers:
        for r in sorted(outliers, key=lambda x: x["net"]):
            tag = "HIGH" if r["net"] > OUTLIER_HIGH else "LOW"
            print(f"  [{tag:4s}] {r['id']:40s}  net={r['net']:+6.1f}  "
                  f"biome={r['biome']}  tier={r['tier']}")
    else:
        print("  None found.")
    print()

    # ASCII histogram
    print("--- Net Impact Histogram ---")
    print(ascii_histogram(nets))

    # Summary
    avg_all = sum(nets) / len(nets)
    print(f"Overall average net impact: {avg_all:+.2f}")
    if avg_all > 5:
        print("  WARNING: Pool skews generous (positive). Consider adding more costs.")
    elif avg_all < -5:
        print("  WARNING: Pool skews punishing (negative). Consider adding more benefits.")
    else:
        print("  Pool balance looks reasonable.")


if __name__ == "__main__":
    main()

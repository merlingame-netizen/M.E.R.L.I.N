#!/usr/bin/env python3
"""Card pool auditor for M.E.R.L.I.N. — analyzes all card JSON files.

Usage: python tools/card_audit.py [--save]
  --save  Write JSON report to docs/audits/card_pool_audit.json
"""

import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CARDS_DIR = ROOT / "data" / "cards"
REPORT_PATH = ROOT / "docs" / "audits" / "card_pool_audit.json"

REQUIRED_FIELDS = {"id", "text", "biome", "options"}
EXPECTED_OPTION_COUNT = 3


def load_all_cards() -> tuple[list[dict], list[Path]]:
    """Load cards from all JSON files in data/cards/."""
    cards: list[dict] = []
    files = sorted(CARDS_DIR.glob("*.json"))
    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            print(f"  WARN: {path.name}: {e}")
            continue

        raw_cards: list[dict] = []
        if isinstance(data, list):
            raw_cards = [c for c in data if isinstance(c, dict) and "id" in c]
        elif isinstance(data, dict):
            for val in data.values():
                if isinstance(val, list):
                    raw_cards.extend(c for c in val if isinstance(c, dict) and "id" in c)

        for card in raw_cards:
            card["_source"] = path.name
        cards.extend(raw_cards)
    return cards, files


def find_duplicate_ids(cards: list[dict]) -> list[dict]:
    seen: dict[str, str] = {}
    dupes: list[dict] = []
    for card in cards:
        cid = card.get("id", "")
        src = card.get("_source", "")
        if cid in seen:
            dupes.append({"id": cid, "files": [seen[cid], src]})
        else:
            seen[cid] = src
    return dupes


def find_duplicate_texts(cards: list[dict]) -> list[dict]:
    seen: dict[str, str] = {}
    dupes: list[dict] = []
    for card in cards:
        text = card.get("text", "").strip()
        if not text:
            continue
        if text in seen:
            dupes.append({"id_a": seen[text], "id_b": card["id"],
                          "text_preview": text[:80]})
        else:
            seen[text] = card.get("id", "?")
    return dupes


def distribution(cards: list[dict], field: str) -> dict[str, int]:
    counter = Counter(card.get(field) or "(missing)" for card in cards)
    return dict(counter.most_common())


def tag_coverage(cards: list[dict]) -> dict[str, int]:
    counter: Counter = Counter()
    for card in cards:
        for tag in card.get("tags", []):
            counter[tag] += 1
    return dict(counter.most_common())


def find_missing_fields(cards: list[dict]) -> list[dict]:
    issues: list[dict] = []
    for card in cards:
        missing = [f for f in REQUIRED_FIELDS if f not in card or not card[f]]
        if missing:
            issues.append({"id": card.get("id", "(no id)"), "missing": missing,
                           "source": card.get("_source", "?")})
    return issues


def find_wrong_option_count(cards: list[dict]) -> list[dict]:
    issues: list[dict] = []
    for card in cards:
        opts = card.get("options", [])
        n = len(opts) if isinstance(opts, list) else 0
        if n != EXPECTED_OPTION_COUNT:
            issues.append({"id": card["id"], "option_count": n,
                           "source": card.get("_source", "?")})
    return issues


def build_report(cards: list[dict], files: list[Path]) -> dict:
    faction_field = "faction"

    return {
        "total_cards": len(cards),
        "source_files": dict(Counter(c["_source"] for c in cards).most_common()),
        "duplicate_ids": find_duplicate_ids(cards),
        "duplicate_texts": find_duplicate_texts(cards),
        "missing_fields": find_missing_fields(cards),
        "wrong_option_count": find_wrong_option_count(cards),
        "distribution_biome": distribution(cards, "biome"),
        "distribution_faction": distribution(cards, faction_field),
        "distribution_trust_tier": distribution(cards, "trust_tier"),
        "distribution_champ_lexical": distribution(cards, "champ_lexical"),
        "tag_coverage": tag_coverage(cards),
        "unique_tags": len(tag_coverage(cards)),
    }


def print_section(title: str, data, *, limit: int = 20) -> None:
    print(f"\n  {title}")
    print(f"  {'-' * len(title)}")
    if isinstance(data, dict):
        for k, v in list(data.items())[:limit]:
            print(f"    {str(k):30s} {v}")
        if len(data) > limit:
            print(f"    ... and {len(data) - limit} more")
    elif isinstance(data, list):
        if not data:
            print("    (none)")
        for item in data[:limit]:
            print(f"    {item}")
        if len(data) > limit:
            print(f"    ... and {len(data) - limit} more")
    else:
        print(f"    {data}")


def print_report(report: dict) -> int:
    print(f"\n{'=' * 60}")
    print(f"  CARD POOL AUDIT -- {report['total_cards']} cards from "
          f"{len(report['source_files'])} files")
    print(f"{'=' * 60}")

    print_section("Source Files", report["source_files"])
    print_section("Duplicate IDs", report["duplicate_ids"])
    print_section("Near-Duplicate Texts", report["duplicate_texts"])
    print_section("Missing Required Fields", report["missing_fields"])
    print_section("Wrong Option Count (expected 3)", report["wrong_option_count"])
    print_section("Distribution: Biome", report["distribution_biome"])
    print_section("Distribution: Faction", report["distribution_faction"])
    print_section("Distribution: Trust Tier", report["distribution_trust_tier"])
    print_section("Distribution: Champ Lexical", report["distribution_champ_lexical"])
    print_section("Tag Coverage", report["tag_coverage"])
    print(f"\n    Unique tags: {report['unique_tags']}")

    issues = (len(report["duplicate_ids"]) + len(report["duplicate_texts"])
              + len(report["missing_fields"]) + len(report["wrong_option_count"]))
    score = max(0, 100 - issues * 2)
    print(f"\n{'=' * 60}")
    print(f"  TOTAL ISSUES: {issues}  |  Quality score: {score}/100")
    print(f"{'=' * 60}\n")
    return score


def main() -> None:
    if not CARDS_DIR.is_dir():
        print(f"ERROR: Card directory not found: {CARDS_DIR}")
        sys.exit(1)

    cards, files = load_all_cards()
    print(f"Loaded {len(cards)} cards from {len(files)} files")
    if not cards:
        print("No cards found.")
        sys.exit(1)

    report = build_report(cards, files)
    score = print_report(report)

    if "--save" in sys.argv:
        REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
        REPORT_PATH.write_text(
            json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(f"Report saved to {REPORT_PATH}")

    sys.exit(0 if score >= 70 else 1)


if __name__ == "__main__":
    main()

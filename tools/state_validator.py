#!/usr/bin/env python3
"""Validate M.E.R.L.I.N. saved game state JSON files.

Usage:
    python tools/state_validator.py profile.json
    python tools/state_validator.py --generate-sample
"""

import argparse
import json
import sys
from pathlib import Path

FACTIONS = ["druides", "anciens", "korrigans", "niamh", "ankou"]
STARTER_OGHAMS = ["beith", "luis", "quert"]
BIOMES = [
    "foret_broceliande", "landes_bruyere", "cotes_sauvages",
    "villages_celtes", "cercles_pierres", "marais_korrigans",
    "collines_dolmens", "iles_mystiques",
]
LIFE_MAX = 100

META_REQUIRED_KEYS = [
    "anam", "total_runs", "faction_rep", "trust_merlin",
    "talent_tree", "oghams", "endings_seen", "arc_tags",
    "biome_runs", "biomes_unlocked", "tutorial_flags", "stats",
]
RUN_STATE_REQUIRED_KEYS = ["biome", "card_index", "life_essence"]


def _result(status: str, field: str, message: str) -> dict:
    return {"status": status, "field": field, "message": message}


def validate_profile(data: dict) -> list[dict]:
    results = []

    # Top-level keys
    for key in ("version", "meta"):
        if key in data:
            results.append(_result("PASS", key, "present"))
        else:
            results.append(_result("FAIL", key, "missing required top-level key"))

    if "timestamp" in data:
        results.append(_result("PASS", "timestamp", f"value={data['timestamp']}"))
    else:
        results.append(_result("WARN", "timestamp", "missing (optional but expected)"))

    meta = data.get("meta")
    if not isinstance(meta, dict):
        results.append(_result("FAIL", "meta", "must be a dictionary"))
        return results

    # Meta required keys
    for key in META_REQUIRED_KEYS:
        if key in meta:
            results.append(_result("PASS", f"meta.{key}", "present"))
        else:
            results.append(_result("FAIL", f"meta.{key}", "missing required key"))

    # anam
    anam = meta.get("anam", None)
    if isinstance(anam, (int, float)):
        if anam >= 0:
            results.append(_result("PASS", "meta.anam", f"value={anam}"))
        else:
            results.append(_result("FAIL", "meta.anam", f"must be >= 0, got {anam}"))
    elif anam is not None:
        results.append(_result("FAIL", "meta.anam", f"must be numeric, got {type(anam).__name__}"))

    # total_runs
    total_runs = meta.get("total_runs", None)
    if isinstance(total_runs, (int, float)):
        if total_runs >= 0:
            results.append(_result("PASS", "meta.total_runs", f"value={total_runs}"))
        else:
            results.append(_result("WARN", "meta.total_runs", f"negative value: {total_runs}"))
    elif total_runs is not None:
        results.append(_result("FAIL", "meta.total_runs", f"must be numeric"))

    # trust_merlin (0-100)
    trust = meta.get("trust_merlin", None)
    if isinstance(trust, (int, float)):
        if 0 <= trust <= 100:
            results.append(_result("PASS", "meta.trust_merlin", f"value={trust}"))
        else:
            results.append(_result("WARN", "meta.trust_merlin", f"out of 0-100 range: {trust}"))
    elif trust is not None:
        results.append(_result("FAIL", "meta.trust_merlin", "must be numeric"))

    # faction_rep
    faction_rep = meta.get("faction_rep", {})
    if isinstance(faction_rep, dict):
        for faction in FACTIONS:
            val = faction_rep.get(faction)
            if val is None:
                results.append(_result("FAIL", f"meta.faction_rep.{faction}", "missing faction"))
            elif not isinstance(val, (int, float)):
                results.append(_result("FAIL", f"meta.faction_rep.{faction}", "must be numeric"))
            elif not (0 <= val <= 100):
                results.append(_result("FAIL", f"meta.faction_rep.{faction}", f"must be 0-100, got {val}"))
            else:
                results.append(_result("PASS", f"meta.faction_rep.{faction}", f"value={val}"))
        extra = set(faction_rep.keys()) - set(FACTIONS)
        if extra:
            results.append(_result("WARN", "meta.faction_rep", f"unexpected factions: {extra}"))
    else:
        results.append(_result("FAIL", "meta.faction_rep", "must be a dictionary"))

    # oghams
    oghams = meta.get("oghams", {})
    if isinstance(oghams, dict):
        owned = oghams.get("owned", [])
        if isinstance(owned, list):
            for starter in STARTER_OGHAMS:
                if starter in owned:
                    results.append(_result("PASS", f"meta.oghams.owned", f"starter '{starter}' present"))
                else:
                    results.append(_result("FAIL", f"meta.oghams.owned", f"missing starter ogham '{starter}'"))
        else:
            results.append(_result("FAIL", "meta.oghams.owned", "must be a list"))
        if "equipped" not in oghams:
            results.append(_result("FAIL", "meta.oghams.equipped", "missing"))
        else:
            results.append(_result("PASS", "meta.oghams.equipped", f"value='{oghams['equipped']}'"))
    elif oghams is not None:
        results.append(_result("FAIL", "meta.oghams", "must be a dictionary"))

    # biome_runs
    biome_runs = meta.get("biome_runs", {})
    if isinstance(biome_runs, dict):
        for biome in BIOMES:
            if biome not in biome_runs:
                results.append(_result("WARN", f"meta.biome_runs.{biome}", "missing biome entry"))

    # stats
    stats = meta.get("stats", {})
    if isinstance(stats, dict):
        for stat_key in ["total_cards", "total_minigames_won", "total_deaths", "total_play_time_seconds"]:
            val = stats.get(stat_key)
            if val is not None and isinstance(val, (int, float)) and val >= 0:
                results.append(_result("PASS", f"meta.stats.{stat_key}", f"value={val}"))
            elif val is not None:
                results.append(_result("WARN", f"meta.stats.{stat_key}", f"unexpected value: {val}"))

    # run_state (optional)
    run_state = data.get("run_state")
    if run_state is None:
        results.append(_result("PASS", "run_state", "null (no active run)"))
    elif isinstance(run_state, dict):
        results.append(_result("PASS", "run_state", "present (active run)"))
        for key in RUN_STATE_REQUIRED_KEYS:
            if key in run_state:
                results.append(_result("PASS", f"run_state.{key}", f"value={run_state[key]}"))
            else:
                results.append(_result("FAIL", f"run_state.{key}", "missing required key"))

        life = run_state.get("life_essence")
        if isinstance(life, (int, float)):
            if not (0 <= life <= LIFE_MAX):
                results.append(_result("FAIL", "run_state.life_essence", f"must be 0-{LIFE_MAX}, got {life}"))
        elif life is not None:
            results.append(_result("FAIL", "run_state.life_essence", "must be numeric"))

        card_index = run_state.get("card_index")
        if isinstance(card_index, (int, float)) and card_index < 0:
            results.append(_result("WARN", "run_state.card_index", f"negative: {card_index}"))

        active = run_state.get("active")
        if active is not None and not isinstance(active, bool):
            results.append(_result("WARN", "run_state.active", f"expected bool, got {type(active).__name__}"))

        cards_played = run_state.get("cards_played")
        if isinstance(cards_played, (int, float)) and cards_played < 0:
            results.append(_result("WARN", "run_state.cards_played", f"negative: {cards_played}"))
    else:
        results.append(_result("FAIL", "run_state", f"must be dict or null, got {type(run_state).__name__}"))

    return results


def generate_sample() -> dict:
    return {
        "version": "1.0.0",
        "timestamp": 1710500000,
        "meta": {
            "anam": 42,
            "total_runs": 5,
            "faction_rep": {f: 10.0 for f in FACTIONS},
            "trust_merlin": 25,
            "talent_tree": {"unlocked": []},
            "oghams": {"owned": list(STARTER_OGHAMS), "equipped": "beith"},
            "ogham_discounts": {},
            "endings_seen": [],
            "arc_tags": [],
            "biome_runs": {b: 0 for b in BIOMES},
            "biomes_unlocked": ["foret_broceliande"],
            "tutorial_flags": {},
            "stats": {
                "total_cards": 30, "total_minigames_won": 12,
                "total_deaths": 2, "consecutive_deaths": 0,
                "oghams_discovered_in_runs": 1, "total_anam_earned": 42,
                "total_play_time_seconds": 3600, "total_minigames_played": 20,
            },
        },
        "run_state": None,
    }


def print_results(results: list[dict]) -> int:
    counts = {"PASS": 0, "WARN": 0, "FAIL": 0}
    for r in results:
        tag = r["status"]
        counts[tag] = counts.get(tag, 0) + 1
        symbol = {"PASS": "+", "WARN": "~", "FAIL": "!"}[tag]
        print(f"  [{symbol}] {tag:4s}  {r['field']:40s}  {r['message']}")

    print(f"\n  --- Summary: {counts['PASS']} PASS, {counts['WARN']} WARN, {counts['FAIL']} FAIL ---")
    return 1 if counts["FAIL"] > 0 else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate M.E.R.L.I.N. profile JSON")
    parser.add_argument("file", nargs="?", help="Path to profile JSON file")
    parser.add_argument("--generate-sample", action="store_true", help="Generate a valid sample profile")
    args = parser.parse_args()

    if args.generate_sample:
        sample = generate_sample()
        out = json.dumps(sample, indent="\t", ensure_ascii=False)
        print(out)
        return 0

    if not args.file:
        parser.print_help()
        return 1

    path = Path(args.file)
    if not path.is_file():
        print(f"Error: file not found: {path}", file=sys.stderr)
        return 1

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"Error: invalid JSON: {exc}", file=sys.stderr)
        return 1

    if not isinstance(data, dict):
        print("Error: top-level JSON must be an object", file=sys.stderr)
        return 1

    print(f"Validating: {path}\n")
    results = validate_profile(data)
    return print_results(results)


if __name__ == "__main__":
    sys.exit(main())

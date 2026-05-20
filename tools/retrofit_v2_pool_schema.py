"""Retrofit the existing v2 pool to the Phase 15 binary/ternary schema
WITHOUT going through a full LLM regen.

What it does, in place on ``data/ai/cards_meta_v2.json`` :

1. Regenerates the 53 fallback entries via the same logic as
   ``regenerate_fallback_prose.py`` - they pick up the new cardinality
   heuristic (PROMISE / half of NARRATIVE COMMUNE -> 2 options ; rest -> 3)
   and scrubbed prose.
2. For the legacy ``llm`` + ``llm_partial`` entries, retrofits :
   - ``cardinality`` = len(enriched_options) - defaults to 3 since they
     were authored before the binary mode existed.
   - ``binary_reason`` = "" (the LLM didn't write one ; binary mode wasn't
     a thing back then).
   - Scrubs ``prose_short``, ``prose_long``, and each option's
     ``success_prose`` / ``partial_prose`` / ``failure_prose`` to remove
     the ``Tu peux X, Y, ou Z`` option-promising sentence pattern.

This buys us the Phase 15 schema on all canonicals in <2s without a 3h LLM
regen. A subsequent ``python tools/dedup_and_expand_pool.py`` will further
refresh the legacy llm entries with co-authored prose+options when the user
budgets the wall-time for it.

Usage : ``python tools/retrofit_v2_pool_schema.py``
"""

from __future__ import annotations

import json
import logging
import pathlib
import sys
from collections import Counter

from dedup_and_expand_pool import (
    _fallback_enrichment,
    _scrub_prose,
)

log = logging.getLogger(__name__)

ROOT = pathlib.Path(__file__).resolve().parent.parent
POOL_PATH = ROOT / "data" / "ai" / "cards_meta_v2.json"


def _entry_to_canonical_view(entry: dict) -> dict:
    return {
        "canonical_summary": entry.get("canonical_summary", ""),
        "type": entry.get("type", ""),
        "rarity": entry.get("rarity", "COMMUNE"),
        "pole": entry.get("pole", ""),
        "emotion": entry.get("emotion", ""),
        "archetype_hint": entry.get("archetype_hint", ""),
        "source_card_ids": entry.get("source_card_ids", []),
        "source_count": entry.get("source_count", 1),
    }


def _retrofit_llm_entry(entry: dict) -> tuple[bool, bool]:
    """Mutate the entry in place. Returns (mutated, scrub_applied)."""
    mutated = False
    scrubbed = False

    if "cardinality" not in entry:
        entry["cardinality"] = len(entry.get("enriched_options", []) or []) or 3
        mutated = True
    if "binary_reason" not in entry:
        entry["binary_reason"] = ""
        mutated = True

    for field in ("prose_short", "prose_long"):
        raw = entry.get(field, "") or ""
        clean = _scrub_prose(raw)
        if clean != raw:
            entry[field] = clean
            scrubbed = True
            mutated = True

    for opt in entry.get("enriched_options", []) or []:
        for field in ("success_prose", "partial_prose", "failure_prose"):
            raw = opt.get(field, "") or ""
            clean = _scrub_prose(raw)
            if clean != raw:
                opt[field] = clean
                scrubbed = True
                mutated = True

    return mutated, scrubbed


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
    if not POOL_PATH.exists():
        log.error("Pool not found: %s", POOL_PATH)
        return 1

    pool = json.loads(POOL_PATH.read_text(encoding="utf-8"))
    canonicals = pool.get("canonicals", [])

    fb_rewrites = 0
    llm_retrofits = 0
    scrub_hits = 0
    before_card = Counter(c.get("cardinality") for c in canonicals if "cardinality" in c)

    for entry in canonicals:
        source = entry.get("enrichment_source")
        if source == "fallback_template":
            view = _entry_to_canonical_view(entry)
            rebuilt = _fallback_enrichment(view)
            entry["anchor_motif"] = rebuilt.get("anchor_motif", entry.get("anchor_motif", ""))
            entry["prose_short"] = rebuilt.get("prose_short", entry.get("prose_short", ""))
            entry["prose_long"] = rebuilt.get("prose_long", entry.get("prose_long", ""))
            entry["cardinality"] = rebuilt.get("cardinality", 3)
            entry["binary_reason"] = rebuilt.get("binary_reason", "")
            entry["enriched_options"] = rebuilt.get("options", [])
            fb_rewrites += 1
        elif source in ("llm", "llm_partial"):
            mutated, scrubbed = _retrofit_llm_entry(entry)
            if mutated:
                llm_retrofits += 1
            if scrubbed:
                scrub_hits += 1

    after_card = Counter(c.get("cardinality") for c in canonicals if "cardinality" in c)

    POOL_PATH.write_text(json.dumps(pool, ensure_ascii=False), encoding="utf-8")
    log.info(
        "Retrofit done : fb_rewrites=%d, llm_retrofits=%d, scrub_hits=%d",
        fb_rewrites,
        llm_retrofits,
        scrub_hits,
    )
    log.info("Cardinality before : %s", dict(before_card))
    log.info("Cardinality after  : %s", dict(after_card))
    return 0


if __name__ == "__main__":
    sys.exit(main())

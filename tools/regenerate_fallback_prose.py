"""Regenerate the fallback prose for v2 pool entries whose enrichment_source
is ``fallback_template``.

Surgical companion to ``dedup_and_expand_pool.py`` : when only the per-verb
prose template or cardinality heuristic changes (no LLM call needed), we
don't want to re-run the full LLM pass. We just rebuild the failing-fallback
entries from the existing canonical metadata using the now-updated
``_fallback_enrichment`` function.

Inputs  : data/ai/cards_meta_v2.json (current state)
Outputs : data/ai/cards_meta_v2.json (in-place, idempotent)

Usage   : ``python tools/regenerate_fallback_prose.py``
"""

from __future__ import annotations

import json
import logging
import pathlib
import sys
from collections import Counter

from dedup_and_expand_pool import _fallback_enrichment

log = logging.getLogger(__name__)

ROOT = pathlib.Path(__file__).resolve().parent.parent
POOL_PATH = ROOT / "data" / "ai" / "cards_meta_v2.json"


def _entry_to_canonical_view(entry: dict) -> dict:
    """Project a saved v2 entry back into the canonical shape that
    ``_fallback_enrichment`` expects (the function reads only a small subset)."""
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


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
    if not POOL_PATH.exists():
        log.error("Pool not found: %s", POOL_PATH)
        return 1

    pool = json.loads(POOL_PATH.read_text(encoding="utf-8"))
    canonicals = pool.get("canonicals", [])
    before = Counter(c.get("enrichment_source", "?") for c in canonicals)
    log.info("Before: %s", dict(before))

    rewrites = 0
    for entry in canonicals:
        if entry.get("enrichment_source") != "fallback_template":
            continue
        canonical_view = _entry_to_canonical_view(entry)
        rebuilt = _fallback_enrichment(canonical_view)
        entry["anchor_motif"] = rebuilt.get("anchor_motif", entry.get("anchor_motif", ""))
        entry["prose_short"] = rebuilt.get("prose_short", entry.get("prose_short", ""))
        entry["prose_long"] = rebuilt.get("prose_long", entry.get("prose_long", ""))
        entry["cardinality"] = rebuilt.get("cardinality", 3)
        entry["binary_reason"] = rebuilt.get("binary_reason", "")
        entry["enriched_options"] = rebuilt.get("options", [])
        # Source stays fallback_template - they were not LLM-enriched.
        rewrites += 1

    POOL_PATH.write_text(json.dumps(pool, ensure_ascii=False), encoding="utf-8")
    after = Counter(c.get("enrichment_source", "?") for c in canonicals)
    log.info("After:  %s", dict(after))
    log.info("Rewrote %d fallback entries in place.", rewrites)
    return 0


if __name__ == "__main__":
    sys.exit(main())

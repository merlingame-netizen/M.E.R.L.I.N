#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
embed_reference_cards.py - v7.7.30 (2026-05-18)

Phase 10 - card-level embeddings for the embedding-first architecture.

Walks every card of every scenario in `scenarios_reference_broceliande.json`,
emits one 768-dim vector per card via Ollama `nomic-embed-text`, and writes
a single index file readable by `tools/cards_rag.py` and the future Godot
side `CardsRAG` autoload.

Input  : data/ai/scenarios_reference_broceliande.json
Output : data/ai/cards_index_broceliande.json
         { model, dim, status, count, generated_at,
           cards: [ { card_uid, scenario_id, card_id, n, type, rarity, pole,
                      emotion, summary, options, vector } ] }

Idempotent: re-running reuses cached vectors from a previous output file
when (scenario_id, card_id, content_hash) matches. Safe to re-run after
adding new scenarios.

See docs/10_llm/EMBEDDING_FIRST_ARCHITECTURE.md L1 for design context.
"""

from __future__ import annotations
import hashlib
import json
import logging
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import Request, urlopen

OLLAMA_BASE = "http://localhost:11434"
EMBED_MODEL = "nomic-embed-text"
ROOT = Path(__file__).resolve().parent.parent
INPUT_PATH = ROOT / "data" / "ai" / "scenarios_reference_broceliande.json"
OUTPUT_PATH = ROOT / "data" / "ai" / "cards_index_broceliande.json"
EXPECTED_DIM = 768
TIMEOUT_S = 60
PROGRESS_EVERY = 100

log = logging.getLogger("embed_reference_cards")


def _ollama_call(endpoint: str, payload: dict, timeout: int = TIMEOUT_S) -> dict:
    body = json.dumps(payload).encode("utf-8")
    req = Request(
        f"{OLLAMA_BASE}{endpoint}",
        data=body,
        headers={"Content-Type": "application/json"},
    )
    with urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def ensure_model_pulled() -> bool:
    """Check the embedding model is installed; pull if not."""
    try:
        with urlopen(f"{OLLAMA_BASE}/api/tags", timeout=5) as r:
            tags = json.loads(r.read().decode("utf-8"))
    except URLError as e:
        log.error("Ollama not reachable at %s : %s", OLLAMA_BASE, e)
        return False
    installed = [m.get("name", "") for m in tags.get("models", [])]
    if any(EMBED_MODEL in n for n in installed):
        log.info("%s already installed", EMBED_MODEL)
        return True
    log.info("%s not found - pulling now (~137 MB)...", EMBED_MODEL)
    try:
        body = json.dumps({"name": EMBED_MODEL, "stream": False}).encode("utf-8")
        req = Request(
            f"{OLLAMA_BASE}/api/pull",
            data=body,
            headers={"Content-Type": "application/json"},
        )
        with urlopen(req, timeout=600) as r:
            r.read()
        log.info("Pulled %s", EMBED_MODEL)
        return True
    except Exception as e:
        log.error("Pull failed : %s", e)
        return False


def embed_text(text: str) -> list[float]:
    """Call Ollama embed for a single text. Returns 768-dim float vector."""
    resp = _ollama_call("/api/embeddings", {"model": EMBED_MODEL, "prompt": text})
    return resp.get("embedding", [])


def compose_card_embed_input(scenario: dict, card: dict) -> str:
    """Concatenate fields that characterise a card for cosine similarity.

    Includes the scenario archetype to differentiate cards that share a
    summary across archetypes (rare, but it happens). Options' verbs are
    appended so retrieval is sensitive to the player-facing choice space.
    """
    options = card.get("options", []) or []
    opt_verbs = " | ".join(
        f"{o.get('verb', '')}={o.get('primary_faction', '')}"
        for o in options
        if o.get("verb")
    )
    parts = [
        scenario.get("archetype_name", ""),
        card.get("type", ""),
        card.get("pole", ""),
        card.get("emotion", ""),
        card.get("summary", ""),
        opt_verbs,
    ]
    return " . ".join(p for p in parts if p)


def _card_uid(scenario_id: str, card_id: str) -> str:
    """Stable unique id across the pool. Used for cache lookups."""
    return f"{scenario_id}::{card_id}"


def _content_hash(text: str) -> str:
    """SHA1 of the embed-input text. Cache key for idempotent reruns."""
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:16]


def _load_cache(path: Path) -> dict[str, dict]:
    """Read existing output (if any) and index by card_uid for cache hits."""
    if not path.exists():
        return {}
    try:
        prev = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        log.warning("Could not parse previous output (%s) - rebuilding fresh", e)
        return {}
    cache: dict[str, dict] = {}
    for entry in prev.get("cards", []):
        uid = entry.get("card_uid")
        if uid:
            cache[uid] = entry
    return cache


def _write_empty(reason: str) -> None:
    OUTPUT_PATH.write_text(
        json.dumps(
            {
                "model": EMBED_MODEL,
                "dim": 0,
                "status": reason,
                "count": 0,
                "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                "cards": [],
            },
            indent=2,
        ),
        encoding="utf-8",
    )


def main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )

    if not INPUT_PATH.exists():
        log.error("Input not found : %s", INPUT_PATH)
        return 1

    try:
        scenarios = json.loads(INPUT_PATH.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as e:
        log.error("Failed to parse %s : %s", INPUT_PATH.name, e)
        return 1
    log.info("Loaded %d scenarios from %s", len(scenarios), INPUT_PATH.name)

    if not ensure_model_pulled():
        _write_empty("ollama_unavailable")
        log.warning("Wrote empty index to %s", OUTPUT_PATH.name)
        return 2

    cache = _load_cache(OUTPUT_PATH)
    log.info("Cache hit base: %d existing entries", len(cache))

    cards_out: list[dict] = []
    skipped: list[str] = []
    cache_hits = 0
    start = time.time()
    total_cards = sum(len(s.get("cards", []) or []) for s in scenarios)
    log.info("Total cards to embed (pre-cache): %d", total_cards)

    processed = 0
    for scenario in scenarios:
        sid = scenario.get("id", "")
        if not sid:
            log.warning("Scenario without id, skipping")
            continue
        for card in scenario.get("cards", []) or []:
            processed += 1
            cid = card.get("card_id", "")
            if not cid:
                skipped.append(f"{sid}/no-card_id")
                continue
            uid = _card_uid(sid, cid)
            text = compose_card_embed_input(scenario, card)
            if not text:
                skipped.append(f"{uid}/empty-input")
                continue
            content_hash = _content_hash(text)

            cached = cache.get(uid)
            if cached and cached.get("content_hash") == content_hash:
                cards_out.append(cached)
                cache_hits += 1
                continue

            try:
                vec = embed_text(text)
            except Exception as e:
                log.error("%s : embed failed : %s", uid, e)
                skipped.append(f"{uid}/embed-error")
                continue
            if not vec:
                skipped.append(f"{uid}/empty-vector")
                continue
            if len(vec) != EXPECTED_DIM:
                log.warning(
                    "%s : unexpected dim %d (expected %d)",
                    uid,
                    len(vec),
                    EXPECTED_DIM,
                )

            cards_out.append(
                {
                    "card_uid": uid,
                    "scenario_id": sid,
                    "card_id": cid,
                    "n": card.get("n"),
                    "type": card.get("type"),
                    "rarity": card.get("rarity"),
                    "pole": card.get("pole"),
                    "emotion": card.get("emotion"),
                    "summary": card.get("summary"),
                    "options": card.get("options", []),
                    "branch_label": card.get("branch_label"),
                    "route_mask": card.get("route_mask"),
                    "archetype_name": scenario.get("archetype_name"),
                    "content_hash": content_hash,
                    "vector": vec,
                }
            )

            if processed % PROGRESS_EVERY == 0:
                elapsed = time.time() - start
                rate = processed / elapsed if elapsed > 0 else 0
                eta = (total_cards - processed) / rate if rate > 0 else 0
                log.info(
                    "%d/%d cards . %.1f/s . cache_hits=%d . ETA %.0fs",
                    processed,
                    total_cards,
                    rate,
                    cache_hits,
                    eta,
                )

    dim = (
        len(cards_out[0]["vector"])
        if cards_out and isinstance(cards_out[0].get("vector"), list)
        else 0
    )
    output = {
        "model": EMBED_MODEL,
        "dim": dim,
        "status": "ok" if cards_out else "no_cards",
        "count": len(cards_out),
        "cache_hits": cache_hits,
        "skipped": skipped[:50],  # cap the noise
        "skipped_total": len(skipped),
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "cards": cards_out,
    }
    OUTPUT_PATH.write_text(json.dumps(output, ensure_ascii=False), encoding="utf-8")
    elapsed = time.time() - start
    log.info(
        "Wrote %d cards (%d-dim) to %s (%.1f MB)",
        len(cards_out),
        dim,
        OUTPUT_PATH.name,
        OUTPUT_PATH.stat().st_size / 1024 / 1024,
    )
    log.info(
        "Total time : %.1fs . cache_hits=%d . skipped=%d",
        elapsed,
        cache_hits,
        len(skipped),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())

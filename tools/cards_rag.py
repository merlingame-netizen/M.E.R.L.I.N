#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
cards_rag.py - v7.7.30 (2026-05-18)

Phase 10 - runtime kNN retrieval over the card-level embedding index.

Loads `data/ai/cards_index_broceliande.json` once, builds a numpy matrix
in memory, exposes:

    rag = CardsRAG.load()
    rag.embed_query("Une rencontre te revele un secret du chene")
    hits = rag.knn(query_vec, k=5, filters={"type": "EVENT", "pole_in": ["nature"]})
    rag.compose_route_vec(beat_vec, recent_choice_vecs, intro_vec)

Uses pure numpy for the kNN (no hnswlib dependency for the PoC; 2 900
items x 768 dim brute-force cosine is ~3 ms - well under the 1 ms target
once we upgrade to HNSW later).

See docs/10_llm/EMBEDDING_FIRST_ARCHITECTURE.md L2-L4 for design context.
"""

from __future__ import annotations
import argparse
import json
import logging
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Sequence
from urllib.request import Request, urlopen

try:
    import numpy as np
except ImportError:  # pragma: no cover - explicit fail-fast
    print(
        "[FATAL] numpy is required: pip install numpy",
        file=sys.stderr,
    )
    raise

OLLAMA_BASE = "http://localhost:11434"
EMBED_MODEL = "nomic-embed-text"
ROOT = Path(__file__).resolve().parent.parent
INDEX_PATH = ROOT / "data" / "ai" / "cards_index_broceliande.json"

log = logging.getLogger("cards_rag")


@dataclass(frozen=True)
class CardHit:
    """A single retrieval result. Frozen so it can be safely shared."""

    card_uid: str
    score: float
    scenario_id: str
    card_id: str
    type: str
    rarity: str
    pole: str
    emotion: str
    summary: str
    options: list
    branch_label: Optional[str]
    archetype_name: Optional[str]


class CardsRAG:
    """In-memory kNN over the card-level embedding index."""

    def __init__(
        self,
        vectors: "np.ndarray",
        cards: list[dict],
        model: str,
        dim: int,
    ) -> None:
        if vectors.ndim != 2 or vectors.shape[0] != len(cards):
            raise ValueError(
                f"vectors shape {vectors.shape} mismatches cards count {len(cards)}"
            )
        # L2-normalize so cosine = dot product. Done once, kept normalized.
        norms = np.linalg.norm(vectors, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        self._vectors: "np.ndarray" = (vectors / norms).astype(np.float32, copy=False)
        self._cards: list[dict] = cards
        self._model: str = model
        self._dim: int = dim

    # ---------- construction ----------

    @classmethod
    def load(cls, index_path: Path = INDEX_PATH) -> "CardsRAG":
        if not index_path.exists():
            raise FileNotFoundError(
                f"Card index not found: {index_path}\n"
                f"Run: python tools/embed_reference_cards.py"
            )
        raw = json.loads(index_path.read_text(encoding="utf-8"))
        if raw.get("status") != "ok":
            raise RuntimeError(
                f"Index status not ok: {raw.get('status')!r}. "
                f"Re-run embed_reference_cards.py."
            )
        entries = raw.get("cards", [])
        if not entries:
            raise RuntimeError("Index is empty.")

        dim = raw.get("dim") or len(entries[0].get("vector", []))
        n = len(entries)
        mat = np.zeros((n, dim), dtype=np.float32)
        cards: list[dict] = []
        for i, e in enumerate(entries):
            vec = e.get("vector") or []
            if len(vec) != dim:
                log.warning("entry %d has dim %d (expected %d) - skipping", i, len(vec), dim)
                continue
            mat[i] = np.asarray(vec, dtype=np.float32)
            cards.append(e)
        # Trim if any rows were skipped due to dim mismatch.
        mat = mat[: len(cards)]
        log.info("Loaded %d cards (%d-dim) from %s", len(cards), dim, index_path.name)
        return cls(mat, cards, raw.get("model", EMBED_MODEL), dim)

    # ---------- embedding ----------

    def embed_query(self, text: str, timeout: int = 120) -> "np.ndarray":
        """Embed a query string via Ollama. Returns normalized float32 (dim,).

        Phase 22 : retries up to 4 times on HTTP 500 AND socket timeout with
        backoff. On RAM-constrained workstations Ollama can fail to swap
        between the gemma generator and the nomic embedder (500 or timeout) ;
        the re-attempt usually succeeds once the swap settles. Longer default
        timeout (120s) for the cold-swap case.
        """
        from urllib.error import HTTPError, URLError
        body = json.dumps({"model": self._model, "prompt": text}).encode("utf-8")
        req = Request(
            f"{OLLAMA_BASE}/api/embeddings",
            data=body,
            headers={"Content-Type": "application/json"},
        )
        resp: Optional[dict] = None
        last_err: Optional[Exception] = None
        for attempt in range(4):
            try:
                with urlopen(req, timeout=timeout) as r:
                    resp = json.loads(r.read().decode("utf-8"))
                break
            except HTTPError as e:
                last_err = e
                if e.code == 500 and attempt < 3:
                    time.sleep(3.0 + 3.0 * attempt)
                    continue
                raise
            except (TimeoutError, URLError, OSError) as e:
                last_err = e
                if attempt < 3:
                    time.sleep(3.0 + 3.0 * attempt)
                    continue
                raise
        if resp is None:
            if last_err is not None:
                raise last_err
            raise RuntimeError("embed_query : exhausted retries with no response")
        vec = np.asarray(resp.get("embedding", []), dtype=np.float32)
        if vec.size != self._dim:
            raise ValueError(
                f"Embedding dim mismatch: got {vec.size}, expected {self._dim}"
            )
        norm = float(np.linalg.norm(vec))
        if norm > 0:
            vec = vec / norm
        return vec

    # ---------- retrieval ----------

    def knn(
        self,
        query_vec: "np.ndarray",
        k: int = 5,
        filters: Optional[dict] = None,
        exclude_uids: Optional[Sequence[str]] = None,
        mmr_lambda: Optional[float] = None,
        mmr_pool: int = 32,
        dedup_summary: bool = False,
    ) -> list[CardHit]:
        """Return top-k hits by cosine similarity, after applying filters.

        Filters supported:
          - "type":     str or list[str]    (exact match against card.type)
          - "rarity":   str or list[str]
          - "pole":     str or list[str]
          - "pole_in":  list[str]           (alias)
          - "emotion":  str or list[str]
        Filters that point to None are ignored.

        exclude_uids: card_uid strings to skip (already played this run).

        mmr_lambda: if set in (0,1], apply Maximal Marginal Relevance
            re-ranking on the top `mmr_pool` filtered candidates instead of
            naive top-k. Higher lambda = closer to pure similarity. Lower
            lambda = more diversity. Typical: 0.6. Sprint 11.2 fix for the
            "Beat N == Beat N+1" v7.7.30 pathology.
        mmr_pool: number of pre-filtered candidates to feed into MMR
            (ignored if mmr_lambda is None).
        dedup_summary: if True, keep only the highest-scoring card per
            unique `summary` string in the candidate pool before MMR/top-k.
            The Brocéliande pool has 97 % string duplication; this is the
            single biggest knob for diversity. Sprint 11.2.
        """
        if query_vec.size != self._dim:
            raise ValueError(
                f"query_vec dim {query_vec.size} != index dim {self._dim}"
            )
        q = query_vec.astype(np.float32, copy=False)
        norm = float(np.linalg.norm(q))
        if norm > 0:
            q = q / norm
        scores = self._vectors @ q  # (N,) cosine since both normalized
        order = np.argsort(-scores)  # descending

        filters = filters or {}
        exclude = set(exclude_uids or [])
        wanted_types = _coerce_set(filters.get("type"))
        wanted_rarity = _coerce_set(filters.get("rarity"))
        wanted_pole = _coerce_set(filters.get("pole") or filters.get("pole_in"))
        wanted_emotion = _coerce_set(filters.get("emotion"))

        # First pass: collect filtered candidates in similarity-order.
        # When dedup_summary is on, we scan deeper (limit*3) since most
        # candidates collapse together by canonical summary.
        candidate_pool: list[int] = []
        seen_summaries: set[str] = set()
        candidate_limit = max(k, mmr_pool) if mmr_lambda is not None else k
        scan_budget = candidate_limit * 3 if dedup_summary else candidate_limit
        for idx in order:
            card = self._cards[int(idx)]
            uid = card.get("card_uid", "")
            if uid in exclude:
                continue
            if wanted_types and card.get("type") not in wanted_types:
                continue
            if wanted_rarity and card.get("rarity") not in wanted_rarity:
                continue
            if wanted_pole and card.get("pole") not in wanted_pole:
                continue
            if wanted_emotion and card.get("emotion") not in wanted_emotion:
                continue
            if dedup_summary:
                summary = (card.get("summary") or "").strip()
                if summary in seen_summaries:
                    continue
                seen_summaries.add(summary)
            candidate_pool.append(int(idx))
            if len(candidate_pool) >= candidate_limit:
                break
            if dedup_summary and len(candidate_pool) * 3 >= scan_budget:
                # Bail out if we've scanned 3x the pool size without filling it
                # (uncommon - guards against narrow filters that starve the pool).
                continue

        if mmr_lambda is not None and len(candidate_pool) > k:
            picked_indices = self._mmr_select(q, candidate_pool, k=k, lambda_=mmr_lambda)
        else:
            picked_indices = candidate_pool[:k]

        return [self._build_hit(int(i), float(scores[i])) for i in picked_indices]

    def _mmr_select(
        self,
        query_vec: "np.ndarray",
        candidate_indices: list[int],
        k: int,
        lambda_: float = 0.6,
    ) -> list[int]:
        """Maximal Marginal Relevance selection.

        At each step pick the candidate that maximises:
            lambda * sim(q, c) - (1 - lambda) * max_{p in picked} sim(c, p)

        Sprint 11.2 - prevents the pool's 97 % string-duplicate cluster from
        flooding the top-k with structurally-identical cards.
        """
        lam = float(max(0.0, min(1.0, lambda_)))
        if not candidate_indices:
            return []
        cand_vecs = self._vectors[candidate_indices]  # (M, dim)
        sim_to_q = cand_vecs @ query_vec  # (M,) cosine since both normalized

        # First pick: highest similarity to query.
        first_local = int(np.argmax(sim_to_q))
        picked_local: list[int] = [first_local]
        remaining: list[int] = [i for i in range(len(candidate_indices)) if i != first_local]

        while remaining and len(picked_local) < k:
            picked_mat = cand_vecs[picked_local]  # (P, dim)
            # max sim of each remaining candidate to any already-picked.
            sim_to_picked = cand_vecs[remaining] @ picked_mat.T  # (R, P)
            redundancy = sim_to_picked.max(axis=1)  # (R,)
            relevance = sim_to_q[remaining]  # (R,)
            score = lam * relevance - (1.0 - lam) * redundancy
            best_remaining_idx = int(np.argmax(score))
            chosen_local = remaining.pop(best_remaining_idx)
            picked_local.append(chosen_local)

        return [candidate_indices[i] for i in picked_local]

    def _build_hit(self, idx: int, score: float) -> CardHit:
        card = self._cards[idx]
        return CardHit(
            card_uid=card.get("card_uid", ""),
            score=score,
            scenario_id=card.get("scenario_id", ""),
            card_id=card.get("card_id", ""),
            type=card.get("type", ""),
            rarity=card.get("rarity", ""),
            pole=card.get("pole", ""),
            emotion=card.get("emotion", ""),
            summary=card.get("summary", ""),
            options=card.get("options", []),
            branch_label=card.get("branch_label"),
            archetype_name=card.get("archetype_name"),
        )

    # ---------- personalisation ----------

    def compose_route_vec(
        self,
        beat_vec: "np.ndarray",
        recent_choice_vecs: Sequence["np.ndarray"],
        intro_vec: Optional["np.ndarray"] = None,
        weights: tuple[float, float, float] = (0.5, 0.3, 0.2),
    ) -> "np.ndarray":
        """Blend a beat plan vector with the last few choice vectors and the
        intro vector to produce a personalised query.

        Defaults: 50% current beat, 30% mean of recent choices, 20% intro.
        Returns a normalized float32 vector.
        """
        w_beat, w_choice, w_intro = weights
        out = w_beat * beat_vec.astype(np.float32, copy=False)
        if recent_choice_vecs:
            stack = np.stack(
                [v.astype(np.float32, copy=False) for v in recent_choice_vecs]
            )
            out = out + w_choice * stack.mean(axis=0)
        if intro_vec is not None:
            out = out + w_intro * intro_vec.astype(np.float32, copy=False)
        norm = float(np.linalg.norm(out))
        if norm > 0:
            out = out / norm
        return out

    # ---------- introspection ----------

    @property
    def count(self) -> int:
        return len(self._cards)

    @property
    def model(self) -> str:
        return self._model

    @property
    def dim(self) -> int:
        return self._dim


def _coerce_set(value) -> Optional[set[str]]:
    """Normalise a filter value into a set of strings (or None)."""
    if value is None:
        return None
    if isinstance(value, str):
        return {value}
    if isinstance(value, (list, tuple, set)):
        out = {str(v) for v in value if v}
        return out or None
    return {str(value)}


# ---------- CLI for diagnostics ----------


def _format_hit(h: CardHit) -> str:
    label = (h.summary or "")[:80].replace("\n", " ")
    return (
        f"  {h.score:5.3f}  {h.card_uid:<20s}  "
        f"[{h.type or '-'}/{h.rarity or '-'}/{h.pole or '-'}/{h.emotion or '-'}]  "
        f"{label}"
    )


def main() -> int:
    logging.basicConfig(
        level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr
    )
    parser = argparse.ArgumentParser(description="Diagnostic kNN on the card index")
    parser.add_argument("--query", "-q", required=True, help="Free-text query")
    parser.add_argument("--k", type=int, default=5, help="Number of hits")
    parser.add_argument("--type", default=None, help="Filter on card type")
    parser.add_argument("--pole", default=None, help="Filter on pole")
    parser.add_argument("--rarity", default=None, help="Filter on rarity")
    parser.add_argument("--emotion", default=None, help="Filter on emotion")
    args = parser.parse_args()

    t0 = time.time()
    rag = CardsRAG.load()
    load_ms = (time.time() - t0) * 1000
    log.info("Loaded index in %.0f ms (%d cards)", load_ms, rag.count)

    t1 = time.time()
    qvec = rag.embed_query(args.query)
    embed_ms = (time.time() - t1) * 1000
    log.info("Embedded query in %.0f ms", embed_ms)

    filters = {}
    if args.type:
        filters["type"] = args.type
    if args.pole:
        filters["pole"] = args.pole
    if args.rarity:
        filters["rarity"] = args.rarity
    if args.emotion:
        filters["emotion"] = args.emotion

    t2 = time.time()
    hits = rag.knn(qvec, k=args.k, filters=filters)
    knn_ms = (time.time() - t2) * 1000
    log.info("kNN in %.1f ms - %d hits", knn_ms, len(hits))

    for h in hits:
        print(_format_hit(h))
    return 0


if __name__ == "__main__":
    sys.exit(main())

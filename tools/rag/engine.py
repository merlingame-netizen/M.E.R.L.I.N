"""RAG Engine — ChromaDB + sentence-transformers local vector search.

Provides embedding, indexing, and semantic search across multiple collections.
Storage: ~/.claude/rag/ (persistent ChromaDB on disk).
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

logger = logging.getLogger("rag.engine")

RAG_DIR = Path.home() / ".claude" / "rag"
EMBEDDING_MODEL = "all-MiniLM-L6-v2"

COLLECTIONS = ("memory", "docs", "agents", "code", "voc_data", "outlook")


@dataclass(frozen=True)
class SearchResult:
    text: str
    source: str
    score: float
    metadata: dict[str, Any] = field(default_factory=dict)


class RagEngine:
    """Singleton-ish RAG engine wrapping ChromaDB + sentence-transformers."""

    def __init__(self, persist_dir: Path | None = None) -> None:
        self._persist_dir = persist_dir or RAG_DIR
        self._persist_dir.mkdir(parents=True, exist_ok=True)
        self._client: Any | None = None
        self._embed_fn: Any | None = None

    # ── Lazy init (heavy imports deferred) ──────────────────────────────────

    @property
    def client(self) -> Any:
        if self._client is None:
            import chromadb

            self._client = chromadb.PersistentClient(
                path=str(self._persist_dir / "chroma_db")
            )
        return self._client

    @property
    def embed_fn(self) -> Any:
        if self._embed_fn is None:
            from chromadb.utils.embedding_functions import (
                SentenceTransformerEmbeddingFunction,
            )

            self._embed_fn = SentenceTransformerEmbeddingFunction(
                model_name=EMBEDDING_MODEL
            )
        return self._embed_fn

    def _collection(self, name: str) -> Any:
        return self.client.get_or_create_collection(
            name=name, embedding_function=self.embed_fn
        )

    # ── Indexing ────────────────────────────────────────────────────────────

    def index_documents(
        self,
        collection_name: str,
        documents: list[dict[str, Any]],
    ) -> int:
        """Index a list of documents into a collection.

        Each document dict must have:
          - "text": str  (the content to embed)
          - "id": str    (unique identifier)
          - "metadata": dict  (source_path, source_type, etc.)

        Returns number of documents indexed.
        """
        if not documents:
            return 0

        coll = self._collection(collection_name)

        batch_size = 100
        total = 0
        for i in range(0, len(documents), batch_size):
            batch = documents[i : i + batch_size]
            ids = [d["id"] for d in batch]
            texts = [d["text"] for d in batch]
            metadatas = [d.get("metadata", {}) for d in batch]

            # Sanitize metadata: ChromaDB only accepts str/int/float/bool
            clean_metas = []
            for m in metadatas:
                clean = {}
                for k, v in m.items():
                    if isinstance(v, (str, int, float, bool)):
                        clean[k] = v
                    else:
                        clean[k] = str(v)
                clean_metas.append(clean)

            coll.upsert(ids=ids, documents=texts, metadatas=clean_metas)
            total += len(batch)

        self.write_stats_cache()
        return total

    def delete_by_source(self, collection_name: str, source_path: str) -> None:
        """Remove all chunks from a specific source file."""
        coll = self._collection(collection_name)
        try:
            coll.delete(where={"source_path": source_path})
        except Exception:
            pass

    # ── Search ──────────────────────────────────────────────────────────────

    def search(
        self,
        query: str,
        collection_names: list[str] | None = None,
        n_results: int = 10,
    ) -> list[SearchResult]:
        """Semantic search across one or more collections."""
        targets = collection_names or list(COLLECTIONS)
        all_results: list[SearchResult] = []

        for name in targets:
            try:
                coll = self._collection(name)
                if coll.count() == 0:
                    continue
                results = coll.query(
                    query_texts=[query],
                    n_results=min(n_results, coll.count()),
                )
            except Exception as e:
                logger.warning("Search failed on %s: %s", name, e)
                continue

            if not results or not results.get("documents"):
                continue

            docs = results["documents"][0]
            distances = results["distances"][0] if results.get("distances") else [0.0] * len(docs)
            metadatas = results["metadatas"][0] if results.get("metadatas") else [{}] * len(docs)

            for doc, dist, meta in zip(docs, distances, metadatas):
                score = max(0.0, 1.0 - dist)
                all_results.append(
                    SearchResult(
                        text=doc,
                        source=meta.get("source_path", name),
                        score=round(score, 4),
                        metadata={**meta, "collection": name},
                    )
                )

        all_results.sort(key=lambda r: r.score, reverse=True)
        return all_results[:n_results]

    # ── Stats & maintenance ─────────────────────────────────────────────────

    def get_stats(self) -> dict[str, Any]:
        """Return per-collection counts and total."""
        stats: dict[str, Any] = {}
        total = 0
        for name in COLLECTIONS:
            try:
                coll = self._collection(name)
                count = coll.count()
            except Exception:
                count = 0
            stats[name] = count
            total += count
        stats["_total"] = total
        db_path = self._persist_dir / "chroma_db"
        stats["_db_size_mb"] = round(
            sum(f.stat().st_size for f in db_path.rglob("*") if f.is_file()) / 1048576, 1
        ) if db_path.exists() else 0
        return stats

    def write_stats_cache(self) -> None:
        """Write stats to stats_cache.json for VS Code extension consumption."""
        stats = self.get_stats()
        stats["_updated"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        cache_path = self._persist_dir / "stats_cache.json"
        cache_path.write_text(json.dumps(stats, indent=2), encoding="utf-8")

    def gc(self, collection_name: str | None = None) -> int:
        """Remove chunks whose source_path no longer exists on disk. Returns count removed."""
        targets = [collection_name] if collection_name else list(COLLECTIONS)
        removed = 0
        for name in targets:
            coll = self._collection(name)
            try:
                all_data = coll.get(include=["metadatas"])
            except Exception:
                continue
            if not all_data or not all_data.get("ids"):
                continue
            stale_ids = []
            for doc_id, meta in zip(all_data["ids"], all_data["metadatas"]):
                src = meta.get("source_path", "")
                if src and not Path(src).exists():
                    stale_ids.append(doc_id)
            if stale_ids:
                coll.delete(ids=stale_ids)
                removed += len(stale_ids)
        return removed

    def drop_collection(self, name: str) -> None:
        """Delete an entire collection."""
        try:
            self.client.delete_collection(name)
        except Exception:
            pass


# ── Helpers ─────────────────────────────────────────────────────────────────

def make_chunk_id(source_path: str, chunk_index: int) -> str:
    """Deterministic ID for a chunk."""
    raw = f"{source_path}::{chunk_index}"
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def get_sync_state_path() -> Path:
    """Path to the sync state file tracking last-indexed mtimes."""
    return RAG_DIR / "sync_state.json"


def load_sync_state() -> dict[str, float]:
    """Load {file_path: last_indexed_mtime} mapping."""
    p = get_sync_state_path()
    if p.exists():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_sync_state(state: dict[str, float]) -> None:
    p = get_sync_state_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(state), encoding="utf-8")

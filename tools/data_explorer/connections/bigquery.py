"""BigQuery connection via google-cloud-bigquery + ADC."""

from __future__ import annotations

import logging
import time

from config import BQ_DATASET, BQ_PROJECT, BQ_TIMEOUT, MAX_ROWS
from services.sql_guard import enforce_max_rows, safe_column_list, safe_identifier, validate_sql

_log = logging.getLogger(__name__)


class BigQueryConnection:
    """Persistent single-connection manager for BigQuery."""

    def __init__(self):
        self._client = None
        self._project = BQ_PROJECT
        self._dataset = BQ_DATASET
        self._last_check: float = 0.0

    def connect(self, project: str = "") -> dict:
        """Connect to BigQuery via ADC."""
        self.disconnect()
        t0 = time.time()
        try:
            from google.cloud import bigquery

            proj = project or self._project
            self._client = bigquery.Client(project=proj)
            list(self._client.query("SELECT 1").result())
            self._project = proj
            self._last_check = time.time()
            elapsed = time.time() - t0
            return {
                "connected": True,
                "info": f"BQ OK ({elapsed:.1f}s)",
                "project": self._project,
                "dataset": self._dataset,
            }
        except Exception as exc:
            _log.error("BigQuery connection failed: %s", exc)
            self._client = None
            return {
                "connected": False,
                "info": "BQ connexion echouee — lancer: gcloud auth login --update-adc",
            }

    def disconnect(self) -> None:
        if self._client is not None:
            try:
                self._client.close()
            except Exception:
                pass
            self._client = None
            self._last_check = 0.0

    def is_connected(self) -> bool:
        if self._client is None:
            return False
        # Cache: only re-verify if >60s since last check
        if time.time() - self._last_check < 60:
            return True
        try:
            list(self._client.query("SELECT 1").result())
            self._last_check = time.time()
            return True
        except Exception:
            self._client = None
            self._last_check = 0.0
            return False

    def list_tables(self, database: str = "", filter_: str = "") -> list[dict]:
        dataset = safe_identifier(database or self._dataset, "dataset")
        dataset_ref = f"{self._project}.{dataset}"
        tables = sorted(
            [{"name": t.table_id, "type": t.table_type} for t in self._client.list_tables(dataset_ref)],
            key=lambda t: t["name"],
        )
        if filter_:
            fl = filter_.lower()
            tables = [t for t in tables if fl in t["name"].lower()]
        return tables

    def describe_table(self, table: str) -> dict:
        safe_table = safe_identifier(table, "table")
        full_ref = f"{self._project}.{self._dataset}.{safe_table}" if "." not in safe_table else safe_table
        tref = self._client.get_table(full_ref)
        columns = [
            {"name": f.name, "type": f.field_type, "mode": f.mode}
            for f in tref.schema
        ]
        return {"columns": columns, "num_rows": tref.num_rows}

    def sample(self, table: str, columns: list[str] | None = None, limit: int = 20) -> dict:
        safe_table = safe_identifier(table, "table")
        full_ref = f"`{self._project}.{self._dataset}.{safe_table}`" if "." not in safe_table else f"`{safe_table}`"
        if columns:
            safe_cols = safe_column_list(columns)
            cols = ", ".join(safe_cols)
        else:
            cols = "*"
        sql = f"SELECT {cols} FROM {full_ref} LIMIT {min(limit, MAX_ROWS)}"
        return self._execute_raw(sql)

    def execute(self, sql: str, limit: int = 10_000) -> dict:
        clean_sql, error = validate_sql(sql, "bigquery")
        if error:
            return {"columns": [], "rows": [], "row_count": 0, "error": error}
        clean_sql = enforce_max_rows(clean_sql, min(limit, MAX_ROWS))
        return self._execute_raw(clean_sql)

    def _execute_raw(self, sql: str) -> dict:
        t0 = time.time()
        try:
            query_job = self._client.query(sql, timeout=BQ_TIMEOUT)
            df = query_job.to_dataframe(progress_bar_type=None)
            elapsed_ms = int((time.time() - t0) * 1000)
            columns = list(df.columns)
            rows = df.where(df.notna(), None).values.tolist()
            return {
                "columns": columns,
                "rows": rows,
                "row_count": len(rows),
                "duration_ms": elapsed_ms,
            }
        except Exception as exc:
            _log.error("BigQuery query failed: %s", exc)
            return {
                "columns": [], "rows": [], "row_count": 0,
                "error": "Erreur execution requete — voir logs serveur",
                "duration_ms": int((time.time() - t0) * 1000),
            }

    def info(self) -> dict:
        return {"project": self._project, "dataset": self._dataset}

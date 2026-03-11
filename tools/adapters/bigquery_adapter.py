"""BigQuery adapter — google-cloud-bigquery (ADC) with bq CLI fallback."""

from __future__ import annotations

import json
import re
import subprocess
import time
from typing import Any

from tools.adapters.base_adapter import BaseAdapter

# ── Constants ────────────────────────────────────────────────────────────────

_DEFAULT_PROJECT = "ofr-ppx-propme-1-prd"
_DEFAULT_LIMIT = 100

# Paths — Windows absolute paths, no gcloud assumption in PATH
_PYTHON_EXE = r"C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe"
_GCLOUD_PY = r"C:/Program Files (x86)/Google/Cloud SDK/google-cloud-sdk/lib/gcloud.py"
_BQ_CLI = r"C:/Program Files (x86)/Google/Cloud SDK/google-cloud-sdk/bin/bq"

_AUTH_HINT = (
    "Authentication failed. Run:\n"
    f'  {_PYTHON_EXE} "{_GCLOUD_PY}" auth login --update-adc\n'
    "Then retry."
)

_INSTALL_HINT = (
    "google-cloud-bigquery is not installed.\n"
    "Run:  pip install google-cloud-bigquery\n"
    "Falling back to bq CLI…"
)

# Warn when estimated scan exceeds this threshold (1 GiB)
_WARN_BYTES = 1_073_741_824


# ── Adapter ──────────────────────────────────────────────────────────────────


class BigQueryAdapter(BaseAdapter):
    """
    Adapter for Google BigQuery.

    Primary:  google-cloud-bigquery Python client (ADC).
    Fallback: bq CLI subprocess (if library not installed or auth issues).

    Key safety rules applied automatically:
      - LIMIT injected on SELECT queries without one.
      - Backtick quoting for project.dataset.table references.
      - Dry-run + cost warning when estimated bytes > 1 GiB.
    """

    def __init__(self) -> None:
        super().__init__("bigquery")
        self._bq_client: Any = None  # lazy-init google.cloud.bigquery.Client

    # ── Public interface ─────────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "list-datasets": (
                "List datasets in a project (kwargs: project=ofr-ppx-propme-1-prd)"
            ),
            "list-tables": (
                "List tables in a dataset (kwargs: project, dataset)"
            ),
            "describe": (
                "Get table schema (kwargs: project, dataset, table)"
            ),
            "query": (
                "Execute BigQuery SQL — auto-adds LIMIT, warns on large scans "
                "(kwargs: sql, project, dry_run=False, limit=100)"
            ),
            "dry-run": (
                "Estimate bytes scanned without running the query "
                "(kwargs: sql, project)"
            ),
            "storage-info": (
                "Get table storage stats: row count, logical bytes "
                "(kwargs: project, dataset, table)"
            ),
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch = {
            "list-datasets": self._list_datasets,
            "list-tables": self._list_tables,
            "describe": self._describe,
            "query": self._query,
            "dry-run": self._dry_run,
            "storage-info": self._storage_info,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError  # propagated → error envelope
        return handler(kwargs)

    # ── Client helpers ───────────────────────────────────────────────────────

    def _get_client(self, project: str) -> Any:
        """Return a cached google-cloud-bigquery Client, or raise ImportError."""
        try:
            from google.cloud import bigquery  # noqa: PLC0415
        except ImportError as exc:
            raise ImportError(_INSTALL_HINT) from exc

        if self._bq_client is None or self._bq_client.project != project:
            self._bq_client = bigquery.Client(project=project)
        return self._bq_client

    def _resolve_project(self, kwargs: dict) -> str:
        return kwargs.get("project") or _DEFAULT_PROJECT

    # ── SQL utilities ────────────────────────────────────────────────────────

    @staticmethod
    def _inject_limit(sql: str, limit: int) -> tuple[str, bool]:
        """
        Return (sql_with_limit, was_added).

        Adds `LIMIT {limit}` only to top-level SELECT statements that do
        not already contain a LIMIT clause.  Non-SELECT statements are
        returned unchanged.
        """
        stripped = sql.strip()
        if not re.match(r"(?i)^\s*select\b", stripped):
            return sql, False
        if re.search(r"(?i)\bLIMIT\s+\d+", stripped):
            return sql, False
        return f"{stripped.rstrip(';')}\nLIMIT {limit}", True

    @staticmethod
    def _bytes_human(n: int) -> str:
        for unit in ("B", "KB", "MB", "GB", "TB"):
            if n < 1024:
                return f"{n:.1f} {unit}"
            n /= 1024  # type: ignore[assignment]
        return f"{n:.1f} PB"

    # ── Library-backed actions ───────────────────────────────────────────────

    def _list_datasets(self, kwargs: dict) -> dict:
        project = self._resolve_project(kwargs)
        try:
            client = self._get_client(project)
        except ImportError:
            return self._bq_cli_list_datasets(project)
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self.error(f"BigQuery client error: {exc}")

        self.log(f"list-datasets: project={project}")
        try:
            datasets = list(client.list_datasets())
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self._bq_cli_list_datasets(project)

        rows = [
            {"dataset_id": ds.dataset_id, "project": ds.project}
            for ds in datasets
        ]
        return self.ok({"project": project, "datasets": rows, "count": len(rows)})

    def _list_tables(self, kwargs: dict) -> dict:
        project = self._resolve_project(kwargs)
        dataset = kwargs.get("dataset")
        if not dataset:
            return self.error("Missing required argument: dataset")

        try:
            client = self._get_client(project)
        except ImportError:
            return self._bq_cli_list_tables(project, dataset)
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self.error(f"BigQuery client error: {exc}")

        self.log(f"list-tables: {project}.{dataset}")
        try:
            tables = list(client.list_tables(dataset))
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self._bq_cli_list_tables(project, dataset)

        rows = [
            {"table_id": t.table_id, "table_type": t.table_type}
            for t in tables
        ]
        return self.ok(
            {"project": project, "dataset": dataset, "tables": rows, "count": len(rows)}
        )

    def _describe(self, kwargs: dict) -> dict:
        project = self._resolve_project(kwargs)
        dataset = kwargs.get("dataset")
        table = kwargs.get("table")
        if not dataset:
            return self.error("Missing required argument: dataset")
        if not table:
            return self.error("Missing required argument: table")

        try:
            client = self._get_client(project)
        except ImportError:
            return self._bq_cli_describe(project, dataset, table)
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self.error(f"BigQuery client error: {exc}")

        ref = f"{project}.{dataset}.{table}"
        self.log(f"describe: {ref}")
        try:
            tbl = client.get_table(ref)
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self._bq_cli_describe(project, dataset, table)

        fields = [
            {
                "name": f.name,
                "field_type": f.field_type,
                "mode": f.mode,
                "description": f.description or "",
            }
            for f in tbl.schema
        ]
        return self.ok(
            {
                "table": ref,
                "num_rows": tbl.num_rows,
                "num_bytes": tbl.num_bytes,
                "created": str(tbl.created),
                "modified": str(tbl.modified),
                "schema": fields,
                "field_count": len(fields),
            }
        )

    def _query(self, kwargs: dict) -> dict:
        project = self._resolve_project(kwargs)
        sql = kwargs.get("sql") or kwargs.get("dax")  # accept 'sql' or 'dax' alias
        if not sql:
            return self.error("Missing required argument: sql")
        limit = int(kwargs.get("limit") or _DEFAULT_LIMIT)
        do_dry_run = str(kwargs.get("dry_run", "false")).lower() in ("true", "1", "yes")

        sql, limit_added = self._inject_limit(sql, limit)
        if limit_added:
            self.log(f"Auto-added LIMIT {limit} to SELECT query.")

        # Always dry-run first to estimate cost
        dry_result = self._run_dry_run(project, sql)
        if dry_result is None:
            # dry-run failed but we still attempt the query
            self.log("Dry-run estimate unavailable — proceeding anyway.")
            estimated_bytes = 0
        else:
            estimated_bytes = dry_result.get("bytes_processed", 0)
            self.log(
                f"Estimated scan: {self._bytes_human(estimated_bytes)}"
                f" ({estimated_bytes:,} bytes)"
            )
            if estimated_bytes > _WARN_BYTES:
                self.log(
                    f"WARNING: estimated scan > 1 GiB "
                    f"({self._bytes_human(estimated_bytes)}). "
                    "Consider narrowing WHERE clause or using partition filters."
                )

        if do_dry_run:
            # Caller only wants the estimate
            if dry_result is None:
                return self.error("Dry-run failed — cannot estimate cost.")
            return self.ok(dry_result)

        # Execute
        try:
            client = self._get_client(project)
        except ImportError:
            return self._bq_cli_query(project, sql, estimated_bytes)
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self.error(f"BigQuery client error: {exc}")

        self.log(f"Executing query (project={project})…")
        t0 = time.monotonic()
        try:
            from google.cloud import bigquery  # noqa: PLC0415
            job_config = bigquery.QueryJobConfig(use_query_cache=True)
            job = client.query(sql, job_config=job_config)
            rows_raw = list(job.result())
        except Exception as exc:
            if self._is_auth_error(exc):
                return self.error(_AUTH_HINT)
            return self._bq_cli_query(project, sql, estimated_bytes)

        duration_ms = int((time.monotonic() - t0) * 1000)
        bytes_processed = job.total_bytes_processed or estimated_bytes
        rows = [dict(r) for r in rows_raw]
        self.log(f"Query complete: {len(rows)} rows, {self._bytes_human(bytes_processed)} processed, {duration_ms}ms")

        return self.ok(
            {
                "rows": rows,
                "rows_returned": len(rows),
                "bytes_processed": bytes_processed,
                "bytes_processed_human": self._bytes_human(bytes_processed),
                "duration_ms": duration_ms,
                "cache_hit": job.cache_hit,
            }
        )

    def _dry_run(self, kwargs: dict) -> dict:
        project = self._resolve_project(kwargs)
        sql = kwargs.get("sql") or kwargs.get("dax")
        if not sql:
            return self.error("Missing required argument: sql")

        result = self._run_dry_run(project, sql)
        if result is None:
            return self.error(
                "Dry-run failed. Check SQL syntax and authentication.\n" + _AUTH_HINT
            )
        return self.ok(result)

    def _storage_info(self, kwargs: dict) -> dict:
        project = self._resolve_project(kwargs)
        dataset = kwargs.get("dataset")
        table = kwargs.get("table")
        if not dataset:
            return self.error("Missing required argument: dataset")
        if not table:
            return self.error("Missing required argument: table")

        # Use INFORMATION_SCHEMA — safe pattern (always partition-aware in BQ)
        sql = f"""
SELECT
  table_name,
  total_rows,
  total_logical_bytes,
  total_billable_bytes
FROM `{project}.{dataset}.INFORMATION_SCHEMA.TABLE_STORAGE`
WHERE table_name = '{table}'
"""
        self.log(f"storage-info query for {project}.{dataset}.{table}")
        return self._query({"sql": sql, "project": project, "limit": 10})

    # ── Dry-run helper ───────────────────────────────────────────────────────

    def _run_dry_run(self, project: str, sql: str) -> dict | None:
        """
        Return {bytes_processed, bytes_human} from a dry-run, or None on failure.
        Tries library first, then bq CLI.
        """
        try:
            client = self._get_client(project)
            from google.cloud import bigquery  # noqa: PLC0415
            job_config = bigquery.QueryJobConfig(dry_run=True, use_query_cache=False)
            job = client.query(sql, job_config=job_config)
            n = job.total_bytes_processed or 0
            return {
                "bytes_processed": n,
                "bytes_processed_human": self._bytes_human(n),
                "cache_hit": False,
            }
        except Exception:
            # Try bq CLI fallback for dry-run
            return self._bq_cli_dry_run(project, sql)

    # ── bq CLI fallback ──────────────────────────────────────────────────────

    def _bq_run(self, args: list[str], timeout: int = 60) -> tuple[int, str, str]:
        """Run a bq CLI command. Returns (returncode, stdout, stderr)."""
        cmd = [_BQ_CLI] + args
        self.log(f"bq CLI: {' '.join(str(a) for a in args[:6])}")
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            return result.returncode, result.stdout, result.stderr
        except FileNotFoundError:
            return -1, "", f"bq CLI not found at {_BQ_CLI}"
        except subprocess.TimeoutExpired:
            return -1, "", "bq CLI timed out"

    def _bq_cli_list_datasets(self, project: str) -> dict:
        self.log("Fallback: bq ls (list datasets)")
        rc, out, err = self._bq_run(["--project_id", project, "--format", "json", "ls"])
        if rc != 0:
            return self.error(f"bq ls failed: {err[:300]}\n{_AUTH_HINT}")
        try:
            items = json.loads(out) if out.strip() else []
        except json.JSONDecodeError:
            return self.error(f"bq ls returned non-JSON: {out[:200]}")
        datasets = [
            {"dataset_id": item.get("datasetReference", {}).get("datasetId", ""), "project": project}
            for item in (items if isinstance(items, list) else [])
        ]
        return self.ok({"project": project, "datasets": datasets, "count": len(datasets)})

    def _bq_cli_list_tables(self, project: str, dataset: str) -> dict:
        self.log(f"Fallback: bq ls {project}:{dataset}")
        rc, out, err = self._bq_run(
            ["--project_id", project, "--format", "json", "ls", f"{project}:{dataset}"]
        )
        if rc != 0:
            return self.error(f"bq ls failed: {err[:300]}\n{_AUTH_HINT}")
        try:
            items = json.loads(out) if out.strip() else []
        except json.JSONDecodeError:
            return self.error(f"bq ls returned non-JSON: {out[:200]}")
        tables = [
            {
                "table_id": item.get("tableReference", {}).get("tableId", ""),
                "table_type": item.get("type", ""),
            }
            for item in (items if isinstance(items, list) else [])
        ]
        return self.ok(
            {"project": project, "dataset": dataset, "tables": tables, "count": len(tables)}
        )

    def _bq_cli_describe(self, project: str, dataset: str, table: str) -> dict:
        ref = f"{project}:{dataset}.{table}"
        self.log(f"Fallback: bq show {ref}")
        rc, out, err = self._bq_run(["--format", "json", "show", ref])
        if rc != 0:
            return self.error(f"bq show failed: {err[:300]}\n{_AUTH_HINT}")
        try:
            info = json.loads(out)
        except json.JSONDecodeError:
            return self.error(f"bq show returned non-JSON: {out[:200]}")

        raw_schema = info.get("schema", {}).get("fields", [])
        fields = [
            {
                "name": f.get("name", ""),
                "field_type": f.get("type", ""),
                "mode": f.get("mode", "NULLABLE"),
                "description": f.get("description", ""),
            }
            for f in raw_schema
        ]
        stats = info.get("numRows", ""), info.get("numBytes", "")
        return self.ok(
            {
                "table": f"{project}.{dataset}.{table}",
                "num_rows": stats[0],
                "num_bytes": stats[1],
                "schema": fields,
                "field_count": len(fields),
            }
        )

    def _bq_cli_query(self, project: str, sql: str, estimated_bytes: int = 0) -> dict:
        self.log("Fallback: bq query")
        if estimated_bytes > _WARN_BYTES:
            self.log(
                f"WARNING: scan estimate {self._bytes_human(estimated_bytes)} exceeds 1 GiB."
            )
        t0 = time.monotonic()
        rc, out, err = self._bq_run(
            [
                "--project_id", project,
                "--format", "json",
                "--use_legacy_sql=false",
                "--nouse_cache",
                "query",
                sql,
            ],
            timeout=120,
        )
        duration_ms = int((time.monotonic() - t0) * 1000)
        if rc != 0:
            return self.error(f"bq query failed: {err[:300]}\n{_AUTH_HINT}")
        try:
            rows = json.loads(out) if out.strip() else []
        except json.JSONDecodeError:
            return self.error(f"bq query returned non-JSON: {out[:200]}")
        if not isinstance(rows, list):
            rows = [rows]
        self.log(f"bq query complete: {len(rows)} rows in {duration_ms}ms")
        return self.ok(
            {
                "rows": rows,
                "rows_returned": len(rows),
                "bytes_processed": estimated_bytes,
                "bytes_processed_human": self._bytes_human(estimated_bytes),
                "duration_ms": duration_ms,
                "cache_hit": False,
            }
        )

    def _bq_cli_dry_run(self, project: str, sql: str) -> dict | None:
        """Return dry-run cost dict or None on failure."""
        rc, out, err = self._bq_run(
            [
                "--project_id", project,
                "--format", "json",
                "--use_legacy_sql=false",
                "--dry_run",
                "query",
                sql,
            ]
        )
        if rc != 0:
            return None
        # bq dry_run prints to stderr: "Query successfully validated. Assuming the
        # tables are not modified, running this query will process X bytes of data."
        combined = out + err
        match = re.search(r"process\s+([\d,]+)\s+bytes", combined)
        if not match:
            return None
        n = int(match.group(1).replace(",", ""))
        return {
            "bytes_processed": n,
            "bytes_processed_human": self._bytes_human(n),
            "cache_hit": False,
        }

    # ── Auth detection ───────────────────────────────────────────────────────

    @staticmethod
    def _is_auth_error(exc: Exception) -> bool:
        msg = str(exc).lower()
        return any(
            kw in msg
            for kw in (
                "credentials",
                "unauthenticated",
                "permission denied",
                "403",
                "401",
                "could not automatically determine",
                "application default",
                "invalid_rapt",
                "default credentials",
            )
        )

"""EDH (Hive/Knox) connection.

Metadata (DESCRIBE, SHOW TABLES) → pyodbc (fast, no Tez)
Data queries (SELECT) → Node.js hive-driver bridge (bypasses broken ODBC Tez)
"""

from __future__ import annotations

import json
import logging
import subprocess
import time

from config import (
    EDH_DSN,
    EDH_SCHEMA,
    EDH_TIMEOUT,
    HIVE_BRIDGE_CWD,
    HIVE_BRIDGE_PATH,
    HIVE_BRIDGE_TIMEOUT,
    MAX_ROWS,
)
from services.sql_guard import enforce_max_rows, safe_column_list, safe_identifier, validate_sql

_log = logging.getLogger(__name__)


class EDHConnection:
    """Persistent connection manager for EDH Hive.

    - Metadata via pyodbc (DESCRIBE, SHOW TABLES, SHOW DATABASES)
    - Data queries via hive-driver Node.js bridge (SELECT)
    """

    def __init__(self):
        self._conn = None  # pyodbc connection (metadata only)
        self._dsn = EDH_DSN
        self._schema = EDH_SCHEMA
        self._last_check: float = 0.0

    # ------------------------------------------------------------------
    # Connection lifecycle (pyodbc — metadata only)
    # ------------------------------------------------------------------

    def connect(self, user: str = "", password: str = "") -> dict:
        import pyodbc

        self.disconnect()
        t0 = time.time()
        try:
            conn_str = f"DSN={self._dsn}"
            if user:
                conn_str += f";UID={user};PWD={password}"

            self._conn = pyodbc.connect(conn_str, timeout=EDH_TIMEOUT, autocommit=True)
            self._conn.cursor().execute("SHOW DATABASES").fetchone()
            self._last_check = time.time()
            elapsed = time.time() - t0
            return {"connected": True, "info": f"EDH OK ({elapsed:.0f}s)", "dsn": self._dsn}
        except Exception as exc:
            _log.error("EDH connection failed: %s", exc)
            self._conn = None
            return {"connected": False, "info": "EDH connexion echouee — verifier DSN/credentials"}

    def disconnect(self) -> None:
        if self._conn is not None:
            try:
                self._conn.close()
            except Exception:
                pass
            self._conn = None
            self._last_check = 0.0

    def is_connected(self) -> bool:
        if self._conn is None:
            return False
        if time.time() - self._last_check < 60:
            return True
        try:
            self._conn.cursor().execute("SHOW DATABASES").fetchone()
            self._last_check = time.time()
            return True
        except Exception:
            self._conn = None
            self._last_check = 0.0
            return False

    # ------------------------------------------------------------------
    # Metadata queries (pyodbc — no Tez)
    # ------------------------------------------------------------------

    def list_tables(self, database: str = "", filter_: str = "") -> list[dict]:
        schema = safe_identifier(database or self._schema, "schema")
        cursor = self._conn.cursor()
        cursor.execute(f"SHOW TABLES IN {schema}")
        tables = sorted([{"name": row[0]} for row in cursor.fetchall()], key=lambda t: t["name"])
        if filter_:
            fl = filter_.lower()
            tables = [t for t in tables if fl in t["name"].lower()]
        return tables

    def describe_table(self, table: str) -> dict:
        safe_table = safe_identifier(table, "table")
        full_name = f"{self._schema}.{safe_table}" if "." not in safe_table else safe_table
        cursor = self._conn.cursor()
        cursor.execute(f"DESCRIBE {full_name}")
        columns = []
        for row in cursor.fetchall():
            col = {"name": str(row[0]), "type": str(row[1]) if len(row) > 1 else ""}
            if len(row) > 2:
                col["mode"] = str(row[2])
            columns.append(col)
        return {"columns": columns}

    # ------------------------------------------------------------------
    # Data queries (hive-driver Node.js bridge)
    # ------------------------------------------------------------------

    def sample(self, table: str, columns: list[str] | None = None, limit: int = 20) -> dict:
        safe_table = safe_identifier(table, "table")
        full_name = f"{self._schema}.{safe_table}" if "." not in safe_table else safe_table
        if columns:
            safe_cols = safe_column_list(columns)
            cols = ", ".join(safe_cols)
        else:
            cols = "*"
        sql = f"SELECT {cols} FROM {full_name} LIMIT {min(limit, MAX_ROWS)}"
        return self._execute_via_hive_driver(sql)

    def execute(self, sql: str, limit: int = 10_000) -> dict:
        clean_sql, error = validate_sql(sql, "edh")
        if error:
            return {"columns": [], "rows": [], "row_count": 0, "error": error}
        clean_sql = enforce_max_rows(clean_sql, min(limit, MAX_ROWS))
        return self._execute_via_hive_driver(clean_sql)

    def _execute_via_hive_driver(self, sql: str) -> dict:
        """Execute a data query via the Node.js hive-driver bridge."""
        bridge = str(HIVE_BRIDGE_PATH)
        cwd = str(HIVE_BRIDGE_CWD)

        _log.info("hive-driver query: %s", sql[:200])
        t0 = time.time()

        try:
            proc = subprocess.run(
                ["node", bridge, sql],
                capture_output=True,
                text=True,
                encoding="utf-8",
                timeout=HIVE_BRIDGE_TIMEOUT,
                cwd=cwd,
            )
        except subprocess.TimeoutExpired:
            _log.error("hive-driver timeout after %ds", HIVE_BRIDGE_TIMEOUT)
            return {
                "columns": [], "rows": [], "row_count": 0,
                "error": f"Timeout ({HIVE_BRIDGE_TIMEOUT}s) — requete trop longue",
                "duration_ms": int((time.time() - t0) * 1000),
            }
        except FileNotFoundError:
            _log.error("node not found in PATH")
            return {
                "columns": [], "rows": [], "row_count": 0,
                "error": "Node.js non trouve dans le PATH",
                "duration_ms": 0,
            }

        # Parse JSON from stdout
        stdout = proc.stdout.strip()
        if not stdout:
            stderr_msg = proc.stderr.strip()[:300] if proc.stderr else "no output"
            _log.error("hive-driver empty output: %s", stderr_msg)
            return {
                "columns": [], "rows": [], "row_count": 0,
                "error": f"hive-driver: pas de reponse ({stderr_msg})",
                "duration_ms": int((time.time() - t0) * 1000),
            }

        try:
            result = json.loads(stdout)
        except json.JSONDecodeError as exc:
            _log.error("hive-driver invalid JSON: %s", stdout[:200])
            return {
                "columns": [], "rows": [], "row_count": 0,
                "error": f"hive-driver: JSON invalide ({exc})",
                "duration_ms": int((time.time() - t0) * 1000),
            }

        # Check for bridge-level error
        if "error" in result and result["error"]:
            _log.error("hive-driver error: %s", result["error"][:200])
            return {
                "columns": [], "rows": [], "row_count": 0,
                "error": result["error"][:300],
                "duration_ms": result.get("duration_ms", int((time.time() - t0) * 1000)),
            }

        # Convert rows from [{col: val}] to [[val]] for consistency with frontend
        columns = result.get("columns", [])
        raw_rows = result.get("rows", [])
        rows = [[r.get(c) for c in columns] for r in raw_rows]

        return {
            "columns": columns,
            "rows": rows,
            "row_count": len(rows),
            "duration_ms": result.get("duration_ms", int((time.time() - t0) * 1000)),
        }

    def info(self) -> dict:
        return {"dsn": self._dsn, "schema": self._schema}

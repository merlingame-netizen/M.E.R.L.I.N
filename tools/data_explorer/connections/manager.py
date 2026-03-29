"""DataService protocol — shared interface for EDH and BigQuery connections."""

from __future__ import annotations

from typing import Any, Protocol


class DataService(Protocol):
    """Interface every data source must implement."""

    def connect(self, **kwargs: Any) -> dict:
        """Establish connection. Returns {connected: bool, info: str}."""
        ...

    def disconnect(self) -> None:
        """Close the connection."""
        ...

    def is_connected(self) -> bool:
        ...

    def list_tables(self, database: str = "", filter_: str = "") -> list[dict]:
        """Return [{name, type?}]."""
        ...

    def describe_table(self, table: str) -> dict:
        """Return {columns: [{name, type, mode?}]}."""
        ...

    def sample(self, table: str, columns: list[str] | None = None, limit: int = 20) -> dict:
        """Return {columns: [str], rows: [[any]], duration_ms: int}."""
        ...

    def execute(self, sql: str, limit: int = 10_000) -> dict:
        """Execute SQL. Return {columns, rows, row_count, duration_ms}."""
        ...

    def info(self) -> dict:
        """Return connection metadata."""
        ...

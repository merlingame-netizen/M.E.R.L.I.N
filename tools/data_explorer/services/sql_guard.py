"""SQL safety guard — block destructive queries, enforce LIMIT on EDH, validate identifiers."""

from __future__ import annotations

import re

# Valid SQL identifier: letters, digits, underscores, dots, backticks, hyphens
_IDENT_RE = re.compile(r"^[A-Za-z0-9_.`\-]+$")

# Destructive SQL keywords (blocked on all sources, matched anywhere in query)
_DESTRUCTIVE_KEYWORDS = [
    "DROP", "DELETE", "TRUNCATE", "ALTER", "INSERT", "UPDATE", "CREATE",
    "GRANT", "REVOKE", "LOAD DATA", "MSCK REPAIR", "MERGE",
]
_DESTRUCTIVE_PATTERNS = [
    re.compile(r"\b" + re.escape(kw) + r"\b", re.IGNORECASE)
    for kw in _DESTRUCTIVE_KEYWORDS
]

# Tez-incompatible aggregations (blocked on EDH only)
_TEZ_BLOCKED_PATTERNS = [
    re.compile(r"\bCOUNT\s*\(", re.IGNORECASE),
    re.compile(r"\bGROUP\s+BY\b", re.IGNORECASE),
    re.compile(r"\bDISTINCT\b", re.IGNORECASE),
]


def safe_identifier(value: str, label: str = "identifiant") -> str:
    """Validate that a value is a safe SQL identifier. Raises ValueError if not."""
    if not value or not _IDENT_RE.match(value):
        raise ValueError(f"Identifiant invalide pour {label}: {value!r}")
    return value


def safe_column_list(columns: list[str]) -> list[str]:
    """Validate a list of column names. Raises ValueError on any invalid name."""
    return [safe_identifier(c.strip(), "colonne") for c in columns if c.strip()]


def validate_sql(sql: str, source: str = "edh") -> tuple[str, str | None]:
    """Validate and optionally transform SQL.

    Returns:
        (cleaned_sql, error_message)
        If error_message is not None, the query MUST be rejected.
    """
    stripped = sql.strip()
    if not stripped:
        return stripped, "Requete vide"

    # Block multi-statement queries (semicolon not at end)
    core = stripped.rstrip(";").strip()
    if ";" in core:
        return stripped, "Requetes multi-statement interdites (pas de ';' au milieu)"

    # Block destructive SQL anywhere in the query (not just at start)
    for pattern in _DESTRUCTIVE_PATTERNS:
        match = pattern.search(stripped)
        if match:
            return stripped, f"SQL destructif bloque : {match.group()}"

    # EDH-specific checks
    if source == "edh":
        for pattern in _TEZ_BLOCKED_PATTERNS:
            if pattern.search(stripped):
                return stripped, (
                    "Aggregation (COUNT/GROUP BY/DISTINCT) interdite sur EDH (Tez crash). "
                    "Extrayez les donnees brutes et agregez dans l'onglet Graphiques."
                )

        # Enforce LIMIT on EDH
        if not re.search(r"\bLIMIT\s+\d+", stripped, re.IGNORECASE):
            from config import DEFAULT_LIMIT_EDH
            stripped = f"{core} LIMIT {DEFAULT_LIMIT_EDH}"

    return stripped, None


def enforce_max_rows(sql: str, max_rows: int) -> str:
    """Ensure SQL has a LIMIT not exceeding max_rows."""
    match = re.search(r"\bLIMIT\s+(\d+)", sql, re.IGNORECASE)
    if match:
        current = int(match.group(1))
        if current > max_rows:
            sql = sql[:match.start(1)] + str(max_rows) + sql[match.end(1):]
    return sql

"""Extract structured intelligence from raw communication messages (Outlook, Teams, Calendar)."""
from __future__ import annotations

import os
import re
from datetime import datetime, timezone

__all__ = ["extract_intelligence", "format_digest", "update_digest_file"]

# ---------------------------------------------------------------------------
# Pattern banks (FR + EN, case-insensitive)
# ---------------------------------------------------------------------------
_ACTION_RE = re.compile(
    r"(?:a faire|merci de|prochaines etapes|peux-tu|pourriez-vous|il faudrait"
    r"|n'oublie pas|rappel|urgent"
    r"|TODO|action item|please|could you|next steps|follow.?up"
    r"|don't forget|reminder|ASAP)",
    re.IGNORECASE,
)

_DECISION_RE = re.compile(
    r"(?:on valide|c'est decid[eé]|approuv[eé]|go pour|valid[eé]e?"
    r"|retenu|on part sur|on garde|on supprime|on arrete"
    r"|decided|approved|go ahead|confirmed|we'll go with"
    r"|let's proceed|signed off|greenlight)",
    re.IGNORECASE,
)

_DEADLINE_TRIGGER_RE = re.compile(
    r"(?:avant le|pour le|d'ici|au plus tard|deadline|echeance|date limite|livraison le"
    r"|by|due|deadline|no later than|deliver by|target date|ETA)",
    re.IGNORECASE,
)
_DATE_NEARBY_RE = re.compile(
    r"\d{1,2}[/\-\.]\d{1,2}(?:[/\-\.]\d{2,4})?"
    r"|(?:janv|fevr|mars|avri|mai|juin|juil|aout|sept|octo|nove|dece"
    r"|jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*",
    re.IGNORECASE,
)

_KEY_SUBJECT_RE = re.compile(r"(?:URGENT|IMPORTANT|FYI|INFO|ALERTE)", re.IGNORECASE)

_SNIPPET_RADIUS = 30


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _parse_date(date_str: str) -> str:
    """Convert various date formats to ISO date (YYYY-MM-DD)."""
    if not date_str:
        return datetime.now(timezone.utc).strftime("%Y-%m-%d")
    for fmt in ("%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%d %H:%M:%S%z",
                "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(date_str.strip(), fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _snippet(text: str, match: re.Match) -> str:
    """Return +-30 chars around a regex match."""
    start = max(0, match.start() - _SNIPPET_RADIUS)
    end = min(len(text), match.end() + _SNIPPET_RADIUS)
    return text[start:end].strip()


def _extract_people(msg: dict) -> list[str]:
    """Extract people list from message fields."""
    people: list[str] = []
    for key in ("from", "sender", "to"):
        val = msg.get(key)
        if val:
            people.extend(p.strip() for p in val.split(",") if p.strip())
    return people


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def extract_intelligence(messages: list[dict]) -> list[dict]:
    """Scan messages and return structured intelligence entries."""
    if not messages:
        return []

    entries: list[dict] = []
    for msg in messages:
        source = msg.get("source", "outlook")
        body = msg.get("body_preview") or msg.get("content") or ""
        subject = msg.get("subject", "")
        date = _parse_date(msg.get("date") or msg.get("timestamp", ""))
        people = _extract_people(msg)

        # --- Meeting (calendar item) ---
        if "start" in msg and "end" in msg:
            location = msg.get("location", "")
            attendees = msg.get("required_attendees", [])
            content = (
                f"{subject} — {msg['start']}-{msg['end']}, "
                f"{location or 'no location'}, {len(attendees)} participants"
            )
            entries.append({
                "type": "MEETING", "content": content, "source": source,
                "date": date, "people": people, "raw_match": "",
            })
            continue

        # --- Regex-based detection ---
        checks: list[tuple[str, re.Pattern]] = [
            ("ACTION", _ACTION_RE),
            ("DECISION", _DECISION_RE),
        ]
        for typ, pattern in checks:
            m = pattern.search(body)
            if m:
                raw = _snippet(body, m)
                label = f"Re: {subject} — \"{raw}\"" if subject else f"\"{raw}\""
                entries.append({
                    "type": typ, "content": label, "source": source,
                    "date": date, "people": people, "raw_match": raw,
                })

        # Deadline: trigger + nearby date
        dt_match = _DEADLINE_TRIGGER_RE.search(body)
        if dt_match and _DATE_NEARBY_RE.search(body):
            raw = _snippet(body, dt_match)
            label = f"Re: {subject} — \"{raw}\"" if subject else f"\"{raw}\""
            entries.append({
                "type": "DEADLINE", "content": label, "source": source,
                "date": date, "people": people, "raw_match": raw,
            })

        # KEY_INFO: high importance or subject keywords
        importance = msg.get("importance", 1)
        if importance == 2 or _KEY_SUBJECT_RE.search(subject):
            preview = (body[:80] + "...") if len(body) > 80 else body
            label = f"Re: {subject} — \"{preview}\"" if subject else f"\"{preview}\""
            entries.append({
                "type": "KEY_INFO", "content": label, "source": source,
                "date": date, "people": people, "raw_match": preview,
            })

    return entries


def format_digest(entries: list[dict]) -> str:
    """Format intelligence entries as grouped markdown."""
    if not entries:
        return ""

    by_date: dict[str, dict[str, list[dict]]] = {}
    for e in entries:
        d = e.get("date", "unknown")
        s = e.get("source", "unknown")
        by_date.setdefault(d, {}).setdefault(s, []).append(e)

    lines: list[str] = []
    for date_key in sorted(by_date.keys(), reverse=True):
        lines.append(f"\n## {date_key}\n")
        for src in sorted(by_date[date_key].keys()):
            lines.append(f"### {src.capitalize()}\n")
            for e in by_date[date_key][src]:
                person = e["people"][0] if e.get("people") else "unknown"
                lines.append(f"- [{e['type']}] {e['content']} (from: {person})")
            lines.append("")

    return "\n".join(lines)


def update_digest_file(digest_path: str, new_entries: list[dict]) -> int:
    """Merge new entries into the digest file. Return count of entries added."""
    if not new_entries:
        return 0

    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    frontmatter = (
        "---\n"
        "name: comms__digest\n"
        "description: Intelligence auto-extraite des communications Outlook et Teams"
        " (decisions, actions, deadlines, reunions, personnes cles)\n"
        "type: project\n"
        "auto_updated: true\n"
        f"last_sync: {now_iso}\n"
        "---\n\n"
        "# Communications Digest\n"
    )

    # Read existing content
    existing = ""
    try:
        with open(digest_path, "r", encoding="utf-8") as f:
            existing = f.read()
    except FileNotFoundError:
        existing = ""

    # Strip old frontmatter if present (robust regex)
    body = existing
    fm_match = re.match(r'^---\n.*?\n---\s*', body, re.DOTALL)
    if fm_match:
        body = body[fm_match.end():].strip()
        # Remove the heading line if present
        heading_match = re.match(r'^# Communications Digest\s*', body)
        if heading_match:
            body = body[heading_match.end():].strip()

    # Deduplicate: collect existing bullet contents
    existing_bullets = set()
    for line in body.splitlines():
        stripped = line.strip()
        if stripped.startswith("- ["):
            existing_bullets.add(stripped)

    # Filter new entries against existing
    unique_entries: list[dict] = []
    new_formatted = format_digest(new_entries)
    for line in new_formatted.splitlines():
        stripped = line.strip()
        if stripped.startswith("- [") and stripped in existing_bullets:
            continue
        if stripped.startswith("- ["):
            unique_entries.append(stripped)

    added = len(unique_entries)
    if added == 0:
        return 0

    # Combine body
    combined = body + "\n" + new_formatted if body else new_formatted

    # Trim to 500 lines
    all_lines = combined.splitlines()
    if len(all_lines) > 500:
        # Remove oldest date sections (at end since sorted reverse)
        all_lines = all_lines[:500]

    final = frontmatter + "\n".join(all_lines) + "\n"

    # Atomic write: write to temp then replace
    tmp_path = digest_path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(final)
    os.replace(tmp_path, digest_path)

    return added


# ---------------------------------------------------------------------------
# Demo
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    sample_messages = [
        {
            "subject": "Dashboard Q1",
            "from": "manager@orange.com",
            "to": "dev@orange.com",
            "date": "2026-03-15T10:00:00Z",
            "body_preview": "Bonjour, merci de finaliser le dashboard avant le 20/03. Urgent.",
            "importance": 2,
            "source": "outlook",
        },
        {
            "subject": "Migration BCV",
            "from": "lead@orange.com",
            "to": "team@orange.com",
            "date": "2026-03-15T11:30:00Z",
            "body_preview": "Apres discussion, on part sur la table v_fact pour la prod.",
            "importance": 1,
            "source": "outlook",
        },
        {
            "sender": "Sophie Martin",
            "content": "Dataset IPSOS livre, vous pouvez lancer le traitement.",
            "timestamp": "2026-03-15T14:00:00Z",
            "source": "teams",
            "channel": "#data-team",
        },
        {
            "subject": "Comite Data VOC",
            "from": "orga@orange.com",
            "date": "2026-03-15T09:00:00Z",
            "body_preview": "",
            "importance": 1,
            "source": "outlook",
            "start": "14:00",
            "end": "15:00",
            "location": "Salle Teams",
            "required_attendees": ["a@o.com", "b@o.com", "c@o.com", "d@o.com", "e@o.com"],
        },
    ]

    results = extract_intelligence(sample_messages)
    print(f"Extracted {len(results)} intelligence entries:\n")
    for r in results:
        print(f"  [{r['type']}] {r['content']}")

    print("\n--- Digest ---")
    print(format_digest(results))

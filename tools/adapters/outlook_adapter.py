"""Outlook adapter — COM automation for Microsoft Outlook desktop via win32com."""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from adapters.base_adapter import BaseAdapter


class OutlookAdapter(BaseAdapter):
    """CLI adapter for Microsoft Outlook desktop (mail, calendar, contacts).

    Uses win32com COM automation. Requires Outlook desktop to be running.
    NEVER calls .Send() on any mail item — always .Display() only.
    """

    def __init__(self) -> None:
        super().__init__(tool_name="outlook")
        self._items_cache: list[Any] = []

    # ── Connection ─────────────────────────────────────────────────────────

    def _connect(self) -> tuple[tuple[Any, Any] | None, dict | None]:
        """Return ((app, namespace), None) or (None, error_dict)."""
        try:
            import win32com.client
        except ImportError:
            return None, self.error("pywin32 not installed. Run: pip install pywin32")
        try:
            app = win32com.client.Dispatch("Outlook.Application")
            ns = app.GetNamespace("MAPI")
            return (app, ns), None
        except Exception as exc:
            return None, self.error(
                f"Outlook COM unavailable. Open Outlook desktop and retry. Detail: {exc}"
            )

    # ── BaseAdapter contract ───────────────────────────────────────────────

    def health_probe(self) -> tuple[str, dict]:
        return ("folders", {})

    def list_actions(self) -> dict[str, str]:
        return {
            "inbox": "List inbox messages (--limit=10)",
            "sent": "List sent messages (--limit=10)",
            "search": "Search inbox (--query, --from_addr, --since, --limit=20)",
            "read": "Read message by index (--index=0, --folder=inbox)",
            "send": "Compose draft (--to, --subject, --body, --cc, --bcc, --importance, --attachments)",
            "reply": "Reply to message (--index=0, --body, --reply_all=False)",
            "forward": "Forward message (--index=0, --to, --body)",
            "calendar-today": "Today's calendar events",
            "calendar-week": "This week's calendar events",
            "calendar-search": "Search calendar (--query, --limit=10)",
            "contacts-search": "Search contacts (--query)",
            "folders": "List mail folders",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch = {
            "inbox": self._inbox,
            "sent": self._sent,
            "search": self._search,
            "read": self._read,
            "send": self._send,
            "reply": self._reply,
            "forward": self._forward,
            "calendar-today": self._calendar_today,
            "calendar-week": self._calendar_week,
            "calendar-search": self._calendar_search,
            "contacts-search": self._contacts_search,
            "folders": self._folders,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError(action)
        return handler(**kwargs)

    # ── Mail actions ───────────────────────────────────────────────────────

    def _inbox(self, limit: int | str = 10, **_: Any) -> dict:
        conn, err = self._connect()
        if err:
            return err
        _app, ns = conn
        limit = int(limit)
        folder = ns.GetDefaultFolder(6)
        items = folder.Items
        items.Sort("[ReceivedTime]", True)
        messages = []
        self._items_cache = []
        for i, item in enumerate(items):
            if i >= limit:
                break
            self._items_cache.append(item)
            messages.append(self._format_message(item))
        self.log(f"Fetched {len(messages)} inbox messages")
        return self.ok({"messages": messages, "count": len(messages)})

    def _sent(self, limit: int | str = 10, **_: Any) -> dict:
        conn, err = self._connect()
        if err:
            return err
        _app, ns = conn
        limit = int(limit)
        folder = ns.GetDefaultFolder(5)
        items = folder.Items
        items.Sort("[ReceivedTime]", True)
        messages = []
        self._items_cache = []
        for i, item in enumerate(items):
            if i >= limit:
                break
            self._items_cache.append(item)
            messages.append(self._format_message(item))
        self.log(f"Fetched {len(messages)} sent messages")
        return self.ok({"messages": messages, "count": len(messages)})

    def _search(
        self,
        query: str = "",
        from_addr: str = "",
        since: str = "",
        limit: int | str = 20,
        **_: Any,
    ) -> dict:
        if not query and not from_addr and not since:
            return self.error("At least one of --query, --from_addr, or --since is required")
        conn, err = self._connect()
        if err:
            return err
        _app, ns = conn
        limit = int(limit)

        parts: list[str] = []
        if query:
            safe_q = query.replace("'", "''")
            parts.append(
                f"\"urn:schemas:httpmail:subject\" LIKE '%{safe_q}%'"
                f" OR \"urn:schemas:httpmail:textdescription\" LIKE '%{safe_q}%'"
            )
        if from_addr:
            safe_f = from_addr.replace("'", "''")
            parts.append(f"\"urn:schemas:httpmail:fromemail\" LIKE '%{safe_f}%'")
        if since:
            import re as _re
            safe_since = since.replace("'", "''")
            if not _re.match(r'^\d{4}-\d{2}-\d{2}', safe_since):
                return self.error(f"Invalid --since format: expected YYYY-MM-DD, got {since!r}")
            parts.append(f"\"urn:schemas:httpmail:datereceived\" >= '{safe_since}'")

        dasl_filter = "@SQL=" + " AND ".join(
            f"({p})" if " OR " in p else p for p in parts
        )

        folder = ns.GetDefaultFolder(6)
        items = folder.Items.Restrict(dasl_filter)
        messages = []
        self._items_cache = []
        for i, item in enumerate(items):
            if i >= limit:
                break
            self._items_cache.append(item)
            messages.append(self._format_message(item))
        self.log(f"Search returned {len(messages)} results")
        return self.ok({"messages": messages, "count": len(messages)})

    def _read(self, index: int | str = 0, folder: str = "inbox", **_: Any) -> dict:
        index = int(index)
        if not self._items_cache:
            return self.error(
                "No cached items. Run inbox, sent, or search first to populate the cache."
            )
        if index < 0 or index >= len(self._items_cache):
            return self.error(
                f"Index {index} out of range. Cache has {len(self._items_cache)} items (0-{len(self._items_cache) - 1})."
            )
        item = self._items_cache[index]
        msg = self._format_message(item)
        self.log(f"Read message at index {index}: {msg.get('subject', '')}")
        return self.ok(msg)

    def _send(
        self,
        to: str = "",
        subject: str = "",
        body: str = "",
        cc: str = "",
        bcc: str = "",
        importance: int | str = 1,
        attachments: str = "",
        **_: Any,
    ) -> dict:
        if not to:
            return self.error("--to is required")
        if not subject:
            return self.error("--subject is required")
        conn, err = self._connect()
        if err:
            return err
        app, _ns = conn
        importance = int(importance)

        mail = app.CreateItem(0)
        mail.To = to
        mail.Subject = subject
        mail.Body = body
        if cc:
            mail.CC = cc
        if bcc:
            mail.BCC = bcc
        mail.Importance = importance

        if attachments:
            from pathlib import Path as _Path
            for att_path in attachments.split(";"):
                att_path = att_path.strip()
                if att_path:
                    resolved = _Path(att_path).resolve()
                    if not resolved.is_file():
                        return self.error(f"Attachment not found: {att_path}")
                    mail.Attachments.Add(str(resolved))

        # CRITICAL: Display only, NEVER Send
        mail.Display()
        self.log(f"Draft opened for: {to} — {subject}")
        return self.ok({"status": "draft_opened", "to": to, "subject": subject})

    def _reply(
        self,
        index: int | str = 0,
        body: str = "",
        reply_all: bool | str = False,
        **_: Any,
    ) -> dict:
        index = int(index)
        if isinstance(reply_all, str):
            reply_all = reply_all.lower() in ("true", "1", "yes")

        if not self._items_cache:
            return self.error("No cached items. Run inbox, sent, or search first.")
        if index < 0 or index >= len(self._items_cache):
            return self.error(
                f"Index {index} out of range. Cache has {len(self._items_cache)} items."
            )

        item = self._items_cache[index]
        reply_item = item.ReplyAll() if reply_all else item.Reply()
        if body:
            reply_item.Body = body + "\n\n" + reply_item.Body
        reply_item.Display()
        self.log(f"Reply{'All' if reply_all else ''} opened for index {index}")
        return self.ok({
            "status": "draft_opened",
            "action": "reply_all" if reply_all else "reply",
            "original_subject": getattr(item, "Subject", "") or "",
        })

    def _forward(
        self,
        index: int | str = 0,
        to: str = "",
        body: str = "",
        **_: Any,
    ) -> dict:
        index = int(index)
        if not to:
            return self.error("--to is required for forwarding")
        if not self._items_cache:
            return self.error("No cached items. Run inbox, sent, or search first.")
        if index < 0 or index >= len(self._items_cache):
            return self.error(
                f"Index {index} out of range. Cache has {len(self._items_cache)} items."
            )

        item = self._items_cache[index]
        fwd = item.Forward()
        fwd.To = to
        if body:
            fwd.Body = body + "\n\n" + fwd.Body
        fwd.Display()
        self.log(f"Forward opened for index {index} to {to}")
        return self.ok({
            "status": "draft_opened",
            "action": "forward",
            "to": to,
            "original_subject": getattr(item, "Subject", "") or "",
        })

    # ── Calendar actions ───────────────────────────────────────────────────

    def _calendar_today(self, **_: Any) -> dict:
        return self._calendar_range(days=0)

    def _calendar_week(self, **_: Any) -> dict:
        return self._calendar_range(days=6)

    def _calendar_range(self, days: int) -> dict:
        conn, err = self._connect()
        if err:
            return err
        _app, ns = conn

        now = datetime.now()
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        end = start + timedelta(days=days + 1)

        start_str = start.strftime("%m/%d/%Y %I:%M %p")
        end_str = end.strftime("%m/%d/%Y %I:%M %p")

        folder = ns.GetDefaultFolder(9)
        items = folder.Items
        items.IncludeRecurrences = True
        items.Sort("[Start]")
        restriction = f"[Start] >= '{start_str}' AND [End] <= '{end_str}'"
        filtered = items.Restrict(restriction)

        events = []
        for item in filtered:
            events.append(self._format_calendar_item(item))
        label = "today" if days == 0 else f"next {days + 1} days"
        self.log(f"Found {len(events)} calendar events for {label}")
        return self.ok({"events": events, "count": len(events), "range": label})

    def _calendar_search(self, query: str = "", limit: int | str = 10, **_: Any) -> dict:
        if not query:
            return self.error("--query is required")
        conn, err = self._connect()
        if err:
            return err
        _app, ns = conn
        limit = int(limit)

        safe_q = query.replace("'", "''")
        dasl = f"@SQL=\"urn:schemas:httpmail:subject\" LIKE '%{safe_q}%'"

        folder = ns.GetDefaultFolder(9)
        items = folder.Items
        items.IncludeRecurrences = True
        items.Sort("[Start]")
        filtered = items.Restrict(dasl)

        events = []
        for i, item in enumerate(filtered):
            if i >= limit:
                break
            events.append(self._format_calendar_item(item))
        self.log(f"Calendar search '{query}' returned {len(events)} results")
        return self.ok({"events": events, "count": len(events)})

    # ── Contacts action ────────────────────────────────────────────────────

    def _contacts_search(self, query: str = "", **_: Any) -> dict:
        if not query:
            return self.error("--query is required")
        conn, err = self._connect()
        if err:
            return err
        _app, ns = conn

        safe_q = query.replace("'", "''")
        dasl = (
            f"@SQL=\"urn:schemas:contacts:cn\" LIKE '%{safe_q}%'"
            f" OR \"urn:schemas:contacts:email1\" LIKE '%{safe_q}%'"
        )

        folder = ns.GetDefaultFolder(10)
        filtered = folder.Items.Restrict(dasl)

        contacts = []
        for item in filtered:
            contacts.append({
                "full_name": getattr(item, "FullName", "") or "",
                "email": getattr(item, "Email1Address", "") or "",
                "company": getattr(item, "CompanyName", "") or "",
                "job_title": getattr(item, "JobTitle", "") or "",
                "phone": getattr(item, "BusinessTelephoneNumber", "") or "",
            })
        self.log(f"Contacts search '{query}' returned {len(contacts)} results")
        return self.ok({"contacts": contacts, "count": len(contacts)})

    # ── Folders action ─────────────────────────────────────────────────────

    def _folders(self, **_: Any) -> dict:
        conn, err = self._connect()
        if err:
            return err
        _app, ns = conn

        root = ns.GetDefaultFolder(6).Parent
        folders = []
        for folder in root.Folders:
            try:
                name = getattr(folder, "Name", "") or ""
                count = getattr(folder, "Items", None)
                count = count.Count if count is not None else 0
            except Exception:
                name = str(folder)
                count = 0
            folders.append({"name": name, "count": count})
        self.log(f"Found {len(folders)} top-level folders")
        return self.ok({"folders": folders, "count": len(folders)})

    # ── Formatting helpers ─────────────────────────────────────────────────

    def _format_message(self, item: Any) -> dict:
        try:
            attachments = [
                item.Attachments.Item(i + 1).FileName
                for i in range(item.Attachments.Count)
            ]
        except Exception:
            attachments = []
        try:
            body = (item.Body or "")[:500]
        except Exception:
            body = ""
        try:
            categories = [
                c.strip() for c in (item.Categories or "").split(",") if c.strip()
            ]
        except Exception:
            categories = []
        # Prefer SenderName over Exchange DN addresses
        sender_name = getattr(item, "SenderName", "") or ""
        sender_email = getattr(item, "SenderEmailAddress", "") or ""
        if sender_email.startswith("/O=") or not sender_email:
            from_field = sender_name or sender_email
        elif sender_name:
            from_field = f"{sender_name} <{sender_email}>"
        else:
            from_field = sender_email

        return {
            "subject": getattr(item, "Subject", "") or "",
            "from": from_field,
            "to": getattr(item, "To", "") or "",
            "cc": getattr(item, "CC", "") or "",
            "date": str(getattr(item, "ReceivedTime", "") or ""),
            "body_preview": body,
            "has_attachments": bool(attachments),
            "attachment_names": attachments,
            "importance": getattr(item, "Importance", 1),
            "categories": categories,
        }

    def _format_calendar_item(self, item: Any) -> dict:
        try:
            required = (item.RequiredAttendees or "").split(";")
            required = [a.strip() for a in required if a.strip()]
        except Exception:
            required = []
        try:
            optional = (item.OptionalAttendees or "").split(";")
            optional = [a.strip() for a in optional if a.strip()]
        except Exception:
            optional = []
        return {
            "subject": getattr(item, "Subject", "") or "",
            "start": str(getattr(item, "Start", "") or ""),
            "end": str(getattr(item, "End", "") or ""),
            "location": getattr(item, "Location", "") or "",
            "organizer": getattr(item, "Organizer", "") or "",
            "required_attendees": required,
            "optional_attendees": optional,
            "is_recurring": bool(getattr(item, "IsRecurring", False)),
            "body_preview": (getattr(item, "Body", "") or "")[:200],
        }

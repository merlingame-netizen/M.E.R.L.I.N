"""OneNote adapter — full headless CLI for Microsoft OneNote via COM API.

Uses comtypes vtable-based early binding (NOT win32com IDispatch) because
the OneNote type library is not properly registered for late binding on
many corporate Windows installations.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET  # noqa: N817
from datetime import datetime
from pathlib import Path
from typing import Any


from adapters.base_adapter import BaseAdapter

# ── Constants ────────────────────────────────────────────────────────────────

_COMTYPES_MISSING = "comtypes not installed. Run: pip install comtypes"
_ONENOTE_CLOSED = (
    "OneNote COM unavailable. Open Microsoft OneNote desktop and retry."
)

_ONENOTE_NS_2013 = "http://schemas.microsoft.com/office/onenote/2013/onenote"

# OneNote EXE candidates for typelib loading (resource #3)
_ONENOTE_EXE_CANDIDATES = [
    r"C:\Program Files\Microsoft Office\Root\Office16\ONENOTE.EXE",
    r"C:\Program Files (x86)\Microsoft Office\Root\Office16\ONENOTE.EXE",
    r"C:\Program Files\Microsoft Office\Office16\ONENOTE.EXE",
    r"C:\Program Files (x86)\Microsoft Office\Office16\ONENOTE.EXE",
    r"C:\Program Files\Microsoft Office\Office15\ONENOTE.EXE",
]


def _find_onenote_exe() -> str:
    """Probe known paths and registry for ONENOTE.EXE location."""
    import os

    for candidate in _ONENOTE_EXE_CANDIDATES:
        if os.path.isfile(candidate):
            return candidate
    # Fallback: check Windows Registry
    try:
        import winreg

        key_path = r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OneNote.exe"
        for hive in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
            try:
                with winreg.OpenKey(hive, key_path) as key:
                    exe_path, _ = winreg.QueryValueEx(key, "")
                    if exe_path and os.path.isfile(exe_path):
                        return exe_path
            except OSError:
                continue
    except ImportError:
        pass
    # Last resort: first candidate (will fail with clear error at typelib load)
    return _ONENOTE_EXE_CANDIDATES[0]

# HierarchyScope enum (from comtypes-generated module)
# hsSelf=0, hsChildren=1, hsNotebooks=2, hsSections=3, hsPages=4
_HS_SELF = 0
_HS_CHILDREN = 1
_HS_NOTEBOOKS = 2
_HS_SECTIONS = 3
_HS_PAGES = 4

# PublishFormat enum
_PUBLISH_FORMATS: dict[str, int] = {
    "onenote": 0,
    "package": 1,
    "mhtml": 2,
    "pdf": 3,
    "xps": 4,
    "word": 5,
    "emf": 6,
    "html": 7,
    "onenote07": 8,
}

# SpecialLocation enum
_SPECIAL_LOCATIONS: dict[str, int] = {
    "backup": 0,
    "unfiled_notes": 1,
    "default_notebook": 2,
}

# Default file extensions per format
_FORMAT_EXTENSIONS: dict[str, str] = {
    "pdf": ".pdf",
    "xps": ".xps",
    "word": ".docx",
    "emf": ".emf",
    "html": ".html",
    "mhtml": ".mhtml",
    "onenote": ".one",
    "onenote07": ".one",
    "package": ".onepkg",
}

# Module-level cache for the comtypes-generated interface module
_iface_module = None


def _cdata_escape(text: str) -> str:
    """Escape ]]> sequences inside text destined for CDATA sections."""
    return text.replace("]]>", "]]]]><![CDATA[>")


def _get_iface_module():
    """Load and cache the comtypes-generated OneNote interface module."""
    global _iface_module  # noqa: PLW0603
    if _iface_module is not None:
        return _iface_module
    import comtypes.client  # noqa: PLC0415
    import comtypes.typeinfo  # noqa: PLC0415
    exe_path = _find_onenote_exe()
    tlb = comtypes.typeinfo.LoadTypeLibEx(exe_path + "\\3")
    _iface_module = comtypes.client.GetModule(tlb)
    return _iface_module


# ── Adapter ──────────────────────────────────────────────────────────────────


class OneNoteAdapter(BaseAdapter):
    """
    Full-featured headless OneNote CLI via COM (comtypes vtable binding).

    Requires: OneNote desktop running + comtypes.
    24 actions: hierarchy, CRUD, search, export, sync, navigation, links.
    """

    def __init__(self) -> None:
        super().__init__("onenote")

    # ── Action registry ──────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            # Hierarchy
            "notebooks":        "List all open notebooks",
            "section-groups":   "List section groups (kwargs: notebook=None)",
            "sections":         "List sections (kwargs: notebook=None)",
            "pages":            "List pages in a section (kwargs: section)",
            "tree":             "Full hierarchy tree (kwargs: notebook=None, depth=3)",
            # Page CRUD
            "read":             "Read page as plain text (kwargs: page_id or title)",
            "read-xml":         "Read raw OneNote XML (kwargs: page_id)",
            "create":           "Create page (kwargs: section, title, body_html)",
            "append":           "Append HTML to page (kwargs: page_id/title, body_html)",
            "update":           "Replace page XML (kwargs: page_id, page_xml)",
            "delete":           "Delete a page (kwargs: page_id or title)",
            # Section CRUD
            "create-section":   "Create section (kwargs: notebook, name)",
            "delete-section":   "Delete section (kwargs: section)",
            "rename-section":   "Rename section (kwargs: section, new_name)",
            # Search
            "search":           "Full-text search (kwargs: query, notebook=None)",
            "recent":           "Recently modified pages (kwargs: limit=20, notebook=None)",
            # Export
            "export":           "Export to PDF/HTML/Word (kwargs: id, format=pdf, output)",
            # Navigation & Links
            "navigate":         "Open page in OneNote UI (kwargs: page_id/title)",
            "get-link":         "Get onenote:// hyperlink (kwargs: page_id/title)",
            # Sync
            "sync":             "Force sync (kwargs: notebook=None)",
            # Special
            "special-locations": "Get backup/unfiled/default paths",
            # Notebook management
            "open-notebook":    "Open notebook from path (kwargs: path)",
            "close-notebook":   "Close notebook (kwargs: notebook)",
            # Metadata
            "page-info":        "Page metadata (kwargs: page_id/title)",
        }

    # ── Dispatch ─────────────────────────────────────────────────────────

    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch: dict[str, Any] = {
            "notebooks":        self._notebooks,
            "section-groups":   self._section_groups,
            "sections":         self._sections,
            "pages":            self._pages,
            "tree":             self._tree,
            "read":             self._read,
            "read-xml":         self._read_xml,
            "create":           self._create,
            "append":           self._append,
            "update":           self._update,
            "delete":           self._delete_page,
            "create-section":   self._create_section,
            "delete-section":   self._delete_section,
            "rename-section":   self._rename_section,
            "search":           self._search,
            "recent":           self._recent,
            "export":           self._export,
            "navigate":         self._navigate,
            "get-link":         self._get_link,
            "sync":             self._sync,
            "special-locations": self._special_locations,
            "open-notebook":    self._open_notebook,
            "close-notebook":   self._close_notebook,
            "page-info":        self._page_info,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError
        return handler(**kwargs)

    def health_probe(self) -> tuple[str, dict]:
        return "notebooks", {}

    # ── COM connection ───────────────────────────────────────────────────

    def _connect(self):
        """Return (onenote_app, None) or (None, error_dict).

        Uses comtypes vtable-based early binding via the IApplication interface
        loaded from the OneNote type library embedded in ONENOTE.EXE resource #3.
        """
        try:
            import comtypes.client  # noqa: PLC0415
        except ImportError:
            return None, self.error(_COMTYPES_MISSING)
        try:
            mod = _get_iface_module()
            app = comtypes.client.CreateObject(
                "OneNote.Application",
                interface=mod.IApplication,
            )
            return app, None
        except OSError as exc:
            msg = str(exc)
            if "chargement" in msg.lower() or "loading" in msg.lower():
                return None, self.error(
                    f"Cannot load OneNote type library from {_ONENOTE_EXE}. "
                    "Ensure OneNote desktop (Office 365/2016+) is installed."
                )
            return None, self.error(f"{_ONENOTE_CLOSED} Detail: {exc}")
        except Exception as exc:
            return None, self.error(f"{_ONENOTE_CLOSED} Detail: {exc}")

    # ── Hierarchy ────────────────────────────────────────────────────────

    def _notebooks(self, **_) -> dict:
        app, err = self._connect()
        if err:
            return err
        self.log("Listing notebooks.")
        try:
            xml_str = app.GetHierarchy("", _HS_NOTEBOOKS)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            notebooks = []
            for nb in root.findall(f"{ns}Notebook"):
                notebooks.append({
                    "id": nb.get("ID", ""),
                    "name": nb.get("name", ""),
                    "path": nb.get("path", ""),
                    "is_currently_viewed": nb.get("isCurrentlyViewed", "false") == "true",
                    "color": nb.get("color", ""),
                })
        except Exception as exc:
            return self.error(f"Failed to list notebooks: {exc}")
        return self.ok({"notebooks": notebooks, "count": len(notebooks)})

    def _section_groups(self, notebook: str | None = None, **_) -> dict:
        app, err = self._connect()
        if err:
            return err
        self.log(f"Listing section groups (notebook={notebook}).")
        try:
            start = ""
            if notebook:
                start = _resolve_notebook_id(app, notebook)
                if not start:
                    return self.error(f"Notebook not found: {notebook}")
            xml_str = app.GetHierarchy(start, _HS_CHILDREN)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            groups = []
            for sg in root.iter(f"{ns}SectionGroup"):
                if sg.get("isRecycleBin", "false") == "true":
                    continue
                groups.append({
                    "id": sg.get("ID", ""),
                    "name": sg.get("name", ""),
                    "path": sg.get("path", ""),
                })
        except Exception as exc:
            return self.error(f"Failed to list section groups: {exc}")
        return self.ok({"section_groups": groups, "count": len(groups)})

    def _sections(self, notebook: str | None = None, **_) -> dict:
        app, err = self._connect()
        if err:
            return err
        self.log(f"Listing sections (notebook={notebook}).")
        try:
            start = ""
            if notebook:
                start = _resolve_notebook_id(app, notebook)
                if not start:
                    return self.error(f"Notebook not found: {notebook}")
            xml_str = app.GetHierarchy(start, _HS_SECTIONS)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            sections = []
            for sec in root.iter(f"{ns}Section"):
                sections.append({
                    "id": sec.get("ID", ""),
                    "name": sec.get("name", ""),
                    "path": sec.get("path", ""),
                    "read_only": sec.get("readOnly", "false") == "true",
                    "color": sec.get("color", ""),
                })
        except Exception as exc:
            return self.error(f"Failed to list sections: {exc}")
        return self.ok({"sections": sections, "count": len(sections)})

    def _pages(self, section: str = "", **_) -> dict:
        if not section:
            return self.error("Missing required argument: section")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Listing pages in section: {section}")
        try:
            sec_id = _resolve_section_id(app, section)
            if not sec_id:
                return self.error(f"Section not found: {section}")
            xml_str = app.GetHierarchy(sec_id, _HS_PAGES)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            pages = _parse_pages(root, ns)
        except Exception as exc:
            return self.error(f"Failed to list pages: {exc}")
        return self.ok({"pages": pages, "count": len(pages)})

    def _tree(self, notebook: str | None = None, depth: int | str = 3, **_) -> dict:
        app, err = self._connect()
        if err:
            return err
        depth_int = int(depth)
        self.log(f"Building hierarchy tree (notebook={notebook}, depth={depth_int}).")
        try:
            start = ""
            if notebook:
                start = _resolve_notebook_id(app, notebook)
                if not start:
                    return self.error(f"Notebook not found: {notebook}")
            # Always fetch full pages scope for tree building
            xml_str = app.GetHierarchy(start, _HS_PAGES)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            tree = _build_tree(root, ns, depth_int)
        except Exception as exc:
            return self.error(f"Failed to build tree: {exc}")
        return self.ok({"tree": tree})

    # ── Page CRUD ────────────────────────────────────────────────────────

    def _read(self, page_id: str = "", title: str = "", **_) -> dict:
        if not page_id and not title:
            return self.error("Provide page_id or title")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Reading page: {page_id or title}")
        try:
            pid = page_id or _resolve_page_id(app, title)
            if not pid:
                return self.error(f"Page not found: {title}")
            xml_str = app.GetPageContent(pid, 0)
            root = ET.fromstring(xml_str)
            text_parts = [t.strip() for t in root.itertext() if t.strip()]
            content = "\n".join(text_parts)
        except Exception as exc:
            return self.error(f"Failed to read page: {exc}")
        return self.ok({
            "page_id": pid,
            "title": title,
            "content": content,
            "char_count": len(content),
        })

    def _read_xml(self, page_id: str = "", **_) -> dict:
        if not page_id:
            return self.error("Missing required argument: page_id")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Reading raw XML for page: {page_id}")
        try:
            xml_str = app.GetPageContent(page_id, 0)
        except Exception as exc:
            return self.error(f"Failed to read page XML: {exc}")
        return self.ok({"page_id": page_id, "xml": xml_str})

    def _create(self, section: str = "", title: str = "New Page",
                body_html: str = "", **_) -> dict:
        if not section:
            return self.error("Missing required argument: section")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Creating page '{title}' in section: {section}")
        try:
            sec_id = _resolve_section_id(app, section)
            if not sec_id:
                return self.error(f"Section not found: {section}")
            # CreateNewPage returns the new page ID (comtypes out-param)
            new_page_id = app.CreateNewPage(sec_id, 0)
            if new_page_id and (title != "New Page" or body_html):
                ns_uri = _ONENOTE_NS_2013
                page_xml = (
                    f'<?xml version="1.0"?>'
                    f'<one:Page xmlns:one="{ns_uri}" ID="{new_page_id}">'
                    f'<one:Title><one:OE><one:T><![CDATA[{_cdata_escape(title)}]]></one:T></one:OE></one:Title>'
                )
                if body_html:
                    page_xml += (
                        '<one:Outline><one:OEChildren><one:OE>'
                        f'<one:T><![CDATA[{_cdata_escape(body_html)}]]></one:T>'
                        '</one:OE></one:OEChildren></one:Outline>'
                    )
                page_xml += '</one:Page>'
                app.UpdatePageContent(page_xml, datetime(1, 1, 1))
        except Exception as exc:
            return self.error(f"Failed to create page: {exc}")
        return self.ok({
            "page_id": new_page_id,
            "section": section,
            "title": title,
            "status": "created",
        })

    def _append(self, page_id: str = "", title: str = "",
                body_html: str = "", **_) -> dict:
        if not page_id and not title:
            return self.error("Provide page_id or title")
        if not body_html:
            return self.error("Missing required argument: body_html")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Appending content to page: {page_id or title}")
        try:
            pid = page_id or _resolve_page_id(app, title)
            if not pid:
                return self.error(f"Page not found: {title}")
            xml_str = app.GetPageContent(pid, 0)
            root = ET.fromstring(xml_str)
            ns_uri = _ns_uri(root)
            ns = f"{{{ns_uri}}}" if ns_uri else ""
            # Create new outline element
            outline = ET.SubElement(root, f"{ns}Outline")
            oe_children = ET.SubElement(outline, f"{ns}OEChildren")
            oe = ET.SubElement(oe_children, f"{ns}OE")
            t_elem = ET.SubElement(oe, f"{ns}T")
            t_elem.text = body_html
            updated_xml = ET.tostring(root, encoding="unicode", xml_declaration=True)
            app.UpdatePageContent(updated_xml, datetime(1, 1, 1))
        except Exception as exc:
            return self.error(f"Failed to append to page: {exc}")
        return self.ok({"page_id": pid, "status": "appended"})

    def _update(self, page_id: str = "", page_xml: str = "", **_) -> dict:
        if not page_id:
            return self.error("Missing required argument: page_id")
        if not page_xml:
            return self.error("Missing required argument: page_xml")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Updating page XML: {page_id}")
        try:
            app.UpdatePageContent(page_xml, datetime(1, 1, 1))
        except Exception as exc:
            return self.error(f"Failed to update page: {exc}")
        return self.ok({"page_id": page_id, "status": "updated"})

    def _delete_page(self, page_id: str = "", title: str = "", **_) -> dict:
        if not page_id and not title:
            return self.error("Provide page_id or title")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Deleting page: {page_id or title}")
        try:
            pid = page_id or _resolve_page_id(app, title)
            if not pid:
                return self.error(f"Page not found: {title}")
            app.DeleteHierarchy(pid, datetime(1, 1, 1))
        except Exception as exc:
            return self.error(f"Failed to delete page: {exc}")
        return self.ok({"page_id": pid, "status": "deleted"})

    # ── Section CRUD ─────────────────────────────────────────────────────

    def _create_section(self, notebook: str = "", name: str = "", **_) -> dict:
        if not notebook:
            return self.error("Missing required argument: notebook")
        if not name:
            return self.error("Missing required argument: name")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Creating section '{name}' in notebook: {notebook}")
        try:
            nb_id = _resolve_notebook_id(app, notebook)
            if not nb_id:
                return self.error(f"Notebook not found: {notebook}")
            xml_str = app.GetHierarchy(nb_id, _HS_NOTEBOOKS)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            nb_path = ""
            for nb in root.iter(f"{ns}Notebook"):
                if nb.get("ID") == nb_id:
                    nb_path = nb.get("path", "")
                    break
            if not nb_path:
                return self.error("Cannot determine notebook path")
            section_path = str(Path(nb_path) / f"{name}.one")
            # OpenHierarchy: returns new object ID (out-param)
            # cftSection = 3
            new_id = app.OpenHierarchy(section_path, nb_id, 3)
        except Exception as exc:
            return self.error(f"Failed to create section: {exc}")
        return self.ok({"section_id": new_id, "notebook": notebook, "name": name, "status": "created"})

    def _delete_section(self, section: str = "", **_) -> dict:
        if not section:
            return self.error("Missing required argument: section")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Deleting section: {section}")
        try:
            sec_id = _resolve_section_id(app, section)
            if not sec_id:
                return self.error(f"Section not found: {section}")
            app.DeleteHierarchy(sec_id, datetime(1, 1, 1))
        except Exception as exc:
            return self.error(f"Failed to delete section: {exc}")
        return self.ok({"section": section, "status": "deleted"})

    def _rename_section(self, section: str = "", new_name: str = "", **_) -> dict:
        if not section:
            return self.error("Missing required argument: section")
        if not new_name:
            return self.error("Missing required argument: new_name")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Renaming section '{section}' to '{new_name}'")
        try:
            sec_id = _resolve_section_id(app, section)
            if not sec_id:
                return self.error(f"Section not found: {section}")
            xml_str = app.GetHierarchy(sec_id, _HS_SELF)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            sec_elem = root if root.tag.endswith("Section") else None
            if sec_elem is None:
                for elem in root.iter():
                    if elem.get("ID") == sec_id:
                        sec_elem = elem
                        break
            if sec_elem is None:
                return self.error("Cannot locate section element in hierarchy XML")
            sec_elem.set("name", new_name)
            updated_xml = ET.tostring(root, encoding="unicode", xml_declaration=True)
            app.UpdateHierarchy(updated_xml)
        except Exception as exc:
            return self.error(f"Failed to rename section: {exc}")
        return self.ok({"section": section, "new_name": new_name, "status": "renamed"})

    # ── Search ───────────────────────────────────────────────────────────

    def _search(self, query: str = "", notebook: str | None = None, **_) -> dict:
        if not query:
            return self.error("Missing required argument: query")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Searching for: {query}")
        try:
            start = ""
            if notebook:
                start = _resolve_notebook_id(app, notebook)
                if not start:
                    return self.error(f"Notebook not found: {notebook}")
            # FindPages: comtypes returns the out-param (result XML)
            result_xml = app.FindPages(start, query, False)
            root = ET.fromstring(result_xml) if result_xml else None
            results = []
            if root is not None:
                ns = _ns(root)
                for page in root.iter(f"{ns}Page"):
                    results.append({
                        "id": page.get("ID", ""),
                        "name": page.get("name", ""),
                        "date_time": page.get("dateTime", ""),
                    })
        except Exception as exc:
            return self.error(f"Search failed: {exc}")
        return self.ok({"query": query, "results": results, "count": len(results)})

    def _recent(self, limit: int | str = 20, notebook: str | None = None, **_) -> dict:
        app, err = self._connect()
        if err:
            return err
        limit_int = int(limit)
        self.log(f"Fetching recent pages (limit={limit_int}).")
        try:
            start = ""
            if notebook:
                start = _resolve_notebook_id(app, notebook)
                if not start:
                    return self.error(f"Notebook not found: {notebook}")
            xml_str = app.GetHierarchy(start, _HS_PAGES)
            root = ET.fromstring(xml_str)
            ns = _ns(root)
            all_pages = []
            for page in root.iter(f"{ns}Page"):
                dt_str = page.get("lastModifiedTime", page.get("dateTime", ""))
                all_pages.append({
                    "id": page.get("ID", ""),
                    "name": page.get("name", ""),
                    "last_modified": dt_str,
                })
            all_pages.sort(key=lambda p: p["last_modified"], reverse=True)
            recent = all_pages[:limit_int]
        except Exception as exc:
            return self.error(f"Failed to fetch recent pages: {exc}")
        return self.ok({"pages": recent, "count": len(recent), "total": len(all_pages)})

    # ── Export ────────────────────────────────────────────────────────────

    def _export(self, id: str = "", format: str = "pdf",  # noqa: A002
                output: str = "", **_) -> dict:
        if not id:
            return self.error("Missing required argument: id (hierarchy ID)")
        fmt = format.lower()
        if fmt not in _PUBLISH_FORMATS:
            return self.error(f"Unknown format: {format}. Valid: {', '.join(_PUBLISH_FORMATS)}")
        app, err = self._connect()
        if err:
            return err
        out_path = output
        if not out_path:
            ext = _FORMAT_EXTENSIONS.get(fmt, f".{fmt}")
            out_path = str(Path.home() / "Downloads" / f"onenote_export{ext}")
        out_path = str(Path(out_path).resolve())
        self.log(f"Exporting {id} as {fmt} to {out_path}")
        try:
            app.Publish(id, out_path, _PUBLISH_FORMATS[fmt], "")
        except Exception as exc:
            return self.error(f"Export failed: {exc}")
        return self.ok({"id": id, "format": fmt, "output": out_path, "status": "exported"})

    # ── Navigation & Links ───────────────────────────────────────────────

    def _navigate(self, page_id: str = "", title: str = "", **_) -> dict:
        if not page_id and not title:
            return self.error("Provide page_id or title")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Navigating to: {page_id or title}")
        try:
            pid = page_id or _resolve_page_id(app, title)
            if not pid:
                return self.error(f"Page not found: {title}")
            app.NavigateTo(pid, "")
        except Exception as exc:
            return self.error(f"Navigation failed: {exc}")
        return self.ok({"page_id": pid, "status": "navigated"})

    def _get_link(self, page_id: str = "", title: str = "", **_) -> dict:
        if not page_id and not title:
            return self.error("Provide page_id or title")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Getting link for: {page_id or title}")
        try:
            pid = page_id or _resolve_page_id(app, title)
            if not pid:
                return self.error(f"Page not found: {title}")
            link = app.GetHyperlinkToObject(pid, "")
        except Exception as exc:
            return self.error(f"Failed to get link: {exc}")
        return self.ok({"page_id": pid, "link": link})

    # ── Sync ─────────────────────────────────────────────────────────────

    def _sync(self, notebook: str | None = None, **_) -> dict:
        app, err = self._connect()
        if err:
            return err
        target = "all notebooks"
        self.log(f"Syncing: {notebook or target}")
        try:
            start = ""
            if notebook:
                start = _resolve_notebook_id(app, notebook)
                if not start:
                    return self.error(f"Notebook not found: {notebook}")
            app.SyncHierarchy(start)
        except Exception as exc:
            return self.error(f"Sync failed: {exc}")
        return self.ok({"target": notebook or target, "status": "synced"})

    # ── Special Locations ────────────────────────────────────────────────

    def _special_locations(self, **_) -> dict:
        app, err = self._connect()
        if err:
            return err
        self.log("Fetching special locations.")
        locations = {}
        for name, code in _SPECIAL_LOCATIONS.items():
            try:
                path = app.GetSpecialLocation(code)
                locations[name] = path if isinstance(path, str) else str(path)
            except Exception:
                locations[name] = None
        return self.ok({"locations": locations})

    # ── Notebook Management ──────────────────────────────────────────────

    def _open_notebook(self, path: str = "", **_) -> dict:
        if not path:
            return self.error("Missing required argument: path")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Opening notebook: {path}")
        try:
            # cftNotebook = 1
            nb_id = app.OpenHierarchy(path, "", 1)
        except Exception as exc:
            return self.error(f"Failed to open notebook: {exc}")
        return self.ok({"path": path, "notebook_id": nb_id, "status": "opened"})

    def _close_notebook(self, notebook: str = "", **_) -> dict:
        if not notebook:
            return self.error("Missing required argument: notebook")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Closing notebook: {notebook}")
        try:
            nb_id = _resolve_notebook_id(app, notebook)
            if not nb_id:
                return self.error(f"Notebook not found: {notebook}")
            app.CloseNotebook(nb_id)
        except Exception as exc:
            return self.error(f"Failed to close notebook: {exc}")
        return self.ok({"notebook": notebook, "status": "closed"})

    # ── Page Info ────────────────────────────────────────────────────────

    def _page_info(self, page_id: str = "", title: str = "", **_) -> dict:
        if not page_id and not title:
            return self.error("Provide page_id or title")
        app, err = self._connect()
        if err:
            return err
        self.log(f"Getting page info: {page_id or title}")
        try:
            pid = page_id or _resolve_page_id(app, title)
            if not pid:
                return self.error(f"Page not found: {title}")
            xml_str = app.GetPageContent(pid, 0)
            root = ET.fromstring(xml_str)
            info = {
                "page_id": pid,
                "name": root.get("name", ""),
                "date_time": root.get("dateTime", ""),
                "last_modified_time": root.get("lastModifiedTime", ""),
                "page_level": root.get("pageLevel", "1"),
                "is_currently_viewed": root.get("isCurrentlyViewed", "false") == "true",
                "lang": root.get("lang", ""),
            }
            ns = _ns(root)
            info["outline_count"] = len(list(root.iter(f"{ns}Outline")))
            text_parts = [t.strip() for t in root.itertext() if t.strip()]
            info["word_count"] = sum(len(t.split()) for t in text_parts)
            info["char_count"] = sum(len(t) for t in text_parts)
        except Exception as exc:
            return self.error(f"Failed to get page info: {exc}")
        return self.ok(info)


# ── Private helpers ──────────────────────────────────────────────────────────


def _ns(root: ET.Element) -> str:
    """Extract XML namespace prefix string from root element tag."""
    tag = root.tag
    if tag.startswith("{"):
        return tag[:tag.index("}") + 1]
    return ""


def _ns_uri(root: ET.Element) -> str:
    """Extract raw namespace URI (without braces) from root element tag."""
    tag = root.tag
    if tag.startswith("{"):
        return tag[1:tag.index("}")]
    return ""


def _resolve_notebook_id(app: Any, name_or_id: str) -> str | None:
    """Find notebook ID by name or pass through if already an ID."""
    try:
        xml_str = app.GetHierarchy("", _HS_NOTEBOOKS)
        root = ET.fromstring(xml_str)
        ns = _ns(root)
        for nb in root.findall(f"{ns}Notebook"):
            if nb.get("ID") == name_or_id or nb.get("name") == name_or_id:
                return nb.get("ID")
    except Exception:
        pass
    return None


def _resolve_section_id(app: Any, name_or_id: str) -> str | None:
    """Find section ID by name or pass through if already an ID."""
    try:
        xml_str = app.GetHierarchy("", _HS_SECTIONS)
        root = ET.fromstring(xml_str)
        ns = _ns(root)
        for sec in root.iter(f"{ns}Section"):
            if sec.get("ID") == name_or_id or sec.get("name") == name_or_id:
                return sec.get("ID")
    except Exception:
        pass
    return None


def _resolve_page_id(app: Any, title: str) -> str | None:
    """Find page ID by title (searches all sections)."""
    try:
        xml_str = app.GetHierarchy("", _HS_PAGES)
        root = ET.fromstring(xml_str)
        ns = _ns(root)
        for page in root.iter(f"{ns}Page"):
            if page.get("name") == title:
                return page.get("ID")
    except Exception:
        pass
    return None


def _parse_pages(root: ET.Element, ns: str) -> list[dict]:
    """Parse Page elements from hierarchy XML into dicts."""
    pages = []
    for page in root.iter(f"{ns}Page"):
        pages.append({
            "id": page.get("ID", ""),
            "name": page.get("name", ""),
            "date_time": page.get("dateTime", ""),
            "last_modified": page.get("lastModifiedTime", ""),
            "page_level": page.get("pageLevel", "1"),
            "is_currently_viewed": page.get("isCurrentlyViewed", "false") == "true",
        })
    return pages


def _build_tree(root: ET.Element, ns: str, max_depth: int) -> list[dict]:
    """Build a nested hierarchy tree from XML."""
    tree = []
    tag_name = root.tag.split("}")[-1] if "}" in root.tag else root.tag

    if tag_name == "Notebooks":
        for nb in root.findall(f"{ns}Notebook"):
            tree.append(_tree_notebook(nb, ns, max_depth))
    elif tag_name == "Notebook":
        tree.append(_tree_notebook(root, ns, max_depth))
    else:
        tree.append({"type": tag_name.lower(), "name": root.get("name", ""), "id": root.get("ID", "")})
    return tree


def _tree_notebook(nb: ET.Element, ns: str, depth: int) -> dict:
    """Build tree node for a notebook."""
    node: dict[str, Any] = {
        "type": "notebook",
        "name": nb.get("name", ""),
        "id": nb.get("ID", ""),
        "children": [],
    }
    if depth < 1:
        return node
    for sg in nb.findall(f"{ns}SectionGroup"):
        if sg.get("isRecycleBin", "false") == "true":
            continue
        node["children"].append(_tree_section_group(sg, ns, depth - 1))
    for sec in nb.findall(f"{ns}Section"):
        node["children"].append(_tree_section(sec, ns, depth - 1))
    return node


def _tree_section_group(sg: ET.Element, ns: str, depth: int) -> dict:
    """Build tree node for a section group (recursive)."""
    node: dict[str, Any] = {
        "type": "section_group",
        "name": sg.get("name", ""),
        "id": sg.get("ID", ""),
        "children": [],
    }
    if depth < 1:
        return node
    for child_sg in sg.findall(f"{ns}SectionGroup"):
        if child_sg.get("isRecycleBin", "false") == "true":
            continue
        node["children"].append(_tree_section_group(child_sg, ns, depth - 1))
    for sec in sg.findall(f"{ns}Section"):
        node["children"].append(_tree_section(sec, ns, depth - 1))
    return node


def _tree_section(sec: ET.Element, ns: str, depth: int) -> dict:
    """Build tree node for a section."""
    node: dict[str, Any] = {
        "type": "section",
        "name": sec.get("name", ""),
        "id": sec.get("ID", ""),
        "children": [],
    }
    if depth < 1:
        return node
    for page in sec.findall(f"{ns}Page"):
        node["children"].append({
            "type": "page",
            "name": page.get("name", ""),
            "id": page.get("ID", ""),
            "level": page.get("pageLevel", "1"),
        })
    return node

"""PBIR Engine — Pure Python manipulation of PBI report.json visuals.

Ported from powerbi-dashboard-mcp/src/utils/pbir.ts.
Handles the critical PBI format quirk: config and filters stored as
stringified JSON inside report.json.

Key rule: DECORATIVE_TYPES (shape, textbox, basicShape, image, actionButton)
do NOT get vcObjects. Their styling comes from singleVisual.objects only.
"""

from __future__ import annotations

import copy
import json
import secrets
from pathlib import Path
from typing import Any


# ── Constants ────────────────────────────────────────────────────────────────

DECORATIVE_TYPES = frozenset({
    "basicShape", "textbox", "image", "shape", "actionButton",
})


# ── Helpers ──────────────────────────────────────────────────────────────────

def pbi_literal(value: str) -> dict:
    """Wrap a value in PBI's Literal expression format."""
    return {"expr": {"Literal": {"Value": value}}}


def pbi_color(hex_color: str) -> dict:
    """Build a PBI solid color expression."""
    return {"solid": {"color": pbi_literal(f"'{hex_color}'")}}


def generate_visual_id() -> str:
    """Generate a 20-char hex visual ID (matches pbir.ts generateVisualId)."""
    return secrets.token_hex(10)


def _deep_copy(obj: Any) -> Any:
    """Return a deep copy of an object."""
    return copy.deepcopy(obj)


# ── Report I/O ───────────────────────────────────────────────────────────────

def load_report(report_dir: str) -> dict:
    """Load and fully parse a PBI report.json.

    De-stringifies all nested JSON fields (config, filters, vc.config, vc.filters).
    Returns a fully parsed dict with nested dicts (not strings).

    CRITICAL: Preserves ALL keys from the original JSON — not just the ones we
    know about. This prevents silently dropping undocumented PBI metadata.
    """
    report_path = Path(report_dir) / "report.json"
    if not report_path.exists():
        raise FileNotFoundError(f"report.json not found at {report_path}")

    raw = json.loads(report_path.read_text(encoding="utf-8"))

    # Start with ALL top-level keys, then parse stringified fields
    report = dict(raw)
    report["config"] = _safe_json_parse(raw.get("config", "{}"))

    sections = []
    for s in raw.get("sections", []):
        # Preserve ALL section keys
        section = dict(s)
        section["config"] = _safe_json_parse(s.get("config", "{}"))
        section["filters"] = _safe_json_parse(s.get("filters", "[]"))

        vcs = []
        for vc in s.get("visualContainers", []):
            # Preserve ALL VC keys (not just the 8 we know)
            parsed_vc = dict(vc)
            parsed_vc["config"] = _safe_json_parse(vc.get("config", "{}"))
            parsed_vc["filters"] = _safe_json_parse(vc.get("filters", "[]"))
            vcs.append(parsed_vc)

        section["visualContainers"] = vcs
        sections.append(section)

    report["sections"] = sections
    return report


def save_report(report_dir: str, report: dict) -> None:
    """Save a parsed report back to report.json.

    Re-stringifies config, filters, vc.config, vc.filters.
    Uses compact separators (no spaces) to match native PBI Desktop format.

    CRITICAL: Preserves ALL keys from the parsed report — not just the ones
    we know about. This prevents silently dropping undocumented PBI metadata.
    """
    report_path = Path(report_dir) / "report.json"
    # Compact separators (no spaces) + preserve UTF-8 chars (no \uXXXX escaping)
    _j = {"separators": (",", ":"), "ensure_ascii": False}

    # Start with ALL report keys, then re-stringify parsed fields
    raw = dict(report)
    raw["config"] = json.dumps(report["config"], **_j)

    sections_raw = []
    for s in report["sections"]:
        # Preserve ALL section keys
        s_raw = dict(s)
        s_raw["config"] = json.dumps(s["config"], **_j)
        s_raw["filters"] = json.dumps(s["filters"], **_j)

        vcs_raw = []
        for vc in s["visualContainers"]:
            # Preserve ALL VC keys (not just the 8 we know)
            vc_raw = dict(vc)
            vc_raw["config"] = json.dumps(vc["config"], **_j)
            vc_raw["filters"] = json.dumps(vc["filters"], **_j)
            vcs_raw.append(vc_raw)

        s_raw["visualContainers"] = vcs_raw
        sections_raw.append(s_raw)

    raw["sections"] = sections_raw

    # Use LF + preserve UTF-8 in outer JSON too
    content = json.dumps(raw, indent=2, ensure_ascii=False)
    report_path.write_text(content, encoding="utf-8", newline="\n")

    # Remove backup file — PBI Desktop may use it to restore/merge old state
    backup_path = report_path.with_name("report.backup.json")
    if backup_path.exists():
        backup_path.unlink()


# ── Visual listing ───────────────────────────────────────────────────────────

def list_visuals(report: dict, page_index: int = 0) -> list[dict]:
    """List all visuals on a page with id, type, position, key properties."""
    section = _get_section(report, page_index)
    result = []
    for vc in section["visualContainers"]:
        cfg = vc["config"]
        name = cfg.get("name", "unknown")
        sv = cfg.get("singleVisual", {})
        vtype = sv.get("visualType", "unknown")
        has_vc_objects = "vcObjects" in cfg

        info: dict[str, Any] = {
            "id": name,
            "type": vtype,
            "x": vc["x"],
            "y": vc["y"],
            "width": vc["width"],
            "height": vc["height"],
            "tabOrder": vc["tabOrder"],
            "has_vcObjects": has_vc_objects,
        }

        # Extract fill color for shapes
        fill_val = _extract_literal(sv, "objects", "fill", 0, "properties",
                                     "fillColor", "solid", "color")
        if fill_val:
            info["fill_color"] = fill_val.strip("'")

        # Extract text for textboxes
        if vtype == "textbox":
            text = _extract_textbox_text(sv)
            if text:
                info["text"] = text[:80]

        # Extract measure for cards
        if vtype == "card":
            qr = _extract_card_measure(sv)
            if qr:
                info["measure"] = qr

        result.append(info)
    return result


def get_visual(report: dict, page_index: int, visual_id: str) -> dict | None:
    """Get full config of a single visual."""
    section = _get_section(report, page_index)
    for vc in section["visualContainers"]:
        if vc["config"].get("name") == visual_id:
            return _deep_copy(vc)
    return None


# ── Visual manipulation ─────────────────────────────────────────────────────

def add_visual(report: dict, page_index: int, vtype: str,
               x: int, y: int, width: int, height: int,
               properties: dict | None = None,
               bindings: dict | None = None,
               title: str = "") -> tuple[dict, str]:
    """Add a visual to a page. Returns (new_report, visual_id)."""
    report = _deep_copy(report)
    section = _get_section(report, page_index)
    visual_id = generate_visual_id()

    vc_config = _build_vc_config(visual_id, vtype, x, y, width, height,
                                  properties or {}, bindings or {}, title)

    tab_order = (len(section["visualContainers"]) + 1) * 1000
    new_vc = {
        "x": x, "y": y, "z": 0,
        "width": width, "height": height,
        "config": vc_config,
        "filters": [],
        "tabOrder": tab_order,
    }

    section["visualContainers"].append(new_vc)
    return report, visual_id


def move_visual(report: dict, page_index: int, visual_id: str,
                x: int | None = None, y: int | None = None,
                width: int | None = None, height: int | None = None) -> dict:
    """Move/resize a visual. Updates BOTH vc root AND config.layouts."""
    report = _deep_copy(report)
    section = _get_section(report, page_index)

    for vc in section["visualContainers"]:
        if vc["config"].get("name") == visual_id:
            vc["x"] = x if x is not None else vc["x"]
            vc["y"] = y if y is not None else vc["y"]
            vc["width"] = width if width is not None else vc["width"]
            vc["height"] = height if height is not None else vc["height"]
            # Update config.layouts too
            vc["config"]["layouts"] = [{
                "id": 0,
                "position": {
                    "x": vc["x"], "y": vc["y"],
                    "width": vc["width"], "height": vc["height"],
                },
            }]
            return report

    raise ValueError(f"Visual '{visual_id}' not found")


def delete_visual(report: dict, page_index: int, visual_id: str) -> dict:
    """Delete a visual and reindex tabOrder."""
    report = _deep_copy(report)
    section = _get_section(report, page_index)

    filtered = [vc for vc in section["visualContainers"]
                if vc["config"].get("name") != visual_id]
    if len(filtered) == len(section["visualContainers"]):
        raise ValueError(f"Visual '{visual_id}' not found")

    for i, vc in enumerate(filtered):
        vc["tabOrder"] = i
    section["visualContainers"] = filtered
    return report


def set_fill_color(report: dict, page_index: int, visual_id: str,
                   color: str, transparency: int = 0) -> dict:
    """Change the fill color of a shape/basicShape."""
    report = _deep_copy(report)
    section = _get_section(report, page_index)

    for vc in section["visualContainers"]:
        if vc["config"].get("name") == visual_id:
            sv = vc["config"].setdefault("singleVisual", {})
            objects = sv.setdefault("objects", {})
            objects["fill"] = [{
                "properties": {
                    "show": pbi_literal("true"),
                    "fillColor": pbi_color(color),
                    "transparency": pbi_literal(f"{transparency}D"),
                },
            }]
            return report

    raise ValueError(f"Visual '{visual_id}' not found")


def set_text(report: dict, page_index: int, visual_id: str,
             text: str, font_size: str = "11pt",
             font_color: str = "#000000",
             font_weight: str = "normal",
             font_family: str = "Segoe UI") -> dict:
    """Change textbox content and style."""
    report = _deep_copy(report)
    section = _get_section(report, page_index)

    for vc in section["visualContainers"]:
        if vc["config"].get("name") == visual_id:
            sv = vc["config"].setdefault("singleVisual", {})
            objects = sv.setdefault("objects", {})
            objects["general"] = [_build_paragraphs(
                text, font_size, font_color, font_weight, font_family
            )]
            return report

    raise ValueError(f"Visual '{visual_id}' not found")


def get_visual_type(vc: dict) -> str:
    """Extract the visualType from a VC's config."""
    return vc.get("config", {}).get("singleVisual", {}).get("visualType", "unknown")


def clone_visual(vc: dict, new_x: int, new_y: int,
                 new_width: int, new_height: int,
                 fill_color: str | None = None,
                 fill_transparency: int | None = None,
                 line_weight: int | None = None,
                 line_color: str | None = None,
                 text: str | None = None,
                 font_size: str | None = None,
                 font_color: str | None = None,
                 font_weight: str | None = None,
                 font_family: str | None = None,
                 round_edge: int | None = None,
                 tab_order: int | None = None) -> dict:
    """Deep copy a native VC and modify position/style.

    Preserves ALL metadata from the original VC (including undocumented fields).
    Only modifies the fields we explicitly set.
    """
    new_vc = _deep_copy(vc)

    # Update root position
    new_vc["x"] = new_x
    new_vc["y"] = new_y
    new_vc["width"] = new_width
    new_vc["height"] = new_height
    if tab_order is not None:
        new_vc["tabOrder"] = tab_order

    # Generate new unique ID
    new_id = generate_visual_id()
    new_vc["config"]["name"] = new_id

    # Update config.layouts position (include z + tabOrder like .pbix format)
    z_val = new_vc.get("z", 0)
    new_vc["config"]["layouts"] = [{
        "id": 0,
        "position": {"x": new_x, "y": new_y, "z": z_val,
                      "width": new_width, "height": new_height,
                      "tabOrder": tab_order if tab_order is not None else 0},
    }]

    vtype = get_visual_type(new_vc)
    sv = new_vc["config"].setdefault("singleVisual", {})
    objects = sv.setdefault("objects", {})

    # Update shape fill/line if requested (format matches PBI Desktop .pbix)
    if vtype in ("shape", "basicShape"):
        # Ensure shape type is defined (PBI Desktop requires this)
        if "shape" not in objects:
            objects["shape"] = [{
                "properties": {
                    "tileShape": pbi_literal("'rectangle'"),
                },
            }]
        # Ensure rotation is defined
        if "rotation" not in objects:
            objects["rotation"] = [{
                "properties": {
                    "shapeAngle": pbi_literal("0L"),
                },
            }]
        # drillFilterOtherVisuals required by PBI Desktop
        sv.setdefault("drillFilterOtherVisuals", True)

        if fill_color is not None:
            # CRITICAL: selector {"id": "default"} is REQUIRED by PBI Desktop
            # Without it, PBI falls back to theme default (#118DFF blue)
            # Also: do NOT include "show" or "transparency" — .pbix format
            # only has fillColor in the fill properties
            objects["fill"] = [{
                "properties": {
                    "fillColor": pbi_color(fill_color),
                },
                "selector": {"id": "default"},
            }]
        if line_weight is not None or line_color is not None:
            # Use "outline" instead of "line" (matches .pbix format)
            objects.pop("line", None)
            if line_weight == 0:
                objects["outline"] = [{
                    "properties": {
                        "show": pbi_literal("false"),
                    },
                }]
            else:
                objects["outline"] = [{
                    "properties": {
                        "show": pbi_literal("true"),
                        "lineColor": pbi_color(line_color or "#000000"),
                        "weight": pbi_literal(
                            f"{line_weight}D"),
                    },
                }]

    # Update textbox text if requested
    if vtype == "textbox" and text is not None:
        objects["general"] = [_build_paragraphs(
            text,
            font_size or "11pt",
            font_color or "#000000",
            font_weight or "normal",
            font_family or "Segoe UI",
        )]

    return new_vc


def set_page_background(report: dict, page_index: int,
                        color: str, transparency: int = 0) -> dict:
    """Set the page background color via section config.

    WARNING: Native PBI Desktop reports keep section.config empty ("{}").
    Using this function may cause PBI Desktop to apply theme colors globally.
    Prefer using a full-page background shape instead.
    """
    report = _deep_copy(report)
    section = _get_section(report, page_index)
    config = section.setdefault("config", {})
    objects = config.setdefault("objects", {})
    objects["background"] = [{
        "properties": {
            "color": pbi_color(color),
            "transparency": pbi_literal(f"{transparency}D"),
        },
    }]
    return report


def clear_section_config(report: dict, page_index: int = 0) -> dict:
    """Reset section config to empty — matches native PBI Desktop pattern.

    Native PBI reports always have section.config = {}. Any objects in section
    config can cause PBI Desktop to override visual-level styling with theme colors.
    """
    report = _deep_copy(report)
    section = _get_section(report, page_index)
    section["config"] = {}
    return report


# ── Fix vcObjects ────────────────────────────────────────────────────────────

def fix_decorative_vcobjects(report: dict, dry_run: bool = False) -> tuple[dict, list[dict]]:
    """Remove vcObjects from DECORATIVE_TYPES visuals.

    Returns (new_report, list_of_fixes_applied).
    Each fix: {id, type, x, y, action}.
    """
    report = _deep_copy(report)
    fixes: list[dict] = []

    for section in report["sections"]:
        for vc in section["visualContainers"]:
            cfg = vc["config"]
            sv = cfg.get("singleVisual", {})
            vtype = sv.get("visualType", "unknown")

            if vtype in DECORATIVE_TYPES and "vcObjects" in cfg:
                fix = {
                    "id": cfg.get("name", "?"),
                    "type": vtype,
                    "x": vc["x"],
                    "y": vc["y"],
                    "action": "remove_vcObjects",
                }
                fixes.append(fix)
                if not dry_run:
                    del cfg["vcObjects"]

    return report, fixes


# ── Config builders ──────────────────────────────────────────────────────────

def _build_vc_config(visual_id: str, vtype: str,
                     x: int, y: int, width: int, height: int,
                     properties: dict, bindings: dict,
                     title: str) -> dict:
    """Build the full visual container config dict.

    CRITICAL: vcObjects only added for NON-decorative types.
    """
    result: dict[str, Any] = {
        "name": visual_id,
        "layouts": [{"id": 0, "position": {"x": x, "y": y, "width": width, "height": height}}],
        "singleVisual": _build_single_visual(vtype, properties, bindings, title),
    }

    # THE FIX: decorative types handle their own styling via singleVisual.objects
    if vtype not in DECORATIVE_TYPES:
        result["vcObjects"] = _build_vc_objects(title)

    return result


def _build_vc_objects(title: str = "") -> dict:
    """Build vcObjects (outer container shell) — background hidden, no border/shadow."""
    vc_objects: dict[str, Any] = {
        "background": [{
            "properties": {
                "show": pbi_literal("false"),
                "color": pbi_color("#FFFFFF"),
                "transparency": pbi_literal("100D"),
            },
        }],
        "border": [{
            "properties": {
                "show": pbi_literal("false"),
            },
        }],
        "dropShadow": [{
            "properties": {
                "show": pbi_literal("false"),
            },
        }],
    }

    if title:
        vc_objects["title"] = [{
            "properties": {
                "show": pbi_literal("true"),
                "text": pbi_literal(f"'{title}'"),
            },
        }]
    else:
        vc_objects["title"] = [{
            "properties": {
                "show": pbi_literal("false"),
            },
        }]

    return vc_objects


def _build_single_visual(vtype: str, properties: dict,
                         bindings: dict, title: str) -> dict:
    """Build the singleVisual config for a given type."""
    visual: dict[str, Any] = {"visualType": vtype}

    # Data bindings (for card, slicer, etc.)
    if bindings:
        visual["projections"] = _build_projections(bindings)
        visual["prototypeQuery"] = _build_prototype_query(bindings)

    # Type-specific objects
    objects = _build_visual_objects(vtype, properties, title)
    if objects:
        visual["objects"] = objects

    return visual


def _build_visual_objects(vtype: str, props: dict, title: str) -> dict:
    """Build singleVisual.objects based on visual type."""
    if vtype in ("shape", "basicShape"):
        return _build_shape_objects(props)
    if vtype == "textbox":
        return _build_textbox_objects(props)
    if vtype == "card":
        return _build_card_objects(props, title)
    if vtype == "slicer":
        return _build_slicer_objects(props, title)
    return {}


def _build_shape_objects(props: dict) -> dict:
    """Build fill + line objects for shape/basicShape."""
    fill_color = props.get("fill_color", "#FFFFFF")
    fill_transparency = props.get("fill_transparency", 0)
    line_weight = props.get("line_weight", 0)
    line_color = props.get("line_color", "#000000")
    round_edge = props.get("round_edge", 0)

    objects: dict[str, Any] = {
        "fill": [{
            "properties": {
                "show": pbi_literal("true"),
                "fillColor": pbi_color(fill_color),
                "transparency": pbi_literal(f"{fill_transparency}D"),
            },
        }],
        "line": [{
            "properties": {
                "weight": pbi_literal(f"{line_weight}D"),
                "lineColor": pbi_color(line_color),
                "roundEdge": pbi_literal(f"{round_edge}D"),
            },
        }],
    }

    if props.get("shadow_show"):
        shadow_color = props.get("shadow_color", "#000000")
        shadow_transparency = props.get("shadow_transparency", 70)
        objects["shadow"] = [{
            "properties": {
                "show": pbi_literal("true"),
                "color": pbi_color(shadow_color),
                "transparency": pbi_literal(f"{shadow_transparency}D"),
            },
        }]

    return objects


def _build_textbox_objects(props: dict) -> dict:
    """Build paragraphs object for textbox."""
    text = props.get("text", "")
    font_size = props.get("font_size", "11pt")
    font_color = props.get("font_color", "#000000")
    font_weight = props.get("font_weight", "normal")
    font_family = props.get("font_family", "Segoe UI")

    return {
        "general": [_build_paragraphs(text, font_size, font_color,
                                       font_weight, font_family)],
    }


def _build_card_objects(props: dict, title: str) -> dict:
    """Build labels + categoryLabels for card visual."""
    font_color = props.get("font_color", "#FF7900")
    font_size = props.get("font_size", 22)

    objects: dict[str, Any] = {
        "labels": [{
            "properties": {
                "color": pbi_color(font_color),
                "fontSize": pbi_literal(f"{font_size}D"),
            },
        }],
        "categoryLabels": [{
            "properties": {
                "show": pbi_literal("false"),
            },
        }],
        "wordWrap": [{
            "properties": {
                "show": pbi_literal("true"),
            },
        }],
        "background": [{
            "properties": {
                "show": pbi_literal("false"),
                "transparency": pbi_literal("100D"),
            },
        }],
    }
    return objects


def _build_slicer_objects(props: dict, title: str) -> dict:
    """Build objects for slicer visual — matches native PBI structure."""
    header_color = props.get("header_color", "#FF7900")
    objects: dict[str, Any] = {}
    if title:
        objects["title"] = [{
            "properties": {
                "show": pbi_literal("true"),
                "titleText": pbi_literal(f"'{title}'"),
            },
        }]
    objects["background"] = [{
        "properties": {
            "show": pbi_literal("false"),
            "transparency": pbi_literal("100D"),
        },
    }]
    objects["border"] = [{
        "properties": {
            "show": pbi_literal("false"),
        },
    }]
    objects["header"] = [{
        "properties": {
            "fontColor": pbi_color(header_color),
        },
    }]
    return objects


# ── Data binding builders ────────────────────────────────────────────────────

def _build_projections(bindings: dict) -> dict:
    """Build projections from {role: [{table, measure/column}]}."""
    projections: dict[str, list] = {}
    for role, fields in bindings.items():
        projections[role] = [
            {"queryRef": f"{f['table']}.{f.get('measure') or f.get('column')}"}
            for f in fields
        ]
    return projections


def _build_prototype_query(bindings: dict) -> dict:
    """Build prototypeQuery from bindings."""
    all_fields = [f for fields in bindings.values() for f in fields]

    # Collect unique tables
    tables: dict[str, str] = {}
    for f in all_fields:
        tbl = f.get("table", "")
        if tbl and tbl not in tables:
            alias = "t" if not tables else f"t{len(tables)}"
            tables[tbl] = alias

    from_clause = [
        {"Name": alias, "Entity": entity, "Type": 0}
        for entity, alias in tables.items()
    ]

    select_clause = []
    for f in all_fields:
        tbl = f.get("table", "")
        alias = tables.get(tbl, "t")
        prop = f.get("measure") or f.get("column", "")
        name = f"{tbl}.{prop}" if tbl else prop

        if f.get("measure"):
            select_clause.append({
                "Measure": {
                    "Expression": {"SourceRef": {"Source": alias}},
                    "Property": prop,
                },
                "Name": name,
            })
        else:
            select_clause.append({
                "Column": {
                    "Expression": {"SourceRef": {"Source": alias}},
                    "Property": prop,
                },
                "Name": name,
            })

    return {"Version": 2, "From": from_clause, "Select": select_clause}


# ── Debug & Validation ──────────────────────────────────────────────────

def dump_visual(report: dict, page_index: int, visual_id: str) -> dict | None:
    """Return full JSON structure of a visual container for debugging."""
    section = _get_section(report, page_index)
    for vc in section["visualContainers"]:
        if vc["config"].get("name") == visual_id:
            return _deep_copy(vc)
    return None


def validate_bindings(report: dict, model_path: str, page_index: int = 0) -> list[dict]:
    """Validate that all card bindings reference existing tables/measures in model.bim.

    Returns list of {visual_id, table, measure, status, error}.
    """
    import json as _json
    model_bim = _json.loads(Path(model_path).read_text(encoding="utf-8"))
    tables = model_bim.get("model", {}).get("tables", [])

    # Build lookup: table_name -> set of measure names
    model_measures: dict[str, set[str]] = {}
    for tbl in tables:
        tbl_name = tbl.get("name", "")
        measures = {m["name"] for m in tbl.get("measures", [])}
        columns = {c["name"] for c in tbl.get("columns", [])}
        model_measures[tbl_name] = measures | columns

    section = _get_section(report, page_index)
    results: list[dict] = []

    for vc in section["visualContainers"]:
        cfg = vc["config"]
        sv = cfg.get("singleVisual", {})
        vtype = sv.get("visualType", "")

        if vtype not in ("card", "slicer"):
            continue

        pq = sv.get("prototypeQuery", {})
        from_clause = pq.get("From", [])
        select_clause = pq.get("Select", [])

        # Map alias -> entity
        alias_map = {f["Name"]: f["Entity"] for f in from_clause}

        for sel in select_clause:
            measure_info = sel.get("Measure") or sel.get("Column")
            if not measure_info:
                continue
            source_alias = measure_info.get("Expression", {}).get("SourceRef", {}).get("Source", "")
            prop = measure_info.get("Property", "")
            table_name = alias_map.get(source_alias, source_alias)

            entry = {
                "visual_id": cfg.get("name", "?"),
                "type": vtype,
                "table": table_name,
                "field": prop,
                "binding_type": "Measure" if "Measure" in sel else "Column",
            }

            if table_name not in model_measures:
                entry["status"] = "ERROR"
                entry["error"] = f"Table '{table_name}' not found in model.bim"
            elif prop not in model_measures[table_name]:
                entry["status"] = "ERROR"
                entry["error"] = f"Field '{prop}' not found in table '{table_name}'"
            else:
                entry["status"] = "OK"
                entry["error"] = None

            results.append(entry)

    return results


def patch_theme(report_dir: str, background_show: bool = False) -> dict:
    """Patch the custom theme JSON to override background.show.

    Finds the custom theme in StaticResources/RegisteredResources/,
    sets visualStyles.*.*.background[0].show = background_show.
    Returns {theme_path, patched_keys}.
    """
    import json as _json

    report_path = Path(report_dir)
    # Find custom theme in RegisteredResources
    registered = report_path / "StaticResources" / "RegisteredResources"
    if not registered.exists():
        raise FileNotFoundError(f"RegisteredResources not found at {registered}")

    theme_files = list(registered.glob("*.json"))
    if not theme_files:
        raise FileNotFoundError("No theme JSON found in RegisteredResources")

    patched = []
    for tf in theme_files:
        theme = _json.loads(tf.read_text(encoding="utf-8"))
        vs = theme.setdefault("visualStyles", {})

        # Patch global wildcard background — use transparency only, NOT show.
        # CRITICAL: PBI Desktop treats "show: false" as disabling the entire
        # fill rendering pipeline, which kills shape fills. The native Orange
        # theme uses transparency:100 WITHOUT a "show" key to make backgrounds
        # invisible while preserving fill rendering.
        star = vs.setdefault("*", {})
        star_star = star.setdefault("*", {})
        bg_list = star_star.setdefault("background", [{}])
        if bg_list:
            bg_list[0].pop("show", None)  # Remove show key if present
            bg_list[0]["transparency"] = 100

        tf.write_text(_json.dumps(theme, indent=2, ensure_ascii=False), encoding="utf-8")
        patched.append(str(tf))

    return {"patched_files": patched, "background_show": background_show}


# ── Internal helpers ─────────────────────────────────────────────────────────

def _safe_json_parse(value: Any) -> Any:
    """Parse a string as JSON if it is a string, otherwise return as-is."""
    if isinstance(value, str):
        try:
            return json.loads(value)
        except (json.JSONDecodeError, ValueError):
            return {}
    return value


def _get_section(report: dict, page_index: int) -> dict:
    """Get a section by index, raising on invalid index."""
    sections = report.get("sections", [])
    if page_index < 0 or page_index >= len(sections):
        raise IndexError(f"Page index {page_index} out of range (0-{len(sections) - 1})")
    return sections[page_index]


def _extract_literal(obj: dict, *path: str | int) -> str | None:
    """Walk a nested dict/list path to extract a Literal Value."""
    current: Any = obj
    for key in path:
        if isinstance(current, dict):
            current = current.get(key)
        elif isinstance(current, list) and isinstance(key, int):
            current = current[key] if key < len(current) else None
        else:
            return None
        if current is None:
            return None
    # Final step: extract Literal.Value
    if isinstance(current, dict):
        return current.get("expr", {}).get("Literal", {}).get("Value")
    return None


def _extract_textbox_text(sv: dict) -> str | None:
    """Extract plain text from a textbox's paragraphs."""
    para_raw = _extract_literal(sv, "objects", "general", 0, "properties", "paragraphs")
    if not para_raw:
        return None
    try:
        paras = json.loads(para_raw) if isinstance(para_raw, str) else para_raw
        texts = []
        for p in paras:
            for run in p.get("textRuns", []):
                texts.append(run.get("value", ""))
        return " ".join(texts).strip()
    except (json.JSONDecodeError, TypeError):
        return None


def _extract_card_measure(sv: dict) -> str | None:
    """Extract the measure queryRef from a card visual."""
    projections = sv.get("projections", {})
    values = projections.get("Values", projections.get("Fields", []))
    if values and isinstance(values, list):
        return values[0].get("queryRef")
    return None


def _build_paragraphs(text: str, font_size: str, font_color: str,
                      font_weight: str, font_family: str) -> dict:
    """Build the paragraphs property for textbox general objects."""
    text_style: dict[str, str] = {}
    if font_size:
        text_style["fontSize"] = font_size
    if font_color:
        text_style["color"] = font_color
    if font_weight and font_weight != "normal":
        text_style["fontWeight"] = font_weight
    if font_family:
        text_style["fontFamily"] = font_family

    paragraphs = json.dumps([{
        "textRuns": [{"value": text, "textStyle": text_style}],
    }])

    return {
        "properties": {
            "paragraphs": pbi_literal(paragraphs),
        },
    }

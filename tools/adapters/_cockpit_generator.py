"""Cockpit SAT v4 Generator — Encode cockpit_sat_v4.html layout as PBIR visuals.

Reference: C:/Users/PGNK2128/Downloads/cockpit_sat_v4.html
Generates all shapes, textboxes, cards, slicers for the Cockpit SAT ProPME dashboard.
"""

from __future__ import annotations

from typing import Any

from adapters._pbir_engine import (
    add_visual,
    clone_visual,
    get_visual_type,
    load_report,
    save_report,
)

# ── Color palette (from v4 CSS variables) ────────────────────────────────────

COLORS = {
    "orange": "#FF7900",
    "black": "#000000",
    "blue": "#4BB4E6",
    "green": "#50BE87",
    "dark_red": "#861919",
    "bg": "#F2F2F2",
    "white": "#FFFFFF",
    "card_bg": "#FAFAFA",
    "t1c_bg": "#F8F8F8",
    "legend_bg": "#F2F2F2",
}

# ── Layout constants ─────────────────────────────────────────────────────────

PAGE_W, PAGE_H = 1280, 720
BANNER_H = 96
LEGEND_Y, LEGEND_H = 108, 14
BARO_X, BARO_Y, BARO_W, BARO_H = 8, 128, 170, 170
ACCUEIL_X, ACCUEIL_Y = 188, 128
ACCUEIL_W, ACCUEIL_H = 1084, 170
HEADER_H = 22
BOT_Y = 310
BOT_H = 195
BOT_GAP = 10
BOT_W = 414
T1C_H = 18

# KPI card dimensions (accueil = 9 cols, others = 3 cols)
KPI_GAP = 5

# Measures live in a dedicated table (model.bim: "Mesures")
MEASURE_TABLE = "Mesures"

# ── KPI definitions (from cockpit_sat_v4.html L constant) ────────────────────

SECTIONS: dict[str, dict[str, Any]] = {
    "accueil": {
        "color": "#4BB4E6",
        "label": "SAT Accueil",
        "cols": 9,
        "kpis": [
            {"label": "3901 A2P", "measure": "NPS_3901_A2P", "rep": "NbRep_3901_A2P",
             "subs": [("Commerce", "Commerce_Interne"), ("Suivi Cde", "SuiviCde_Interne")],
             "t1c": "T1C_3901_A2P"},
            {"label": "3901 S/TRAIT.", "measure": "NPS_3901_STrait", "rep": "NbRep_3901_STrait",
             "subs": [("Commerce", "Commerce_Externe"), ("Suivi Cde", "SuiviCde_Externe"),
                      ("Reco", "Reco_Externe")],
             "t1c": "T1C_3901_STrait"},
            {"label": "706 AC", "measure": "NPS_706_AC", "rep": "NbRep_706_AC",
             "t1c": "T1C_706_AC"},
            {"label": "NOMADE/CDC", "measure": "NPS_Nomade", "rep": "NbRep_Nomade"},
            {"label": "DVI", "measure": "NPS_DVI", "rep": "NbRep_DVI"},
            {"label": "BOUTIQUE AD", "measure": "NPS_Boutique_AD", "rep": "NbRep_Boutique_AD",
             "subs": [("GP", "NPS_Boutique_AD_GP"), ("Commerce", "Boutique_AD_Commerce"),
                      ("Service", "Boutique_AD_Service")]},
            {"label": "BOUTIQUE OS", "measure": "NPS_Boutique_OS", "rep": "NbRep_Boutique_OS",
             "subs": [("GP", "NPS_Boutique_OS_GP"), ("Commerce", "Boutique_OS_Commerce"),
                      ("Service", "Boutique_OS_Service")]},
            {"label": "PAP", "measure": "NPS_PAP", "rep": "NbRep_PAP",
             "subs": [("GP", "NPS_PAP_GP")]},
            {"label": "OFFRE MOBILE", "measure": "NPS_Mobile_Achat", "rep": "NbRep_Mobile_Achat"},
        ],
    },
    "achat": {
        "color": "#FF7900",
        "label": "SAT Achat",
        "cols": 3,
        "kpis": [
            {"label": "OFFRE BB PROPME", "measure": "NPS_Offre_BB", "rep": "NbRep_Offre_BB",
             "subs": [("Fibre", "Offre_BB_Fibre"), ("Cuivre", "Offre_BB_Cuivre"),
                      ("Mono", "Offre_BB_Mono"), ("Multi", "Offre_BB_Multi")],
             "t1c": "T1C_Offre_BB"},
            {"label": "PROD OFFRES BB", "measure": "NPS_Prod_BB", "rep": "NbRep_Prod_BB"},
            {"label": "SAV OFFRES BB", "measure": "NPS_SAV_BB", "rep": "NbRep_SAV_BB",
             "t1c": "T1C_DME"},
        ],
    },
    "sav": {
        "color": "#50BE87",
        "label": "SAT SAV",
        "cols": 3,
        "kpis": [
            {"label": "3901 AT", "measure": "NPS_3901_AT", "rep": "NbRep_3901_AT"},
            {"label": "706 AT", "measure": "NPS_706_AT", "rep": "NbRep_706_AT",
             "t1c": "T1C_706_AT"},
            {"label": "OFFRE MOBILE", "measure": "NPS_Mobile_Achat", "rep": "NbRep_Mobile_Achat"},
        ],
    },
    "recla": {
        "color": "#861919",
        "label": "SAT Réclamation",
        "cols": 3,
        "kpis": [
            {"label": "GLOBAL", "measure": "NPS_Recla_Global", "rep": "NbRep_Recla_Global",
             "t1c": "T1C_Recla_Global"},
            {"label": "FRONT (N1)", "measure": "NPS_Recla_Front", "rep": "NbRep_Recla_Front"},
            {"label": "BACK (N2)", "measure": "NPS_Recla_Back", "rep": "NbRep_Recla_Back"},
        ],
    },
}

# Filter slicers — positioned to match reference banner layout
SLICERS = [
    {"label": "Granularité", "table": "Filtre_Granularite", "column": "Granularite",
     "x": 660, "y": 32, "w": 155, "h": 22, "group": "sondage"},
    {"label": "Période", "table": "Filtre_Periode", "column": "Periode",
     "x": 660, "y": 58, "w": 155, "h": 26, "group": "sondage"},
    {"label": "Granularité", "table": "Filtre_Baro_Granularite", "column": "Granularite",
     "x": 980, "y": 32, "w": 170, "h": 22, "group": "baro"},
    {"label": "Période", "table": "Filtre_Baro_Periode", "column": "Periode",
     "x": 980, "y": 58, "w": 120, "h": 26, "group": "baro"},
]


# ── Generator ────────────────────────────────────────────────────────────────

def generate_cockpit(report_dir: str, template: str = "cockpit_sat_v4") -> dict:
    """Generate complete cockpit layout in an existing PBIP report.

    Clears existing visuals on page 0 and rebuilds from scratch.
    """
    report = load_report(report_dir)

    # Reset section config to empty (native PBI pattern — prevents blue override)
    section = report["sections"][0]
    section["config"] = {}
    section["visualContainers"] = []

    visual_count = 0

    # 0. Page background shape (full-page, lowest layer)
    report, _ = add_visual(report, 0, "shape", 0, 0, PAGE_W, PAGE_H,
                           properties={"fill_color": COLORS["bg"],
                                       "fill_transparency": 0,
                                       "line_weight": 0})
    visual_count += 1

    # 1. Banner
    report, visual_count = _add_banner(report, visual_count)

    # 2. Legend
    report, visual_count = _add_legend(report, visual_count)

    # 3. Baromètre
    report, visual_count = _add_barometre(report, visual_count)

    # 4. Accueil section
    report, visual_count = _add_accueil(report, visual_count)

    # 5. Bottom sections (Achat, SAV, Récla)
    report, visual_count = _add_bottom_sections(report, visual_count)

    # 6. Footer
    report, _ = add_visual(report, 0, "textbox", 350, BOT_Y + BOT_H + 12, 580, 14,
                            properties={"text": "40 indicateurs — Mars 2026 — Mois (mensuel) — Source: SOCLE_SONDAGE_PROPME",
                                        "font_size": "8pt", "font_color": "#999999"})
    visual_count += 1

    save_report(report_dir, report)

    return {
        "template": template,
        "report_dir": report_dir,
        "visual_count": visual_count,
        "page": section["displayName"],
    }


def _add_banner(report: dict, count: int) -> tuple[dict, int]:
    """Black banner with title, subtitle, and slicers."""
    # Black background
    report, _ = add_visual(report, 0, "shape", 0, 0, PAGE_W, BANNER_H,
                            properties={"fill_color": COLORS["black"]})
    count += 1

    # Title
    report, _ = add_visual(report, 0, "textbox", 16, 12, 350, 28,
                            properties={"text": "Cockpit SAT ProPME",
                                        "font_size": "18pt", "font_color": "#FFFFFF",
                                        "font_weight": "bold", "font_family": "Arial Black"})
    count += 1

    # Subtitle
    report, _ = add_visual(report, 0, "textbox", 16, 40, 400, 16,
                            properties={"text": "SOCLE_SONDAGE_PROPME — GCP BigQuery",
                                        "font_size": "9pt", "font_color": "#888888"})
    count += 1

    # Section labels above slicers
    report, _ = add_visual(report, 0, "textbox", 660, 14, 200, 14,
                            properties={"text": "SONDAGE TRANSACTIONNEL",
                                        "font_size": "8pt", "font_color": "#888888",
                                        "font_weight": "bold"})
    count += 1

    report, _ = add_visual(report, 0, "textbox", 985, 14, 120, 14,
                            properties={"text": "BAROMÈTRE",
                                        "font_size": "8pt", "font_color": "#888888",
                                        "font_weight": "bold"})
    count += 1

    # Slicers
    for sl in SLICERS:
        report, _ = add_visual(report, 0, "slicer", sl["x"], sl["y"], sl["w"], sl["h"],
                                bindings={"Fields": [{"table": sl["table"], "column": sl["column"]}]},
                                title=sl["label"])
        count += 1

    # NPS / 3M / Mensuel buttons (sondage section, right of Période)
    report, _ = add_visual(report, 0, "shape", 822, 60, 28, 20,
                            properties={"fill_color": "#DDDDDD", "round_edge": 3,
                                        "line_weight": 1, "line_color": "#CCCCCC"})
    count += 1
    report, _ = add_visual(report, 0, "textbox", 822, 62, 28, 16,
                            properties={"text": "NPS", "font_size": "7pt", "font_color": "#666666"})
    count += 1
    report, _ = add_visual(report, 0, "shape", 852, 60, 28, 20,
                            properties={"fill_color": "#DDDDDD", "round_edge": 3,
                                        "line_weight": 1, "line_color": "#CCCCCC"})
    count += 1
    report, _ = add_visual(report, 0, "textbox", 852, 62, 28, 16,
                            properties={"text": "3M", "font_size": "7pt", "font_color": "#666666"})
    count += 1
    report, _ = add_visual(report, 0, "shape", 886, 60, 52, 20,
                            properties={"fill_color": COLORS["orange"], "round_edge": 3})
    count += 1
    report, _ = add_visual(report, 0, "textbox", 886, 62, 52, 16,
                            properties={"text": "Mensuel", "font_size": "7pt",
                                        "font_color": "#FFFFFF", "font_weight": "bold"})
    count += 1

    # "Mars 2026" orange badge (top-right, ref: x=1189-1256, y=37-59)
    report, _ = add_visual(report, 0, "shape", 1189, 37, 68, 22,
                            properties={"fill_color": COLORS["orange"], "round_edge": 6})
    count += 1
    report, _ = add_visual(report, 0, "textbox", 1189, 39, 68, 18,
                            properties={"text": "Mars 2026",
                                        "font_size": "9pt", "font_color": "#FFFFFF",
                                        "font_weight": "bold"})
    count += 1

    return report, count


def _add_legend(report: dict, count: int) -> tuple[dict, int]:
    """NPS color legend bar."""
    # Gray bar
    report, _ = add_visual(report, 0, "shape", 0, LEGEND_Y, PAGE_W, LEGEND_H,
                            properties={"fill_color": COLORS["legend_bg"]})
    count += 1

    # Legend dots
    legends = [
        (420, "#2A7B3F", "● NPS ≥ 50"),
        (530, "#4BB4E6", "● NPS 30–49"),
        (650, "#FF7900", "● NPS 0–29"),
        (760, "#CD3C14", "● NPS < 0"),
    ]
    for lx, color, text in legends:
        report, _ = add_visual(report, 0, "textbox", lx, LEGEND_Y + 2, 50, 15,
                                properties={"text": text, "font_size": "7pt",
                                            "font_color": color})
        count += 1

    return report, count


def _add_barometre(report: dict, count: int) -> tuple[dict, int]:
    """Left sidebar baromètre NPS."""
    # White container with rounded corners
    report, _ = add_visual(report, 0, "shape", BARO_X, BARO_Y, BARO_W, BARO_H,
                            properties={"fill_color": COLORS["white"], "round_edge": 10,
                                        "line_weight": 1, "line_color": "#EEEEEE"})
    count += 1

    # Title
    report, _ = add_visual(report, 0, "textbox", 12, BARO_Y + 8, 160, 30,
                            properties={"text": "BAROMÈTRE NPS\nPROPME MÉTROPOLE",
                                        "font_size": "7pt", "font_color": "#888888",
                                        "font_weight": "bold"})
    count += 1

    # NPS value card
    report, _ = add_visual(report, 0, "card", 30, BARO_Y + 42, 120, 65,
                            properties={"font_color": COLORS["orange"], "font_size": 48},
                            bindings={"Values": [{"table": MEASURE_TABLE, "measure": "NPS_Baro_Global"}]})
    count += 1

    # Response count + period text
    report, _ = add_visual(report, 0, "textbox", 20, BARO_Y + 110, 140, 14,
                            properties={"text": "54 rep. — T4 2025",
                                        "font_size": "7pt", "font_color": "#AAAAAA"})
    count += 1

    return report, count


def _add_accueil(report: dict, count: int) -> tuple[dict, int]:
    """Accueil section: header + 9 KPI cards in grid."""
    sec = SECTIONS["accueil"]

    # White background with rounded corners
    report, _ = add_visual(report, 0, "shape", ACCUEIL_X, ACCUEIL_Y, ACCUEIL_W, ACCUEIL_H,
                            properties={"fill_color": COLORS["white"], "round_edge": 10})
    count += 1

    # Colored header (rounded top corners)
    report, _ = add_visual(report, 0, "shape", ACCUEIL_X, ACCUEIL_Y, ACCUEIL_W, HEADER_H,
                            properties={"fill_color": sec["color"], "round_edge": 10})
    count += 1

    # Header text
    report, _ = add_visual(report, 0, "textbox", ACCUEIL_X + 10, ACCUEIL_Y + 3, 200, 20,
                            properties={"text": sec["label"], "font_size": "12pt",
                                        "font_color": "#FFFFFF", "font_weight": "bold"})
    count += 1

    # KPI cards grid (9 columns)
    card_w = 114
    card_h = 55
    start_x = ACCUEIL_X + 10
    start_y = ACCUEIL_Y + HEADER_H + 4
    sub_label_h = 11
    sub_w_label = 69
    sub_w_value = 46

    for i, kpi in enumerate(sec["kpis"]):
        cx = start_x + i * (card_w + KPI_GAP)
        cy = start_y

        # Card background shape with border
        report, _ = add_visual(report, 0, "shape", cx, cy, card_w, card_h,
                                properties={"fill_color": COLORS["card_bg"], "round_edge": 6,
                                            "line_weight": 1, "line_color": "#EEEEEE"})
        count += 1

        # KPI label
        report, _ = add_visual(report, 0, "textbox", cx + 2, cy + 1, card_w - 4, 12,
                                properties={"text": kpi["label"], "font_size": "6.5pt",
                                            "font_color": "#888888", "font_weight": "bold"})
        count += 1

        # NPS value card (font_size 24 to match reference)
        report, _ = add_visual(report, 0, "card", cx + 2, cy + 13, card_w - 4, 28,
                                properties={"font_color": COLORS["orange"], "font_size": 24},
                                bindings={"Values": [{"table": MEASURE_TABLE, "measure": kpi["measure"]}]})
        count += 1

        # Response count card
        report, _ = add_visual(report, 0, "card", cx + 2, cy + 41, card_w - 4, 12,
                                properties={"font_color": "#AAAAAA", "font_size": 7},
                                bindings={"Values": [{"table": MEASURE_TABLE, "measure": kpi["rep"]}]})
        count += 1

        # Sub-indicators
        sub_y = cy + card_h + 2
        for sub_label, sub_measure in kpi.get("subs", []):
            # Label
            report, _ = add_visual(report, 0, "textbox", cx, sub_y, sub_w_label, sub_label_h,
                                    properties={"text": sub_label, "font_size": "6pt",
                                                "font_color": "#888888"})
            count += 1
            # Value card
            report, _ = add_visual(report, 0, "card", cx + sub_w_label, sub_y, sub_w_value, sub_label_h,
                                    properties={"font_color": "#555555", "font_size": 7},
                                    bindings={"Values": [{"table": MEASURE_TABLE, "measure": sub_measure}]})
            count += 1
            sub_y += sub_label_h + 1

    # T1C bar
    t1c_y = ACCUEIL_Y + ACCUEIL_H - T1C_H - 3
    report, _ = add_visual(report, 0, "shape", ACCUEIL_X + 5, t1c_y, ACCUEIL_W - 10, T1C_H,
                            properties={"fill_color": COLORS["t1c_bg"]})
    count += 1

    # T1C metrics
    tx = ACCUEIL_X + 10
    for kpi in sec["kpis"]:
        t1c = kpi.get("t1c")
        if not t1c:
            continue
        # T1C label
        report, _ = add_visual(report, 0, "textbox", tx, t1c_y + 2, 80, 14,
                                properties={"text": f"T1C {kpi['label']}", "font_size": "6pt",
                                            "font_color": "#999999"})
        count += 1
        # T1C value
        report, _ = add_visual(report, 0, "card", tx + 80, t1c_y + 2, 30, 14,
                                properties={"font_color": "#555555", "font_size": 7},
                                bindings={"Values": [{"table": MEASURE_TABLE, "measure": t1c}]})
        count += 1
        tx += 130

    return report, count


def _add_bottom_sections(report: dict, count: int) -> tuple[dict, int]:
    """Add Achat, SAV, Récla sections in 3-column bottom row."""
    bot_sections = ["achat", "sav", "recla"]
    positions = [
        (8, BOT_Y),
        (8 + BOT_W + BOT_GAP, BOT_Y),
        (8 + (BOT_W + BOT_GAP) * 2, BOT_Y),
    ]

    for sec_name, (sx, sy) in zip(bot_sections, positions):
        sec = SECTIONS[sec_name]
        report, count = _add_section_block(report, count, sx, sy, sec)

    return report, count


def _add_section_block(report: dict, count: int,
                       sx: int, sy: int, sec: dict) -> tuple[dict, int]:
    """Add a single bottom section block (white bg + colored header + KPI cards)."""
    # White background with rounded corners
    report, _ = add_visual(report, 0, "shape", sx, sy, BOT_W, BOT_H,
                            properties={"fill_color": COLORS["white"], "round_edge": 10})
    count += 1

    # Colored header (rounded top corners)
    report, _ = add_visual(report, 0, "shape", sx, sy, BOT_W, HEADER_H,
                            properties={"fill_color": sec["color"], "round_edge": 10})
    count += 1

    # Header text
    report, _ = add_visual(report, 0, "textbox", sx + 10, sy + 3, BOT_W - 20, 20,
                            properties={"text": sec["label"], "font_size": "12pt",
                                        "font_color": "#FFFFFF", "font_weight": "bold"})
    count += 1

    # KPI cards (3 columns)
    card_w = 128
    card_h = 55
    start_x = sx + 10
    start_y = sy + HEADER_H + 4
    sub_label_h = 11
    sub_w_label = int(card_w * 0.6)
    sub_w_value = int(card_w * 0.4)

    for i, kpi in enumerate(sec["kpis"]):
        cx = start_x + i * (card_w + KPI_GAP)
        cy = start_y

        # Card background with border
        report, _ = add_visual(report, 0, "shape", cx, cy, card_w, card_h,
                                properties={"fill_color": COLORS["card_bg"], "round_edge": 6,
                                            "line_weight": 1, "line_color": "#EEEEEE"})
        count += 1

        # KPI label
        report, _ = add_visual(report, 0, "textbox", cx + 2, cy + 1, card_w - 4, 12,
                                properties={"text": kpi["label"], "font_size": "6.5pt",
                                            "font_color": "#888888", "font_weight": "bold"})
        count += 1

        # NPS value (font_size 24 to match reference)
        report, _ = add_visual(report, 0, "card", cx + 2, cy + 13, card_w - 4, 28,
                                properties={"font_color": COLORS["orange"], "font_size": 24},
                                bindings={"Values": [{"table": MEASURE_TABLE, "measure": kpi["measure"]}]})
        count += 1

        # Response count
        report, _ = add_visual(report, 0, "card", cx + 2, cy + 41, card_w - 4, 12,
                                properties={"font_color": "#AAAAAA", "font_size": 7},
                                bindings={"Values": [{"table": MEASURE_TABLE, "measure": kpi["rep"]}]})
        count += 1

        # Sub-indicators
        sub_y = cy + card_h + 2
        for sub_label, sub_measure in kpi.get("subs", []):
            report, _ = add_visual(report, 0, "textbox", cx, sub_y, sub_w_label, sub_label_h,
                                    properties={"text": sub_label, "font_size": "6pt",
                                                "font_color": "#888888"})
            count += 1
            report, _ = add_visual(report, 0, "card", cx + sub_w_label, sub_y, sub_w_value, sub_label_h,
                                    properties={"font_color": "#555555", "font_size": 7},
                                    bindings={"Values": [{"table": MEASURE_TABLE, "measure": sub_measure}]})
            count += 1
            sub_y += sub_label_h + 1

    # T1C bar
    t1c_y = sy + BOT_H - T1C_H - 3
    report, _ = add_visual(report, 0, "shape", sx + 5, t1c_y, BOT_W - 10, T1C_H,
                            properties={"fill_color": COLORS["t1c_bg"]})
    count += 1

    # T1C metrics
    tx = sx + 10
    for kpi in sec["kpis"]:
        t1c = kpi.get("t1c")
        if not t1c:
            continue
        report, _ = add_visual(report, 0, "textbox", tx, t1c_y + 2, 80, 14,
                                properties={"text": f"T1C {kpi['label']}", "font_size": "6pt",
                                            "font_color": "#999999"})
        count += 1
        report, _ = add_visual(report, 0, "card", tx + 80, t1c_y + 2, 30, 14,
                                properties={"font_color": "#555555", "font_size": 7},
                                bindings={"Values": [{"table": MEASURE_TABLE, "measure": t1c}]})
        count += 1
        tx += 120

    return report, count


# ── In-place generator (preserves native PBI metadata) ──────────────────────

def generate_cockpit_inplace(native_dir: str, target_dir: str,
                             template: str = "cockpit_sat_v4") -> dict:
    """Generate cockpit by cloning native VCs and modifying them in-place.

    Unlike generate_cockpit() which clears VCs and rebuilds from scratch,
    this function preserves ALL native PBI metadata by cloning existing VCs
    as templates for each generated visual.

    Args:
        native_dir: Path to the NATIVE working report directory (source of VC templates)
        target_dir: Path to the target report directory (where to save)
    """
    import copy

    native_report = load_report(native_dir)
    section = native_report["sections"][0]

    # Extract one template VC per type from native report
    templates: dict[str, dict] = {}
    for vc in section["visualContainers"]:
        vtype = get_visual_type(vc)
        if vtype not in templates:
            templates[vtype] = vc

    # Fallback: if a type doesn't exist in native, use shape as base
    if "shape" not in templates:
        raise ValueError("Native report has no shape VCs to use as template")

    def _clone_shape(x: int, y: int, w: int, h: int,
                     fill_color: str = "#FFFFFF",
                     fill_transparency: int = 0,
                     line_weight: int = 0,
                     line_color: str = "#000000",
                     round_edge: int = 0,
                     tab_order: int = 0) -> dict:
        return clone_visual(
            templates["shape"], x, y, w, h,
            fill_color=fill_color,
            fill_transparency=fill_transparency,
            line_weight=line_weight,
            line_color=line_color,
            round_edge=round_edge,
            tab_order=tab_order,
        )

    def _clone_textbox(x: int, y: int, w: int, h: int,
                       text: str = "", font_size: str = "11pt",
                       font_color: str = "#000000",
                       font_weight: str = "normal",
                       font_family: str = "Segoe UI",
                       tab_order: int = 0) -> dict:
        tpl = templates.get("textbox", templates["shape"])
        vc = clone_visual(
            tpl, x, y, w, h,
            text=text, font_size=font_size, font_color=font_color,
            font_weight=font_weight, font_family=font_family,
            tab_order=tab_order,
        )
        # Ensure visualType is textbox even if cloned from shape
        vc["config"]["singleVisual"]["visualType"] = "textbox"
        return vc

    def _clone_card(x: int, y: int, w: int, h: int,
                    measure: str, font_color: str = "#FF7900",
                    font_size: int = 22,
                    tab_order: int = 0) -> dict:
        from adapters._pbir_engine import (
            _build_card_objects, _build_projections,
            _build_prototype_query, _build_vc_objects, pbi_literal,
        )
        tpl = templates.get("card", templates["shape"])
        vc = copy.deepcopy(tpl)
        vc["x"], vc["y"] = x, y
        vc["width"], vc["height"] = w, h
        vc["tabOrder"] = tab_order
        from adapters._pbir_engine import generate_visual_id
        vc["config"]["name"] = generate_visual_id()
        vc["config"]["layouts"] = [{"id": 0, "position": {"x": x, "y": y, "z": 0, "width": w, "height": h, "tabOrder": tab_order}}]
        bindings = {"Values": [{"table": MEASURE_TABLE, "measure": measure}]}
        vc["config"]["singleVisual"] = {
            "visualType": "card",
            "projections": _build_projections(bindings),
            "prototypeQuery": _build_prototype_query(bindings),
            "objects": _build_card_objects({"font_color": font_color, "font_size": font_size}, ""),
        }
        vc["config"]["vcObjects"] = _build_vc_objects("")
        return vc

    def _clone_slicer(x: int, y: int, w: int, h: int,
                      table: str, column: str, label: str = "",
                      tab_order: int = 0) -> dict:
        from adapters._pbir_engine import (
            _build_projections, _build_prototype_query,
            _build_slicer_objects, _build_vc_objects,
        )
        tpl = templates.get("slicer", templates["shape"])
        vc = copy.deepcopy(tpl)
        vc["x"], vc["y"] = x, y
        vc["width"], vc["height"] = w, h
        vc["tabOrder"] = tab_order
        from adapters._pbir_engine import generate_visual_id
        vc["config"]["name"] = generate_visual_id()
        vc["config"]["layouts"] = [{"id": 0, "position": {"x": x, "y": y, "width": w, "height": h}}]
        bindings = {"Fields": [{"table": table, "column": column}]}
        vc["config"]["singleVisual"] = {
            "visualType": "slicer",
            "projections": _build_projections(bindings),
            "prototypeQuery": _build_prototype_query(bindings),
            "objects": _build_slicer_objects({}, label),
        }
        vc["config"]["vcObjects"] = _build_vc_objects(label)
        return vc

    # Build all VCs
    all_vcs: list[dict] = []
    tab = 1000

    def _shape(x, y, w, h, **kw):
        nonlocal tab
        kw.setdefault("tab_order", tab)
        all_vcs.append(_clone_shape(x, y, w, h, **kw))
        tab += 200

    def _text(x, y, w, h, **kw):
        nonlocal tab
        kw.setdefault("tab_order", tab)
        all_vcs.append(_clone_textbox(x, y, w, h, **kw))
        tab += 200

    def _card(x, y, w, h, measure, **kw):
        nonlocal tab
        kw.setdefault("tab_order", tab)
        all_vcs.append(_clone_card(x, y, w, h, measure, **kw))
        tab += 200

    def _slicer(x, y, w, h, table, column, label=""):
        nonlocal tab
        all_vcs.append(_clone_slicer(x, y, w, h, table, column, label, tab_order=tab))
        tab += 200

    # ── 0. Page background ──
    _shape(0, 0, PAGE_W, PAGE_H, fill_color=COLORS["bg"])

    # ── 1. Banner ──
    _shape(0, 0, PAGE_W, BANNER_H, fill_color=COLORS["black"])
    _text(16, 12, 350, 28, text="Cockpit SAT ProPME",
          font_size="18pt", font_color="#FFFFFF", font_weight="bold", font_family="Arial Black")
    _text(16, 40, 400, 16, text="SOCLE_SONDAGE_PROPME — GCP BigQuery",
          font_size="9pt", font_color="#888888")
    _text(660, 14, 200, 14, text="SONDAGE TRANSACTIONNEL",
          font_size="8pt", font_color="#888888", font_weight="bold")
    _text(985, 14, 120, 14, text="BAROMÈTRE",
          font_size="8pt", font_color="#888888", font_weight="bold")

    for sl in SLICERS:
        _slicer(sl["x"], sl["y"], sl["w"], sl["h"], sl["table"], sl["column"], sl["label"])

    # NPS/3M/Mensuel buttons
    _shape(822, 60, 28, 20, fill_color="#DDDDDD", line_weight=1, line_color="#CCCCCC")
    _text(822, 62, 28, 16, text="NPS", font_size="7pt", font_color="#666666")
    _shape(852, 60, 28, 20, fill_color="#DDDDDD", line_weight=1, line_color="#CCCCCC")
    _text(852, 62, 28, 16, text="3M", font_size="7pt", font_color="#666666")
    _shape(886, 60, 52, 20, fill_color=COLORS["orange"])
    _text(886, 62, 52, 16, text="Mensuel", font_size="7pt", font_color="#FFFFFF", font_weight="bold")
    _shape(1189, 37, 68, 22, fill_color=COLORS["orange"])
    _text(1189, 39, 68, 18, text="Mars 2026", font_size="9pt", font_color="#FFFFFF", font_weight="bold")

    # ── 2. Legend ──
    _shape(0, LEGEND_Y, PAGE_W, LEGEND_H, fill_color=COLORS["legend_bg"])
    for lx, color, ltext in [(420, "#2A7B3F", "● NPS ≥ 50"), (530, "#4BB4E6", "● NPS 30–49"),
                              (650, "#FF7900", "● NPS 0–29"), (760, "#CD3C14", "● NPS < 0")]:
        _text(lx, LEGEND_Y + 2, 50, 15, text=ltext, font_size="7pt", font_color=color)

    # ── 3. Baromètre ──
    _shape(BARO_X, BARO_Y, BARO_W, BARO_H, fill_color=COLORS["white"], line_weight=1, line_color="#EEEEEE")
    _text(12, BARO_Y + 8, 160, 30, text="BAROMÈTRE NPS\nPROPME MÉTROPOLE",
          font_size="7pt", font_color="#888888", font_weight="bold")
    _card(30, BARO_Y + 42, 120, 65, "NPS_Baro_Global", font_color=COLORS["orange"], font_size=48)
    _text(20, BARO_Y + 110, 140, 14, text="54 rep. — T4 2025",
          font_size="7pt", font_color="#AAAAAA")

    # ── 4. Accueil ──
    _build_section_inplace(all_vcs, SECTIONS["accueil"], ACCUEIL_X, ACCUEIL_Y,
                           ACCUEIL_W, ACCUEIL_H, 9, _shape, _text, _card, tab)
    tab = 1000 + len(all_vcs) * 200  # sync tab counter

    # ── 5. Bottom sections ──
    bot_positions = [(8, BOT_Y), (8 + BOT_W + BOT_GAP, BOT_Y),
                     (8 + (BOT_W + BOT_GAP) * 2, BOT_Y)]
    for sec_name, (sx, sy) in zip(["achat", "sav", "recla"], bot_positions):
        tab = 1000 + len(all_vcs) * 200
        _build_section_inplace(all_vcs, SECTIONS[sec_name], sx, sy,
                               BOT_W, BOT_H, 3, _shape, _text, _card, tab)
        tab = 1000 + len(all_vcs) * 200

    # ── 6. Footer ──
    _text(350, BOT_Y + BOT_H + 12, 580, 14,
          text="40 indicateurs — Mars 2026 — Mois (mensuel) — Source: SOCLE_SONDAGE_PROPME",
          font_size="8pt", font_color="#999999")

    # Replace section VCs with our generated ones (all cloned from native)
    section["visualContainers"] = all_vcs

    # Save to target
    save_report(target_dir, native_report)

    return {
        "template": template,
        "native_dir": native_dir,
        "target_dir": target_dir,
        "visual_count": len(all_vcs),
        "page": section["displayName"],
    }


def _build_section_inplace(all_vcs: list, sec: dict,
                           sx: int, sy: int, sw: int, sh: int, cols: int,
                           _shape, _text, _card, tab_base: int) -> None:
    """Add a KPI section block using clone helpers."""
    # White background
    _shape(sx, sy, sw, sh, fill_color=COLORS["white"])
    # Colored header
    _shape(sx, sy, sw, HEADER_H, fill_color=sec["color"])
    # Header text
    _text(sx + 10, sy + 3, sw - 20, 20, text=sec["label"],
          font_size="12pt", font_color="#FFFFFF", font_weight="bold")

    # KPI cards
    card_w = (sw - 20 - (cols - 1) * KPI_GAP) // cols
    card_h = 55
    start_x = sx + 10
    start_y = sy + HEADER_H + 4
    sub_label_h = 11
    sub_w_label = int(card_w * 0.6)
    sub_w_value = int(card_w * 0.4)

    for i, kpi in enumerate(sec["kpis"]):
        cx = start_x + i * (card_w + KPI_GAP)
        cy = start_y

        # Card background
        _shape(cx, cy, card_w, card_h, fill_color=COLORS["card_bg"],
               line_weight=1, line_color="#EEEEEE")
        # KPI label
        _text(cx + 2, cy + 1, card_w - 4, 12, text=kpi["label"],
              font_size="6.5pt", font_color="#888888", font_weight="bold")
        # NPS value
        _card(cx + 2, cy + 13, card_w - 4, 28, kpi["measure"],
              font_color=COLORS["orange"], font_size=24)
        # Response count
        _card(cx + 2, cy + 41, card_w - 4, 12, kpi["rep"],
              font_color="#AAAAAA", font_size=7)

        # Sub-indicators
        sub_y = cy + card_h + 2
        for sub_label, sub_measure in kpi.get("subs", []):
            _text(cx, sub_y, sub_w_label, sub_label_h,
                  text=sub_label, font_size="6pt", font_color="#888888")
            _card(cx + sub_w_label, sub_y, sub_w_value, sub_label_h,
                  sub_measure, font_color="#555555", font_size=7)
            sub_y += sub_label_h + 1

    # T1C bar
    t1c_y = sy + sh - T1C_H - 3
    _shape(sx + 5, t1c_y, sw - 10, T1C_H, fill_color=COLORS["t1c_bg"])

    tx = sx + 10
    for kpi in sec["kpis"]:
        t1c = kpi.get("t1c")
        if not t1c:
            continue
        _text(tx, t1c_y + 2, 80, 14, text=f"T1C {kpi['label']}",
              font_size="6pt", font_color="#999999")
        _card(tx + 80, t1c_y + 2, 30, 14, t1c, font_color="#555555", font_size=7)
        tx += 130 if sec.get("cols", 3) > 3 else 120

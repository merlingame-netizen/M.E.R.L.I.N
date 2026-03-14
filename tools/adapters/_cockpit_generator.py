"""Cockpit SAT v4 Generator — Encode cockpit_sat_v4.html layout as PBIR visuals.

Reference: C:/Users/PGNK2128/Downloads/cockpit_sat_v4.html
Generates all shapes, textboxes, cards, slicers for the Cockpit SAT ProPME dashboard.
"""

from __future__ import annotations

from typing import Any

from adapters._pbir_engine import (
    add_visual,
    load_report,
    save_report,
    set_page_background,
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
BANNER_H = 90
LEGEND_Y, LEGEND_H = 105, 14
BARO_X, BARO_Y, BARO_W, BARO_H = 8, 125, 170, 170
ACCUEIL_X, ACCUEIL_Y = 188, 125
ACCUEIL_W, ACCUEIL_H = 1084, 170
HEADER_H = 22
BOT_Y = 305
BOT_H = 200
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

# Filter slicers
SLICERS = [
    {"label": "Sondage Trans.", "table": "Filtre_Granularite", "column": "Granularite",
     "x": 640, "y": 10, "w": 150, "h": 38},
    {"label": "Période", "table": "Filtre_Periode", "column": "Periode",
     "x": 640, "y": 50, "w": 150, "h": 30},
    {"label": "Baromètre", "table": "Filtre_Baro_Granularite", "column": "Granularite",
     "x": 960, "y": 10, "w": 150, "h": 38},
    {"label": "Baro Période", "table": "Filtre_Baro_Periode", "column": "Periode",
     "x": 960, "y": 50, "w": 150, "h": 30},
]


# ── Generator ────────────────────────────────────────────────────────────────

def generate_cockpit(report_dir: str, template: str = "cockpit_sat_v4") -> dict:
    """Generate complete cockpit layout in an existing PBIP report.

    Clears existing visuals on page 0 and rebuilds from scratch.
    """
    report = load_report(report_dir)

    # Set page background
    report = set_page_background(report, 0, COLORS["bg"])

    # Clear existing visuals
    section = report["sections"][0]
    section["visualContainers"] = []

    visual_count = 0

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

    # Slicers
    for sl in SLICERS:
        report, _ = add_visual(report, 0, "slicer", sl["x"], sl["y"], sl["w"], sl["h"],
                                bindings={"Fields": [{"table": sl["table"], "column": sl["column"]}]},
                                title=sl["label"])
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
    # White container
    report, _ = add_visual(report, 0, "shape", BARO_X, BARO_Y, BARO_W, BARO_H,
                            properties={"fill_color": COLORS["white"]})
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

    # Response count card
    report, _ = add_visual(report, 0, "card", 30, BARO_Y + 110, 120, 20,
                            properties={"font_color": "#AAAAAA", "font_size": 9},
                            bindings={"Values": [{"table": MEASURE_TABLE, "measure": "NbRep_Baro_Global"}]})
    count += 1

    return report, count


def _add_accueil(report: dict, count: int) -> tuple[dict, int]:
    """Accueil section: header + 9 KPI cards in grid."""
    sec = SECTIONS["accueil"]

    # White background
    report, _ = add_visual(report, 0, "shape", ACCUEIL_X, ACCUEIL_Y, ACCUEIL_W, ACCUEIL_H,
                            properties={"fill_color": COLORS["white"]})
    count += 1

    # Colored header
    report, _ = add_visual(report, 0, "shape", ACCUEIL_X, ACCUEIL_Y, ACCUEIL_W, HEADER_H,
                            properties={"fill_color": sec["color"]})
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

        # Card background shape
        report, _ = add_visual(report, 0, "shape", cx, cy, card_w, card_h,
                                properties={"fill_color": COLORS["card_bg"]})
        count += 1

        # KPI label
        report, _ = add_visual(report, 0, "textbox", cx + 2, cy + 1, card_w - 4, 12,
                                properties={"text": kpi["label"], "font_size": "6.5pt",
                                            "font_color": "#888888", "font_weight": "bold"})
        count += 1

        # NPS value card
        report, _ = add_visual(report, 0, "card", cx + 2, cy + 13, card_w - 4, 28,
                                properties={"font_color": COLORS["orange"], "font_size": 22},
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
    # White background
    report, _ = add_visual(report, 0, "shape", sx, sy, BOT_W, BOT_H,
                            properties={"fill_color": COLORS["white"]})
    count += 1

    # Colored header
    report, _ = add_visual(report, 0, "shape", sx, sy, BOT_W, HEADER_H,
                            properties={"fill_color": sec["color"]})
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

        # Card background
        report, _ = add_visual(report, 0, "shape", cx, cy, card_w, card_h,
                                properties={"fill_color": COLORS["card_bg"]})
        count += 1

        # KPI label
        report, _ = add_visual(report, 0, "textbox", cx + 2, cy + 1, card_w - 4, 12,
                                properties={"text": kpi["label"], "font_size": "6.5pt",
                                            "font_color": "#888888", "font_weight": "bold"})
        count += 1

        # NPS value
        report, _ = add_visual(report, 0, "card", cx + 2, cy + 13, card_w - 4, 28,
                                properties={"font_color": COLORS["orange"], "font_size": 22},
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

"""
OneNote Orange Templates — Design System HTML inline
Palette Orange Brand: #FF7900, #000, #FFF, #333, #EEE, #CCC
Statuts: #50BE87 (ok), #CD3C14 (ko), #FFD200 (warning), #4BB4E6 (info), #999 (backlog)
"""

FONT = "'Helvetica Neue',Arial,sans-serif"

# --- Colors ---
C_ORANGE = "#FF7900"
C_BLACK = "#000000"
C_WHITE = "#FFFFFF"
C_TEXT = "#333333"
C_GRAY_LIGHT = "#EEEEEE"
C_GRAY_BORDER = "#CCCCCC"
C_BLUE = "#4BB4E6"
C_GREEN = "#50BE87"
C_RED = "#CD3C14"
C_YELLOW = "#FFD200"
C_PURPLE = "#A885D8"
C_GRAY = "#999999"

STATUS_COLORS = {
    "en cours": (C_GREEN, C_WHITE),
    "bloque": (C_RED, C_WHITE),
    "en attente": (C_YELLOW, C_BLACK),
    "termine": (C_BLUE, C_WHITE),
    "backlog": (C_GRAY, C_WHITE),
    "cette semaine": (C_ORANGE, C_WHITE),
    "haute": (C_RED, C_WHITE),
    "moyenne": (C_YELLOW, C_BLACK),
    "basse": (C_BLUE, C_WHITE),
    "decision": (C_BLUE, C_WHITE),
    "risque": (C_RED, C_WHITE),
}


def orange_header(title, subtitle="", section=""):
    """Header bandeau orange avec titre blanc."""
    sub = ""
    if subtitle or section:
        parts = []
        if subtitle:
            parts.append(subtitle)
        if section:
            parts.append(f"Section : {section}")
        sub = (
            f"<br/><span style=\"color:{C_WHITE};font-size:9pt;"
            f"font-family:{FONT};\">{' | '.join(parts)}</span>"
        )
    return (
        f"<div style=\"background:{C_ORANGE};padding:12px 20px;margin-bottom:16px;\">"
        f"<span style=\"color:{C_WHITE};font-size:18pt;font-weight:bold;"
        f"font-family:{FONT};\">{title}</span>"
        f"{sub}</div>"
    )


def orange_table(headers, rows, striped=True):
    """Tableau avec header noir, lignes alternees blanc/gris."""
    html = (
        f"<table style=\"border-collapse:collapse;width:100%;"
        f"font-family:{FONT};font-size:10pt;margin-bottom:16px;\">"
    )
    # Header row
    html += f"<tr style=\"background:{C_BLACK};\">"
    for h in headers:
        html += (
            f"<th style=\"color:{C_WHITE};padding:8px 12px;"
            f"text-align:left;border:1px solid #333;\">{h}</th>"
        )
    html += "</tr>"
    # Data rows
    for i, row in enumerate(rows):
        bg = C_GRAY_LIGHT if (striped and i % 2 == 1) else C_WHITE
        html += f"<tr style=\"background:{bg};\">"
        for cell in row:
            html += (
                f"<td style=\"padding:8px 12px;"
                f"border:1px solid {C_GRAY_BORDER};\">{cell}</td>"
            )
        html += "</tr>"
    html += "</table>"
    return html


def orange_kpi_cards(cards):
    """Ligne de KPI cards. cards = [(value, label, color), ...]"""
    html = (
        "<table style=\"border:none;margin-bottom:16px;\" "
        "cellpadding=\"0\" cellspacing=\"8\"><tr>"
    )
    for value, label, color in cards:
        html += (
            f"<td style=\"background:{color};padding:12px 20px;"
            f"text-align:center;min-width:130px;\">"
            f"<span style=\"color:{C_WHITE};font-size:24pt;"
            f"font-weight:bold;\">{value}</span><br/>"
            f"<span style=\"color:{C_WHITE};font-size:9pt;"
            f"font-family:{FONT};\">{label}</span></td>"
        )
    html += "</tr></table>"
    return html


def status_badge(status):
    """Badge colore pour un statut."""
    key = status.lower().strip()
    bg, fg = STATUS_COLORS.get(key, (C_GRAY, C_WHITE))
    return (
        f"<span style=\"background:{bg};color:{fg};"
        f"padding:2px 8px;font-size:8pt;font-weight:bold;\">"
        f"{status.upper()}</span>"
    )


def section_sep(title):
    """Separateur de section avec barre orange a gauche."""
    return (
        f"<div style=\"border-left:4px solid {C_ORANGE};"
        f"padding-left:12px;margin:16px 0 8px 0;\">"
        f"<span style=\"font-size:13pt;font-weight:bold;"
        f"color:{C_BLACK};\">{title}</span></div>"
    )


def orange_list(items):
    """Liste a puces avec carre orange."""
    html = "<ul style=\"list-style:none;padding-left:0;margin:8px 0;\">"
    for item in items:
        html += (
            f"<li style=\"padding:3px 0;font-family:{FONT};"
            f"font-size:10pt;color:{C_TEXT};\">"
            f"<span style=\"color:{C_ORANGE};font-weight:bold;"
            f"margin-right:8px;\">&#9632;</span>{item}</li>"
        )
    html += "</ul>"
    return html


def orange_callout(text, color=C_ORANGE):
    """Encadre / callout avec bordure coloree."""
    return (
        f"<div style=\"border:2px solid {color};padding:12px 16px;"
        f"margin:8px 0;background:{C_WHITE};\">"
        f"<span style=\"font-family:{FONT};font-size:10pt;"
        f"color:{C_TEXT};\">{text}</span></div>"
    )


def build_page_html(*blocks):
    """Assemble des blocs HTML en une page complete."""
    return "\n".join(blocks)

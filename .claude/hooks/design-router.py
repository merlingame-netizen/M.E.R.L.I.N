#!/usr/bin/env python3
"""design-router — UserPromptSubmit hook.

Détecte une intention de **design applicatif / UI / UX / frontend / animation**
dans le prompt utilisateur et injecte un rappel pour invoquer le méga-skill
`/design` (avec rappel de l'ÉTAPE 0 branding : Orange reste brandé).

Contrat hook :
  - stdin  : JSON { "prompt": "...", "hook_event_name": "UserPromptSubmit", ... }
  - stdout : texte ajouté au contexte (si match) — sinon rien.
  - exit 0 toujours (ne jamais bloquer le prompt).

Installé :
  - projet : `.claude/settings.json` (présent quand on travaille sur ce repo) ;
  - global : `~/.claude/settings.json` via `tools/install_design_skill.py`.
"""
from __future__ import annotations

import json
import re
import sys

# Mots-clés déclencheurs (minuscule, accents tolérés). Frontières de mot pour
# éviter les faux positifs (ex. "ui" dans "build", "css" dans "success").
_TRIGGERS = [
    r"design", r"\bui\b", r"\bux\b", r"front[\s-]?end", r"interface",
    r"\becrans?\b", r"\bécrans?\b", r"composants?", r"landing", r"maquette",
    r"wireframe", r"animation", r"anim[ée]", r"micro[\s-]?interaction",
    r"\bmotion\b", r"framer", r"21st", r"\bcharte\b", r"design[\s-]?system",
    r"responsive", r"\bcss\b", r"tailwind", r"accessibilit", r"\ba11y\b",
    r"branding", r"\bbrand\b", r"site\s+web", r"page\s+web", r"\bhero\b",
    r"\bwebapp\b", r"\bspa\b", r"th[èe]me\s+(visuel|graphique)", r"refonte",
    r"\bvitrine\b", r"portfolio", r"dashboard", r"\bhud\b", r"glassmorph",
]
_RE = re.compile("|".join(_TRIGGERS), re.IGNORECASE)

# Bypass : si le prompt commence par * / ! (préfixes outillage MERLIN), on ne
# nudge pas (l'utilisateur force un comportement explicite).
_BYPASS = ("*", "/", "!")

_REMINDER = (
    "[design-router] Cette demande relève du **design applicatif / UI / UX / "
    "frontend / animation**. Invoque le méga-skill **`/design`** (Skill tool, "
    "name=\"design\") AVANT d'écrire du code UI.\n"
    "ÉTAPE 0 obligatoire — BRANDING (`.claude/skills/design/branding/BRANDS.md`) :\n"
    " • Projet ORANGE → charte Orange (Boosted #FF7900, fond clair, animations "
    "SOBRES — jamais le style sombre/néon).\n"
    " • Client connu (IDRAC = rouge #A71F28 + or) → sa charte réelle.\n"
    " • Sinon (HTML autonome hors Orange) → style signature « Dark Animated ».\n"
    "Piliers : perf (Core Web Vitals) central, transform/opacity only, "
    "prefers-reduced-motion respecté, cibles ≥44px."
)


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0  # jamais bloquer
    prompt = str(data.get("prompt", "") or "")
    stripped = prompt.lstrip()
    if stripped[:1] in _BYPASS:
        return 0
    if _RE.search(prompt):
        sys.stdout.write(_REMINDER)
    return 0


if __name__ == "__main__":
    sys.exit(main())

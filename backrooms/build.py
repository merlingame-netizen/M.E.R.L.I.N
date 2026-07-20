#!/usr/bin/env python3
"""
Assemble the self-contained Poolrooms game.

Concatenates `vendor/three.module.js` + `game.js` into a single inline
<script type="module"> and injects it into `shell.html`, producing:

  * index.html         — full standalone HTML page (deployable anywhere)
  * (optional 2nd arg) — body-only variant for the Claude Artifact tool
                         (no <!doctype>/<html>/<head>/<body>; those are added
                         by the Artifact host)

game.js is wrapped in an IIFE so none of its top-level identifiers can collide
with Three.js's (e.g. clamp/lerp/min/max), while still closing over every
Three.js class exported into the shared module scope.

Usage:
  python build.py                       # writes index.html
  python build.py /path/to/artifact.html  # also writes the Artifact body
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
THREE = (ROOT / "vendor" / "three.module.js").read_text(encoding="utf-8")
GAME = (ROOT / "game.js").read_text(encoding="utf-8")
SHELL = (ROOT / "shell.html").read_text(encoding="utf-8")

# Strip Three.js's single top-level `export { ... };` — the bindings stay in
# module scope, so the IIFE below can still reference them by name.
three_body, n = re.subn(r"(?m)^export\s*\{[^;{}]*\}\s*;\s*$", "", THREE)
if n != 1:
    sys.exit(f"build.py: expected exactly 1 top-level export in three.module.js, found {n}")

module_js = (
    "/* ==== vendored three.js r170 (MIT) — do not edit; see vendor/three.module.js ==== */\n"
    + three_body.rstrip()
    + "\n\n/* ==== Poolrooms game (see game.js) ==== */\n"
    + ";(function(){\n"
    + GAME
    + "\n})();\n"
)

script_tag = '<script type="module">\n' + module_js + "\n</script>"
body = SHELL.replace("<!--INLINE_SCRIPT-->", script_tag)

DESC = ("Poolrooms — a visually rich, mobile-playable Three.js Backrooms (Level 37) game: "
        "wade the endless liminal pools, collect the almond water, reach the exit, evade the entity.")

page = f"""<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="theme-color" content="#05201f">
<meta name="description" content="{DESC}">
<title>Poolrooms — Backrooms Level 37</title>
</head>
<body>
{body}
</body>
</html>
"""

(ROOT / "index.html").write_text(page, encoding="utf-8")
print(f"wrote {ROOT/'index.html'} ({len(page)//1024} KB)")

if len(sys.argv) > 1:
    Path(sys.argv[1]).write_text(body, encoding="utf-8")
    print(f"wrote {sys.argv[1]} ({len(body)//1024} KB, artifact body)")

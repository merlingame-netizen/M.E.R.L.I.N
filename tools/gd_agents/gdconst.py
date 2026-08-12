#!/usr/bin/env python3
"""Lecture/patch des constantes GDScript — le socle des analyseurs qui proposent
un diff plutôt qu'une note.

Pourquoi ce module existe : le codeur local (`coder_local.py`) n'applique que des
propositions portant `change.before` / `change.after`, un remplacement de texte
exact. Aucun analyseur ne savait produire ça, donc TOUTE la chaîne autonome
s'arrêtait à la file de missions. Ici on donne aux analyseurs le seul outil qui
manquait : lire une constante, calculer sa valeur corrigée EN PYTHON, et rendre
le couple de lignes exactes à échanger.

Doctrine : le LLM ne calcule jamais un chiffre. Il ne fait que mettre en mots ce
que ce module a mesuré.

Trois formes de déclaration sont reconnues dans `merlin_constants.gd` :
    const NOM := 25
    const NOM: int = 25
    const NOM: float = 0.10
…et les entiers nommés à l'intérieur d'un dictionnaire constant :
    const EFFECT_CAPS := {
        "drain_per_card": 1,
        "ADD_REPUTATION": {"max": 20, "min": -20},
    }

Stdlib seule. Ne lève jamais sur un fichier absent ou illisible.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# Chemin tel que le codeur local l'attend (relatif au dépôt du jeu).
CONSTANTS_TARGET = "scripts/merlin/merlin_constants.gd"


def _constants_path() -> Path:
    """Le fichier de VÉRITÉ pour produire un `before`.

    Sur la VM, le jeu vit dans son propre dépôt (`~/workspace/merlin-game`) et le
    codeur patche un worktree de CE dépôt. Lire la copie du dépôt d'outillage
    donnerait un `before` qui n'existe pas là-bas : le patch serait rejeté avec
    « le texte à remplacer n'existe pas ». On lit donc le clone du jeu s'il est
    présent, l'outillage sinon (poste de dev, tests)."""
    game = Path.home() / "workspace" / "merlin-game" / CONSTANTS_TARGET
    return game if game.exists() else ROOT / CONSTANTS_TARGET


CONSTANTS = _constants_path()

# `const NOM[: type] =|:= <nombre>` suivi éventuellement d'un commentaire.
_SCALAR = re.compile(
    r"^(?P<head>const\s+(?P<name>[A-Z][A-Z0-9_]*)\s*(?::\s*(?:int|float)\s*)?:?=\s*)"
    r"(?P<value>-?\d+(?:\.\d+)?)(?P<tail>\s*(?:#.*)?)$")


def source(path: Path | None = None) -> str:
    try:
        return (path or CONSTANTS).read_text(encoding="utf-8")
    except Exception:
        return ""


def scalars(path: Path | None = None) -> dict[str, dict]:
    """{NOM: {value, line, lineno, unique}} pour toutes les constantes scalaires.

    `unique` dit si la ligne apparaît une seule fois dans le fichier : le codeur
    refuse un remplacement ambigu, autant le savoir dès la proposition."""
    text = source(path)
    out: dict[str, dict] = {}
    lines = text.splitlines()
    for i, line in enumerate(lines, 1):
        m = _SCALAR.match(line.strip())
        if not m:
            continue
        raw = m.group("value")
        out[m.group("name")] = {
            "value": float(raw) if "." in raw else int(raw),
            "raw": raw,               # le littéral TEL QU'ÉCRIT (« 2.0 », pas « 2 »)
            "line": line,
            "lineno": i,
            "unique": text.count(line) == 1,
        }
    return out


def dict_ints(const_name: str, path: Path | None = None) -> dict[str, dict]:
    """Entiers nommés à l'intérieur d'un dictionnaire constant.

    Les clés imbriquées sont aplaties avec un point : `ADD_REPUTATION.max`.
    On lit le bloc `const NOM := { … }` par comptage d'accolades (pas de parseur
    GDScript : on n'a besoin que des couples "clé": nombre)."""
    text = source(path)
    start = text.find(f"const {const_name} ")
    if start < 0:
        return {}
    depth, i, opened = 0, text.find("{", start), False
    if i < 0:
        return {}
    j = i
    while j < len(text):
        if text[j] == "{":
            depth += 1
            opened = True
        elif text[j] == "}":
            depth -= 1
            if opened and depth == 0:
                break
        j += 1
    block = text[i:j + 1]
    base_line = text[:i].count("\n")

    out: dict[str, dict] = {}
    parent = ""
    for k, line in enumerate(block.splitlines()):
        stripped = line.strip()
        key = re.match(r'"([^"]+)"\s*:\s*\{', stripped)
        if key:
            parent = key.group(1)
        # une ligne peut porter plusieurs couples : {"max": 20, "min": -20}
        inline_parent = key.group(1) if key else parent
        for kk, vv in re.findall(r'"([^"]+)"\s*:\s*(-?\d+(?:\.\d+)?)\s*[,}]', stripped):
            name = f"{inline_parent}.{kk}" if key or (parent and not stripped.startswith('"' + kk)) else kk
            if not key and re.match(rf'"{re.escape(kk)}"\s*:', stripped):
                name = kk          # clé de premier niveau
            out[name] = {
                "value": float(vv) if "." in vv else int(vv),
                "raw": vv,
                "line": line,
                "lineno": base_line + k + 1,
                "unique": text.count(line) == 1,
            }
        if stripped.endswith("},") or stripped == "}":
            parent = ""
    return out


def patch_line(entry: dict, new_value) -> tuple[str, str] | None:
    """(before, after) — la ligne exacte à échanger, commentaire préservé.

    Rend None si la ligne n'est pas unique dans le fichier (le codeur refuserait
    le remplacement) ou si la valeur ne change pas."""
    line = entry.get("line", "")
    if not line or not entry.get("unique"):
        return None
    old = entry["value"]
    if old == new_value:
        return None
    # On cherche le littéral TEL QU'ÉCRIT dans le fichier. Reformater l'ancienne
    # valeur ne marche pas : `2.0` reformaté donne `2`, qui ne se trouve nulle
    # part dans « "score_bonus_cap": 2.0, » — le patch échouait en silence.
    ancien = entry.get("raw") or (f"{old:g}" if isinstance(old, float) else str(int(old)))
    nouveau = (str(int(new_value)) if isinstance(old, int) or float(new_value).is_integer()
               and "." not in ancien else f"{float(new_value):g}")
    # On ne touche QUE le nombre de la déclaration, jamais un chiffre du
    # commentaire de fin de ligne : découper sur le premier # est indispensable.
    code, sep, comment = line.partition("#")
    new_code, n = re.subn(rf"(?<![\w.]){re.escape(ancien)}(?![\w.])", nouveau, code, count=1)
    if n != 1:
        return None
    return line, new_code + sep + comment


if __name__ == "__main__":
    import json
    sc = scalars()
    print(f"{len(sc)} constantes scalaires lues dans {CONSTANTS_TARGET}")
    for n in ("LIFE_ESSENCE_MAX", "LIFE_ESSENCE_DRAIN_PER_CARD", "MIN_CARDS_FOR_VICTORY",
              "SESSION_CARDS_MIN", "SESSION_CARDS_MAX", "LIFE_ESSENCE_HEAL_PER_REST"):
        if n in sc:
            print(f"  {n:32} = {sc[n]['value']}  (l.{sc[n]['lineno']}, "
                  f"{'unique' if sc[n]['unique'] else 'AMBIGU'})")
    caps = dict_ints("EFFECT_CAPS")
    print("\nEFFECT_CAPS :", json.dumps({k: v["value"] for k, v in caps.items()},
                                        ensure_ascii=False))
    demo = patch_line(sc["LIFE_ESSENCE_HEAL_PER_REST"], 20)
    print("\nexemple de patch :\n  avant : " + demo[0] + "\n  après : " + demo[1])

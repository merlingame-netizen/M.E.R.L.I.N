# -*- coding: utf-8 -*-
"""Agent factory M.E.R.L.I.N. (BIBLE §24, R119).

Genere des fiches agents .claude/agents/<name>.md depuis un template canon,
met a jour le registre AGENTS.md, et valide le parc existant (refs mortes,
systemes obsoletes pre-reset 2026-05-25).

Usage:
    python tools/create_agent.py --list
    python tools/create_agent.py --validate
    python tools/create_agent.py --name sfx_reviewer --role "Revue des SFX" \
        --triggers "sfx,audio review" --refs "docs/BIBLE.md,scripts/game/merlin_fx.gd"
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
AGENTS_DIR = PROJECT_ROOT / ".claude" / "agents"
REGISTRY = AGENTS_DIR / "AGENTS.md"

# Systemes des jeux ANTERIEURS au reset 2026-05-25 — toute mention = fiche perimee.
# HEURISTIQUE rapport-seulement : un faux positif est possible (ex. \bMOS\b) ; la sortie
# est un backlog de relecture humaine/agent, jamais un gate bloquant.
STALE_PATTERNS: dict[str, str] = {
    "ogham": r"\boghams?\b",
    "rune-circuit": r"rune[-_]circuits?",
    "mos": r"\bMOS\b",
    "fastroute": r"fastroute",
    "bestiole": r"bestiole",
    "triade": r"\btriade\b",
    "souffle": r"souffle d'ogham",
    "biome 3d/rail": r"3d rail|broceliandeforest3d|merlincabinhub|introceltos",
    "5 factions reputation": r"druides/anciens/korrigans|niamh|ankou",
    "minigames": r"\bminigames?\b",
    "scripts/merlin (supprime)": r"scripts/merlin/",
}

# Refs de fichiers a verifier (chemins projet plausibles dans les fiches).
FILE_REF_RE = re.compile(
    r"`?((?:docs|scripts|tools|addons|data|scenes|assets|audio|music)/[\w\-./]+\.\w{1,5})`?"
)

TEMPLATE = """# {title} — M.E.R.L.I.N.

> Genere par `tools/create_agent.py` le {date}. Canon = `docs/BIBLE.md` v2.0.

## Role
{role}

## AUTO-ACTIVATION RULE
**Invoke this agent AUTOMATICALLY when:**
{triggers_block}

## Expertise
- (a completer apres premiere mission)

## Checklist
- [ ] Lire `docs/BIBLE.md` (sections pertinentes) AVANT toute action
- [ ] Verdict structure : APPROUVE / MODIFIE (spec exacte) / REJETE (regle canon citee)
- [ ] Gates BIBLE §24 respectes selon le type de changement

## Reference Files
{refs_block}

## Communication
Rapport concis : verdict + faits + citations canon. Escalade `merlin_guardian` si
derogation a la vision, AskUserQuestion si decision user requise.
"""


@dataclass
class LintResult:
    """Resultat de lint d'une fiche agent."""

    name: str
    dead_refs: list[str] = field(default_factory=list)
    stale_hits: list[str] = field(default_factory=list)

    @property
    def is_clean(self) -> bool:
        return not self.dead_refs and not self.stale_hits


def _iter_agent_files() -> list[Path]:
    return sorted(p for p in AGENTS_DIR.glob("*.md") if p.name != "AGENTS.md")


def list_agents() -> int:
    """Affiche le parc : nom de fichier + titre (1re ligne #)."""
    files = _iter_agent_files()
    for path in files:
        title = ""
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("# "):
                title = line[2:].strip()
                break
        print(f"{path.name:45s} {title}")
    print(f"\n{len(files)} agents")
    return 0


def _lint_file(path: Path) -> LintResult:
    text = path.read_text(encoding="utf-8", errors="replace")
    low = text.lower()
    result = LintResult(name=path.name)

    for label, pattern in STALE_PATTERNS.items():
        if re.search(pattern, low, flags=re.IGNORECASE):
            result.stale_hits.append(label)

    seen: set[str] = set()
    for match in FILE_REF_RE.finditer(text):
        ref = match.group(1).rstrip(".,;:")
        if ref in seen:
            continue
        seen.add(ref)
        if not (PROJECT_ROOT / ref).exists():
            result.dead_refs.append(ref)
    return result


def validate_park() -> int:
    """Lint du parc complet : refs mortes + mentions de systemes obsoletes.

    Exit 0 toujours (mode rapport) — la sortie sert de backlog de reecriture.
    """
    results = [_lint_file(p) for p in _iter_agent_files()]
    clean = [r for r in results if r.is_clean]
    dirty = [r for r in results if not r.is_clean]

    print(f"=== create_agent --validate : {len(results)} fiches, "
          f"{len(clean)} propres, {len(dirty)} a reecrire ===\n")
    for r in sorted(dirty, key=lambda x: -(len(x.dead_refs) + len(x.stale_hits))):
        print(f"[STALE] {r.name}")
        if r.stale_hits:
            print(f"        systemes obsoletes : {', '.join(r.stale_hits)}")
        if r.dead_refs:
            print(f"        refs mortes        : {', '.join(r.dead_refs[:6])}"
                  + (" ..." if len(r.dead_refs) > 6 else ""))
    if dirty:
        print("\nReecrire en priorite les fiches invoquees par les cascades "
              "(game_designer, ux_flow, game_playtester, game_design_auditor, "
              "content_*, audio_*) — canon = docs/BIBLE.md v2.0.")
    return 0


def create_agent(name: str, role: str, triggers: str, refs: str) -> int:
    """Cree .claude/agents/<name>.md depuis le template + enregistre dans AGENTS.md."""
    if not re.fullmatch(r"[a-z][a-z0-9_]+", name):
        print(f"ERREUR: nom invalide '{name}' (snake_case ascii attendu)")
        return 1
    target = AGENTS_DIR / f"{name}.md"
    if target.exists():
        print(f"ERREUR: {target} existe deja — editer la fiche existante.")
        return 1

    from datetime import date as _date
    title = name.replace("_", " ").title()
    triggers_list = [t.strip() for t in triggers.split(",") if t.strip()]
    refs_list = [r.strip() for r in refs.split(",") if r.strip()]
    if "docs/BIBLE.md" not in refs_list:
        refs_list.insert(0, "docs/BIBLE.md")

    content = TEMPLATE.format(
        title=title,
        date=_date.today().isoformat(),
        role=role,
        triggers_block="\n".join(f"- Mots-cles : `{t}`" for t in triggers_list)
        or "- (definir les declencheurs)",
        refs_block="\n".join(f"- `{r}`" for r in refs_list),
    )
    target.write_text(content, encoding="utf-8")
    print(f"OK: {target.relative_to(PROJECT_ROOT)} cree")

    if REGISTRY.exists():
        reg_text = REGISTRY.read_text(encoding="utf-8", errors="replace")
        marker = "### Generated (factory)"
        header = "| Role | File | Specialty |\n|------|------|-----------|\n"
        row = f"| **{title}** | `{name}.md` | {role} |\n"
        if marker not in reg_text:
            reg_text += f"\n\n{marker}\n\n{header}{row}"
        else:
            # Insertion DANS la table de la section (jamais en fin de fichier — review HIGH-1).
            anchor = reg_text.index(marker)
            sep_at = reg_text.find("|------|------|-----------|\n", anchor)
            if sep_at == -1:
                reg_text = reg_text[:anchor] + f"{marker}\n\n{header}{row}" \
                    + reg_text[anchor + len(marker):].lstrip("\n")
            else:
                insert_at = sep_at + len("|------|------|-----------|\n")
                reg_text = reg_text[:insert_at] + row + reg_text[insert_at:]
        REGISTRY.write_text(reg_text, encoding="utf-8")
        print(f"OK: registre {REGISTRY.name} mis a jour")
    return 0


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description="Agent factory M.E.R.L.I.N. (BIBLE §24)")
    parser.add_argument("--list", action="store_true", help="lister le parc")
    parser.add_argument("--validate", action="store_true",
                        help="lint du parc (refs mortes, obsolescence)")
    parser.add_argument("--name", help="nom snake_case du nouvel agent")
    parser.add_argument("--role", default="", help="role d'une ligne")
    parser.add_argument("--triggers", default="",
                        help="mots-cles d'activation, separes par des virgules")
    parser.add_argument("--refs", default="",
                        help="fichiers de reference, separes par des virgules")
    args = parser.parse_args()

    if args.list:
        return list_agents()
    if args.validate:
        return validate_park()
    if args.name:
        if not args.role:
            print("ERREUR: --role requis avec --name")
            return 1
        return create_agent(args.name, args.role, args.triggers, args.refs)
    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

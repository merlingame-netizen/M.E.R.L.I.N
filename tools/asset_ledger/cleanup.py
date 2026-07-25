#!/usr/bin/env python3
"""
asset_ledger/cleanup.py - M.E.R.L.I.N. asset quarantine tool.

Consumes docs/asset-ledger/graph.json (written by scan.py, schema_version 3)
and proposes / performs a SAFE quarantine of orphan_static assets.

This tool NEVER deletes anything by itself. It only ever MOVES files into a
git-tracked .trash/<date>/ mirror of their original path, on a dedicated git
branch that is never pushed or merged automatically. The only place real
deletion can happen is --purge-trash, and only on already-quarantined trash
batches older than the retention window.

Modes:
  (default)       dry-run: compute the plan, write the proposal markdown,
                  touch nothing on disk and nothing in git.
  --apply         create branch, move files to .trash/, commit. Stays on the
                  new branch for human/Claude review (no push, no merge).
  --auto          same as --apply, meant for non-interactive callers such as
                  watchdog.py. Candidates are always orphan_static only.
  --purge-trash   hard-delete expired .trash/<date>/ batches (retention_days).

Pure stdlib (Python 3.12).
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

RETENTION_DAYS_DEFAULT = 30

# Defense-in-depth: even though the scanner already never marks these as
# orphan_static, we re-check here so cleanup.py is safe to run against any
# graph.json, including hand-edited or stale ones.
FORBIDDEN_PREFIXES = (
    "addons/", "docs/", "tests/", ".git", ".godot",
    "scenes/", "scripts/", "tools/", "data/i18n/",
)
FORBIDDEN_SUFFIXES = (".translation",)
FORBIDDEN_NAMES = {
    "project.godot", "export_presets.cfg", "icon.svg", "default_bus_layout.tres",
}


# --------------------------------------------------------------------------- #
# Small helpers (kept local, no coupling to scan.py internals)
# --------------------------------------------------------------------------- #

def human(n: int) -> str:
    f = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if f < 1024 or unit == "TB":
            return f"{f:.1f} {unit}" if unit != "B" else f"{int(f)} B"
        f /= 1024
    return f"{f:.1f} TB"


def now_iso() -> str:
    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S")


def load_graph(graph_path: Path) -> dict:
    try:
        return json.loads(graph_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: failed to read graph {graph_path}: {exc}", file=sys.stderr)
        sys.exit(2)


# --------------------------------------------------------------------------- #
# Candidate selection
# --------------------------------------------------------------------------- #

def _prefix_blocks(rel: str, prefix: str) -> bool:
    clean = prefix.rstrip("/")
    return rel == clean or rel.startswith(clean + "/")


def path_guard_reason(rel: str) -> str | None:
    """Return a block reason if rel must never be touched, else None."""
    posix_rel = rel.replace("\\", "/")
    for prefix in FORBIDDEN_PREFIXES:
        if _prefix_blocks(posix_rel, prefix):
            return f"forbidden prefix ({prefix})"
    if posix_rel.endswith(FORBIDDEN_SUFFIXES):
        return "translation file"
    name = posix_rel.rsplit("/", 1)[-1]
    if name in FORBIDDEN_NAMES:
        return f"forbidden name ({name})"
    return None


def load_keep_globs(root: Path) -> list[str]:
    keep_file = root / ".asset-keep"
    if not keep_file.exists():
        return []
    patterns: list[str] = []
    for raw in keep_file.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.upper().startswith("KEEP:"):
            line = line[5:].strip()
        if line:
            patterns.append(line)
    return patterns


def matches_keep(rel: str, patterns: list[str]) -> str | None:
    posix_rel = rel.replace("\\", "/")
    for pat in patterns:
        if fnmatch.fnmatch(posix_rel, pat):
            return pat
    return None


def build_plan(
    root: Path, graph: dict, max_bytes: int | None
) -> tuple[list[dict], list[tuple[dict, str]], list[tuple[dict, str]]]:
    """Return (selected, kept_by_asset_keep, skipped_by_guard)."""
    keep_globs = load_keep_globs(root)
    selected: list[dict] = []
    kept: list[tuple[dict, str]] = []
    skipped: list[tuple[dict, str]] = []

    for node in graph.get("nodes", []):
        if node.get("status") != "orphan_static":
            continue
        rel = node.get("rel", "")
        reason = path_guard_reason(rel)
        if reason:
            skipped.append((node, reason))
            continue
        pat = matches_keep(rel, keep_globs)
        if pat:
            kept.append((node, pat))
            continue
        selected.append(node)

    selected.sort(key=lambda n: n.get("size_bytes", 0), reverse=True)

    if max_bytes is not None:
        capped: list[dict] = []
        total = 0
        for node in selected:
            if total >= max_bytes:
                break
            capped.append(node)
            total += node.get("size_bytes", 0)
        selected = capped

    return selected, kept, skipped


# --------------------------------------------------------------------------- #
# Trash / git primitives
# --------------------------------------------------------------------------- #

def _rel_is_safe(rel: str) -> bool:
    """Reject absolute paths or any '..' segment (defense against poisoned graph)."""
    if not rel or os.path.isabs(rel) or rel.startswith(("/", "\\")):
        return False
    parts = rel.replace("\\", "/").split("/")
    return ".." not in parts


def move_to_trash(root: Path, rel: str, date_str: str) -> tuple[bool, str]:
    if not _rel_is_safe(rel):
        return False, "unsafe path rejected (absolute or contains '..')"
    src = (root / rel).resolve()
    dst = (root / ".trash" / date_str / rel).resolve()
    root_res = root.resolve()
    # Both endpoints must stay inside the project root.
    if root_res not in src.parents and src != root_res:
        return False, "source escapes project root"
    if root_res not in dst.parents:
        return False, "destination escapes project root"
    if not src.exists():
        return False, "source missing on disk"
    if dst.exists():
        return False, "already present in .trash (skipped)"
    dst.parent.mkdir(parents=True, exist_ok=True)
    try:
        shutil.move(str(src), str(dst))
    except (OSError, shutil.Error) as exc:
        return False, f"move failed: {exc}"
    return True, "moved"


def purge_trash(root: Path, retention_days: int) -> list[tuple[str, int]]:
    """Hard-delete .trash/<date>/ batches older than retention_days. Returns
    [(batch_name, bytes_freed), ...]. This is the ONLY real deletion path."""
    trash_root = root / ".trash"
    removed: list[tuple[str, int]] = []
    if not trash_root.exists():
        return removed
    cutoff = datetime.now() - timedelta(days=retention_days)
    for child in sorted(trash_root.iterdir()):
        if not child.is_dir():
            continue
        try:
            batch_date = datetime.strptime(child.name, "%Y-%m-%d")
        except ValueError:
            continue
        if batch_date >= cutoff:
            continue
        size = 0
        for f in child.rglob("*"):
            try:
                if f.is_file():
                    size += f.stat().st_size
            except OSError:
                pass
        shutil.rmtree(child, ignore_errors=True)
        removed.append((child.name, size))
    return removed


def run_git(root: Path, args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args], cwd=root, capture_output=True, text=True, timeout=60
    )


def git_available(root: Path) -> bool:
    try:
        result = run_git(root, ["rev-parse", "--is-inside-work-tree"])
        return result.returncode == 0 and result.stdout.strip() == "true"
    except (OSError, subprocess.SubprocessError):
        return False


def git_branch_exists(root: Path, name: str) -> bool:
    result = run_git(root, ["rev-parse", "--verify", "--quiet", f"refs/heads/{name}"])
    return result.returncode == 0


def unique_branch_name(root: Path, base: str) -> str:
    if not git_branch_exists(root, base):
        return base
    i = 2
    while git_branch_exists(root, f"{base}-{i}"):
        i += 1
    return f"{base}-{i}"


def git_create_and_checkout(root: Path, name: str) -> bool:
    return run_git(root, ["checkout", "-b", name]).returncode == 0


def git_add_paths(root: Path, pathspecs: list[str]) -> bool:
    """Stage ONLY the given pathspecs (never `git add -A`), recording both
    additions (.trash) and deletions (moved sources). Avoids sweeping unrelated
    working-tree changes into the automated commit."""
    if not pathspecs:
        return True
    # chunk to stay well under command-line limits
    ok = True
    for i in range(0, len(pathspecs), 200):
        chunk = pathspecs[i:i + 200]
        if run_git(root, ["add", "-A", "--", *chunk]).returncode != 0:
            ok = False
    return ok


def git_diff_stat_cached(root: Path) -> str:
    result = run_git(root, ["diff", "--cached", "--stat"])
    return result.stdout.strip() if result.returncode == 0 else ""


def git_commit(root: Path, message: str) -> bool:
    return run_git(root, ["commit", "-m", message]).returncode == 0


def build_commit_message(moved: int, moved_bytes: int, trash_date: str) -> str:
    return (
        f"chore(assets): quarantine {moved} orphan assets ({human(moved_bytes)} freed)\n\n"
        f"Moved to .trash/{trash_date}/ mirroring original res:// paths.\n"
        f"Reversible: `git checkout main -- <path>` to restore a tracked file, "
        f"or move the file back from .trash/{trash_date}/<path> to <path>.\n"
        f"Nothing was hard-deleted; --purge-trash only removes batches past retention.\n\n"
        f"Generated by tools/asset_ledger/cleanup.py"
    )


@dataclass
class ApplyResult:
    branch: str
    moved: int = 0
    moved_bytes: int = 0
    skipped: list[tuple[str, str]] = field(default_factory=list)
    diff_stat: str = ""
    committed: bool = False


def do_apply(root: Path, selected: list[dict], use_branch: bool) -> ApplyResult:
    """Move selected orphans into .trash/. Reversibility comes from .trash itself.

    use_branch=True  (interactive --apply): create a dedicated review branch and
      commit ONLY the affected paths, then stay on the branch for human review.
    use_branch=False (unattended --auto from watchdog): NO branch switch, NO
      commit, NO sweep of unrelated WIP. Files are recoverable from .trash.
    """
    has_git = git_available(root)
    if use_branch and not has_git:
        print("ERROR: --apply requires a git repository", file=sys.stderr)
        sys.exit(3)

    date_str = datetime.now().strftime("%Y-%m-%d")
    branch = ""
    if use_branch:
        branch = unique_branch_name(root, f"chore/asset-cleanup-{date_str}")
        if not git_create_and_checkout(root, branch):
            print(f"ERROR: failed to create/checkout branch {branch}", file=sys.stderr)
            sys.exit(3)

    result = ApplyResult(branch=branch)
    moved_rels: list[str] = []
    for node in selected:
        ok, reason = move_to_trash(root, node["rel"], date_str)
        if ok:
            result.moved += 1
            result.moved_bytes += node.get("size_bytes", 0)
            moved_rels.append(node["rel"])
        else:
            result.skipped.append((node["rel"], reason))
            print(f"[cleanup] SKIP {node['rel']}: {reason}", file=sys.stderr)

    if has_git and moved_rels:
        # Stage only the moved sources (deletions) + the .trash additions.
        git_add_paths(root, [".trash", *moved_rels])
        result.diff_stat = git_diff_stat_cached(root)
        if use_branch:
            message = build_commit_message(result.moved, result.moved_bytes, date_str)
            result.committed = git_commit(root, message)
            if not result.committed:
                print("WARNING: git commit failed (files are still quarantined in .trash)",
                      file=sys.stderr)
    return result


# --------------------------------------------------------------------------- #
# Proposal markdown
# --------------------------------------------------------------------------- #

def write_proposal_md(
    root: Path,
    mode: str,
    selected: list[dict],
    kept: list[tuple[dict, str]],
    skipped_guard: list[tuple[dict, str]],
    branch_name: str | None = None,
    diff_stat: str | None = None,
) -> Path:
    date_str = datetime.now().strftime("%Y-%m-%d")
    out_dir = root / "docs" / "asset-ledger"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"CLEANUP-PROPOSAL-{date_str}.md"
    total_bytes = sum(n.get("size_bytes", 0) for n in selected)

    lines: list[str] = [
        "# Proposition de nettoyage des assets orphelins",
        "",
        f"Genere: {now_iso()}",
        f"Mode: {mode}",
        f"Fichiers candidats: {len(selected)}",
        f"Volume total a liberer: {human(total_bytes)} ({total_bytes} octets)",
    ]
    if branch_name:
        lines.append(f"Branche: `{branch_name}`")
    lines += [
        "",
        "Ces fichiers ont le statut `orphan_static` dans le graphe de reference "
        "(docs/asset-ledger/graph.json) : aucune reference statique n'est detectee "
        "depuis les racines du jeu (project.godot, export_presets.cfg, addons actives).",
        "",
        "## Candidats (tries par taille decroissante)",
        "",
        "| Chemin | Taille | Type | Derniere modif | Git |",
        "|---|---|---|---|---|",
    ]
    for n in selected:
        git_flag = "oui" if n.get("git_tracked") else "non"
        lines.append(
            f"| `{n.get('rel')}` | {human(n.get('size_bytes', 0))} | "
            f"{n.get('type', '?')} | {n.get('mtime', '?')} | {git_flag} |"
        )
    lines.append("")

    if kept:
        lines += ["## Ecartes par .asset-keep", "", "| Chemin | Motif |", "|---|---|"]
        for n, pat in kept:
            lines.append(f"| `{n.get('rel')}` | `{pat}` |")
        lines.append("")

    if skipped_guard:
        lines += [
            "## Ecartes par le garde-fou de chemin (defense-in-depth)",
            "",
            "| Chemin | Raison |",
            "|---|---|",
        ]
        for n, reason in skipped_guard:
            lines.append(f"| `{n.get('rel')}` | {reason} |")
        lines.append("")

    if diff_stat:
        lines += ["## Apercu git diff --stat", "", "```", diff_stat, "```", ""]

    lines += [
        "## Reversibilite",
        "",
        "Aucun fichier n'est jamais supprime directement par cet outil. En mode "
        "--apply/--auto, les fichiers sont deplaces vers `.trash/<date>/<chemin original>` "
        "sur une branche git dediee, jamais fusionnee ni poussee automatiquement.",
        "",
        "Pour restaurer un fichier :",
        "- Depuis git (si suivi) : `git checkout main -- <chemin>`",
        "- Depuis la quarantaine : deplacer `.trash/<date>/<chemin>` vers `<chemin>`",
        "",
        "Le contenu de `.trash/` n'est supprime pour de bon qu'apres expiration de la "
        "retention (`--purge-trash`, defaut 30 jours), et uniquement sur des lots deja "
        "en quarantaine.",
        "",
    ]
    out_path.write_text("\n".join(lines), encoding="utf-8")
    return out_path


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Quarantine orphan_static assets from docs/asset-ledger/graph.json "
            "into .trash/ (never hard-deletes)."
        )
    )
    parser.add_argument("--root", default=".", help="Project root (default: cwd)")
    parser.add_argument(
        "--graph", default=None,
        help="Path to graph.json (default: <root>/docs/asset-ledger/graph.json)",
    )
    parser.add_argument(
        "--apply", action="store_true",
        help="Create a git branch, quarantine files, commit (no push, no merge)",
    )
    parser.add_argument(
        "--auto", action="store_true",
        help="Like --apply, non-interactive, static-only (used by watchdog.py)",
    )
    parser.add_argument(
        "--purge-trash", action="store_true", dest="purge_trash",
        help="Hard-delete .trash/<date>/ batches older than retention (real deletion)",
    )
    parser.add_argument(
        "--retention-days", type=int, default=RETENTION_DAYS_DEFAULT,
        help="Trash retention in days for --purge-trash (default: 30)",
    )
    parser.add_argument(
        "--max-bytes", type=int, default=None,
        help="Cap selection to the biggest orphans until this many bytes is reached",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)
    root = Path(args.root).resolve()

    if args.purge_trash:
        removed = purge_trash(root, args.retention_days)
        freed = sum(size for _, size in removed)
        print(
            f"[cleanup] purge-trash: removed {len(removed)} expired batch(es), "
            f"freed {human(freed)}", file=sys.stderr,
        )
        for name, size in removed:
            print(f"  - .trash/{name} ({human(size)})", file=sys.stderr)
        return 0

    graph_path = (
        Path(args.graph).resolve() if args.graph
        else root / "docs" / "asset-ledger" / "graph.json"
    )
    if not graph_path.exists():
        print(f"ERROR: graph not found at {graph_path}", file=sys.stderr)
        print(
            "Run the scanner first: "
            f"python tools/asset_ledger/scan.py --root \"{root}\"", file=sys.stderr,
        )
        return 2

    graph = load_graph(graph_path)
    selected, kept, skipped_guard = build_plan(root, graph, args.max_bytes)

    exit_code = 0
    if args.apply or args.auto:
        use_branch = bool(args.apply)   # --auto never branches/commits
        mode = "apply" if args.apply else "auto"
        result = do_apply(root, selected, use_branch)
        proposal = write_proposal_md(
            root, mode, selected, kept, skipped_guard,
            branch_name=result.branch or "(none: auto quarantine to .trash)",
            diff_stat=result.diff_stat,
        )
        print(
            f"[cleanup] mode={mode} branch={result.branch or '-'} moved={result.moved} "
            f"freed={human(result.moved_bytes)} skipped={len(result.skipped)} "
            f"committed={result.committed}", file=sys.stderr,
        )
        # M3: signal failure if an interactive apply moved files but could not commit.
        if use_branch and result.moved > 0 and not result.committed:
            exit_code = 4
    else:
        proposal = write_proposal_md(root, "dry-run", selected, kept, skipped_guard)
        total_bytes = sum(n.get("size_bytes", 0) for n in selected)
        print(
            f"[cleanup] mode=dry-run candidates={len(selected)} "
            f"would-free={human(total_bytes)} kept={len(kept)} "
            f"guard-skipped={len(skipped_guard)}", file=sys.stderr,
        )

    print(f"[cleanup] proposal written: {proposal}", file=sys.stderr)
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())

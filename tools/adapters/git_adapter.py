"""Git adapter — agent-native git and GitHub CLI wrapper for M.E.R.L.I.N. project."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

from adapters.base_adapter import BaseAdapter  # noqa: E402

# ── Constants ───────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(r"C:\Users\PGNK2128\Godot-MCP")

_GH_CANDIDATES = [
    "gh",
    r"C:/Program Files/GitHub CLI/gh.exe",
    r"C:\Program Files\GitHub CLI\gh.exe",
]

# ── Helpers ──────────────────────────────────────────────────────────────────


def _run(cmd: list[str], timeout: int = 60) -> tuple[str, str, int]:
    """Run a subprocess in PROJECT_ROOT, return (stdout, stderr, returncode)."""
    result = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return result.stdout, result.stderr, result.returncode


def _find_gh() -> str | None:
    """Return the first usable gh CLI path, or None."""
    for candidate in _GH_CANDIDATES:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
        p = Path(candidate)
        if p.exists():
            return str(p)
    return None


# ── Adapter ─────────────────────────────────────────────────────────────────


class GitAdapter(BaseAdapter):
    """Adapter for git and GitHub CLI operations on the M.E.R.L.I.N. project."""

    def __init__(self) -> None:
        super().__init__("git")
        self._gh_bin: str | None = _find_gh()

    # ── BaseAdapter interface ────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "status":     "Show working tree status (short format with branch)",
            "diff":       "Show diff vs HEAD (or --staged diff with staged=True)",
            "log":        "Show last 20 commits (oneline format)",
            "commit":     "Stage files and commit (requires message=, files= optional)",
            "push":       "Push current branch to origin",
            "pull":       "Pull latest changes from origin",
            "branch":     "List all local and remote branches",
            "pr-list":    "List open pull requests (requires gh CLI)",
            "pr-create":  "Create a pull request (requires title=, body= optional)",
            "pr-view":    "View PR details (requires number= or url=)",
            "issue-list": "List open issues (requires gh CLI)",
            "search":     "Search commit history by keyword (requires query=)",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "status":
                return self._status()
            case "diff":
                return self._diff(**kwargs)
            case "log":
                return self._log()
            case "commit":
                return self._commit(**kwargs)
            case "push":
                return self._push(**kwargs)
            case "pull":
                return self._pull()
            case "branch":
                return self._branch()
            case "pr-list":
                return self._pr_list()
            case "pr-create":
                return self._pr_create(**kwargs)
            case "pr-view":
                return self._pr_view(**kwargs)
            case "issue-list":
                return self._issue_list()
            case "search":
                return self._search(**kwargs)
            case _:
                raise NotImplementedError(action)

    # ── Actions ─────────────────────────────────────────────────────────────

    def _status(self) -> dict:
        """git status --short --branch"""
        self.log("Running git status …")
        stdout, stderr, code = _run(["git", "status", "--short", "--branch"])
        if code != 0:
            return self.error(f"git status failed (exit {code}): {stderr.strip()}")
        lines = [ln for ln in stdout.splitlines() if ln]
        branch_line = lines[0].lstrip("## ").strip() if lines else ""
        changed = [ln for ln in lines[1:] if ln]
        self.log(f"Branch: {branch_line} | {len(changed)} changed file(s)")
        return self.ok(
            {
                "branch": branch_line,
                "changed_files": changed,
                "clean": len(changed) == 0,
                "raw": stdout,
            }
        )

    def _diff(self, staged: bool = False, **_kwargs: Any) -> dict:
        """git diff HEAD or git diff --staged"""
        label = "staged" if staged else "HEAD"
        self.log(f"Running git diff ({label}) …")
        cmd = ["git", "diff", "--staged"] if staged else ["git", "diff", "HEAD"]
        stdout, stderr, code = _run(cmd)
        if code != 0:
            return self.error(f"git diff failed (exit {code}): {stderr.strip()}")
        lines = stdout.splitlines()
        self.log(f"Diff: {len(lines)} line(s)")
        return self.ok({"staged": staged, "diff": stdout, "lines": len(lines)})

    def _log(self) -> dict:
        """git log --oneline -n 20"""
        self.log("Running git log (last 20 commits) …")
        stdout, stderr, code = _run(["git", "log", "--oneline", "-n", "20"])
        if code != 0:
            return self.error(f"git log failed (exit {code}): {stderr.strip()}")
        commits = [ln.strip() for ln in stdout.splitlines() if ln.strip()]
        self.log(f"Found {len(commits)} commit(s)")
        return self.ok({"commits": commits, "count": len(commits)})

    def _commit(
        self,
        message: str = "",
        files: list[str] | None = None,
        **_kwargs: Any,
    ) -> dict:
        """Stage files then commit. Never uses -a. Requires non-empty message."""
        if not message or not message.strip():
            return self.error("commit action requires a non-empty message= kwarg")

        # Stage specific files or use already-staged files
        if files:
            self.log(f"Staging {len(files)} file(s): {files}")
            for f in files:
                stdout, stderr, code = _run(["git", "add", "--", f])
                if code != 0:
                    return self.error(
                        f"git add failed for '{f}' (exit {code}): {stderr.strip()}"
                    )
        else:
            self.log("Using already-staged files (no files= kwarg provided)")

        # Verify there is something staged before committing
        check_out, _, check_code = _run(["git", "diff", "--cached", "--stat"])
        if check_code == 0 and not check_out.strip():
            return self.error(
                "Nothing staged to commit. "
                "Provide files= to stage them, or stage manually first."
            )

        self.log(f"Committing with message: {message[:80]!r}")
        stdout, stderr, code = _run(["git", "commit", "-m", message])
        if code != 0:
            return self.error(f"git commit failed (exit {code}): {stderr.strip()}")

        # Extract commit hash from output
        commit_hash = ""
        for line in stdout.splitlines():
            if line.startswith("["):
                import re
                m = re.search(r"\b([0-9a-f]{7,})\b", line)
                if m:
                    commit_hash = m.group(1)
                break

        self.log(f"Committed: {commit_hash}")
        return self.ok(
            {
                "committed": True,
                "hash": commit_hash,
                "message": message,
                "stdout": stdout.strip(),
            }
        )

    def _push(self, branch: str = "", **_kwargs: Any) -> dict:
        """git push origin <current-branch>. NEVER force-pushes."""
        # Determine branch name
        if not branch:
            out, _, code = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"])
            if code != 0:
                return self.error("Could not determine current branch name")
            branch = out.strip()

        self.log(f"Pushing branch '{branch}' to origin …")
        stdout, stderr, code = _run(["git", "push", "origin", branch], timeout=60)
        if code != 0:
            return self.error(
                f"git push failed (exit {code}): {(stdout + stderr).strip()}"
            )
        self.log("Push successful")
        return self.ok(
            {
                "branch": branch,
                "pushed": True,
                "stdout": stdout.strip(),
                "stderr": stderr.strip(),
            }
        )

    def _pull(self) -> dict:
        """git pull"""
        self.log("Running git pull …")
        stdout, stderr, code = _run(["git", "pull"], timeout=60)
        if code != 0:
            return self.error(
                f"git pull failed (exit {code}): {(stdout + stderr).strip()}"
            )
        self.log("Pull successful")
        return self.ok({"pulled": True, "stdout": stdout.strip(), "stderr": stderr.strip()})

    def _branch(self) -> dict:
        """git branch -a — list all branches."""
        self.log("Listing all branches …")
        stdout, stderr, code = _run(["git", "branch", "-a"])
        if code != 0:
            return self.error(f"git branch failed (exit {code}): {stderr.strip()}")
        branches = [ln.strip() for ln in stdout.splitlines() if ln.strip()]
        current = next((b.lstrip("* ") for b in branches if b.startswith("*")), "")
        self.log(f"Current branch: {current} | Total: {len(branches)}")
        return self.ok({"branches": branches, "current": current, "count": len(branches)})

    def _pr_list(self) -> dict:
        """gh pr list --json number,title,state,url"""
        gh = self._require_gh()
        if isinstance(gh, dict):
            return gh
        self.log("Listing pull requests via gh …")
        stdout, stderr, code = _run(
            [gh, "pr", "list", "--json", "number,title,state,url"]
        )
        if code != 0:
            return self.error(f"gh pr list failed (exit {code}): {stderr.strip()}")
        try:
            prs = json.loads(stdout) if stdout.strip() else []
        except json.JSONDecodeError as exc:
            return self.error(f"Could not parse gh output: {exc}")
        self.log(f"Found {len(prs)} PR(s)")
        return self.ok({"pull_requests": prs, "count": len(prs)})

    def _pr_create(
        self,
        title: str = "",
        body: str = "",
        **_kwargs: Any,
    ) -> dict:
        """gh pr create --title ... --body ..."""
        if not title:
            return self.error("pr-create action requires title= kwarg")
        gh = self._require_gh()
        if isinstance(gh, dict):
            return gh
        self.log(f"Creating PR: {title!r}")
        cmd = [gh, "pr", "create", "--title", title]
        if body:
            cmd += ["--body", body]
        else:
            cmd += ["--body", ""]
        stdout, stderr, code = _run(cmd, timeout=30)
        if code != 0:
            return self.error(
                f"gh pr create failed (exit {code}): {(stdout + stderr).strip()}"
            )
        url = stdout.strip()
        self.log(f"PR created: {url}")
        return self.ok({"created": True, "url": url, "title": title})

    def _pr_view(self, number: int | str = "", **_kwargs: Any) -> dict:
        """gh pr view <number or url>"""
        if not number:
            return self.error("pr-view action requires number= kwarg")
        gh = self._require_gh()
        if isinstance(gh, dict):
            return gh
        self.log(f"Viewing PR #{number} …")
        stdout, stderr, code = _run([gh, "pr", "view", str(number)])
        if code != 0:
            return self.error(
                f"gh pr view failed (exit {code}): {(stdout + stderr).strip()}"
            )
        return self.ok({"number": number, "output": stdout.strip()})

    def _issue_list(self) -> dict:
        """gh issue list --json number,title,state"""
        gh = self._require_gh()
        if isinstance(gh, dict):
            return gh
        self.log("Listing issues via gh …")
        stdout, stderr, code = _run(
            [gh, "issue", "list", "--json", "number,title,state"]
        )
        if code != 0:
            return self.error(f"gh issue list failed (exit {code}): {stderr.strip()}")
        try:
            issues = json.loads(stdout) if stdout.strip() else []
        except json.JSONDecodeError as exc:
            return self.error(f"Could not parse gh output: {exc}")
        self.log(f"Found {len(issues)} issue(s)")
        return self.ok({"issues": issues, "count": len(issues)})

    def _search(self, query: str = "", **_kwargs: Any) -> dict:
        """git log --all --oneline --grep=<query>"""
        if not query:
            return self.error("search action requires query= kwarg")
        self.log(f"Searching commit history for: {query!r}")
        stdout, stderr, code = _run(
            ["git", "log", "--all", "--oneline", "--grep", query]
        )
        if code != 0:
            return self.error(f"git log --grep failed (exit {code}): {stderr.strip()}")
        results = [ln.strip() for ln in stdout.splitlines() if ln.strip()]
        self.log(f"Found {len(results)} matching commit(s)")
        return self.ok({"query": query, "commits": results, "count": len(results)})

    # ── Internal helpers ─────────────────────────────────────────────────────

    def _require_gh(self) -> str | dict:
        """Return gh CLI path or an error dict if not found."""
        if self._gh_bin is None:
            self._gh_bin = _find_gh()
        if self._gh_bin is None:
            searched = ", ".join(_GH_CANDIDATES)
            return self.error(
                f"GitHub CLI (gh) not found. Searched: {searched}. "
                "Install from https://cli.github.com/ and ensure it is in PATH."
            )
        return self._gh_bin

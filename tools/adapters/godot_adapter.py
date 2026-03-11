"""Godot adapter — wraps Godot CLI operations for CLI-Anything."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any

from tools.adapters.base_adapter import BaseAdapter

# ── Constants ───────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(r"C:\Users\PGNK2128\Godot-MCP")

_GODOT_CANDIDATES = [
    Path(r"C:\Users\PGNK2128\AppData\Local\Programs\Godot\Godot.exe"),
    Path(r"C:\Users\PGNK2128\AppData\Local\Programs\Godot\godot.exe"),
    "godot4",
    "godot",
]

_ERROR_PATTERNS = [
    re.compile(r"\bERROR\b", re.IGNORECASE),
    re.compile(r"\bSCRIPT ERROR\b", re.IGNORECASE),
]
_WARNING_PATTERNS = [
    re.compile(r"\bWARNING\b", re.IGNORECASE),
    re.compile(r"\bWARN\b"),
]

# Windows user-data directory for Godot save files (app_userdata/<app_name>)
_GODOT_APPDATA = Path(os.environ.get("APPDATA", ""), "Godot", "app_userdata")


# ── Helpers ─────────────────────────────────────────────────────────────────


def _find_godot() -> str | None:
    """Return the first usable Godot executable path, or None."""
    import shutil

    for candidate in _GODOT_CANDIDATES:
        path = str(candidate)
        if isinstance(candidate, Path):
            if candidate.exists():
                return path
        else:
            resolved = shutil.which(path)
            if resolved:
                return resolved
    return None


def _run(cmd: list[str], timeout: int = 120) -> tuple[str, str, int]:
    """Run a subprocess, return (stdout, stderr, returncode)."""
    result = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return result.stdout, result.stderr, result.returncode


def _classify_output(text: str) -> dict[str, list[str]]:
    """Parse combined stdout/stderr for errors and warnings."""
    errors: list[str] = []
    warnings: list[str] = []
    for line in text.splitlines():
        if any(p.search(line) for p in _ERROR_PATTERNS):
            errors.append(line.strip())
        elif any(p.search(line) for p in _WARNING_PATTERNS):
            warnings.append(line.strip())
    return {"errors": errors, "warnings": warnings}


def _read_project_version() -> str:
    """Extract the application version string from project.godot."""
    project_file = PROJECT_ROOT / "project.godot"
    if not project_file.exists():
        return "unknown"
    try:
        content = project_file.read_text(encoding="utf-8")
        match = re.search(r'config/version\s*=\s*"([^"]+)"', content)
        if match:
            return match.group(1)
        # Fallback: use config_version (engine version field)
        match = re.search(r"config_version\s*=\s*(\d+)", content)
        if match:
            return f"v{match.group(1)}"
    except OSError:
        pass
    return "unknown"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _parse_export_presets() -> list[dict[str, str]]:
    """Parse export_presets.cfg and return list of preset dicts."""
    cfg_path = PROJECT_ROOT / "export_presets.cfg"
    if not cfg_path.exists():
        return []

    presets: list[dict[str, str]] = []
    content = cfg_path.read_text(encoding="utf-8")

    # Sections are named [preset.N] with key=value pairs following
    section_pattern = re.compile(r"\[preset\.(\d+)\]")
    current: dict[str, str] = {}
    for line in content.splitlines():
        line = line.strip()
        if section_pattern.match(line):
            if current:
                presets.append(current)
            current = {}
        else:
            kv = re.match(r'^(\w+)\s*=\s*"?([^"]*)"?$', line)
            if kv:
                current[kv.group(1)] = kv.group(2)
    if current:
        presets.append(current)
    return presets


# ── Adapter ─────────────────────────────────────────────────────────────────


class GodotAdapter(BaseAdapter):
    """Adapter for Godot 4.x CLI operations."""

    def __init__(self) -> None:
        super().__init__("godot")
        self._godot_bin: str | None = _find_godot()

    # ── BaseAdapter interface ────────────────────────────────────────────────

    def list_actions(self) -> dict[str, str]:
        return {
            "validate": "Run validate.bat — full project validation pipeline",
            "validate_step0": "Run Godot editor headless parse check only",
            "smoke": "Smoke-test a specific scene (requires scene= kwarg)",
            "test": "Run headless test suite via res://tests/headless_runner.tscn",
            "export": "Export project for a named preset (requires preset= kwarg)",
            "telemetry": "Aggregate JSON stats from Godot user:// save files",
            "list_presets": "List available export presets from export_presets.cfg",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "validate":
                return self._validate()
            case "validate_step0":
                return self._validate_step0()
            case "smoke":
                return self._smoke(**kwargs)
            case "test":
                return self._test()
            case "export":
                return self._export(**kwargs)
            case "telemetry":
                return self._telemetry()
            case "list_presets":
                return self._list_presets()
            case _:
                raise NotImplementedError(action)

    # ── Actions ─────────────────────────────────────────────────────────────

    def _validate(self) -> dict:
        """Run validate.bat and parse its output."""
        self.log("Running validate.bat …")
        try:
            stdout, stderr, code = _run(
                ["cmd", "/c", str(PROJECT_ROOT / "validate.bat")],
                timeout=300,
            )
        except subprocess.TimeoutExpired:
            return self.error("validate.bat timed out after 300s")
        except OSError as exc:
            return self.error(f"Failed to launch validate.bat: {exc}")

        combined = stdout + "\n" + stderr
        classified = _classify_output(combined)
        self.log(
            f"validate.bat exit={code} | errors={len(classified['errors'])} "
            f"warnings={len(classified['warnings'])}"
        )
        return self.ok(
            {
                "exit_code": code,
                "passed": code == 0 and not classified["errors"],
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _validate_step0(self) -> dict:
        """Run the Godot editor headless parse check (Step 0 equivalent)."""
        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        self.log("Running editor parse check (--editor --headless --quit) …")
        try:
            stdout, stderr, code = _run(
                [godot, "--editor", "--headless", "--quit"],
                timeout=120,
            )
        except subprocess.TimeoutExpired:
            return self.error("Editor parse check timed out after 120s")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        combined = stdout + "\n" + stderr
        classified = _classify_output(combined)
        self.log(
            f"step0 exit={code} | errors={len(classified['errors'])} "
            f"warnings={len(classified['warnings'])}"
        )
        return self.ok(
            {
                "exit_code": code,
                "passed": code == 0 and not classified["errors"],
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _smoke(self, scene: str = "", **_kwargs: Any) -> dict:
        """Smoke-test a scene by running it headlessly for 15 seconds."""
        if not scene:
            return self.error("smoke action requires scene= kwarg (e.g. scene='res://scenes/MerlinGame.tscn')")

        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        self.log(f"Smoke-testing scene: {scene}")
        try:
            stdout, stderr, code = _run(
                [godot, "--headless", "--quit-after", "15", "--scene-path", scene],
                timeout=60,
            )
        except subprocess.TimeoutExpired:
            return self.error(f"Smoke test for '{scene}' timed out after 60s")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        combined = stdout + "\n" + stderr
        classified = _classify_output(combined)
        self.log(
            f"smoke exit={code} | errors={len(classified['errors'])} "
            f"warnings={len(classified['warnings'])}"
        )
        return self.ok(
            {
                "scene": scene,
                "exit_code": code,
                "passed": code == 0 and not classified["errors"],
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _test(self) -> dict:
        """Run the headless test suite and parse JSON output."""
        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        runner_scene = "res://tests/headless_runner.tscn"
        self.log(f"Running test suite via {runner_scene} …")
        try:
            stdout, stderr, code = _run(
                [godot, "--headless", "--quit-after", "60", runner_scene],
                timeout=90,
            )
        except subprocess.TimeoutExpired:
            return self.error("Test run timed out after 90s")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        # Attempt to extract JSON block from stdout
        test_results: dict | None = None
        json_match = re.search(r"(\{.*\"total\".*\})", stdout, re.DOTALL)
        if json_match:
            try:
                test_results = json.loads(json_match.group(1))
            except json.JSONDecodeError as exc:
                self.log(f"Warning: could not parse test JSON: {exc}")

        classified = _classify_output(stdout + "\n" + stderr)
        passed_overall = (
            code == 0
            and not classified["errors"]
            and (test_results is None or test_results.get("failed") == [])
        )
        return self.ok(
            {
                "exit_code": code,
                "passed": passed_overall,
                "test_results": test_results,
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _export(self, preset: str = "", **_kwargs: Any) -> dict:
        """Export project for the given preset name."""
        if not preset:
            return self.error("export action requires preset= kwarg")

        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        version = _read_project_version()
        output_dir = PROJECT_ROOT / "builds" / preset / version
        output_dir.mkdir(parents=True, exist_ok=True)

        # Determine extension based on preset name heuristic
        ext_map = {
            "windows": ".exe",
            "win": ".exe",
            "linux": ".x86_64",
            "mac": ".app",
            "web": ".html",
            "android": ".apk",
        }
        ext = next(
            (v for k, v in ext_map.items() if k in preset.lower()),
            ".bin",
        )
        output_path = output_dir / f"game{ext}"

        self.log(f"Exporting preset '{preset}' → {output_path}")
        try:
            stdout, stderr, code = _run(
                [godot, "--export-release", preset, str(output_path)],
                timeout=300,
            )
        except subprocess.TimeoutExpired:
            return self.error(f"Export of '{preset}' timed out after 300s")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        size_bytes: int | None = None
        sha256: str | None = None
        if output_path.exists():
            size_bytes = output_path.stat().st_size
            sha256 = _sha256(output_path)
            self.log(f"Output: {output_path} ({size_bytes} bytes, sha256={sha256[:12]}…)")
        else:
            self.log("Warning: output file not found after export")

        classified = _classify_output(stdout + "\n" + stderr)
        return self.ok(
            {
                "preset": preset,
                "version": version,
                "output_path": str(output_path),
                "exit_code": code,
                "passed": code == 0 and output_path.exists(),
                "size_bytes": size_bytes,
                "sha256": sha256,
                "errors": classified["errors"],
                "warnings": classified["warnings"],
                "stdout": stdout,
                "stderr": stderr,
            }
        )

    def _telemetry(self) -> dict:
        """Read and aggregate JSON stats from Godot user:// save files."""
        # Determine app name from project.godot
        project_file = PROJECT_ROOT / "project.godot"
        app_name = "DRU"  # default from project.godot config/name
        if project_file.exists():
            content = project_file.read_text(encoding="utf-8")
            match = re.search(r'config/name\s*=\s*"([^"]+)"', content)
            if match:
                app_name = match.group(1)

        userdata_dir = _GODOT_APPDATA / app_name
        self.log(f"Reading save files from: {userdata_dir}")

        if not userdata_dir.exists():
            return self.ok(
                {
                    "userdata_dir": str(userdata_dir),
                    "files_found": 0,
                    "stats": {},
                    "note": "Directory does not exist — no save data found",
                }
            )

        json_files = list(userdata_dir.glob("*.json"))
        stats: dict[str, Any] = {}
        parse_errors: list[str] = []

        for f in json_files:
            try:
                data = json.loads(f.read_text(encoding="utf-8"))
                stats[f.name] = data
            except (json.JSONDecodeError, OSError) as exc:
                parse_errors.append(f"{f.name}: {exc}")
                self.log(f"Warning: could not parse {f.name}: {exc}")

        self.log(f"Found {len(json_files)} JSON save file(s), {len(parse_errors)} parse error(s)")
        return self.ok(
            {
                "userdata_dir": str(userdata_dir),
                "files_found": len(json_files),
                "stats": stats,
                "parse_errors": parse_errors,
            }
        )

    def _list_presets(self) -> dict:
        """List export preset names from export_presets.cfg."""
        presets = _parse_export_presets()
        names = [p.get("name", f"preset_{i}") for i, p in enumerate(presets)]
        self.log(f"Found {len(names)} export preset(s): {names}")
        return self.ok(
            {
                "presets": names,
                "details": presets,
                "cfg_path": str(PROJECT_ROOT / "export_presets.cfg"),
                "cfg_exists": (PROJECT_ROOT / "export_presets.cfg").exists(),
            }
        )

    # ── Internal helpers ─────────────────────────────────────────────────────

    def _require_godot(self) -> str | dict:
        """Return godot binary path or an error dict if not found."""
        if self._godot_bin is None:
            self._godot_bin = _find_godot()
        if self._godot_bin is None:
            return self.error(
                "Godot binary not found. Searched PATH and "
                r"C:\Users\PGNK2128\AppData\Local\Programs\Godot\. "
                "Install Godot 4 and ensure it is in PATH."
            )
        return self._godot_bin

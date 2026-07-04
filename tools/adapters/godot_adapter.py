"""Godot adapter — wraps Godot CLI operations for CLI-Anything."""

from __future__ import annotations

import base64
import hashlib
import html
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
    Path(r"C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe"),
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
# Noise patterns filtered BEFORE classification. The Godot editor at headless
# parse time recursively scans the project root and emits ERROR-level lines
# for any non-Godot subfolder it encounters (node_modules under
# tools/octogent/, etc.). These are filesystem-scan complaints, not script
# errors — filtering them prevents false-positive gate failures that pause
# the autonomous loop. Keep this list narrow; if a real script error happens
# to phrase-match, prefer suppressing it elsewhere.
_NOISE_PATTERNS = [
    re.compile(r"Cannot go into subdir '"),                       # editor recursive scan
    re.compile(r"\.import.*not found.*tools/"),                    # asset import cache misses (tools/ only — narrowed per C45 code review HIGH)
    re.compile(r"Failed to load script .*\.js"),                   # node_modules .js files
    re.compile(r"buffer error: Stream ends prematurely"),          # editor proj resource parse
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


def _run(cmd: list[str], timeout: int = 120, env: dict | None = None) -> tuple[str, str, int]:
    """Run a subprocess, return (stdout, stderr, returncode). Optional env overlay."""
    full_env: dict | None = None
    if env:
        full_env = os.environ.copy()
        full_env.update(env)
    result = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
        timeout=timeout,
        env=full_env,
    )
    return result.stdout, result.stderr, result.returncode


def _classify_output(text: str) -> dict[str, list[str]]:
    """Parse combined stdout/stderr for errors and warnings.

    Noise lines (filesystem scan complaints, asset cache misses) are skipped
    BEFORE classification — see `_NOISE_PATTERNS` for rationale.
    """
    errors: list[str] = []
    warnings: list[str] = []
    for line in text.splitlines():
        if any(p.search(line) for p in _NOISE_PATTERNS):
            continue
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


def _diff_png_pct(path_a: Path, path_b: Path) -> float:
    """Return percentage of pixels differing between two PNGs (C49).

    Lazy-imports Pillow (PIL.Image) — if unavailable or any decode/IO error
    occurs, returns 0.0 so the caller can degrade gracefully (regression
    detection becomes a no-op). The caller is expected to log a single
    warning when Pillow is missing; this helper stays silent on success.

    Comparison strategy:
      - Both images opened and converted to RGB (drops alpha — visual-only).
      - If dimensions differ, the smaller image is resized (NEAREST) to
        match the larger so per-pixel comparison is well-defined.
      - A pixel counts as "differing" when ANY channel diverges by more
        than 8 (small noise tolerance for compression/render jitter).
      - Returns differing_pixels / total_pixels * 100.

    Args:
      path_a: First PNG (typically the current capture).
      path_b: Second PNG (typically the previous baseline).

    Returns:
      Float 0.0..100.0 — percentage of differing pixels. 0.0 on any
      failure (file missing, decode error, Pillow not installed).
    """
    try:
        from PIL import Image  # noqa: PLC0415 — lazy import, graceful degrade
    except ImportError:
        return 0.0
    try:
        if not path_a.exists() or not path_b.exists():
            return 0.0
        with Image.open(path_a) as ia, Image.open(path_b) as ib:
            img_a = ia.convert("RGB")
            img_b = ib.convert("RGB")
            # Normalise dimensions: resize the smaller to match the larger.
            wa, ha = img_a.size
            wb, hb = img_b.size
            if (wa, ha) != (wb, hb):
                target = (max(wa, wb), max(ha, hb))
                if (wa, ha) != target:
                    img_a = img_a.resize(target, Image.Resampling.NEAREST)
                if (wb, hb) != target:
                    img_b = img_b.resize(target, Image.Resampling.NEAREST)
            pixels_a = img_a.tobytes()
            pixels_b = img_b.tobytes()
            if len(pixels_a) != len(pixels_b):
                return 0.0  # mismatched after resize — treat as no-baseline
            total_pixels = len(pixels_a) // 3  # 3 channels per pixel (RGB)
            if total_pixels == 0:
                return 0.0
            differing = 0
            tolerance = 8
            # Iterate by pixel triplet — Python loop, but PNGs from smoke
            # are small (typically 1280x720 ~= 920k pixels) and this only
            # runs ONCE per scene per verify_all call (≤8 scenes).
            for i in range(0, len(pixels_a), 3):
                if (
                    abs(pixels_a[i] - pixels_b[i]) > tolerance
                    or abs(pixels_a[i + 1] - pixels_b[i + 1]) > tolerance
                    or abs(pixels_a[i + 2] - pixels_b[i + 2]) > tolerance
                ):
                    differing += 1
            return (differing / total_pixels) * 100.0
    except (OSError, ValueError, MemoryError):
        return 0.0


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
            "soak": "PROOF v10.13: Monte Carlo logic soak (runs=, archetype=) + optional autoplay= full UI runs (loops=)",
            "verify_all": "FORGE: parse-check + smoke ALL scenes/*.tscn, write JSON report (one-shot autonomy verify)",
            "test": "Run headless test suite via res://tests/headless_runner.tscn",
            "export": "Export project for a named preset (requires preset= kwarg)",
            "telemetry": "Aggregate JSON stats from Godot user:// save files",
            "list_presets": "List available export presets from export_presets.cfg",
            "bible-site": "Generate the MERLIN Bible Site (docs/MERLIN_BIBLE_SITE.html)",
            "bible-serve": "Start the interactive Bible Server (Flask, localhost:8080)",
            "bible-serve-stop": "Stop the running Bible Server",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "validate":
                return self._validate()
            case "validate_step0":
                return self._validate_step0()
            case "smoke":
                return self._smoke(**kwargs)
            case "soak":
                return self._soak(**kwargs)
            case "verify_all":
                return self._verify_all(**kwargs)
            case "test":
                return self._test()
            case "export":
                return self._export(**kwargs)
            case "telemetry":
                return self._telemetry()
            case "list_presets":
                return self._list_presets()
            case "bible-site":
                return self._bible_site()
            case "bible-serve":
                return self._bible_serve(**kwargs)
            case "bible-serve-stop":
                return self._bible_serve_stop()
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
                timeout=300,
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

    def _soak(
        self,
        runs: str = "200",
        archetype: str = "mixed",
        autoplay: str = "",
        loops: str = "3",
        per_archetype: str = "",
        **_kwargs: Any,
    ) -> dict:
        """v10.13 Phase P — proof gate « 100% fiable ».

        1. Logic soak: probe_soak.gd headless, N Monte Carlo runs (archetypes,
           degenerate cases, S5 save/resume). Pass = N/N + zero SCRIPT ERROR.
        2. Optional (autoplay=true): autoplay_run.gd windowed, full UI runs with
           LLM ON (intro -> beats -> draft -> MerlinEnd). Pass = loops/loops.
        """
        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        self.log(f"Soak: {runs} logic runs (archetype={archetype}, per_archetype={per_archetype or 'false'}) …")
        soak_args = [godot, "--headless", "--path", ".", "--script",
                     "res://tools/probe_soak.gd", "--",
                     f"--runs={runs}", f"--archetype={archetype}"]
        if str(per_archetype).lower() in ("1", "true", "yes"):
            soak_args.append("--per-archetype")  # v10.14 : 5 x runs, cibles par archetype
        try:
            stdout, stderr, code = _run(soak_args, timeout=600)
        except subprocess.TimeoutExpired:
            return self.error("probe_soak timed out after 600s")
        except OSError as exc:
            return self.error(f"Failed to launch probe_soak: {exc}")

        combined = stdout + "\n" + stderr
        script_errors = [
            line.strip() for line in combined.splitlines() if "SCRIPT ERROR" in line
        ]
        match = re.search(r"(\d+)/(\d+) PASS", stdout)
        soak_pass, soak_total = (
            (int(match.group(1)), int(match.group(2))) if match else (0, int(runs))
        )
        data: dict[str, Any] = {
            "soak": {
                "exit_code": code,
                "pass": soak_pass,
                "total": soak_total,
                "summary": [
                    line.strip() for line in stdout.splitlines()
                    if line.startswith("[SOAK]")
                ],
            },
            "script_errors": script_errors,
        }
        passed = code == 0 and soak_pass == soak_total and not script_errors
        log_parts = [f"logic {soak_pass}/{soak_total}"]

        if str(autoplay).lower() in ("1", "true", "yes"):
            self.log(f"Autoplay: {loops} full UI runs (LLM ON) …")
            try:
                a_out, a_err, a_code = _run(
                    [godot, "--path", ".", "--script",
                     "res://tools/autoplay_run.gd", "--", f"--loops={loops}"],
                    timeout=2200,  # v10.22 : 3 runs × deadline 600 s + fins + settle (1600 coupait des runs sains)
                )
            except subprocess.TimeoutExpired:
                return self.error("autoplay_run timed out after 2200s")
            except OSError as exc:
                return self.error(f"Failed to launch autoplay_run: {exc}")
            a_combined = a_out + "\n" + a_err
            a_errors = [
                line.strip() for line in a_combined.splitlines()
                if "SCRIPT ERROR" in line
            ]
            a_match = re.search(r"(\d+)/(\d+) PASS", a_out)
            a_pass, a_total = (
                (int(a_match.group(1)), int(a_match.group(2)))
                if a_match else (0, int(loops))
            )
            data["autoplay"] = {
                "exit_code": a_code,
                "pass": a_pass,
                "total": a_total,
                "lines": [
                    line.strip() for line in a_out.splitlines()
                    if line.startswith("[AUTOPLAY]")
                ],
            }
            data["script_errors"] = script_errors + a_errors
            passed = passed and a_code == 0 and a_pass == a_total and not a_errors
            log_parts.append(f"autoplay {a_pass}/{a_total}")

        data["passed"] = passed
        self.log(f"soak passed={passed} | " + " | ".join(log_parts))
        return self.ok(data)

    def _smoke(self, scene: str = "", duration: str = "10", capture: str = "", capture_interval: str = "200", **_kwargs: Any) -> dict:
        """Smoke-test a scene by running it (windowed) for N seconds and grepping for runtime errors.

        Headless mode skips _ready/_process for many engine subsystems (3D rendering, input,
        audio), so SCRIPT ERROR from those paths are NOT caught. We launch with a normal display
        but `--quit-after` to bound the run. The scene is passed as a positional arg
        (Godot 4 ignores --scene-path).

        Optional --capture <dir> records frames every <capture-interval> ms (default 200) via
        the CaptureRecorder autoload. Frames saved as frame_NNNN.png in <dir>.
        """
        if not scene:
            return self.error("smoke action requires scene= kwarg (e.g. scene='res://scenes/MerlinGame.tscn')")

        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        try:
            quit_after = max(2, int(duration))
        except (TypeError, ValueError):
            quit_after = 10

        timeout_s = quit_after + 30  # generous buffer for project loading
        # Capture mode: gate the CaptureRecorder autoload via env vars.
        capture_env: dict | None = None
        capture_dir_resolved: str = ""
        if capture:
            capture_dir_resolved = str((PROJECT_ROOT / capture).resolve()) if not Path(capture).is_absolute() else capture
            Path(capture_dir_resolved).mkdir(parents=True, exist_ok=True)
            try:
                cap_int_ms = max(50, int(capture_interval))
            except (TypeError, ValueError):
                cap_int_ms = 200
            max_frames = max(1, int((quit_after * 1000) / cap_int_ms) + 5)
            capture_env = {
                "MERLIN_CAPTURE_DIR": capture_dir_resolved,
                "MERLIN_CAPTURE_INTERVAL_MS": str(cap_int_ms),
                "MERLIN_CAPTURE_MAX_FRAMES": str(max_frames),
            }
            self.log(f"Capture: dir={capture_dir_resolved} interval={cap_int_ms}ms max_frames={max_frames}")
        self.log(f"Smoke-testing scene '{scene}' for {quit_after}s (timeout {timeout_s}s)")
        try:
            stdout, stderr, code = _run(
                [godot, "--path", str(PROJECT_ROOT), "--quit-after", str(quit_after), scene],
                timeout=timeout_s,
                env=capture_env,
            )
        except subprocess.TimeoutExpired:
            return self.error(f"Smoke test for '{scene}' timed out after {timeout_s}s — likely hang in _ready")
        except OSError as exc:
            return self.error(f"Failed to launch Godot: {exc}")

        combined = stdout + "\n" + stderr
        classified = _classify_output(combined)
        # Runtime-only signal: SCRIPT ERROR is what crashes a play session (parse errors are caught
        # by validate_step0). We surface them separately.
        script_errors = [e for e in classified["errors"] if "SCRIPT ERROR" in e or "Identifier" in e or "not declared" in e]
        passed = code == 0 and not script_errors
        self.log(
            f"smoke exit={code} | script_errors={len(script_errors)} "
            f"total_errors={len(classified['errors'])} warnings={len(classified['warnings'])} "
            f"passed={passed}"
        )
        result_data: dict = {
            "scene": scene,
            "duration_s": quit_after,
            "exit_code": code,
            "passed": passed,
            "script_errors": script_errors,
            "errors": classified["errors"],
            "warnings": classified["warnings"][:20],  # cap noise
            "stdout_tail": "\n".join(stdout.splitlines()[-50:]),
            "stderr_tail": "\n".join(stderr.splitlines()[-50:]),
        }
        if capture and capture_dir_resolved:
            captured = sorted(Path(capture_dir_resolved).glob("frame_*.png"))
            result_data["capture_dir"] = capture_dir_resolved
            result_data["capture_frames"] = len(captured)
            result_data["capture_first"] = str(captured[0]) if captured else ""
            result_data["capture_last"] = str(captured[-1]) if captured else ""
        return self.ok(result_data)

    def _verify_all(
        self,
        scenes_dir: str = "scenes",
        duration: str = "5",
        capture: str = "true",
        strict: str = "false",
        **_kwargs: Any,
    ) -> dict:
        """FORGE one-shot autonomy verification.

        Flow:
          1. validate_step0 (editor headless parse-check on every script)
          2. [C54] _test (headless test suite via res://tests/headless_runner.gd).
             Quality dimension: UNIT-TEST COVERAGE. Test failures are recorded
             but NON-BLOCKING — scene smoking always proceeds for full picture.
          3. enumerate scenes_dir/*.tscn (default `scenes/`)
          4. _smoke each scene for `duration` seconds (default 5)
             [C47] If capture=true (default), each scene also drops PNG frames
             via the CaptureRecorder autoload. Last frame = visual baseline.
          4b. [C49] Diff each current capture vs the previous run's capture
              (per-scene PNG). Flag `visual_regression: True` when pixel
              diff > 5%. Distinct from `script_errors` — a scene can pass
              smoke but render differently. Surfaced; doesn't fail by default.
          5. write JSON report to .octogent/tentacles/godot_runtime/last_verify.json
          6. return aggregated PASS/FAIL (requires step0_passed AND tests_passed
             AND scenes_failed == 0 AND scenes_total > 0)

        Args:
          scenes_dir: relative dir under PROJECT_ROOT to scan for *.tscn.
          duration:   per-scene smoke window in seconds.
          capture:    "true"/"false" — toggle PNG capture during smoke.
                      Defaults true; set "false" for fast no-baseline checks.
          strict:     [C50] "true"/"false" — enforce ZERO-WARNING BAR.
                      When true, the run FAILS if ANY warnings are detected
                      (step0 OR any scene smoke), regardless of error/script
                      error status. This adds a quality dimension on top of
                      the legacy errors-only gate: clean output is required
                      before merge. Default "false" preserves the existing
                      behavior so legacy callers see no change.

        Used by:
          - Manual: `python tools/cli.py godot verify_all`
          - Watchdog: periodic call from director-watchdog.sh
          - Workers: spawned godot_runtime tentacle workers
        """
        from datetime import datetime, timezone
        import json as _json

        self.log(
            f"verify_all: scenes_dir='{scenes_dir}' duration={duration}s "
            f"capture={capture} strict={strict}"
        )

        capture_enabled = str(capture).lower() in ("true", "1", "yes", "on")
        # [C50] When strict mode is on, we also gate on warnings — see
        # aggregation block below. Surfaced into the JSON report as
        # `strict_mode` so consumers can tell which gate produced the verdict.
        strict_enabled = str(strict).lower() in ("true", "1", "yes", "on")

        # Step 1: parse-check
        step0 = self._validate_step0()
        step0_ok = step0.get("status") == "ok"
        step0_data = step0.get("data", {}) if step0_ok else {}
        step0_passed = bool(step0_data.get("passed"))
        # [C50] Count step0 warnings for the strict gate. `_validate_step0`
        # already exposes `data["warnings"]` as a list[str].
        step0_warnings_count = len(step0_data.get("warnings", []) or [])

        # Step 2 [C54]: headless test suite (UNIT-TEST COVERAGE quality dimension).
        # Failures are aggregated into the report but kept NON-BLOCKING for the
        # scene smoking step — we still want the full per-scene picture even when
        # tests are red, so the verify_all report stays diagnostically rich.
        tests = self._test()
        tests_ok = tests.get("status") == "ok"
        tests_data = tests.get("data", {}) if tests_ok else {}
        # Prefer the explicit `passed` flag from _test() (handles the JSON
        # test_results.failed == [] semantics); fall back to ok-and-no-errors
        # when that flag is missing (defensive against future _test() reshapes).
        if "passed" in tests_data:
            tests_passed = bool(tests_data.get("passed"))
        else:
            tests_passed = tests_ok and not tests_data.get("errors")
        self.log(
            f"verify_all: tests_passed={tests_passed} "
            f"exit_code={tests_data.get('exit_code')}"
        )

        # Step 3: enumerate scenes (top-level .tscn only — subfolders excluded by design;
        # main playable scenes live in scenes/)
        scenes_root = PROJECT_ROOT / scenes_dir
        scene_paths = sorted(scenes_root.glob("*.tscn")) if scenes_root.exists() else []
        scene_results: list[dict] = []
        scenes_passed = 0
        scenes_failed = 0
        slow_scenes = 0  # [C55] FPS < 30 or mem_peak_mb > 500

        # [C55] Per-scene perf JSON dir for PerfRecorder autoload dumps.
        perf_root = (
            PROJECT_ROOT
            / "tools"
            / "octogent"
            / ".octogent"
            / "tentacles"
            / "godot_runtime"
            / "perf"
        )
        perf_root.mkdir(parents=True, exist_ok=True)

        # [C47] Build a unique capture root per verify_all run so successive runs
        # don't overwrite each other. Uses ISO-UTC stripped of colons for FS safety.
        # Lives under the godot_runtime tentacle so the UI can find baselines.
        capture_root: Path | None = None
        if capture_enabled and scene_paths:
            ts_safe = (
                datetime.now(timezone.utc)
                .isoformat()
                .replace(":", "-")
                .replace(".", "-")
            )
            capture_root = (
                PROJECT_ROOT
                / "tools"
                / "octogent"
                / ".octogent"
                / "tentacles"
                / "godot_runtime"
                / "captures"
                / ts_safe
            )
            capture_root.mkdir(parents=True, exist_ok=True)
            self.log(f"verify_all: capture_root={capture_root}")

        # Step 4: smoke each scene
        for sp in scene_paths:
            rel = sp.relative_to(PROJECT_ROOT).as_posix()
            res_uri = f"res://{rel}"
            self.log(f"verify_all: smoking {res_uri}")

            # [C47] Per-scene capture dir + interval ≈ duration*1000ms
            # → CaptureRecorder fires ~1-2 frames; we keep the LAST one as the
            # baseline (last_frame is what the player sees at end of smoke).
            smoke_kwargs: dict = {"scene": res_uri, "duration": duration}
            if capture_root is not None:
                scene_stem = sp.stem  # e.g. "MerlinGame"
                scene_capture_dir = capture_root / scene_stem
                smoke_kwargs["capture"] = str(scene_capture_dir)
                # Cap interval at half-duration so we get at least 1 frame even
                # on shorter smokes; floor at 1000ms.
                try:
                    cap_interval = max(1000, (int(duration) * 1000) // 2)
                except (TypeError, ValueError):
                    cap_interval = 2500
                smoke_kwargs["capture_interval"] = str(cap_interval)

            # [C55] Patch MERLIN_PERF_OUT around the smoke call so PerfRecorder
            # autoload dumps a per-scene JSON. Use try/finally to restore the prior
            # value (or unset) — keeps zero-overhead default for unrelated callers.
            scene_perf_path = perf_root / f"{sp.stem}.json"
            # Wipe any stale file so a missing dump (e.g. autoload not yet active)
            # is detectable as "no perf data" instead of stale C54 numbers.
            try:
                if scene_perf_path.exists():
                    scene_perf_path.unlink()
            except OSError:
                pass
            _prev_perf_env = os.environ.get("MERLIN_PERF_OUT")
            os.environ["MERLIN_PERF_OUT"] = str(scene_perf_path)
            try:
                r = self._smoke(**smoke_kwargs)
            finally:
                if _prev_perf_env is None:
                    os.environ.pop("MERLIN_PERF_OUT", None)
                else:
                    os.environ["MERLIN_PERF_OUT"] = _prev_perf_env
            data = r.get("data", {}) if isinstance(r, dict) else {}
            passed = bool(data.get("passed"))

            # [C47] Resolve capture_path — prefer the LAST frame for end-of-scene
            # state; fall back to first if last missing; empty if capture failed.
            capture_path = ""
            if capture_root is not None:
                last_frame = data.get("capture_last") or data.get("capture_first") or ""
                if last_frame:
                    try:
                        # Store as repo-relative POSIX path for portability.
                        capture_path = (
                            Path(last_frame).resolve().relative_to(PROJECT_ROOT).as_posix()
                        )
                    except (ValueError, OSError):
                        capture_path = last_frame  # absolute fallback

            # [C55] Read PerfRecorder JSON if it landed; truncate to 3 surfaced fields.
            perf: dict | None = None
            if scene_perf_path.exists():
                try:
                    raw = json.loads(scene_perf_path.read_text(encoding="utf-8"))
                    perf = {
                        "fps_avg": float(raw.get("fps_avg", 0.0)),
                        "fps_min": float(raw.get("fps_min", 0.0)),
                        "mem_peak_mb": float(raw.get("mem_peak_mb", 0.0)),
                    }
                    # Slow gate (informational only — does not flip all_passed).
                    if perf["fps_avg"] < 30.0 or perf["mem_peak_mb"] > 500.0:
                        slow_scenes += 1
                except (OSError, ValueError, json.JSONDecodeError) as exc:
                    self.log(f"verify_all: WARN perf parse failed for {sp.stem}: {exc}")

            # [C50] Surface warnings_count from underlying _smoke data so the
            # strict gate can aggregate without re-parsing stdout. _smoke caps
            # the warnings list at 20 entries (noise control), so we count the
            # raw list length here — adequate for go/no-go decisions.
            scene_warnings_count = len(data.get("warnings", []) or [])
            scene_results.append(
                {
                    "scene": res_uri,
                    "passed": passed,
                    "duration_s": data.get("duration_s"),
                    "exit_code": data.get("exit_code"),
                    "script_errors": data.get("script_errors", []),
                    "warnings_count": scene_warnings_count,
                    "capture_path": capture_path,
                    "capture_frames": data.get("capture_frames", 0),
                    # [C55] perf metrics (fps_avg, fps_min, mem_peak_mb) or empty dict
                    "perf": perf,
                    # [C49] populated by the regression-diff pass below; defaults
                    # here keep the schema stable when capture is disabled or no
                    # baseline exists.
                    "pixel_diff_pct": 0.0,
                    "visual_regression": False,
                }
            )
            if passed:
                scenes_passed += 1
            else:
                scenes_failed += 1

        # [C49] Visual regression diff: compare current captures vs the
        # most recent PRIOR capture root. This is the third dimension of
        # the C47/C48/C49 visual-loop trio:
        #   C47 = capture (write PNG baseline)
        #   C48 = view    (HTML report renders the PNG)
        #   C49 = compare (this block — flag if rendering changed >5%)
        # A scene can pass C45 smoke (no script errors) yet visually
        # regress (e.g. a sprite went black, a UI broke layout) — this
        # surfaces those without failing all_passed by default.
        baseline_root_name: str | None = None
        visual_regressions = 0
        if capture_root is not None:
            try:
                captures_parent = capture_root.parent  # .../captures/
                all_roots = sorted(
                    [d for d in captures_parent.glob("*") if d.is_dir()],
                    key=lambda p: p.name,
                )
                prior_roots = [d for d in all_roots if d.name != capture_root.name]
                if prior_roots:
                    baseline_root = prior_roots[-1]
                    baseline_root_name = baseline_root.name
                    self.log(f"verify_all: baseline_root={baseline_root}")
                    pillow_available = True
                    try:
                        import PIL.Image  # noqa: F401, PLC0415
                    except ImportError:
                        pillow_available = False
                        self.log(
                            "verify_all: WARN Pillow (PIL) not installed — "
                            "visual regression diff disabled. "
                            "All pixel_diff_pct=0.0. `pip install Pillow` to enable."
                        )
                    if pillow_available:
                        for sr in scene_results:
                            cap_rel = sr.get("capture_path") or ""
                            if not cap_rel:
                                continue
                            scene_uri = sr.get("scene", "")
                            try:
                                stem = Path(scene_uri.replace("res://", "")).stem
                            except (TypeError, ValueError):
                                continue
                            current_path = (
                                cap_rel
                                if Path(cap_rel).is_absolute()
                                else PROJECT_ROOT / cap_rel
                            )
                            current_path = Path(current_path)
                            baseline_scene_dir = baseline_root / stem
                            baseline_path = baseline_scene_dir / current_path.name
                            if baseline_path.exists():
                                pct = _diff_png_pct(current_path, baseline_path)
                                sr["pixel_diff_pct"] = round(pct, 3)
                                sr["visual_regression"] = pct > 5.0
                                if sr["visual_regression"]:
                                    visual_regressions += 1
                                    self.log(
                                        f"verify_all: VISUAL REGRESSION on "
                                        f"{scene_uri} ({pct:.2f}% > 5.0%)"
                                    )
            except OSError as exc:
                self.log(f"verify_all: WARN regression diff skipped: {exc}")

        # Step 5: write report
        # [C54] all_passed requires the headless test suite to pass — UNIT-TEST
        # COVERAGE gate. A green report means: scripts parse, tests pass, AND
        # every scene boots without runtime errors.
        # [C55] slow_scenes informational — does NOT flip all_passed (yet).
        # [C49] visual_regressions informational — does NOT flip all_passed (yet).
        # [C50] strict mode adds a ZERO-WARNING gate ON TOP of the legacy gate.
        all_passed = (
            step0_passed
            and tests_passed
            and scenes_failed == 0
            and len(scene_paths) > 0
        )
        # [C50] ZERO-WARNING BAR — strict gate applied AFTER the legacy gate.
        # Sum scene warnings independently so report consumers see the
        # breakdown even when not in strict mode.
        scenes_warnings_total = sum(s.get("warnings_count", 0) for s in scene_results)
        if strict_enabled:
            all_passed = (
                all_passed
                and step0_warnings_count == 0
                and scenes_warnings_total == 0
            )
        # [C54] tests_summary: compact view of test outcome.
        tests_summary = {
            "exit_code": tests_data.get("exit_code"),
            "duration_s": tests_data.get("duration_s"),
            "details": list(tests_data.get("results", []) or [])[:10],
        }
        report = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "passed": all_passed,
            "strict_mode": strict_enabled,
            "step0_passed": step0_passed,
            "step0_warnings_count": step0_warnings_count,
            "tests_passed": tests_passed,
            "tests_summary": tests_summary,
            "scenes_total": len(scene_paths),
            "scenes_passed": scenes_passed,
            "scenes_failed": scenes_failed,
            "scenes_warnings_total": scenes_warnings_total,
            "slow_scenes": slow_scenes,
            "scenes": scene_results,
            "scenes_dir": scenes_dir,
            # [C49] Visual regression surface (additive, non-blocking by
            # default — `all_passed` doesn't consider visual_regressions).
            # `baseline_compared_against` is the directory NAME (timestamp)
            # of the prior capture root, or null if no prior run existed.
            "baseline_compared_against": baseline_root_name,
            "visual_regressions": visual_regressions,
        }
        # Distinguish "no scenes found" (misconfigured path) from "scenes failed"
        # — both yield passed=False but consumers must respond differently.
        # (per C45 code-review MEDIUM)
        if not scene_paths:
            report["no_scenes_found"] = True
            report["error_hint"] = (
                f"scenes_dir '{scenes_dir}' contains no .tscn files — "
                f"check the path or the scenes_dir kwarg."
            )
        report_dir = PROJECT_ROOT / "tools" / "octogent" / ".octogent" / "tentacles" / "godot_runtime"
        report_dir.mkdir(parents=True, exist_ok=True)
        report_path = report_dir / "last_verify.json"
        try:
            report_path.write_text(_json.dumps(report, indent=2), encoding="utf-8")
        except OSError as exc:
            self.log(f"verify_all: WARN failed to write report: {exc}")

        # [C48] HTML report — viewing primitive that complements C47 capture.
        # Self-contained file (inline CSS, base64 images <100KB) sitting next to
        # last_verify.json so the Octogent UI can link straight to it.
        html_path = report_dir / "last_verify.html"
        try:
            html_path.write_text(self._render_verify_html(report), encoding="utf-8")
        except OSError as exc:
            self.log(f"verify_all: WARN failed to write HTML report: {exc}")

        self.log(
            f"verify_all: passed={all_passed} strict={strict_enabled} "
            f"step0={step0_passed}(warns={step0_warnings_count}) "
            f"tests={tests_passed} "
            f"scenes={scenes_passed}/{len(scene_paths)}(warns={scenes_warnings_total}) "
            f"slow={slow_scenes} visual_regressions={visual_regressions} "
            f"baseline={baseline_root_name or 'none'} report={report_path}"
        )
        return self.ok(
            {
                **report,
                "report_path": str(report_path),
                "step0_summary": {
                    "exit_code": step0.get("data", {}).get("exit_code"),
                    "errors": step0.get("data", {}).get("errors", [])[:5],
                }
                if step0_ok
                else step0,
            }
        )

    def _render_verify_html(self, report: dict) -> str:
        """[C48] Render a self-contained HTML view of a verify_all report.

        Sister of last_verify.json — same content, browsable. The visibility
        primitive that complements C47's capture primitive: C47 shoots the
        screenshots, C48 makes them readable in a single click from the
        Octogent UI (linked tentacle dir).

        Layout:
          - Inline CSS (CRT phosphor + parchemin theme — celtic golds/browns/teals)
          - PASS/FAIL banner header with timestamp + scenes_passed/scenes_total
          - One <section> per scene: name, badge, capture <img>, script_errors
          - Footer: link back to last_verify.json + generated-at timestamp

        Image policy:
          - <100 KB: embed as data:image/png;base64,... (one self-contained file)
          - >=100 KB: relative <img src="..."> (HTML lives next to JSON in
            tentacles/godot_runtime/, so capture_path is repo-relative POSIX
            and we compute a relative POSIX path back from the report dir).

        All user-derived text (scene paths, script_errors, error hints) is
        passed through html.escape() to prevent injection.
        """
        from datetime import datetime, timezone

        passed = bool(report.get("passed"))
        step0_passed = bool(report.get("step0_passed"))
        scenes = report.get("scenes", []) or []
        scenes_total = report.get("scenes_total", len(scenes))
        scenes_passed_n = report.get("scenes_passed", 0)
        scenes_failed_n = report.get("scenes_failed", 0)
        timestamp = report.get("timestamp", "")
        scenes_dir = report.get("scenes_dir", "")
        no_scenes_found = bool(report.get("no_scenes_found"))
        error_hint = report.get("error_hint", "")

        # Tentacle dir — HTML lives at <root>/tools/octogent/.octogent/tentacles/godot_runtime/last_verify.html
        # Captures live at <root>/tools/octogent/.octogent/tentacles/godot_runtime/captures/<ts>/<scene>/...
        # so a relative link from the HTML file to a capture is "captures/<ts>/<scene>/frame.png" — but the
        # capture_path stored in the report is repo-relative POSIX. We resolve absolutely, then compute relative.
        tentacle_dir = (
            PROJECT_ROOT
            / "tools"
            / "octogent"
            / ".octogent"
            / "tentacles"
            / "godot_runtime"
        )

        def _img_tag(capture_path: str) -> str:
            """Return an <img> tag (or empty string if no capture)."""
            if not capture_path:
                return ""
            abs_path = (PROJECT_ROOT / capture_path).resolve()
            if not abs_path.exists():
                return (
                    '<div class="capture-missing">capture missing: '
                    + html.escape(capture_path)
                    + "</div>"
                )
            try:
                size = abs_path.stat().st_size
            except OSError:
                size = 0
            # Embed as base64 data URL for small images so the file is fully
            # self-contained (no external requests, can be sent over chat).
            if 0 < size < 100 * 1024:
                try:
                    raw = abs_path.read_bytes()
                    b64 = base64.b64encode(raw).decode("ascii")
                    return (
                        '<img class="capture" alt="scene capture" '
                        f'src="data:image/png;base64,{b64}" />'
                    )
                except OSError:
                    pass  # fall through to relative link
            # Larger images — relative link from the HTML file's dir.
            try:
                rel = abs_path.relative_to(tentacle_dir).as_posix()
            except ValueError:
                # Capture isn't under the tentacle dir — use absolute file:// URL
                # as a last resort. file:// links are best-effort across browsers.
                rel = abs_path.as_uri()
            return (
                '<img class="capture" alt="scene capture" src="'
                + html.escape(rel, quote=True)
                + '" loading="lazy" />'
            )

        # Build per-scene sections.
        section_blocks: list[str] = []
        for sc in scenes:
            sc_name = html.escape(str(sc.get("scene", "?")))
            sc_passed = bool(sc.get("passed"))
            badge_cls = "badge-pass" if sc_passed else "badge-fail"
            badge_txt = "PASS" if sc_passed else "FAIL"
            cap_path = sc.get("capture_path", "") or ""
            img_html = _img_tag(cap_path)
            errs = sc.get("script_errors", []) or []
            if errs:
                err_items = "".join(
                    f"<li>{html.escape(str(e))}</li>" for e in errs
                )
                err_html = (
                    '<details class="errors" open><summary>'
                    f"script_errors ({len(errs)})"
                    f"</summary><ul>{err_items}</ul></details>"
                )
            else:
                err_html = ""
            exit_code = sc.get("exit_code")
            duration = sc.get("duration_s")
            meta = (
                f'<div class="meta">exit={html.escape(str(exit_code))} '
                f"duration={html.escape(str(duration))}s "
                f"frames={html.escape(str(sc.get('capture_frames', 0)))}</div>"
            )
            section_blocks.append(
                '<section class="scene">'
                f'<header><span class="scene-name">{sc_name}</span>'
                f'<span class="badge {badge_cls}">{badge_txt}</span></header>'
                f"{meta}{img_html}{err_html}"
                "</section>"
            )

        if not section_blocks:
            empty_msg = (
                html.escape(error_hint)
                if (no_scenes_found and error_hint)
                else "no scenes were checked"
            )
            section_blocks.append(
                f'<section class="scene empty"><p>{empty_msg}</p></section>'
            )

        sections_html = "\n".join(section_blocks)
        banner_cls = "banner-pass" if passed else "banner-fail"
        banner_txt = "PASS" if passed else "FAIL"
        step0_txt = "PASS" if step0_passed else "FAIL"
        generated_at = datetime.now(timezone.utc).isoformat()

        # CSS: CRT phosphor + parchemin theme (golds/browns/teals matching Octogent)
        css = """
        :root {
          --bg: #1a1410;
          --bg-elev: #241c14;
          --parchment: #f0e2c4;
          --gold: #d4a657;
          --gold-bright: #e8c47b;
          --teal: #4a9a99;
          --teal-bright: #6dc3c2;
          --pass: #5fbf65;
          --fail: #d04848;
          --warn: #e8b34a;
          --text: #e8d5a8;
          --text-dim: #a08862;
          --border: #58422a;
        }
        * { box-sizing: border-box; }
        html, body { margin: 0; padding: 0; }
        body {
          background: var(--bg);
          color: var(--text);
          font-family: ui-monospace, SFMono-Regular, "Cascadia Code", Menlo, Consolas, monospace;
          font-size: 14px;
          line-height: 1.5;
          padding: 24px;
          max-width: 1100px;
          margin: 0 auto;
        }
        h1 { color: var(--gold-bright); margin: 0; font-size: 22px; letter-spacing: 0.05em; }
        .banner {
          padding: 18px 22px;
          margin-bottom: 24px;
          border: 2px solid var(--border);
          border-radius: 6px;
          background: var(--bg-elev);
          display: flex;
          align-items: center;
          gap: 18px;
          flex-wrap: wrap;
        }
        .banner-pass { border-color: var(--pass); box-shadow: 0 0 16px rgba(95,191,101,0.18); }
        .banner-fail { border-color: var(--fail); box-shadow: 0 0 16px rgba(208,72,72,0.22); }
        .banner-status {
          font-size: 28px;
          font-weight: 700;
          padding: 4px 14px;
          border-radius: 4px;
          letter-spacing: 0.1em;
        }
        .banner-pass .banner-status { background: var(--pass); color: #0a1c0c; }
        .banner-fail .banner-status { background: var(--fail); color: #1c0a0a; }
        .banner-meta { color: var(--text-dim); font-size: 13px; }
        .banner-meta strong { color: var(--gold); font-weight: 600; }
        .scene {
          background: var(--bg-elev);
          border: 1px solid var(--border);
          border-radius: 6px;
          padding: 16px;
          margin-bottom: 18px;
        }
        .scene header {
          display: flex;
          align-items: center;
          gap: 12px;
          justify-content: space-between;
          margin-bottom: 8px;
        }
        .scene-name { color: var(--teal-bright); font-size: 15px; font-weight: 600; word-break: break-all; }
        .badge {
          display: inline-block;
          padding: 2px 10px;
          border-radius: 3px;
          font-size: 12px;
          font-weight: 700;
          letter-spacing: 0.08em;
          flex-shrink: 0;
        }
        .badge-pass { background: var(--pass); color: #0a1c0c; }
        .badge-fail { background: var(--fail); color: #1c0a0a; }
        .meta { color: var(--text-dim); font-size: 12px; margin-bottom: 10px; }
        .capture {
          display: block;
          max-width: 100%;
          height: auto;
          margin: 8px 0;
          border: 1px solid var(--border);
          border-radius: 4px;
          background: #000;
          image-rendering: -webkit-optimize-contrast;
        }
        .capture-missing {
          padding: 10px;
          background: #2a1a14;
          border: 1px dashed var(--warn);
          color: var(--warn);
          font-size: 12px;
          border-radius: 4px;
          margin: 8px 0;
        }
        details.errors {
          background: #2a1414;
          border: 1px solid var(--fail);
          border-radius: 4px;
          padding: 8px 12px;
          margin-top: 10px;
        }
        details.errors summary {
          cursor: pointer;
          color: var(--fail);
          font-weight: 600;
        }
        details.errors ul {
          margin: 8px 0 0;
          padding-left: 20px;
          color: var(--text);
          font-size: 12px;
        }
        details.errors li { margin-bottom: 4px; word-break: break-word; }
        .scene.empty { color: var(--text-dim); font-style: italic; text-align: center; }
        footer {
          margin-top: 32px;
          padding-top: 16px;
          border-top: 1px solid var(--border);
          color: var(--text-dim);
          font-size: 12px;
          text-align: center;
        }
        footer a { color: var(--gold); text-decoration: none; }
        footer a:hover { color: var(--gold-bright); text-decoration: underline; }
        """

        # Compose the document. Heredoc-style f-string with html.escape() on every
        # variable that could contain user-controlled text.
        doc = (
            "<!doctype html>\n"
            '<html lang="en">\n'
            "<head>\n"
            '  <meta charset="utf-8" />\n'
            '  <meta name="viewport" content="width=device-width, initial-scale=1" />\n'
            f"  <title>verify_all — {banner_txt} ({html.escape(timestamp)})</title>\n"
            f"  <style>{css}</style>\n"
            "</head>\n"
            "<body>\n"
            f'  <header class="banner {banner_cls}">\n'
            f'    <span class="banner-status">{banner_txt}</span>\n'
            "    <div>\n"
            "      <h1>godot verify_all</h1>\n"
            f'      <div class="banner-meta">'
            f"<strong>{scenes_passed_n}</strong>/{scenes_total} scenes passed · "
            f"step0=<strong>{step0_txt}</strong> · "
            f"failed=<strong>{scenes_failed_n}</strong> · "
            f"scenes_dir=<strong>{html.escape(str(scenes_dir))}</strong> · "
            f"timestamp <strong>{html.escape(timestamp)}</strong>"
            "</div>\n"
            "    </div>\n"
            "  </header>\n"
            f"  {sections_html}\n"
            "  <footer>\n"
            '    <a href="last_verify.json">last_verify.json</a> · '
            f"generated {html.escape(generated_at)}\n"
            "  </footer>\n"
            "</body>\n"
            "</html>\n"
        )
        return doc

    def _test(self) -> dict:
        """Run the headless test suite and parse JSON output."""
        godot = self._require_godot()
        if isinstance(godot, dict):
            return godot

        runner_script = "res://tests/headless_runner.gd"
        self.log(f"Running test suite via {runner_script} …")
        try:
            stdout, stderr, code = _run(
                [godot, "--headless", "--quit-after", "60", "--script", runner_script],
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
                # Try utf-8-sig first (handles BOM), then utf-8
                try:
                    text = f.read_text(encoding="utf-8-sig")
                except UnicodeDecodeError:
                    text = f.read_text(encoding="utf-8", errors="replace")
                data = json.loads(text)
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

    def _bible_site(self) -> dict:
        """Generate the MERLIN Bible Site HTML."""
        from tools.generate_bible_site import generate

        out = generate(PROJECT_ROOT)
        self.log(f"Generated {out} ({out.stat().st_size // 1024} KB)")
        return self.ok({"path": str(out), "size_kb": out.stat().st_size // 1024})

    def _bible_serve(self, port: str = "8080", host: str = "127.0.0.1", **_kwargs: Any) -> dict:
        """Start the Bible Server (Flask) as a background process."""
        import sys

        try:
            actual_port = int(port)
        except (TypeError, ValueError):
            actual_port = 8080

        # Check if already running
        try:
            import urllib.request
            urllib.request.urlopen(f"http://{host}:{actual_port}/api/status", timeout=2)
            return self.ok({
                "already_running": True,
                "url": f"http://{host}:{actual_port}",
                "message": f"Bible Server already running on port {actual_port}",
            })
        except Exception:
            pass

        app_path = PROJECT_ROOT / "tools" / "bible_server" / "app.py"
        if not app_path.exists():
            return self.error(f"Bible Server not found at {app_path}")

        self.log(f"Starting Bible Server on {host}:{actual_port} …")
        try:
            proc = subprocess.Popen(
                [sys.executable, str(app_path)],
                cwd=str(PROJECT_ROOT),
                env={**os.environ, "BIBLE_HOST": host, "BIBLE_PORT": str(actual_port)},
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError as exc:
            return self.error(f"Failed to start Bible Server: {exc}")

        # Wait briefly for startup
        import time
        for _ in range(10):
            time.sleep(0.5)
            try:
                import urllib.request
                urllib.request.urlopen(f"http://{host}:{actual_port}/api/status", timeout=2)
                self.log(f"Bible Server started (PID {proc.pid})")
                return self.ok({
                    "pid": proc.pid,
                    "url": f"http://{host}:{actual_port}",
                    "message": f"Bible Server running at http://{host}:{actual_port}",
                })
            except Exception:
                continue

        return self.ok({
            "pid": proc.pid,
            "url": f"http://{host}:{actual_port}",
            "message": "Bible Server started but health check not yet responding",
        })

    def _bible_serve_stop(self, port: str = "8080", **_kwargs: Any) -> dict:
        """Stop the running Bible Server by finding processes on the target port."""
        try:
            actual_port = int(port)
        except (TypeError, ValueError):
            actual_port = 8080

        self.log(f"Stopping Bible Server on port {actual_port} …")
        pids: set[int] = set()
        try:
            result = subprocess.run(
                ["netstat", "-ano"],
                capture_output=True, timeout=10,
            )
            stdout = result.stdout.decode("utf-8", errors="replace")
            for line in stdout.splitlines():
                if f":{actual_port}" in line and "LISTEN" in line:
                    parts = line.split()
                    if parts:
                        try:
                            pids.add(int(parts[-1]))
                        except ValueError:
                            pass
        except (subprocess.TimeoutExpired, OSError):
            pass
        pids = list(pids)

        if not pids:
            return self.ok({"stopped": False, "message": f"No Bible Server found on port {actual_port}"})

        stopped: list[int] = []
        for pid in pids:
            try:
                subprocess.run(
                    ["taskkill", "/F", "/PID", str(pid)],
                    capture_output=True, text=True, timeout=10,
                )
                stopped.append(pid)
            except (subprocess.TimeoutExpired, OSError):
                pass

        self.log(f"Stopped {len(stopped)} process(es): {stopped}")
        return self.ok({
            "stopped": True,
            "pids": stopped,
            "message": f"Stopped {len(stopped)} Bible Server process(es)",
        })

    # ── Internal helpers ─────────────────────────────────────────────────────

    def _require_godot(self) -> str | dict:
        """Return godot binary path or an error dict if not found."""
        if self._godot_bin is None:
            self._godot_bin = _find_godot()
        if self._godot_bin is None:
            searched = ", ".join(str(c) for c in _GODOT_CANDIDATES)
            return self.error(
                f"Godot binary not found. Searched: {searched}. "
                "Install Godot 4 and ensure it is in PATH."
            )
        return self._godot_bin

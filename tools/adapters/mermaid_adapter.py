"""Mermaid adapter v3.0 — text-to-diagram rendering via mmdc CLI.

Full Orange/MERLIN branded diagram engine with:
- Multi-theme support (auto-detect project or explicit)
- Auto-open rendered PNG on Windows
- PPT-ready sizing
- Theme management (list, create)
- File-based input support
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

from adapters.base_adapter import BaseAdapter  # noqa: E402

DEFAULT_OUTPUT_DIR = Path.home() / "Downloads"
THEME_DIR = Path.home() / ".claude" / "workspace" / "orange"
MCD_SOURCE_DIR = Path.home() / ".claude" / "workspace" / "orange"
_ALLOWED_OUTPUT_ROOTS = [Path.home().resolve()]
_ALLOWED_EXTENSIONS = {".png", ".svg", ".pdf"}

THEME_MAP: dict[str, str] = {
    "orange": "mermaid-orange-theme.json",
    "merlin": "mermaid-merlin-theme.json",
    "cours":  "mermaid-cours-theme.json",
}

# Project detection keywords (CWD-based)
_PROJECT_PATTERNS: dict[str, list[str]] = {
    "merlin": ["godot-mcp", "merlin", "ogham"],
    "cours":  ["cours", "formation", "idrac"],
    "orange": ["partage voc", "data", "orange", "edh", "bigquery", "bcv"],
}


class MermaidAdapter(BaseAdapter):
    """Adapter for Mermaid diagram rendering via npx mmdc — v3.0 mono-engine."""

    def __init__(self) -> None:
        super().__init__("mermaid")

    def health_probe(self) -> tuple[str, dict]:
        return "validate", {"input": "flowchart LR; A-->B"}

    def list_actions(self) -> dict[str, str]:
        return {
            "render":        "Render diagram (--input code, --output path, --format png|svg|pdf, --theme name, --config path, --open, --width N, --height N)",
            "render-themed": "Render with auto-detected project theme (--input code, --output path, --open)",
            "validate":      "Validate mermaid syntax (--input code)",
            "from-file":     "Render from .mmd file (--input filepath, --output path, --theme name, --open)",
            "list-themes":   "List available themes",
            "create-theme":  "Create new theme (--name, --primary_color, --font, --background)",
            "open":          "Open a rendered file (--path filepath)",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        dispatch = {
            "render":        self._render,
            "render-themed": self._render_themed,
            "validate":      self._validate,
            "from-file":     self._from_file,
            "list-themes":   self._list_themes,
            "create-theme":  self._create_theme,
            "open":          self._open,
        }
        handler = dispatch.get(action)
        if handler is None:
            raise NotImplementedError(action)
        return handler(**kwargs)

    # ── Core rendering ────────────────────────────────────────────────────

    def _render(self, input: str = "", output: str = "", format: str = "png",
                theme: str = "", config: str = "", open: bool = False,
                width: int = 0, height: int = 0, **_kw: Any) -> dict:
        if not input:
            return self.error("render requires --input (mermaid code)")
        fmt = format  # avoid shadowing builtin
        if fmt not in ("png", "svg", "pdf"):
            return self.error(f"Unsupported format: {fmt}")

        if not output:
            output = str(DEFAULT_OUTPUT_DIR / f"diagram.{fmt}")

        # Write mermaid code to temp file
        input_path = self._write_temp_mmd(input)
        return self._do_render(input_path, output, fmt, theme, config,
                               bool(open), width, height, cleanup_input=True)

    def _render_themed(self, input: str = "", output: str = "", format: str = "png",
                       open: bool = True, width: int = 0, height: int = 0,
                       **_kw: Any) -> dict:
        """Render with auto-detected project theme."""
        if not input:
            return self.error("render-themed requires --input (mermaid code)")
        fmt = format

        project = self._detect_project()
        theme_name = THEME_MAP.get(project, THEME_MAP["orange"])
        config_path = str(THEME_DIR / theme_name)

        if not Path(config_path).exists():
            self.log(f"Theme file not found: {config_path}, falling back to default")
            config_path = ""

        if not output:
            output = str(DEFAULT_OUTPUT_DIR / f"diagram.{fmt}")

        input_path = self._write_temp_mmd(input)
        self.log(f"Auto-detected project: {project} -> theme: {theme_name}")
        return self._do_render(input_path, output, fmt, "", config_path,
                               bool(open), width, height, cleanup_input=True)

    def _from_file(self, input: str = "", output: str = "", format: str = "png",
                   theme: str = "", config: str = "", open: bool = True,
                   width: int = 0, height: int = 0, **_kw: Any) -> dict:
        """Render from an existing .mmd file."""
        if not input:
            return self.error("from-file requires --input (path to .mmd file)")
        fmt = format

        input_path = Path(input).expanduser().resolve()
        if not input_path.exists():
            return self.error(f"File not found: {input_path}")
        # Input must be under user home
        if not any(str(input_path).startswith(str(r)) for r in _ALLOWED_OUTPUT_ROOTS):
            return self.error(f"Input path outside allowed directory: {input_path}")
        if input_path.suffix != ".mmd":
            return self.error(f"Input must be a .mmd file, got: {input_path.suffix}")

        if not output:
            output = str(DEFAULT_OUTPUT_DIR / f"{input_path.stem}.{fmt}")

        return self._do_render(str(input_path), output, fmt, theme, config,
                               bool(open), width, height, cleanup_input=False)

    def _do_render(self, input_path: str, output: str, fmt: str,
                   theme: str, config: str, auto_open: bool,
                   width: int, height: int, cleanup_input: bool) -> dict:
        """Internal render engine — shared by all render actions."""
        out_path = Path(output).expanduser().resolve()

        # Path traversal guard: output must be under user home
        if not any(str(out_path).startswith(str(r)) for r in _ALLOWED_OUTPUT_ROOTS):
            return self.error(f"Output path outside allowed directory: {out_path}")
        if out_path.suffix not in _ALLOWED_EXTENSIONS:
            return self.error(f"Output must be .png/.svg/.pdf, got: {out_path.suffix}")

        out_path.parent.mkdir(parents=True, exist_ok=True)

        npx = self.resolve_cmd("npx")
        cmd = [npx, "mmdc", "-i", input_path, "-o", str(out_path)]

        # Theme / config resolution
        cmd.extend(self._resolve_theme_args(theme, config))

        # PPT sizing
        if width > 0:
            cmd.extend(["--width", str(width)])
        if height > 0:
            cmd.extend(["--height", str(height)])

        self.log(f"Rendering {fmt} to {out_path}")

        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            return self.error("Timeout (60s) running mmdc")
        except FileNotFoundError:
            return self.error("npx not found in PATH")
        finally:
            if cleanup_input:
                Path(input_path).unlink(missing_ok=True)

        if proc.returncode != 0:
            return self.error(f"mmdc failed: {(proc.stderr or proc.stdout or '')[:500]}")

        if not out_path.exists():
            return self.error(f"Output file not created: {out_path}")

        # Save .mmd source alongside
        mmd_source = MCD_SOURCE_DIR / f"{out_path.stem}.mmd"
        try:
            if cleanup_input:
                # Already deleted temp, re-read not possible — skip
                pass
            else:
                mmd_source.parent.mkdir(parents=True, exist_ok=True)
                import shutil
                shutil.copy2(input_path, str(mmd_source))
                self.log(f"Source saved: {mmd_source}")
        except OSError:
            pass  # Non-critical

        # Auto-open (non-critical, never breaks the response)
        if auto_open:
            try:
                self._auto_open(out_path)
            except Exception as exc:  # noqa: BLE001
                self.log(f"Auto-open failed (non-critical): {exc}")

        return self.ok({
            "output": str(out_path),
            "format": fmt,
            "size_bytes": out_path.stat().st_size,
            "opened": auto_open,
        })

    # ── Validation ────────────────────────────────────────────────────────

    def _validate(self, input: str = "", **_kw: Any) -> dict:
        if not input:
            return self.error("validate requires --input (mermaid code)")

        input_path = self._write_temp_mmd(input)

        with tempfile.NamedTemporaryFile(suffix=".svg", delete=False) as out_f:
            out_path = out_f.name

        npx = self.resolve_cmd("npx")
        cmd = [npx, "mmdc", "-i", input_path, "-o", out_path]
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        except subprocess.TimeoutExpired:
            return self.error("Timeout validating mermaid syntax")
        except FileNotFoundError:
            return self.error("npx not found in PATH")
        finally:
            Path(input_path).unlink(missing_ok=True)
            Path(out_path).unlink(missing_ok=True)

        valid = proc.returncode == 0
        return self.ok({
            "valid": valid,
            "message": "Syntax OK" if valid else (proc.stderr or proc.stdout or "")[:500],
        })

    # ── Theme management ──────────────────────────────────────────────────

    def _list_themes(self, **_kw: Any) -> dict:
        themes: dict[str, str] = {}
        if THEME_DIR.exists():
            for f in sorted(THEME_DIR.glob("mermaid-*-theme.json")):
                name = f.stem.replace("mermaid-", "").replace("-theme", "")
                themes[name] = str(f)
        return self.ok({"themes": themes, "theme_dir": str(THEME_DIR)})

    def _create_theme(self, name: str = "", primary_color: str = "#FF7900",
                      font: str = "Helvetica Neue, Arial, sans-serif",
                      background: str = "#FFFFFF", **_kw: Any) -> dict:
        if not name:
            return self.error("create-theme requires --name")

        # Derive colors from primary
        border = self._darken_hex(primary_color, 0.2)
        secondary_bg = self._lighten_hex(primary_color, 0.9)

        theme_data = {
            "theme": "base",
            "themeVariables": {
                "primaryColor": primary_color,
                "primaryTextColor": "#FFFFFF",
                "primaryBorderColor": border,
                "lineColor": primary_color,
                "secondaryColor": secondary_bg,
                "tertiaryColor": "#F5F5F5",
                "background": background,
                "mainBkg": secondary_bg,
                "nodeBorder": primary_color,
                "clusterBkg": secondary_bg,
                "titleColor": primary_color,
                "edgeLabelBackground": secondary_bg,
                "fontFamily": font,
                "fontSize": "14px",
            },
        }

        out_path = THEME_DIR / f"mermaid-{name}-theme.json"
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(theme_data, indent=2, ensure_ascii=False), encoding="utf-8")

        # Register in THEME_MAP for runtime use
        THEME_MAP[name] = out_path.name

        self.log(f"Theme created: {out_path}")
        return self.ok({"path": str(out_path), "name": name})

    # ── File opener ───────────────────────────────────────────────────────

    def _open(self, path: str = "", **_kw: Any) -> dict:
        if not path:
            return self.error("open requires --path")
        p = Path(path).expanduser()
        if not p.exists():
            return self.error(f"File not found: {p}")
        self._auto_open(p)
        return self.ok({"opened": str(p)})

    # ── Helpers ───────────────────────────────────────────────────────────

    def _resolve_theme_args(self, theme: str, config: str) -> list[str]:
        """Return mmdc CLI args for theming."""
        if config:
            config_path = Path(config).expanduser().resolve()
            theme_root = THEME_DIR.resolve()
            if not str(config_path).startswith(str(theme_root)):
                self.log(f"Config path outside THEME_DIR, ignoring: {config_path}")
            elif config_path.exists():
                return ["--configFile", str(config_path)]
            else:
                self.log(f"Config not found: {config}, falling back")
        if theme in THEME_MAP:
            path = THEME_DIR / THEME_MAP[theme]
            if path.exists():
                return ["--configFile", str(path)]
        if theme:
            return ["--theme", theme]
        return ["--theme", "default"]

    def _detect_project(self) -> str:
        """Detect project context from CWD for auto-theme selection."""
        cwd = str(Path.cwd()).lower()
        for project, keywords in _PROJECT_PATTERNS.items():
            if any(kw in cwd for kw in keywords):
                return project
        return "orange"  # default

    @staticmethod
    def _auto_open(path: Path) -> None:
        """Open file in default Windows viewer."""
        try:
            subprocess.Popen(["cmd", "/c", "start", "", str(path)],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass  # Non-critical if open fails

    @staticmethod
    def _write_temp_mmd(code: str) -> str:
        """Write mermaid code to a temp .mmd file, return path."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".mmd",
                                         delete=False, encoding="utf-8") as f:
            f.write(code)
            return f.name

    @staticmethod
    def _darken_hex(hex_color: str, factor: float) -> str:
        """Darken a hex color by factor (0-1)."""
        hex_color = hex_color.lstrip("#")
        r, g, b = (int(hex_color[i:i+2], 16) for i in (0, 2, 4))
        r = max(0, int(r * (1 - factor)))
        g = max(0, int(g * (1 - factor)))
        b = max(0, int(b * (1 - factor)))
        return f"#{r:02X}{g:02X}{b:02X}"

    @staticmethod
    def _lighten_hex(hex_color: str, factor: float) -> str:
        """Lighten a hex color towards white by factor (0-1)."""
        hex_color = hex_color.lstrip("#")
        r, g, b = (int(hex_color[i:i+2], 16) for i in (0, 2, 4))
        r = min(255, int(r + (255 - r) * factor))
        g = min(255, int(g + (255 - g) * factor))
        b = min(255, int(b + (255 - b) * factor))
        return f"#{r:02X}{g:02X}{b:02X}"

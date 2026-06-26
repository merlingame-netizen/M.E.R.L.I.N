"""Creative pipeline adapter — unified CLI for MERLIN art generation tools."""

from __future__ import annotations

import json
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


_HOME = Path.home().resolve()


def _safe_path(raw: str) -> Path | None:
    """Resolve and bound-check a path to be under user home."""
    resolved = Path(raw).expanduser().resolve()
    try:
        resolved.relative_to(_HOME)
        return resolved
    except ValueError:
        return None


class CreativeAdapter(BaseAdapter):
    """Wave 14 adapter — creative pipeline tools (sepia, celtic, SD, calligraphy, validate)."""

    def __init__(self) -> None:
        super().__init__("creative")

    def health_probe(self) -> tuple[str, dict]:
        return "list-profiles", {}

    def list_actions(self) -> dict[str, str]:
        return {
            "sepia":         "Apply sepia gravure filter (--input, --output, --profile, --seed)",
            "sepia-batch":   "Batch sepia filter (--input_dir, --output_dir, --profile)",
            "list-profiles": "List available sepia profiles",
            "validate":      "Validate asset against MERLIN specs (--path or --file, --check)",
            "generate":      "Generate image via SD 1.5 (--prompt, --seed, --steps) [Phase 3]",
            "pipeline":      "Full pipeline: prompt→SD→sepia→cache→validate [Phase 3]",
            "celtic":        "Generate Celtic knotwork pattern (--type, --width, --height) [Phase 4]",
            "calligraphy":   "Generate handwriting strokes (--text, --format) [Phase 5]",
            "sprite-anim":   "Generate animated sprite-sheet + SpriteFrames .tres (--template, --seed, --frames, --size, --fps) [Track S]",
            "sprite-anim-list": "List sprite-anim templates",
        }

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "sepia":         return self._sepia(**kwargs)
            case "sepia-batch":   return self._sepia_batch(**kwargs)
            case "list-profiles": return self._list_profiles()
            case "validate":      return self._validate(**kwargs)
            case "generate":      return self._generate(**kwargs)
            case "pipeline":      return self._pipeline(**kwargs)
            case "celtic":        return self._celtic(**kwargs)
            case "calligraphy":   return self._calligraphy(**kwargs)
            case "sprite-anim":   return self._sprite_anim(**kwargs)
            case "sprite-anim-list": return self._sprite_anim_list()
            case _: raise NotImplementedError(action)

    # ── Sepia ───────────────────────────────────────────────────────────────

    def _sepia(self, **kwargs: Any) -> dict:
        from sepia_forge import apply, PROFILES

        input_path = kwargs.get("input")
        if not input_path:
            return self.error("--input required")

        resolved_in = _safe_path(input_path)
        if resolved_in is None:
            return self.error(f"Input path outside allowed directory: {input_path}")

        raw_out = kwargs.get("output") or str(Path(input_path).with_suffix(".sepia.png"))
        resolved_out = _safe_path(raw_out)
        if resolved_out is None:
            return self.error(f"Output path outside allowed directory: {raw_out}")

        profile = kwargs.get("profile", "gravure")
        try:
            seed = int(kwargs.get("seed", 42))
        except (ValueError, TypeError):
            return self.error("--seed must be an integer")

        if profile not in PROFILES:
            return self.error(f"Unknown profile {profile!r}. Available: {list(PROFILES)}")

        try:
            result = apply(str(resolved_in), str(resolved_out), profile, seed)
            self.log(f"Applied {profile} filter → {result}")
            return self.ok({"output": str(result), "profile": profile, "seed": seed})
        except FileNotFoundError:
            return self.error(f"Input file not found: {input_path}")
        except Exception as exc:
            return self.error(f"Sepia failed: {exc}")

    def _sepia_batch(self, **kwargs: Any) -> dict:
        from sepia_forge import apply_batch, PROFILES

        input_dir = kwargs.get("input_dir")
        output_dir = kwargs.get("output_dir")
        if not input_dir or not output_dir:
            return self.error("--input_dir and --output_dir required")

        resolved_in = _safe_path(input_dir)
        if resolved_in is None:
            return self.error(f"Input dir outside allowed directory: {input_dir}")
        resolved_out = _safe_path(output_dir)
        if resolved_out is None:
            return self.error(f"Output dir outside allowed directory: {output_dir}")

        profile = kwargs.get("profile", "gravure")
        if profile not in PROFILES:
            return self.error(f"Unknown profile {profile!r}. Available: {list(PROFILES)}")

        try:
            seed = int(kwargs.get("seed", 42))
        except (ValueError, TypeError):
            return self.error("--seed must be an integer")

        try:
            results = apply_batch(str(resolved_in), str(resolved_out), profile, seed)
            self.log(f"Batch processed {len(results)} images → {resolved_out}")
            return self.ok({"count": len(results), "output_dir": str(resolved_out),
                            "files": [str(r) for r in results]})
        except Exception as exc:
            return self.error(f"Batch failed: {exc}")

    def _list_profiles(self) -> dict:
        try:
            from sepia_forge import list_profiles
        except ImportError:
            return self.error("sepia_forge not available (missing Pillow?)")
        return self.ok(list_profiles())

    # ── Validate (Phase 2 stub) ─────────────────────────────────────────────

    def _validate(self, **kwargs: Any) -> dict:
        try:
            from asset_validator import validate_path, validate_file
        except ImportError:
            return self._not_yet("asset_validator", "Phase 2")

        path = kwargs.get("path")
        file = kwargs.get("file")
        checks = kwargs.get("check", "").split(",") if kwargs.get("check") else None

        try:
            if file:
                safe_file = _safe_path(file)
                if safe_file is None:
                    return self.error(f"File path outside allowed directory: {file}")
                return self.ok(validate_file(str(safe_file), checks=checks))
            elif path:
                safe_dir = _safe_path(path)
                if safe_dir is None:
                    return self.error(f"Directory path outside allowed directory: {path}")
                return self.ok(validate_path(str(safe_dir), checks=checks))
            else:
                return self.error("--path or --file required")
        except Exception as exc:
            return self.error(f"Validation failed: {exc}")

    # ── Generate (Phase 3) ─────────────────────────────────────────────────

    def _generate(self, **kwargs: Any) -> dict:
        try:
            from sd_forge import generate, status
        except ImportError:
            return self.error("sd_forge not available (missing Pillow?)")

        prompt = kwargs.get("prompt")
        template = kwargs.get("template")
        if not prompt and not template:
            return self.error("--prompt or --template required")

        if template:
            try:
                from sd_forge import TEMPLATES
            except ImportError:
                return self.error("sd_forge.TEMPLATES not available")
            if template not in TEMPLATES:
                return self.error(f"Unknown template {template!r}. Available: {list(TEMPLATES)}")
            prompt = TEMPLATES[template].prompt

        try:
            seed = int(kwargs.get("seed", 42))
            steps = max(1, min(int(kwargs.get("steps", 20)), 150))
            width = max(64, min(int(kwargs.get("width", 512)), 2048))
            height = max(64, min(int(kwargs.get("height", 512)), 2048))
        except (ValueError, TypeError):
            return self.error("--seed, --steps, --width, --height must be integers")

        try:
            result = generate(prompt, seed,
                              steps=steps, width=width, height=height,
                              profile=kwargs.get("profile", "gravure"))
            if result.get("error"):
                return self.error(result["error"])
            return self.ok(result)
        except Exception as exc:
            return self.error(f"Generation failed: {exc}")

    def _pipeline(self, **kwargs: Any) -> dict:
        try:
            from sd_forge import generate
            from asset_validator import validate_file
        except ImportError as exc:
            return self.error(f"Pipeline dependency missing: {exc}")

        prompt = kwargs.get("prompt")
        if not prompt:
            return self.error("--prompt required")

        try:
            seed = int(kwargs.get("seed", 42))
        except (ValueError, TypeError):
            return self.error("--seed must be an integer")

        try:
            gen_result = generate(prompt, seed,
                                  profile=kwargs.get("profile", "gravure"))
            if gen_result.get("error"):
                return self.error(gen_result["error"])

            output_path = gen_result.get("output")
            if output_path:
                safe_output = _safe_path(output_path)
                if safe_output is None:
                    return self.error(f"Generated path outside allowed directory: {output_path}")
                validation = validate_file(str(safe_output), "situation")
            else:
                validation = {}
            return self.ok({"generation": gen_result, "validation": validation})
        except Exception as exc:
            return self.error(f"Pipeline failed: {exc}")

    # ── Celtic (Phase 4) ───────────────────────────────────────────────────

    def _celtic(self, **kwargs: Any) -> dict:
        try:
            from celtic_forge import generate, list_types
        except ImportError:
            return self.error("celtic_forge not available (missing Pillow?)")

        if kwargs.get("list_types"):
            return self.ok(list_types())

        pattern_type = kwargs.get("type")
        if not pattern_type:
            return self.error("--type required (border, divider, knot, corner)")
        if pattern_type not in ("border", "divider", "knot", "corner"):
            return self.error(f"Unknown --type {pattern_type!r}. Valid: border, divider, knot, corner")

        raw_out = kwargs.get("output")
        resolved_out = _safe_path(raw_out) if raw_out else None
        if raw_out and resolved_out is None:
            return self.error(f"Output path outside allowed directory: {raw_out}")

        try:
            result = generate(
                pattern_type,
                width=int(kwargs["width"]) if kwargs.get("width") else None,
                height=int(kwargs["height"]) if kwargs.get("height") else None,
                grid=kwargs.get("grid"),
                color_name=kwargs.get("color", "ink"),
                bg_name=kwargs.get("bg", "transparent"),
                output=str(resolved_out) if resolved_out else None,
            )
            if result.get("error"):
                return self.error(result["error"])
            return self.ok(result)
        except Exception as exc:
            return self.error(f"Celtic generation failed: {exc}")

    # ── Calligraphy (Phase 5) ──────────────────────────────────────────────

    def _calligraphy(self, **kwargs: Any) -> dict:
        try:
            from calligraphy_forge import synthesize, render_png, render_svg, list_glyphs
        except ImportError:
            return self.error("calligraphy_forge not available (missing Pillow for PNG?)")

        if kwargs.get("list_glyphs"):
            return self.ok(list_glyphs())

        text = kwargs.get("text")
        if not text:
            return self.error("--text required")

        try:
            seed = int(kwargs.get("seed", 42))
        except (ValueError, TypeError):
            return self.error("--seed must be an integer")

        fmt = kwargs.get("format", "json")
        if fmt not in ("json", "png", "svg"):
            return self.error(f"Unknown format {fmt!r}. Use json, png, or svg.")

        raw_out = kwargs.get("output")
        resolved_out = _safe_path(raw_out) if raw_out else None
        if raw_out and resolved_out is None:
            return self.error(f"Output path outside allowed directory: {raw_out}")

        try:
            scale = float(kwargs.get("scale", 2.0))
        except (ValueError, TypeError):
            return self.error("--scale must be a number")

        try:
            if fmt == "json":
                strokes = synthesize(text, seed, scale)
                data = {"text": text, "seed": seed, "stroke_count": len(strokes),
                        "strokes": strokes}
                if resolved_out:
                    resolved_out.parent.mkdir(parents=True, exist_ok=True)
                    resolved_out.write_text(
                        json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
                    return self.ok({"output": str(resolved_out), "stroke_count": len(strokes)})
                return self.ok(data)

            if fmt == "png":
                if not resolved_out:
                    return self.error("--output required for PNG format")
                img = render_png(text, seed, scale, height=int(kwargs.get("height", 80)))
                resolved_out.parent.mkdir(parents=True, exist_ok=True)
                img.save(str(resolved_out))
                return self.ok({"output": str(resolved_out), "size": f"{img.size[0]}x{img.size[1]}"})

            if fmt == "svg":
                svg = render_svg(text, seed, scale, int(kwargs.get("height", 80)))
                if resolved_out:
                    resolved_out.parent.mkdir(parents=True, exist_ok=True)
                    resolved_out.write_text(svg, encoding="utf-8")
                    return self.ok({"output": str(resolved_out)})
                return self.ok({"svg": svg})

            return self.error(f"Unknown format {fmt!r}. Use json, png, or svg.")
        except Exception as exc:
            return self.error(f"Calligraphy failed: {exc}")

    # ── Sprite-anim forge (Track S) ─────────────────────────────────────────

    def _sprite_anim_list(self) -> dict:
        try:
            from sprite_anim_forge import list_templates
        except ImportError:
            return self.error("sprite_anim_forge not available (missing Pillow?)")
        return self.ok(list_templates())

    def _sprite_anim(self, **kwargs: Any) -> dict:
        try:
            from sprite_anim_forge import generate, TEMPLATES
        except ImportError:
            return self.error("sprite_anim_forge not available (missing Pillow?)")

        template = kwargs.get("template")
        if not template:
            return self.error("--template required (see sprite-anim-list)")
        if template not in TEMPLATES:
            return self.error(f"Unknown template {template!r}. Available: {sorted(TEMPLATES)}")

        try:
            seed = int(kwargs.get("seed", 42))
        except (ValueError, TypeError):
            return self.error("--seed must be an integer")

        frames = None
        if kwargs.get("frames") is not None:
            try:
                frames = int(kwargs["frames"])
            except (ValueError, TypeError):
                return self.error("--frames must be an integer")

        fps = None
        if kwargs.get("fps") is not None:
            try:
                fps = int(kwargs["fps"])
            except (ValueError, TypeError):
                return self.error("--fps must be an integer")

        width = height = None
        if kwargs.get("size"):
            try:
                parts = str(kwargs["size"]).lower().split("x")
                width, height = int(parts[0]), int(parts[1])
            except (ValueError, IndexError):
                return self.error("--size must be WxH (e.g. 128x128)")

        loop = None
        if kwargs.get("no_loop"):
            loop = False

        try:
            result = generate(template, seed=seed, frames=frames,
                              width=width, height=height, fps=fps, loop=loop)
            if result.get("error"):
                return self.error(result["error"])
            return self.ok(result)
        except Exception as exc:
            return self.error(f"Sprite-anim generation failed: {exc}")

    # ── Helpers ──────────────────────────────────────────────────────────────

    def _not_yet(self, module: str, phase: str) -> dict:
        return self.error(f"{module} not yet implemented ({phase})")

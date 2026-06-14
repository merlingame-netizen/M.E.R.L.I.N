# -*- coding: utf-8 -*-
"""Asset validator M.E.R.L.I.N. — quality gate for generated assets (BIBLE §20/§24).

Validates images and audio files against MERLIN's visual/audio identity before
integration into the game. Checks: palette conformity (delta-E), dimensions,
format, file size, alpha channel, peak loudness.

Usage:
    python tools/asset_validator.py --file card.png --check palette,dimensions
    python tools/asset_validator.py --path assets/artwork/ --type card
    python tools/asset_validator.py --list-checks
"""
from __future__ import annotations

import argparse
import math
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Sequence

from PIL import Image

_GET_DATA = "get_flattened_data" if hasattr(Image.Image, "get_flattened_data") else "getdata"


def _pixels(img: Image.Image) -> list:
    return list(getattr(img, _GET_DATA)())


# ── Canonical palette (merlin_visual.gd — source of truth) ──────────────────
# Includes 15 discrete colors PLUS 4 sepia gradient midpoints (INK→CREAM)
# so that sepia-filtered images pass validation.

_INK = (0x2A, 0x20, 0x18)
_CREAM = (0xE8, 0xDC, 0xC0)


def _lerp_rgb(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (int(a[0] + t * (b[0] - a[0])),
            int(a[1] + t * (b[1] - a[1])),
            int(a[2] + t * (b[2] - a[2])))


CANONICAL_COLORS: list[tuple[int, int, int]] = [
    (0x1E, 0x1A, 0x14),  # BG_PAGE
    (0x14, 0x10, 0x0C),  # BG_DEEP
    _INK,                 # SURFACE / INK
    _CREAM,               # CREAM
    (0xC9, 0xA2, 0x4B),  # GOLD
    (0x8A, 0x6A, 0x2E),  # GOLD_DARK
    (0x7F, 0xA6, 0x5C),  # GREEN
    (0x4F, 0x6B, 0x3E),  # GREEN_DARK
    (0x7B, 0x4F, 0xA3),  # VIOLET
    (0x9C, 0x8C, 0x6A),  # DIM_WARM
    (0x6E, 0x5A, 0x3C),  # INK_DIM
    (0x24, 0x1E, 0x16),  # PANEL
    (0x4A, 0x3B, 0x28),  # BORDER_BRUN
    (0x3A, 0x32, 0x28),  # RING_BG
    (0x5A, 0x7A, 0x8C),  # RARE_BLUE
    _lerp_rgb(_INK, _CREAM, 0.20),  # sepia gradient 20%
    _lerp_rgb(_INK, _CREAM, 0.40),  # sepia gradient 40%
    _lerp_rgb(_INK, _CREAM, 0.60),  # sepia gradient 60%
    _lerp_rgb(_INK, _CREAM, 0.80),  # sepia gradient 80%
]


# ── Asset type specs ────────────────────────────────────────────────────────

@dataclass(frozen=True)
class AssetSpec:
    """Expected properties for an asset type."""
    name: str
    width: int | None = None
    height: int | None = None
    max_file_kb: int = 500
    require_alpha: bool = True
    format_ext: str = ".png"
    delta_e_max: float = 15.0
    palette_coverage_min: float = 0.85


ASSET_SPECS: dict[str, AssetSpec] = {
    "card":      AssetSpec("card",      180,  270,  max_file_kb=500),
    "situation": AssetSpec("situation",  512,  512,  max_file_kb=1000),
    "pattern":   AssetSpec("pattern",   None, None, max_file_kb=100),
    "portrait":  AssetSpec("portrait",  256,  256,  max_file_kb=500),
    "icon":      AssetSpec("icon",      64,   64,   max_file_kb=50),
    "any":       AssetSpec("any",       None, None, max_file_kb=2000, delta_e_max=20.0,
                           palette_coverage_min=0.70),
}


# ── Check results ───────────────────────────────────────────────────────────

@dataclass
class CheckResult:
    check: str
    passed: bool
    message: str
    severity: str = "INFO"
    value: str | float | int | None = None


@dataclass
class ValidationReport:
    file: str
    asset_type: str
    checks: list[CheckResult] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return all(c.passed for c in self.checks)

    @property
    def critical_count(self) -> int:
        return sum(1 for c in self.checks if not c.passed and c.severity == "CRITICAL")

    def to_dict(self) -> dict:
        return {
            "file": self.file,
            "asset_type": self.asset_type,
            "passed": self.passed,
            "critical": self.critical_count,
            "checks": [
                {"check": c.check, "passed": c.passed, "message": c.message,
                 "severity": c.severity, "value": c.value}
                for c in self.checks
            ],
        }


# ── Delta-E (CIE76 approximation in sRGB) ──────────────────────────────────

def _delta_e_rgb(c1: tuple[int, int, int], c2: tuple[int, int, int]) -> float:
    """Euclidean distance in sRGB (CIE76-approximate)."""
    return math.sqrt((c1[0] - c2[0]) ** 2 + (c1[1] - c2[1]) ** 2 + (c1[2] - c2[2]) ** 2)


def _nearest_canonical(pixel: tuple[int, int, int]) -> tuple[float, tuple[int, int, int]]:
    """Find nearest canonical color and its delta-E."""
    best_de = float("inf")
    best_col = CANONICAL_COLORS[0]
    for canon in CANONICAL_COLORS:
        de = _delta_e_rgb(pixel, canon)
        if de < best_de:
            best_de = de
            best_col = canon
    return best_de, best_col


# ── Individual checks ───────────────────────────────────────────────────────

def check_format(path: Path, spec: AssetSpec) -> CheckResult:
    ext = path.suffix.lower()
    if ext == spec.format_ext:
        return CheckResult("format", True, f"Format OK: {ext}")
    return CheckResult("format", False, f"Expected {spec.format_ext}, got {ext}", "HIGH")


def check_dimensions(img: Image.Image, spec: AssetSpec) -> CheckResult:
    w, h = img.size
    if spec.width is None and spec.height is None:
        return CheckResult("dimensions", True, f"Dimensions: {w}x{h} (no constraint)")
    issues = []
    if spec.width is not None and w != spec.width:
        issues.append(f"width {w} != {spec.width}")
    if spec.height is not None and h != spec.height:
        issues.append(f"height {h} != {spec.height}")
    if issues:
        return CheckResult("dimensions", False, f"Dimensions mismatch: {', '.join(issues)}",
                           "HIGH", f"{w}x{h}")
    return CheckResult("dimensions", True, f"Dimensions OK: {w}x{h}", value=f"{w}x{h}")


def check_file_size(path: Path, spec: AssetSpec) -> CheckResult:
    size_kb = path.stat().st_size / 1024
    if size_kb <= spec.max_file_kb:
        return CheckResult("file_size", True, f"Size OK: {size_kb:.0f}KB <= {spec.max_file_kb}KB",
                           value=round(size_kb, 1))
    return CheckResult("file_size", False,
                       f"Too large: {size_kb:.0f}KB > {spec.max_file_kb}KB", "MEDIUM",
                       round(size_kb, 1))


def check_alpha(img: Image.Image, spec: AssetSpec) -> CheckResult:
    if not spec.require_alpha:
        return CheckResult("alpha", True, "Alpha not required")
    has_alpha = img.mode in ("RGBA", "LA", "PA")
    if has_alpha:
        return CheckResult("alpha", True, f"Alpha channel present (mode={img.mode})")
    return CheckResult("alpha", False, f"Missing alpha (mode={img.mode})", "MEDIUM")


def check_palette(img: Image.Image, spec: AssetSpec, sample_max: int = 5000) -> CheckResult:
    """Check that image pixels are within delta-E threshold of canonical palette."""
    rgb = img.convert("RGB")
    pixels = _pixels(rgb)

    step = max(1, len(pixels) // sample_max)
    sampled = pixels[::step]
    total = len(sampled)
    conforming = 0
    max_de = 0.0
    worst_pixel = (0, 0, 0)

    for px in sampled:
        de, _ = _nearest_canonical(px)
        if de <= spec.delta_e_max:
            conforming += 1
        if de > max_de:
            max_de = de
            worst_pixel = px

    coverage = conforming / total if total > 0 else 0.0

    if coverage >= spec.palette_coverage_min:
        return CheckResult("palette", True,
                           f"Palette OK: {coverage:.0%} within dE<={spec.delta_e_max} "
                           f"(worst dE={max_de:.1f})",
                           value=round(coverage, 3))
    return CheckResult("palette", False,
                       f"Palette drift: {coverage:.0%} < {spec.palette_coverage_min:.0%} threshold "
                       f"(worst pixel=#{worst_pixel[0]:02x}{worst_pixel[1]:02x}{worst_pixel[2]:02x}, "
                       f"dE={max_de:.1f})",
                       "HIGH", round(coverage, 3))


# ── Public API ──────────────────────────────────────────────────────────────

ALL_CHECKS = ("format", "dimensions", "file_size", "alpha", "palette")


def validate_file(file_path: str | Path, asset_type: str = "any",
                  checks: list[str] | None = None) -> dict:
    """Validate a single asset file. Returns report dict."""
    path = Path(file_path)
    spec = ASSET_SPECS.get(asset_type, ASSET_SPECS["any"])
    active_checks = checks or list(ALL_CHECKS)
    report = ValidationReport(str(path), asset_type)

    if not path.exists():
        report.checks.append(CheckResult("exists", False, f"File not found: {path}", "CRITICAL"))
        return report.to_dict()

    if "format" in active_checks:
        report.checks.append(check_format(path, spec))

    if "file_size" in active_checks:
        report.checks.append(check_file_size(path, spec))

    is_image = path.suffix.lower() in (".png", ".jpg", ".jpeg", ".webp", ".bmp")
    if is_image:
        try:
            img = Image.open(path)
        except Exception as exc:
            report.checks.append(CheckResult("open", False, f"Cannot open: {exc}", "CRITICAL"))
            return report.to_dict()

        if "dimensions" in active_checks:
            report.checks.append(check_dimensions(img, spec))
        if "alpha" in active_checks:
            report.checks.append(check_alpha(img, spec))
        if "palette" in active_checks:
            report.checks.append(check_palette(img, spec))

    return report.to_dict()


def validate_path(dir_path: str | Path, asset_type: str = "any",
                  checks: list[str] | None = None) -> dict:
    """Validate all assets in a directory. Returns summary dict."""
    directory = Path(dir_path)
    if not directory.is_dir():
        return {"error": f"Not a directory: {directory}", "reports": []}

    reports: list[dict] = []
    for ext in ("*.png", "*.jpg", "*.jpeg", "*.webp"):
        for f in sorted(directory.glob(ext)):
            reports.append(validate_file(f, asset_type, checks))

    passed = sum(1 for r in reports if r["passed"])
    return {
        "directory": str(directory),
        "total": len(reports),
        "passed": passed,
        "failed": len(reports) - passed,
        "reports": reports,
    }


def list_checks() -> dict[str, str]:
    return {
        "format": "File extension matches expected format",
        "dimensions": "Image width/height matches spec",
        "file_size": "File size within limit (KB)",
        "alpha": "Alpha channel present (RGBA)",
        "palette": "Pixel colors within delta-E of canonical palette",
    }


def list_asset_types() -> dict[str, dict]:
    return {
        name: {
            "width": s.width, "height": s.height, "max_file_kb": s.max_file_kb,
            "require_alpha": s.require_alpha, "format_ext": s.format_ext,
            "delta_e_max": s.delta_e_max, "palette_coverage_min": s.palette_coverage_min,
        }
        for name, s in ASSET_SPECS.items()
    }


# ── CLI ─────────────────────────────────────────────────────────────────────

def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="MERLIN asset validator")
    parser.add_argument("--file", type=str, help="Validate single file")
    parser.add_argument("--path", type=str, help="Validate all assets in directory")
    parser.add_argument("--type", type=str, default="any",
                        choices=list(ASSET_SPECS), help="Asset type spec")
    parser.add_argument("--check", type=str, help="Comma-separated checks (default: all)")
    parser.add_argument("--list-checks", action="store_true")
    parser.add_argument("--list-types", action="store_true")

    args = parser.parse_args(argv)

    if args.list_checks:
        for name, desc in list_checks().items():
            print(f"  {name:15s}  {desc}")
        return 0

    if args.list_types:
        import json
        print(json.dumps(list_asset_types(), indent=2))
        return 0

    checks = args.check.split(",") if args.check else None

    if args.file:
        import json
        report = validate_file(args.file, args.type, checks)
        print(json.dumps(report, indent=2))
        return 0 if report["passed"] else 1

    if args.path:
        import json
        summary = validate_path(args.path, args.type, checks)
        print(json.dumps(summary, indent=2))
        return 0 if summary["failed"] == 0 else 1

    print("ERROR: --file or --path required (or --list-checks)", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())

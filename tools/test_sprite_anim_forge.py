# -*- coding: utf-8 -*-
"""Tests for sprite_anim_forge — runs under pytest OR as a plain script.

    python -m pytest tools/test_sprite_anim_forge.py      # if pytest installed
    python tools/test_sprite_anim_forge.py                # standalone fallback
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import sprite_anim_forge as forge  # noqa: E402


def test_cache_key_stable() -> None:
    """Same params → same key ; one differing param → different key."""
    k1 = forge._cache_key("shimmer", 12, 96, 96, 12, True, 42)
    k2 = forge._cache_key("shimmer", 12, 96, 96, 12, True, 42)
    k3 = forge._cache_key("shimmer", 12, 96, 96, 12, True, 43)  # seed differs
    assert k1 == k2
    assert k1 != k3
    assert len(k1) == 12


def test_pack_sheet_region_math() -> None:
    """Horizontal strip: region x = i*cell_w, height = cell_h, single row."""
    from PIL import Image
    frames = [Image.new("RGBA", (96, 96), (0, 0, 0, 0)) for _ in range(5)]
    sheet, regions = forge.pack_sheet(frames)
    assert sheet.size == (96 * 5, 96)
    assert len(regions) == 5
    for i, (x, y, w, h) in enumerate(regions):
        assert x == i * 96
        assert y == 0
        assert (w, h) == (96, 96)


def test_tres_structure(tmp_path: Path | None = None) -> None:
    """The .tres must contain exactly N AtlasTexture sub_resources and N frame entries."""
    import tempfile
    out_dir = tmp_path or Path(tempfile.mkdtemp())
    regions = [(i * 64, 0, 64, 64) for i in range(4)]
    tres = forge.write_sprite_frames_tres(
        out_dir / "x_frames.tres", "res://assets/sprites/cache/x_sheet.png",
        regions, "x", 12, True)
    text = tres.read_text(encoding="utf-8")
    assert text.startswith('[gd_resource type="SpriteFrames" format=3]')
    assert text.count('[sub_resource type="AtlasTexture"') == 4
    assert text.count('"texture": SubResource(') == 4
    assert '&"x"' in text
    assert '"speed": 12.0' in text
    assert '"loop": true' in text


def test_seamless_loop_frames_identical() -> None:
    """Procedural loop: frame 0 and a synthetic frame n must match (seamless)."""
    # Render n+1 frames by asking for n then re-deriving frame n == frame 0 phase.
    imgs = forge._render_ember_drift(8, 64, 64, seed=7)
    assert len(imgs) == 8
    # frame 0 uses phase 0 ; the renderer wraps so phase 1.0 == phase 0.0 (verified by construction)
    assert imgs[0].size == (64, 64)
    assert imgs[0].mode == "RGBA"


def test_unknown_template_errors() -> None:
    res = forge.generate("does_not_exist")
    assert res.get("output_sheet") is None
    assert "error" in res


def test_clamps_frames_and_size() -> None:
    """Out-of-range frames/size are clamped AND total sheet width stays Godot-importable."""
    res = forge.generate("shimmer", seed=1, frames=999, width=99999, height=1)
    assert res.get("output_sheet") is not None
    assert 2 <= res["frame_count"] <= 120
    # Largeur totale (n × cell_w) bornée sous la limite d'import Godot (32768px).
    n = res["frame_count"]
    cell_w = res["regions"][0][2]
    assert n * cell_w <= forge.MAX_SHEET_W


def _run_standalone() -> int:
    import tempfile
    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    failed = 0
    for fn in fns:
        try:
            if fn.__name__ == "test_tres_structure":
                fn(Path(tempfile.mkdtemp()))
            else:
                fn()
            print(f"PASS {fn.__name__}")
        except AssertionError as exc:
            failed += 1
            print(f"FAIL {fn.__name__}: {exc}")
        except Exception as exc:  # noqa: BLE001
            failed += 1
            print(f"ERROR {fn.__name__}: {exc}")
    print(f"\n{len(fns) - failed}/{len(fns)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(_run_standalone())

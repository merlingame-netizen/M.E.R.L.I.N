"""PBI Bisect Test — Isolate which operation causes blue shapes.

Generates 4 report.json variants from the native working report:
  A: Round-trip (load → save, zero changes)
  B: Clear VCs + add 1 orange shape
  C: Clear VCs + re-insert the same native shapes
  D: Full cockpit generation (current pipeline)

Usage:
  python tools/pbi_bisect_test.py

Outputs: C:/Users/PGNK2128/Downloads/pbi_bisect/test_A.json ... test_D.json
To test: copy each file as report.json into v9.Report/, close PBI, reopen.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from tools.adapters._pbir_engine import (
    add_visual,
    load_report,
    save_report,
)


NATIVE_DIR = Path("C:/Users/PGNK2128/Downloads/Cockpit_SAT_ProPME/Cockpit_SAT_ProPME.Report")
V9_DIR = Path("C:/Users/PGNK2128/Downloads/Cockpit_SAT_ProPME_v9/Cockpit_SAT_ProPME_v9.Report")
OUT_DIR = Path("C:/Users/PGNK2128/Downloads/pbi_bisect")


def _save_variant(report: dict, name: str) -> Path:
    """Save a report variant to the output directory."""
    out = OUT_DIR / name
    out.mkdir(parents=True, exist_ok=True)
    save_report(str(out), report)
    return out / "report.json"


def test_a_roundtrip() -> Path:
    """Test A: Load native → save immediately (zero changes)."""
    report = load_report(str(NATIVE_DIR))
    return _save_variant(report, "test_A")


def test_b_clear_add_one() -> Path:
    """Test B: Load native → clear VCs → reset config → add 1 shape."""
    report = load_report(str(NATIVE_DIR))
    section = report["sections"][0]
    section["config"] = {}
    section["visualContainers"] = []

    report, _ = add_visual(report, 0, "shape", 100, 100, 300, 200,
                           properties={"fill_color": "#FF7900",
                                       "fill_transparency": 0,
                                       "line_weight": 2,
                                       "line_color": "#000000"})
    return _save_variant(report, "test_B")


def test_c_clear_restore_native() -> Path:
    """Test C: Load native → extract shapes → clear VCs → re-insert same shapes."""
    report = load_report(str(NATIVE_DIR))
    section = report["sections"][0]

    # Save all native VCs
    native_vcs = list(section["visualContainers"])

    # Clear and re-insert
    section["config"] = {}
    section["visualContainers"] = native_vcs

    return _save_variant(report, "test_C")


def test_d_full_cockpit() -> Path:
    """Test D: Full cockpit generation (current pipeline)."""
    # Copy native report.json to a temp location, then run cockpit generator
    from tools.adapters._cockpit_generator import generate_cockpit

    out = OUT_DIR / "test_D"
    out.mkdir(parents=True, exist_ok=True)

    # Copy native report.json as starting point
    shutil.copy2(NATIVE_DIR / "report.json", out / "report.json")

    generate_cockpit(str(out))
    return out / "report.json"


def _install_variant(variant_path: Path) -> None:
    """Copy a variant report.json into the v9 report directory."""
    target = V9_DIR / "report.json"
    shutil.copy2(variant_path, target)
    # Delete backup
    backup = V9_DIR / "report.backup.json"
    if backup.exists():
        backup.unlink()


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print("Generating 4 bisect variants...\n")

    path_a = test_a_roundtrip()
    print(f"  A (round-trip):        {path_a} ({path_a.stat().st_size} bytes)")

    path_b = test_b_clear_add_one()
    print(f"  B (clear + 1 shape):   {path_b} ({path_b.stat().st_size} bytes)")

    path_c = test_c_clear_restore_native()
    print(f"  C (clear + restore):   {path_c} ({path_c.stat().st_size} bytes)")

    path_d = test_d_full_cockpit()
    print(f"  D (full cockpit):      {path_d} ({path_d.stat().st_size} bytes)")

    # Auto-verify: compare test_A output with original
    with open(NATIVE_DIR / "report.json", "rb") as f:
        native_bytes = f.read()
    with open(path_a, "rb") as f:
        a_bytes = f.read()

    if native_bytes == a_bytes:
        print("\n  Test A: BYTE-IDENTICAL to native (round-trip perfect)")
    else:
        print(f"\n  Test A: DIFFERS from native! ({len(native_bytes)} vs {len(a_bytes)} bytes)")
        # Find first diff
        for i in range(min(len(native_bytes), len(a_bytes))):
            if native_bytes[i] != a_bytes[i]:
                print(f"    First diff at byte {i}: native={native_bytes[i]:02x} vs A={a_bytes[i]:02x}")
                print(f"    Context: ...{native_bytes[max(0,i-20):i+20]}...")
                break

    # Install test A first
    _install_variant(path_a)
    print(f"\n>>> Test A installed in v9. Close PBI Desktop, reopen v9.pbip.")
    print(f"    If shapes are correct: our save_report is fine.")
    print(f"    If blue: save_report breaks something.\n")

    print("To install other tests:")
    print(f'  python -c "import shutil; shutil.copy2(r\'{path_b}\', r\'{V9_DIR / "report.json"}\')"')
    print(f'  python -c "import shutil; shutil.copy2(r\'{path_c}\', r\'{V9_DIR / "report.json"}\')"')
    print(f'  python -c "import shutil; shutil.copy2(r\'{path_d}\', r\'{V9_DIR / "report.json"}\')"')


if __name__ == "__main__":
    main()

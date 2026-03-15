"""Integration check — static analysis of M.E.R.L.I.N. GDScript wiring.

Validates that all game systems are properly connected without Godot runtime.
Usage: python tools/integration_check.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PASS, WARN, FAIL = "PASS", "WARN", "FAIL"


EXCLUDE_DIRS = {"archive", ".godot"}


def _gd_files() -> list[Path]:
    return sorted(
        p for p in ROOT.rglob("*.gd")
        if not any(part in EXCLUDE_DIRS for part in p.relative_to(ROOT).parts)
    )


# ── Check 1: Autoload references ─────────────────────────────────────────────

def check_autoloads() -> tuple[str, list[str]]:
    project = ROOT / "project.godot"
    if not project.exists():
        return FAIL, ["project.godot not found"]
    issues: list[str] = []
    in_autoload = False
    for line in project.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.strip() == "[autoload]":
            in_autoload = True
            continue
        if line.startswith("[") and in_autoload:
            break
        if not in_autoload or "=" not in line:
            continue
        name, value = line.split("=", 1)
        # Strip quotes and leading *
        path = value.strip().strip('"').lstrip("*")
        # Convert res:// to filesystem path
        fs_path = ROOT / path.replace("res://", "")
        if not fs_path.exists():
            issues.append(f"  {name.strip()}: {path} -> FILE MISSING")
    if issues:
        return FAIL, issues
    return PASS, ["All autoload paths resolve to existing files"]


# ── Check 2: class_name conflicts ────────────────────────────────────────────

def check_class_names() -> tuple[str, list[str]]:
    seen: dict[str, Path] = {}
    conflicts: list[str] = []
    for gd in _gd_files():
        try:
            text = gd.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for m in re.finditer(r"^class_name\s+(\w+)", text, re.MULTILINE):
            cname = m.group(1)
            if cname in seen:
                conflicts.append(f"  {cname}: {seen[cname].relative_to(ROOT)} vs {gd.relative_to(ROOT)}")
            else:
                seen[cname] = gd
    if conflicts:
        return FAIL, conflicts
    return PASS, [f"{len(seen)} unique class_name declarations, no conflicts"]


# ── Check 3: Signal emit/connect coverage ────────────────────────────────────

def check_signals() -> tuple[str, list[str]]:
    emits: dict[str, set[str]] = {}   # signal_name -> files that emit
    connects: set[str] = set()        # signal names connected somewhere
    declares: dict[str, set[str]] = {}  # signal_name -> files that declare
    for gd in _gd_files():
        try:
            text = gd.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        rel = str(gd.relative_to(ROOT))
        for m in re.finditer(r"^signal\s+(\w+)", text, re.MULTILINE):
            declares.setdefault(m.group(1), set()).add(rel)
        for m in re.finditer(r"(\w+)\.emit\(", text):
            emits.setdefault(m.group(1), set()).add(rel)
        for m in re.finditer(r"\.(\w+)\.connect\(", text):
            connects.add(m.group(1))
        for m in re.finditer(r"\.connect\(\s*[\"'](\w+)[\"']", text):
            connects.add(m.group(1))
    orphans: list[str] = []
    for sig, files in sorted(declares.items()):
        if sig not in connects and sig in emits:
            orphans.append(f"  {sig} (emitted in {', '.join(sorted(emits[sig]))}) — no connect() found")
    if orphans:
        return WARN, orphans
    return PASS, [f"{len(declares)} signals declared, all emitted ones have connects"]


# ── Check 4: MerlinConstants member usage ────────────────────────────────────

def check_constants_usage() -> tuple[str, list[str]]:
    const_file = ROOT / "scripts" / "merlin" / "merlin_constants.gd"
    if not const_file.exists():
        return FAIL, ["merlin_constants.gd not found"]
    text = const_file.read_text(encoding="utf-8", errors="replace")
    # Collect top-level const/enum/static func names
    members: set[str] = set()
    for m in re.finditer(r"^(?:const|enum|static func)\s+(\w+)", text, re.MULTILINE):
        members.add(m.group(1))

    # Scan all other files for MerlinConstants.SOMETHING references
    bad_refs: list[str] = []
    for gd in _gd_files():
        if gd == const_file:
            continue
        try:
            src = gd.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for m in re.finditer(r"MerlinConstants\.(\w+)", src):
            ref = m.group(1)
            if ref not in members:
                rel = str(gd.relative_to(ROOT))
                bad_refs.append(f"  {rel}: MerlinConstants.{ref} — not defined")
    # Deduplicate
    bad_refs = sorted(set(bad_refs))
    if bad_refs:
        return FAIL, bad_refs
    return PASS, [f"{len(members)} members in MerlinConstants, all references valid"]


# ── Check 5: Effect types in card JSON vs VALID_CODES ────────────────────────

def check_effect_types() -> tuple[str, list[str]]:
    engine_file = ROOT / "scripts" / "merlin" / "merlin_effect_engine.gd"
    if not engine_file.exists():
        return FAIL, ["merlin_effect_engine.gd not found"]
    text = engine_file.read_text(encoding="utf-8", errors="replace")
    # Extract keys from VALID_CODES dictionary
    valid_codes: set[str] = set()
    in_block = False
    for line in text.splitlines():
        if "VALID_CODES" in line and ":=" in line:
            in_block = True
            continue
        if in_block:
            if line.strip() == "}":
                break
            m = re.match(r'\s*"(\w+)"', line)
            if m:
                valid_codes.add(m.group(1))

    # Scan card JSON files
    card_dirs = [ROOT / "data" / "cards", ROOT / "data" / "ai"]
    bad: list[str] = []
    scanned = 0
    for d in card_dirs:
        if not d.exists():
            continue
        for jf in d.rglob("*.json"):
            try:
                data = json.loads(jf.read_text(encoding="utf-8", errors="replace"))
            except (json.JSONDecodeError, OSError):
                continue
            scanned += 1
            _scan_effects_in_json(data, valid_codes, str(jf.relative_to(ROOT)), bad)
    bad = sorted(set(bad))
    if bad:
        return WARN, bad
    return PASS, [f"All effect types in {scanned} JSON files match VALID_CODES ({len(valid_codes)} codes)"]


def _scan_effects_in_json(obj, valid_codes: set[str], source: str, bad: list[str]) -> None:
    if isinstance(obj, dict):
        etype = obj.get("type")
        if isinstance(etype, str) and etype.isupper() and "_" in etype:
            if etype not in valid_codes:
                bad.append(f"  {source}: unknown effect type \"{etype}\"")
        for v in obj.values():
            _scan_effects_in_json(v, valid_codes, source, bad)
    elif isinstance(obj, list):
        for item in obj:
            _scan_effects_in_json(item, valid_codes, source, bad)


# ── Check 6: Store dispatch action coverage ──────────────────────────────────

def check_store_dispatch() -> tuple[str, list[str]]:
    store_file = ROOT / "scripts" / "merlin" / "merlin_store.gd"
    if not store_file.exists():
        return FAIL, ["merlin_store.gd not found"]
    text = store_file.read_text(encoding="utf-8", errors="replace")

    # Extract action types from the match statement in _reduce()
    handled: set[str] = set()
    in_reduce = False
    for line in text.splitlines():
        if "func _reduce(" in line:
            in_reduce = True
            continue
        if in_reduce:
            # Stop at next func definition
            if re.match(r"^func\s+", line) and "_reduce" not in line:
                break
            m = re.match(r'\s+"(\w+)":', line)
            if m:
                handled.add(m.group(1))

    # Scan all files for dispatch({"type": "XXX"}) calls
    dispatch_pat = re.compile(r'dispatch\(\s*\{[^}]*"type"\s*:\s*"(\w+)"', re.DOTALL)
    # Also match dispatch({"type": VAR}) — skip those
    used: dict[str, set[str]] = {}
    for gd in _gd_files():
        if gd == store_file:
            continue
        try:
            src = gd.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for m in dispatch_pat.finditer(src):
            action = m.group(1)
            used.setdefault(action, set()).add(str(gd.relative_to(ROOT)))

    unhandled: list[str] = []
    for action, files in sorted(used.items()):
        if action not in handled:
            unhandled.append(f"  dispatch(\"{action}\") used in {', '.join(sorted(files))} — not in store match")
    if unhandled:
        return FAIL, unhandled
    return PASS, [f"{len(handled)} actions handled, {len(used)} action types dispatched — all covered"]


# ── Runner ────────────────────────────────────────────────────────────────────

CHECKS = [
    ("Autoload references", check_autoloads),
    ("class_name conflicts", check_class_names),
    ("Signal emit/connect", check_signals),
    ("MerlinConstants usage", check_constants_usage),
    ("Effect types in cards", check_effect_types),
    ("Store dispatch actions", check_store_dispatch),
]

ICONS = {PASS: "+", WARN: "~", FAIL: "!"}


def main() -> int:
    print("=" * 60)
    print("  M.E.R.L.I.N. Integration Check")
    print(f"  Root: {ROOT}")
    print("=" * 60)
    results: list[tuple[str, str]] = []
    for label, fn in CHECKS:
        status, details = fn()
        results.append((label, status))
        icon = ICONS[status]
        print(f"\n[{icon}] {label}: {status}")
        for d in details:
            print(d)

    print("\n" + "=" * 60)
    counts = {s: sum(1 for _, r in results if r == s) for s in (PASS, WARN, FAIL)}
    total = len(results)
    score = counts[PASS] / total * 100 if total else 0
    print(f"  Score: {counts[PASS]}/{total} PASS, {counts[WARN]} WARN, {counts[FAIL]} FAIL ({score:.0f}%)")
    print("=" * 60)
    return 1 if counts[FAIL] > 0 else 0


if __name__ == "__main__":
    sys.exit(main())

"""Migrate MerlinVisual.PALETTE references to CRT_PALETTE across all GDScript files.

Key rename mapping: PALETTE keys that don't exist in CRT_PALETTE get renamed.
Keys that exist in both palettes only need the palette reference changed.
"""

import re
import os
import sys
from pathlib import Path

# Keys that need both palette change AND key rename
# Order: longer keys first to avoid partial matches
KEY_RENAMES = [
    # paper variants (longer first!)
    ("paper_warm", "bg_panel"),
    ("paper_dark", "bg_dark"),
    ("paper", "bg_panel"),
    # ink variants (longer first!)
    ("ink_faded", "border"),
    ("ink_soft", "phosphor_dim"),
    ("ink", "phosphor"),
    # accent variants (longer first!)
    ("accent_glow", "phosphor_glow"),
    ("accent_soft", "amber_dim"),
    ("accent", "amber"),
    # celtic variants (longer first!)
    ("celtic_gold", "amber_bright"),
    ("celtic_brown", "amber_dim"),
    ("celtic_green", "phosphor_dim"),
    ("celtic_red", "danger"),
    ("celtic_purple", "cyan"),
]

# Keys that exist in BOTH palettes (same name, different values)
# These only need PALETTE -> CRT_PALETTE, no key rename
SAME_KEYS = [
    "shadow", "line", "mist", "danger", "success", "warning",
    "souffle", "souffle_full", "ogham_glow", "bestiole",
    "inactive", "inactive_dark",
    "event_today", "event_past", "locked",
    "block", "block_alt",
    "eye_cyan", "eye_white", "eye_deep", "eye_outer", "eye_bright",
    "slit_glow",
    "choice_normal", "choice_hover", "choice_selected",
    "reward_bg", "reward_border",
    "llm_bg", "llm_bg_hover", "llm_text", "llm_success", "llm_warning", "llm_error",
    "bg_deep", "bg_dark", "bg_panel", "bg_highlight",
    "phosphor", "phosphor_dim", "phosphor_bright", "phosphor_glow",
    "amber", "amber_dim", "amber_bright",
    "cyan", "cyan_dim",
    "border", "border_bright", "scanline",
]

# Special fixes for broken keys (reference non-existent PALETTE keys)
BROKEN_KEY_FIXES = {
    # biome_radial.gd uses PALETTE["gbc_*"] which don't exist
    'PALETTE["gbc_dark_0"]': 'GBC["black"]',
    'PALETTE["gbc_dark_1"]': 'GBC["dark_gray"]',
    'PALETTE["gbc_dark_2"]': 'GBC["gray"]',
    'PALETTE["gbc_mid_1"]': 'GBC["light_gray"]',
    'PALETTE["gbc_mid_2"]': 'GBC["cream"]',
    'PALETTE["gbc_light_0"]': 'GBC["white"]',
    'PALETTE["gbc_light_1"]': 'GBC["cream"]',
    # hub_hotspot.gd uses PALETTE["text_light"] which doesn't exist
    'PALETTE["text_light"]': 'CRT_PALETTE["phosphor"]',
    # pixel_art_showcase.gd uses non-existent keys via .get()
    '.PALETTE.get("bg_mid"': '.CRT_PALETTE.get("bg_panel"',
    '.PALETTE.get("ink_gold"': '.CRT_PALETTE.get("amber"',
    '.PALETTE.get("ink_warm"': '.CRT_PALETTE.get("phosphor_dim"',
}

# Files to skip (archive, merlin_visual.gd itself)
SKIP_PATTERNS = ["archive/", "merlin_visual.gd"]

def should_skip(filepath: str) -> bool:
    normalized = filepath.replace("\\", "/")
    return any(p in normalized for p in SKIP_PATTERNS)


def migrate_line(line: str) -> str:
    """Apply all migrations to a single line."""
    original = line

    # Step 0: Fix broken key references first
    for old, new in BROKEN_KEY_FIXES.items():
        if old in line:
            line = line.replace(f"MerlinVisual.{old}", f"MerlinVisual.{new}")

    # Step 1: Rename keys (dot notation) — order matters (longer first)
    for old_key, new_key in KEY_RENAMES:
        # Dot notation: PALETTE.paper_warm → CRT_PALETTE.bg_panel
        line = line.replace(
            f"MerlinVisual.PALETTE.{old_key}",
            f"MerlinVisual.CRT_PALETTE.{new_key}"
        )
        # Bracket notation: PALETTE["paper_warm"] → CRT_PALETTE["bg_panel"]
        line = line.replace(
            f'MerlinVisual.PALETTE["{old_key}"]',
            f'MerlinVisual.CRT_PALETTE["{new_key}"]'
        )
        # .get() notation: PALETTE.get("paper", ...) → CRT_PALETTE.get("bg_panel", ...)
        line = line.replace(
            f'MerlinVisual.PALETTE.get("{old_key}"',
            f'MerlinVisual.CRT_PALETTE.get("{new_key}"'
        )

    # Step 2: Replace remaining PALETTE → CRT_PALETTE (same-named keys)
    # This catches all remaining dot/bracket/get patterns
    line = line.replace("MerlinVisual.PALETTE", "MerlinVisual.CRT_PALETTE")

    return line


def migrate_file(filepath: str, dry_run: bool = False) -> int:
    """Migrate a single file. Returns count of changed lines."""
    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    changed = 0
    new_lines = []
    for i, line in enumerate(lines):
        new_line = migrate_line(line)
        if new_line != line:
            changed += 1
            if dry_run:
                print(f"  L{i+1}: {line.rstrip()}")
                print(f"    -> {new_line.rstrip()}")
        new_lines.append(new_line)

    if changed > 0 and not dry_run:
        with open(filepath, "w", encoding="utf-8", newline="\n") as f:
            f.writelines(new_lines)

    return changed


def main():
    dry_run = "--dry-run" in sys.argv
    project_root = Path("c:/Users/PGNK2128/Godot-MCP")
    scripts_dir = project_root / "scripts"

    if dry_run:
        print("=== DRY RUN — no files will be modified ===\n")

    total_files = 0
    total_changes = 0

    for gd_file in sorted(scripts_dir.rglob("*.gd")):
        filepath = str(gd_file)
        if should_skip(filepath):
            continue

        # Check if file has any PALETTE references
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        if "MerlinVisual.PALETTE" not in content:
            continue

        rel_path = gd_file.relative_to(project_root)
        changes = migrate_file(filepath, dry_run)
        if changes > 0:
            print(f"{'[DRY] ' if dry_run else ''}  {rel_path}: {changes} lines migrated")
            total_files += 1
            total_changes += changes

    print(f"\n{'[DRY RUN] ' if dry_run else ''}Total: {total_changes} lines in {total_files} files")


if __name__ == "__main__":
    main()

"""
Batch Asset Generator — Orchestrates Blender headless runs for M.E.R.L.I.N.
Usage: python batch_generate.py [--wave N] [--dry-run] [--biome X] [--category Y]

Waves:
  1: Vegetation (all biomes)     ~720 assets
  2: Rocks & terrain             ~480 assets
  3: Structures                  ~240 assets
  4: Props & decorations         ~400 assets
  5: Characters & creatures      ~170 assets
  6: Collectibles & oghams       ~143 assets
  7: Water features              ~79 assets
  all: Everything                ~2232 assets
"""

import subprocess
import os
import sys
import json
import time

BLENDER_PATH = r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
GENERATOR_SCRIPT = os.path.join(SCRIPT_DIR, "blender_n64_generator.py")
PROJECT_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
OUTPUT_BASE = os.path.join(PROJECT_ROOT, "Assets", "n64_assets")

BIOMES = [
    "foret_broceliande", "landes_bruyere", "cotes_sauvages",
    "villages_celtes", "cercles_pierres", "marais_korrigans",
    "collines_dolmens", "iles_mystiques", "shared",
]

# Wave definitions: (category, batch_per_biome, seed_offset)
WAVES = {
    1: [("vegetation", 10, 100)],
    2: [("rocks", 8, 200)],
    3: [("structures", 4, 300)],
    4: [("props", 6, 400)],
    5: [("characters", 3, 500)],
    6: [("collectibles", 4, 600)],
    7: [("water", 3, 700)],
}


def run_blender_batch(category, biome, batch_size, seed, dry_run=False):
    cmd = [
        BLENDER_PATH, "--background", "--python", GENERATOR_SCRIPT,
        "--", "--category", category, "--biome", biome,
        "--batch", str(batch_size), "--seed", str(seed),
        "--output", OUTPUT_BASE,
    ]

    if dry_run:
        print(f"  [DRY-RUN] blender --background --python ... --category {category} --biome {biome} --batch {batch_size}")
        return True

    print(f"  Running: {category}/{biome} x{batch_size} (seed={seed})")
    t0 = time.time()

    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=300,
            cwd=SCRIPT_DIR,
        )
        elapsed = time.time() - t0

        if result.returncode == 0:
            # Count generated files
            out_dir = os.path.join(OUTPUT_BASE, category, biome)
            glb_count = len([f for f in os.listdir(out_dir) if f.endswith('.glb')]) if os.path.isdir(out_dir) else 0
            print(f"    OK ({elapsed:.1f}s) — {glb_count} .glb files in {out_dir}")
            return True
        else:
            print(f"    FAIL ({elapsed:.1f}s)")
            if result.stderr:
                for line in result.stderr.strip().split('\n')[-5:]:
                    print(f"      {line}")
            return False
    except subprocess.TimeoutExpired:
        print(f"    TIMEOUT (>300s)")
        return False
    except FileNotFoundError:
        print(f"    ERROR: Blender not found at {BLENDER_PATH}")
        return False


def run_wave(wave_num, biomes_filter=None, dry_run=False):
    wave_defs = WAVES.get(wave_num)
    if not wave_defs:
        print(f"Unknown wave: {wave_num}")
        return

    biomes = biomes_filter if biomes_filter else BIOMES
    total = sum(batch * len(biomes) for _, batch, _ in wave_defs)

    print(f"\n{'='*60}")
    print(f"WAVE {wave_num}: {', '.join(cat for cat, _, _ in wave_defs)}")
    print(f"Biomes: {len(biomes)} | Estimated assets: {total}")
    print(f"{'='*60}\n")

    success = 0
    fail = 0

    for category, batch_per_biome, seed_offset in wave_defs:
        for i, biome in enumerate(biomes):
            seed = seed_offset + i * 100
            ok = run_blender_batch(category, biome, batch_per_biome, seed, dry_run)
            if ok:
                success += 1
            else:
                fail += 1

    print(f"\nWave {wave_num} complete: {success} OK, {fail} FAIL")
    return fail == 0


def count_existing_assets():
    total = 0
    by_category = {}
    for category in os.listdir(OUTPUT_BASE) if os.path.isdir(OUTPUT_BASE) else []:
        cat_dir = os.path.join(OUTPUT_BASE, category)
        if not os.path.isdir(cat_dir):
            continue
        cat_count = 0
        for biome in os.listdir(cat_dir):
            biome_dir = os.path.join(cat_dir, biome)
            if os.path.isdir(biome_dir):
                glbs = [f for f in os.listdir(biome_dir) if f.endswith('.glb')]
                cat_count += len(glbs)
        by_category[category] = cat_count
        total += cat_count
    return total, by_category


def main():
    args = sys.argv[1:]

    dry_run = "--dry-run" in args
    wave_num = None
    biome_filter = None
    category_filter = None

    i = 0
    while i < len(args):
        if args[i] == "--wave" and i + 1 < len(args):
            wave_num = args[i + 1]
            i += 2
        elif args[i] == "--biome" and i + 1 < len(args):
            biome_filter = [args[i + 1]]
            i += 2
        elif args[i] == "--category" and i + 1 < len(args):
            category_filter = args[i + 1]
            i += 2
        elif args[i] == "--status":
            total, by_cat = count_existing_assets()
            print(f"\nN64 Assets Status: {total} total .glb files")
            for cat, count in sorted(by_cat.items()):
                print(f"  {cat}: {count}")
            print(f"\nTarget: 2000+  |  Remaining: ~{max(0, 2000 - total)}")
            return
        else:
            i += 1

    if wave_num is None:
        print("Usage: python batch_generate.py --wave <1-7|all> [--biome X] [--dry-run] [--status]")
        print("\nWaves:")
        for w, defs in WAVES.items():
            cats = ', '.join(c for c, _, _ in defs)
            batches = sum(b * len(BIOMES) for _, b, _ in defs)
            print(f"  {w}: {cats} (~{batches} assets)")
        total_all = sum(sum(b * len(BIOMES) for _, b, _ in defs) for defs in WAVES.values())
        print(f"  all: everything (~{total_all} assets)")
        return

    if wave_num == "all":
        for w in sorted(WAVES.keys()):
            run_wave(w, biome_filter, dry_run)
    else:
        run_wave(int(wave_num), biome_filter, dry_run)

    # Final status
    total, by_cat = count_existing_assets()
    print(f"\n{'='*60}")
    print(f"TOTAL ASSETS: {total} .glb files")
    for cat, count in sorted(by_cat.items()):
        print(f"  {cat}: {count}")
    print(f"Target: 2000+  |  Remaining: ~{max(0, 2000 - total)}")
    print(f"{'='*60}")


if __name__ == "__main__":
    main()

"""
Generate full scene batch: 3 variants per category for BK Showcase scene.
Run: blender --background --python generate_scene_batch.py
"""
import bpy
import sys
import os
import json
import traceback

script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, script_dir)

import importlib
gen_mod = importlib.import_module("blender_n64_generator")

BIOME = "foret_broceliande"
OUTPUT_BASE = os.path.normpath(os.path.join(script_dir, "..", "..", "Assets", "bk_assets"))
VARIANTS_PER_TYPE = 3

ASSET_DEFS = [
    ("vegetation",   "tree_bk"),
    ("rocks",        "rock_bk"),
    ("structures",   "structure_bk"),
    ("megaliths",    "megalith_bk"),
    ("collectibles", "collectible_bk"),
    ("characters",   "creature_bk"),
    ("props",        "bridge_bk"),
]

results = []
total = len(ASSET_DEFS) * VARIANTS_PER_TYPE

for category, gen_name in ASSET_DEFS:
    out_dir = os.path.join(OUTPUT_BASE, category, BIOME)
    os.makedirs(out_dir, exist_ok=True)

    gen_func = gen_mod.GENERATORS[category][gen_name]
    budget = gen_mod.TRI_BUDGETS.get(gen_name, 300)

    for v in range(VARIANTS_PER_TYPE):
        gen_mod.clear_scene()

        try:
            obj = gen_func(BIOME, v)

            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')

            tris = gen_mod.count_tris(obj)

            filename = f"{gen_name}_{BIOME}_{v:04d}.glb"
            filepath = os.path.join(out_dir, filename)

            gen_mod.export_glb(obj, filepath, gen_name=gen_name)

            file_size = os.path.getsize(filepath) if os.path.exists(filepath) else 0
            status = "OK" if tris <= budget else f"OVER ({tris}/{budget})"
            print(f"  [{len(results)+1}/{total}] {gen_name} v{v}: {tris} tris [{status}], {round(file_size/1024,1)}KB")

            results.append({
                "name": filename,
                "path": f"bk_assets/{category}/{BIOME}/{filename}",
                "category": category,
                "biome": BIOME,
                "generator": gen_name,
                "variant": v,
                "tris": tris,
                "budget": budget,
                "sizeKb": round(file_size / 1024, 1),
            })

        except Exception as e:
            print(f"  [ERROR] {gen_name} v{v}: {e}")
            traceback.print_exc()

# Write combined manifest
manifest_path = os.path.join(OUTPUT_BASE, "scene_manifest.json")
with open(manifest_path, "w") as f:
    json.dump(results, f, indent=2)
print(f"\n=== Scene batch: {len(results)}/{total} assets generated ===")
print(f"Manifest: {manifest_path}")

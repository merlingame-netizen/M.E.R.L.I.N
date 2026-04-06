"""
Generate test batch: one asset per category for BK art style validation.
Run: blender --background --python generate_test_batch.py
"""
import bpy
import sys
import os

# Add parent to path so we can import the generator
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, script_dir)

# Import after path setup
import importlib
gen_mod = importlib.import_module("blender_n64_generator")

BIOME = "foret_broceliande"
OUTPUT_BASE = os.path.normpath(os.path.join(script_dir, "..", "..", "Assets", "bk_assets"))

# One asset per generator
TEST_ASSETS = [
    ("vegetation",   "tree_bk",        0),
    ("rocks",        "rock_bk",        0),
    ("structures",   "structure_bk",   0),
    ("megaliths",    "megalith_bk",    0),
    ("collectibles", "collectible_bk", 0),
    ("characters",   "creature_bk",    0),
    ("props",        "bridge_bk",      0),
]

results = []

for category, gen_name, variant in TEST_ASSETS:
    out_dir = os.path.join(OUTPUT_BASE, category, BIOME)
    os.makedirs(out_dir, exist_ok=True)

    gen_mod.clear_scene()

    gen_func = gen_mod.GENERATORS[category][gen_name]

    try:
        obj = gen_func(BIOME, variant)

        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')

        tris = gen_mod.count_tris(obj)
        budget = gen_mod.TRI_BUDGETS.get(gen_name, 300)

        filename = f"{gen_name}_{BIOME}_0000.glb"
        filepath = os.path.join(out_dir, filename)

        gen_mod.export_glb(obj, filepath, gen_name=gen_name)

        file_size = os.path.getsize(filepath) if os.path.exists(filepath) else 0
        status = "OK" if tris <= budget else f"OVER ({tris}/{budget})"
        print(f"  {gen_name}: {tris} tris [{status}], {round(file_size/1024,1)}KB -> {filepath}")
        results.append((gen_name, tris, budget, filepath))

    except Exception as e:
        print(f"  [ERROR] {gen_name}: {e}")
        import traceback
        traceback.print_exc()

print(f"\n=== Test batch: {len(results)}/7 assets generated ===")
for name, tris, budget, path in results:
    print(f"  {name}: {tris}/{budget} tris")

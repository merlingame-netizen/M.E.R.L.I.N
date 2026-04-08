"""Rebuild all _manifest.json files by scanning actual .glb files on disk."""
import os
import json
import struct

ASSETS_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))), "Assets", "n64_assets")


def estimate_tris_from_glb(filepath):
    """Estimate triangle count from GLB file size (rough heuristic)."""
    try:
        size = os.path.getsize(filepath)
        # GLB overhead ~1-2KB, ~100 bytes per tri with vertex colors
        return max(4, (size - 1500) // 80)
    except Exception:
        return 0


def rebuild_all():
    total_assets = 0
    total_manifests = 0

    for category in sorted(os.listdir(ASSETS_ROOT)):
        cat_dir = os.path.join(ASSETS_ROOT, category)
        if not os.path.isdir(cat_dir):
            continue

        for biome in sorted(os.listdir(cat_dir)):
            biome_dir = os.path.join(cat_dir, biome)
            if not os.path.isdir(biome_dir):
                continue

            glb_files = sorted([f for f in os.listdir(biome_dir) if f.endswith('.glb')])
            if not glb_files:
                continue

            assets = []
            for f in glb_files:
                filepath = os.path.join(biome_dir, f)
                size_kb = round(os.path.getsize(filepath) / 1024, 1)
                tris = estimate_tris_from_glb(filepath)

                # Parse generator name and variant from filename
                # Format: generator_biome_variant.glb
                name_no_ext = f.replace('.glb', '')
                parts = name_no_ext.rsplit('_', 1)
                variant = 0
                try:
                    variant = int(parts[-1])
                except (ValueError, IndexError):
                    pass

                # Extract generator: remove biome suffix and variant
                generator = name_no_ext
                if biome in generator:
                    generator = generator.split(f'_{biome}')[0]

                assets.append({
                    "name": f,
                    "category": category,
                    "biome": biome,
                    "generator": generator,
                    "variant": variant,
                    "tris": tris,
                    "file_size_kb": size_kb,
                })

            manifest = {
                "category": category,
                "biome": biome,
                "count": len(assets),
                "assets": assets,
            }

            manifest_path = os.path.join(biome_dir, "_manifest.json")
            with open(manifest_path, 'w') as fp:
                json.dump(manifest, fp, indent=2)

            total_assets += len(assets)
            total_manifests += 1
            print(f"  {category}/{biome}: {len(assets)} assets")

    print(f"\nRebuilt {total_manifests} manifests, {total_assets} total assets")


if __name__ == "__main__":
    rebuild_all()

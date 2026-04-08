"""
Blender headless thumbnail renderer for N64 assets.
Run: blender --background --python render_thumbnails.py -- [--limit N]
Generates 128x128 PNG thumbnails next to each .glb file.
"""
import bpy
import os
import sys
import glob
import math

def parse_args():
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    args = {"limit": 0, "force": False}
    i = 0
    while i < len(argv):
        if argv[i] == "--limit" and i+1 < len(argv):
            args["limit"] = int(argv[i+1]); i += 2
        elif argv[i] == "--force":
            args["force"] = True; i += 1
        else:
            i += 1
    return args

def setup_scene():
    """Setup a clean scene with N64-style lighting for thumbnail rendering."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

    # Camera
    bpy.ops.object.camera_add(location=(1.8, -1.8, 1.2))
    cam = bpy.context.active_object
    cam.name = "ThumbCam"
    cam.rotation_euler = (math.radians(65), 0, math.radians(45))
    cam.data.lens = 35
    bpy.context.scene.camera = cam

    # Lights
    bpy.ops.object.light_add(type='SUN', location=(3, -2, 5))
    sun = bpy.context.active_object
    sun.data.energy = 2.0
    sun.data.color = (1.0, 0.95, 0.85)

    bpy.ops.object.light_add(type='POINT', location=(-2, 1, 3))
    fill = bpy.context.active_object
    fill.data.energy = 50.0
    fill.data.color = (0.7, 0.8, 1.0)

    # World background
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.03, 0.05, 0.03, 1.0)
        bg.inputs[1].default_value = 1.0

    # Render settings
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'ShaderNodeEeveeSpecular') else 'BLENDER_EEVEE'
    scene.render.resolution_x = 192
    scene.render.resolution_y = 192
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

    return cam

def render_glb(glb_path, output_path, cam):
    """Import a GLB, frame it, render thumbnail."""
    # Clear imported objects
    bpy.ops.object.select_all(action='DESELECT')
    existing = set(bpy.data.objects.keys())

    # Import
    bpy.ops.import_scene.gltf(filepath=glb_path)

    # Find new objects
    new_objs = [bpy.data.objects[n] for n in bpy.data.objects.keys() if n not in existing]
    if not new_objs:
        return False

    # Compute bounding box of all new objects
    from mathutils import Vector
    min_co = Vector((999, 999, 999))
    max_co = Vector((-999, -999, -999))
    for obj in new_objs:
        if obj.type == 'MESH':
            for v in obj.bound_box:
                world_co = obj.matrix_world @ Vector(v)
                min_co.x = min(min_co.x, world_co.x)
                min_co.y = min(min_co.y, world_co.y)
                min_co.z = min(min_co.z, world_co.z)
                max_co.x = max(max_co.x, world_co.x)
                max_co.y = max(max_co.y, world_co.y)
                max_co.z = max(max_co.z, world_co.z)

    center = (min_co + max_co) / 2
    size = max_co - min_co
    max_dim = max(size.x, size.y, size.z, 0.01)

    # Position camera to frame the object
    dist = max_dim * 2.5
    cam.location = (center.x + dist * 0.6, center.y - dist * 0.6, center.z + dist * 0.5)

    direction = center - cam.location
    cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

    # Render
    bpy.context.scene.render.filepath = output_path
    bpy.ops.render.render(write_still=True)

    # Remove imported objects
    for obj in new_objs:
        bpy.data.objects.remove(obj, do_unlink=True)

    return True

def main():
    args = parse_args()
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(os.path.dirname(script_dir))
    assets_root = os.path.join(project_root, "Assets", "n64_assets")

    glb_files = sorted(glob.glob(os.path.join(assets_root, "**", "*.glb"), recursive=True))
    total = len(glb_files)

    if args["limit"] > 0:
        glb_files = glb_files[:args["limit"]]

    # Filter out already rendered (unless --force)
    if not args["force"]:
        glb_files = [f for f in glb_files if not os.path.exists(f.replace('.glb', '.png'))]

    print(f"\n{'='*50}")
    print(f"Thumbnail Renderer — {len(glb_files)} to render (of {total} total)")
    print(f"{'='*50}\n")

    if not glb_files:
        print("All thumbnails already exist. Use --force to re-render.")
        return

    cam = setup_scene()
    rendered = 0
    errors = 0

    for i, glb_path in enumerate(glb_files):
        png_path = glb_path.replace('.glb', '.png')
        rel = os.path.relpath(glb_path, assets_root)

        try:
            ok = render_glb(glb_path, png_path, cam)
            if ok:
                rendered += 1
                if (rendered % 25 == 0) or rendered <= 5:
                    print(f"  [{rendered}/{len(glb_files)}] {rel}")
            else:
                errors += 1
        except Exception as e:
            errors += 1
            print(f"  [ERROR] {rel}: {e}")

    print(f"\nDone: {rendered} rendered, {errors} errors")

if __name__ == "__main__":
    main()

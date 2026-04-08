"""
Blender headless thumbnail renderer for Trellis v16 assets.
Run: blender --background --python render_trellis_thumbnails.py
Generates 256x256 PNG thumbnails next to each .glb file.
"""
import bpy
import os
import sys
import math
import glob


TRELLIS_DIR = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "Assets", "trellis", "trellis_output_v16"
))
THUMB_SIZE = 256


def clear_scene() -> None:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for c in bpy.data.collections:
        bpy.data.collections.remove(c)
    for m in bpy.data.meshes:
        bpy.data.meshes.remove(m)
    for mat in bpy.data.materials:
        bpy.data.materials.remove(mat)


def setup_render() -> None:
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE_NEXT' if hasattr(bpy.types, 'ShaderNodeEeveeSpecular') else 'BLENDER_EEVEE'
    scene.render.resolution_x = THUMB_SIZE
    scene.render.resolution_y = THUMB_SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'

    # Dark background (match viewer)
    scene.world = bpy.data.worlds.new("ThumbWorld")
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.016, 0.024, 0.016, 1.0)
        bg.inputs[1].default_value = 0.3


def setup_camera() -> bpy.types.Object:
    bpy.ops.object.camera_add(location=(0, 0, 0))
    cam = bpy.context.active_object
    cam.name = "ThumbCam"
    cam.data.lens = 35
    cam.data.clip_start = 0.01
    cam.data.clip_end = 100
    bpy.context.scene.camera = cam
    return cam


def setup_lighting() -> None:
    # Key light
    bpy.ops.object.light_add(type='SUN', location=(3, -2, 5))
    key = bpy.context.active_object
    key.name = "KeyLight"
    key.data.energy = 3.0
    key.data.color = (1.0, 0.98, 0.95)
    key.rotation_euler = (math.radians(45), math.radians(15), math.radians(30))

    # Fill light
    bpy.ops.object.light_add(type='SUN', location=(-2, 3, 2))
    fill = bpy.context.active_object
    fill.name = "FillLight"
    fill.data.energy = 1.0
    fill.data.color = (0.7, 0.8, 1.0)
    fill.rotation_euler = (math.radians(60), math.radians(-30), math.radians(-45))

    # Rim light
    bpy.ops.object.light_add(type='SUN', location=(-1, -3, 3))
    rim = bpy.context.active_object
    rim.name = "RimLight"
    rim.data.energy = 1.5
    rim.data.color = (0.6, 1.0, 0.7)
    rim.rotation_euler = (math.radians(30), math.radians(60), math.radians(150))


def frame_camera_on_object(cam: bpy.types.Object, obj: bpy.types.Object) -> None:
    """Position camera to frame the object nicely (3/4 view)."""
    # Compute bounding box in world space
    bbox_corners = [obj.matrix_world @ bpy.mathutils.Vector(corner) for corner in obj.bound_box] if hasattr(bpy, 'mathutils') else []

    # Fallback: use dimensions
    dims = obj.dimensions
    max_dim = max(dims.x, dims.y, dims.z, 0.01)
    center = obj.location.copy()

    # Try to get actual center from bounding box
    if bbox_corners:
        from mathutils import Vector
        bbox_min = Vector((min(c.x for c in bbox_corners), min(c.y for c in bbox_corners), min(c.z for c in bbox_corners)))
        bbox_max = Vector((max(c.x for c in bbox_corners), max(c.y for c in bbox_corners), max(c.z for c in bbox_corners)))
        center = (bbox_min + bbox_max) / 2
        dims = bbox_max - bbox_min
        max_dim = max(dims.x, dims.y, dims.z, 0.01)

    # 3/4 view angle
    dist = max_dim * 2.2
    angle_h = math.radians(35)
    angle_v = math.radians(25)

    cam.location.x = center.x + dist * math.cos(angle_v) * math.sin(angle_h)
    cam.location.y = center.y - dist * math.cos(angle_v) * math.cos(angle_h)
    cam.location.z = center.z + dist * math.sin(angle_v)

    # Point camera at center
    direction = center - cam.location
    rot_quat = direction.to_track_quat('-Z', 'Y')
    cam.rotation_euler = rot_quat.to_euler()


def import_glb(filepath: str) -> bpy.types.Object | None:
    """Import a GLB file and return the root object."""
    before = set(bpy.data.objects)
    try:
        bpy.ops.import_scene.gltf(filepath=filepath)
    except Exception as e:
        print(f"  ERROR importing {filepath}: {e}")
        return None

    after = set(bpy.data.objects)
    new_objects = after - before

    if not new_objects:
        return None

    # Find root (parent-less) object
    roots = [o for o in new_objects if o.parent is None or o.parent not in new_objects]
    if roots:
        return roots[0]
    return list(new_objects)[0]


def render_thumbnail(glb_path: str, cam: bpy.types.Object) -> bool:
    """Render a single GLB to a PNG thumbnail."""
    name = os.path.splitext(os.path.basename(glb_path))[0]
    out_path = os.path.join(os.path.dirname(glb_path), name + ".png")

    if os.path.exists(out_path):
        print(f"  SKIP {name} (thumbnail exists)")
        return True

    # Clean meshes from previous import
    for obj in list(bpy.data.objects):
        if obj.type == 'MESH' or obj.type == 'EMPTY':
            if obj.name not in ("ThumbCam", "KeyLight", "FillLight", "RimLight"):
                bpy.data.objects.remove(obj, do_unlink=True)

    # Import
    root = import_glb(glb_path)
    if not root:
        print(f"  FAIL {name} (import failed)")
        return False

    # Frame camera
    frame_camera_on_object(cam, root)

    # Render
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)

    print(f"  OK {name} -> {out_path}")
    return True


def main() -> None:
    print(f"\n=== Trellis Thumbnail Renderer ===")
    print(f"Directory: {TRELLIS_DIR}")

    glb_files = sorted(glob.glob(os.path.join(TRELLIS_DIR, "*.glb")))
    print(f"Found {len(glb_files)} GLB files\n")

    if not glb_files:
        print("No GLB files found!")
        return

    clear_scene()
    setup_render()
    cam = setup_camera()
    setup_lighting()

    success = 0
    for glb in glb_files:
        if render_thumbnail(glb, cam):
            success += 1

    print(f"\n=== Done: {success}/{len(glb_files)} thumbnails rendered ===")


if __name__ == "__main__":
    main()

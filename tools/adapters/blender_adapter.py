"""Blender CLI Bridge — Headless 3D asset generation for M.E.R.L.I.N."""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

_HERE = Path(__file__).resolve().parent
_ROOT = _HERE.parent
for _p in (_ROOT, _HERE):
    _s = str(_p)
    if _s not in sys.path:
        sys.path.insert(0, _s)

from adapters.base_adapter import BaseAdapter  # noqa: E402

# ── Constants ───────────────────────────────────────────────────────────────

BLENDER_EXE = r"C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"
PROJECT_DIR = Path(__file__).resolve().parent.parent.parent
ASSETS_DIR = PROJECT_DIR / "assets" / "3d_models"
SCRIPTS_DIR = PROJECT_DIR / "tools" / "blender_scripts"


# ── Helpers ─────────────────────────────────────────────────────────────────

def _ensure_dirs() -> None:
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    SCRIPTS_DIR.mkdir(parents=True, exist_ok=True)


def _run_blender_script(
    script_content: str,
    blend_file: str | None = None,
    timeout: int = 120,
) -> dict:
    """Execute a Python script in Blender headless mode."""
    _ensure_dirs()

    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".py", delete=False, dir=str(SCRIPTS_DIR)
    ) as f:
        f.write(script_content)
        script_path = f.name

    try:
        cmd = [BLENDER_EXE, "--background"]
        if blend_file:
            cmd.append(blend_file)
        cmd.extend(["--python", script_path])

        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, cwd=str(PROJECT_DIR)
        )

        # Parse JSON output if present (scripts print JSON to stdout)
        output = result.stdout
        json_result = None
        for line in output.split("\n"):
            line = line.strip()
            if line.startswith('{"') or line.startswith("["):
                try:
                    json_result = json.loads(line)
                except json.JSONDecodeError:
                    pass

        return {
            "status": "ok" if result.returncode == 0 else "error",
            "returncode": result.returncode,
            "stdout": output[-2000:] if len(output) > 2000 else output,
            "stderr": result.stderr[-1000:] if len(result.stderr) > 1000 else result.stderr,
            "data": json_result,
            "script_path": script_path,
        }
    except subprocess.TimeoutExpired:
        return {"status": "timeout", "timeout": timeout}
    finally:
        try:
            os.unlink(script_path)
        except OSError:
            pass


# ── Blender script templates ───────────────────────────────────────────────

def _script_version() -> str:
    return '''
import bpy, sys, json
info = {
    "version": ".".join(str(x) for x in bpy.app.version),
    "build_date": bpy.app.build_date.decode(),
    "python": sys.version.split()[0],
    "cycles": hasattr(bpy.types, "CyclesRenderSettings"),
    "eevee": True
}
print(json.dumps(info))
'''


def _script_terrain(
    name: str, size_x: float, size_y: float, subdivisions: int,
    height_scale: float, seed: int, style: str, output: str,
) -> str:
    return f'''
import bpy, bmesh, json, math, random
from mathutils import Vector, noise

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.mesh.primitive_grid_add(x_subdivisions={subdivisions}, y_subdivisions={subdivisions}, size=1)
obj = bpy.context.active_object
obj.name = "{name}"
obj.scale = ({size_x}, {size_y}, 1)
bpy.ops.object.transform_apply(scale=True)

random.seed({seed})
for v in obj.data.vertices:
    x, y = v.co.x / {size_x}, v.co.y / {size_y}
    if "{style}" == "cliff":
        h = 0.0
        if y > -0.2:
            h = 1.0 - max(0, (y + 0.2)) * 3.0
            h = max(0, h)
        h += noise.noise(Vector((x * 4, y * 4, 0))) * 0.15
        h *= {height_scale}
        if abs(y + 0.2) < 0.15:
            h += random.uniform(-0.3, 0.3) * {height_scale}
    elif "{style}" == "hills":
        h = noise.noise(Vector((x * 3, y * 3, {seed} * 0.1))) * 0.5
        h += noise.noise(Vector((x * 7, y * 7, {seed} * 0.2))) * 0.2
        h *= {height_scale}
    elif "{style}" == "island":
        dist = math.sqrt(x*x + y*y)
        h = max(0, 1.0 - dist * 2.5) * {height_scale}
        h += noise.noise(Vector((x * 5, y * 5, 0))) * 0.3 * {height_scale}
    else:
        h = noise.noise(Vector((x * 5, y * 5, 0))) * 0.1 * {height_scale}
    v.co.z = h

bpy.ops.object.shade_flat()

mat = bpy.data.materials.new("{name}_mat")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Base Color"].default_value = (0.35, 0.45, 0.25, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    bsdf.inputs["Metallic"].default_value = 0.0
obj.data.materials.append(mat)

mod = obj.modifiers.new("Decimate", 'DECIMATE')
mod.ratio = 0.6
bpy.ops.object.modifier_apply(modifier="Decimate")
bpy.ops.object.shade_flat()

import os
os.makedirs(os.path.dirname(r"{output}"), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=r"{output}", export_format='GLB',
    use_selection=True, export_apply=True
)
size = os.path.getsize(r"{output}")
print(json.dumps({{"status": "ok", "file": r"{output}", "size_bytes": size,
    "vertices": len(obj.data.vertices), "faces": len(obj.data.polygons)}}))
'''


def _script_tower(
    name: str, height: float, radius: float, segments: int,
    ruined: bool, output: str,
) -> str:
    return f'''
import bpy, bmesh, json, math, random
from mathutils import Vector

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

random.seed(42)
objects = []

bpy.ops.mesh.primitive_cylinder_add(
    vertices={segments}, radius={radius}, depth={height},
    location=(0, 0, {height/2})
)
tower = bpy.context.active_object
tower.name = "{name}"
objects.append(tower)

stone_mat = bpy.data.materials.new("stone")
stone_mat.use_nodes = True
bsdf = stone_mat.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Base Color"].default_value = (0.35, 0.33, 0.28, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.95
tower.data.materials.append(stone_mat)

window_mat = bpy.data.materials.new("window_dark")
window_mat.use_nodes = True
bsdf_w = window_mat.node_tree.nodes.get("Principled BSDF")
if bsdf_w:
    bsdf_w.inputs["Base Color"].default_value = (0.05, 0.04, 0.03, 1.0)
    bsdf_w.inputs["Roughness"].default_value = 1.0

for i in range(4):
    angle = (i / 4.0) * math.pi * 2 + 0.3
    h = {height} * (0.25 + i * 0.18)
    bpy.ops.mesh.primitive_cube_add(
        size=0.5,
        location=(math.cos(angle) * {radius} * 0.95, math.sin(angle) * {radius} * 0.95, h)
    )
    win = bpy.context.active_object
    win.scale = (0.4, 0.15, 0.6)
    win.rotation_euler.z = angle + math.pi/2
    win.data.materials.append(window_mat)
    objects.append(win)

if {ruined}:
    for i in range({segments}):
        if random.random() > 0.4:
            angle = (i / {segments}) * math.pi * 2
            h = random.uniform(0.5, 2.0)
            bpy.ops.mesh.primitive_cube_add(
                size=0.5,
                location=(
                    math.cos(angle) * {radius} * 0.85,
                    math.sin(angle) * {radius} * 0.85,
                    {height} + h * 0.5
                )
            )
            cren = bpy.context.active_object
            cren.scale = (0.4, 0.5, h)
            cren.rotation_euler = (
                random.uniform(-0.1, 0.1),
                random.uniform(-0.1, 0.1),
                angle
            )
            cren.data.materials.append(stone_mat)
            objects.append(cren)

    for i in range(8):
        angle = random.uniform(0, math.pi * 2)
        dist = random.uniform({radius} * 1.5, {radius} * 3.5)
        h = random.uniform({height} * 0.5, {height} * 1.2)
        size = random.uniform(0.2, 0.6)
        bpy.ops.mesh.primitive_cube_add(size=size, location=(
            math.cos(angle) * dist, math.sin(angle) * dist, h
        ))
        debris = bpy.context.active_object
        debris.rotation_euler = (random.uniform(0, 1), random.uniform(0, 1), random.uniform(0, 1))
        debris.data.materials.append(stone_mat)
        objects.append(debris)

moss_mat = bpy.data.materials.new("moss")
moss_mat.use_nodes = True
bsdf_m = moss_mat.node_tree.nodes.get("Principled BSDF")
if bsdf_m:
    bsdf_m.inputs["Base Color"].default_value = (0.18, 0.35, 0.12, 1.0)
    bsdf_m.inputs["Roughness"].default_value = 1.0

for i in range(6):
    angle = random.uniform(0, math.pi * 2)
    h = random.uniform(1, {height} * 0.7)
    bpy.ops.mesh.primitive_cube_add(size=0.3, location=(
        math.cos(angle) * {radius} * 1.02, math.sin(angle) * {radius} * 1.02, h
    ))
    moss = bpy.context.active_object
    moss.scale = (0.5, random.uniform(0.3, 1.5), random.uniform(0.3, 0.8))
    moss.rotation_euler.z = angle
    moss.data.materials.append(moss_mat)
    objects.append(moss)

bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = tower
bpy.ops.object.join()

bpy.ops.object.shade_flat()

mod = tower.modifiers.new("Decimate", 'DECIMATE')
mod.ratio = 0.7
bpy.ops.object.modifier_apply(modifier="Decimate")
bpy.ops.object.shade_flat()

import os
os.makedirs(os.path.dirname(r"{output}"), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=r"{output}", export_format='GLB',
    use_selection=True, export_apply=True
)
size = os.path.getsize(r"{output}")
verts = len(tower.data.vertices)
faces = len(tower.data.polygons)
print(json.dumps({{"status": "ok", "file": r"{output}", "size_bytes": size,
    "vertices": verts, "faces": faces}}))
'''


# Object type templates (injected into Blender script)
_OBJECT_TEMPLATES = {
    "rock": '''
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius={scale})
obj = bpy.context.active_object
import random; random.seed(hash("{name}"))
for v in obj.data.vertices:
    v.co.x += random.uniform(-0.15, 0.15) * {scale}
    v.co.y += random.uniform(-0.15, 0.15) * {scale}
    v.co.z += random.uniform(-0.1, 0.1) * {scale}
obj.scale.z = 0.7
''',
    "crystal": '''
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.3*{scale}, depth=2.0*{scale})
obj = bpy.context.active_object
obj.rotation_euler.x = 0.15
bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.2*{scale}, depth=1.3*{scale}, location=(0.4*{scale}, 0.2*{scale}, -0.3*{scale}))
comp = bpy.context.active_object
comp.rotation_euler = (0.3, 0.2, 0.5)
comp.select_set(True)
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.join()
''',
    "menhir": '''
bpy.ops.mesh.primitive_cube_add(size=1)
obj = bpy.context.active_object
obj.scale = (0.4*{scale}, 0.3*{scale}, 2.5*{scale})
bpy.ops.object.transform_apply(scale=True)
import random; random.seed(hash("{name}"))
for v in obj.data.vertices:
    if v.co.z > 0:
        factor = 1.0 - (v.co.z / (2.5*{scale})) * 0.4
        v.co.x *= factor
        v.co.y *= factor
    v.co.x += random.uniform(-0.05, 0.05) * {scale}
    v.co.y += random.uniform(-0.05, 0.05) * {scale}
obj.rotation_euler.y = random.uniform(-0.08, 0.08)
''',
    "tree": '''
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.15*{scale}, depth=2.0*{scale}, location=(0,0,1.0*{scale}))
trunk = bpy.context.active_object
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0*{scale}, location=(0, 0, 2.5*{scale}))
canopy = bpy.context.active_object
import random; random.seed(hash("{name}"))
for v in canopy.data.vertices:
    v.co.x += random.uniform(-0.2, 0.2) * {scale}
    v.co.y += random.uniform(-0.2, 0.2) * {scale}
    v.co.z += random.uniform(-0.15, 0.15) * {scale}
canopy.scale.z = 0.8
leaf_mat = bpy.data.materials.new("leaf")
leaf_mat.use_nodes = True
bsdf_l = leaf_mat.node_tree.nodes.get("Principled BSDF")
bsdf_l.inputs["Base Color"].default_value = (0.2, 0.45, 0.15, 1.0)
canopy.data.materials.append(leaf_mat)
trunk.select_set(True); canopy.select_set(True)
bpy.context.view_layer.objects.active = trunk
bpy.ops.object.join()
obj = trunk
''',
    "cabin": '''
bpy.ops.mesh.primitive_cube_add(size=1, location=(0,0,0.5*{scale}))
base = bpy.context.active_object
base.scale = (1.5*{scale}, 1.0*{scale}, 0.8*{scale})
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=1.2*{scale}, depth=0.8*{scale}, location=(0,0,1.3*{scale}))
roof = bpy.context.active_object
roof.scale.y = 0.7
roof.rotation_euler.z = 0.785
bpy.ops.mesh.primitive_cube_add(size=0.3*{scale}, location=(0.5*{scale}, 0, 1.5*{scale}))
chimney = bpy.context.active_object
chimney.scale.z = 1.5
door_mat = bpy.data.materials.new("door")
door_mat.use_nodes = True
bsdf_d = door_mat.node_tree.nodes.get("Principled BSDF")
bsdf_d.inputs["Base Color"].default_value = (0.15, 0.10, 0.06, 1.0)
bpy.ops.mesh.primitive_cube_add(size=0.1, location=(0, -1.0*{scale}+0.05, 0.35*{scale}))
door = bpy.context.active_object
door.scale = (0.3*{scale}, 0.05, 0.5*{scale})
door.data.materials.append(door_mat)
base.select_set(True); roof.select_set(True); chimney.select_set(True); door.select_set(True)
bpy.context.view_layer.objects.active = base
bpy.ops.object.join()
obj = base
''',
    "bush": '''
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5*{scale})
obj = bpy.context.active_object
obj.scale = (1.0, 0.8, 0.6)
import random; random.seed(hash("{name}"))
for v in obj.data.vertices:
    v.co += v.co.normalized() * random.uniform(-0.1, 0.1) * {scale}
''',
}


def _script_object(
    name: str, obj_type: str, scale: float,
    r: float, g: float, b: float, output: str,
) -> str:
    template = _OBJECT_TEMPLATES.get(obj_type, _OBJECT_TEMPLATES["rock"])
    template_filled = template.format(name=name, scale=scale)

    return f'''
import bpy, json, os

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

{template_filled}

obj.name = "{name}"
bpy.ops.object.shade_flat()

mat = bpy.data.materials.new("{name}_mat")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Base Color"].default_value = ({r}, {g}, {b}, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
if not obj.data.materials:
    obj.data.materials.append(mat)
else:
    obj.data.materials[0] = mat

os.makedirs(os.path.dirname(r"{output}"), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=r"{output}", export_format='GLB',
    use_selection=True, export_apply=True)
size = os.path.getsize(r"{output}")
print(json.dumps({{"status": "ok", "file": r"{output}", "size_bytes": size,
    "type": "{obj_type}", "vertices": len(obj.data.vertices),
    "faces": len(obj.data.polygons)}}))
'''


def _script_ocean(
    name: str, size_x: float, size_y: float, resolution: int, output: str,
) -> str:
    return f'''
import bpy, bmesh, json, math, os

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.mesh.primitive_grid_add(x_subdivisions={resolution}, y_subdivisions=int({resolution}*0.67), size=1)
obj = bpy.context.active_object
obj.name = "{name}"
obj.scale = ({size_x}, {size_y}, 1)
bpy.ops.object.transform_apply(scale=True)

from mathutils import noise, Vector
for v in obj.data.vertices:
    x, y = v.co.x / {size_x}, v.co.y / {size_y}
    wave = math.sin(x * 8) * math.sin(y * 5) * 0.3
    wave += noise.noise(Vector((x * 12, y * 8, 0))) * 0.15
    v.co.z = wave

bpy.ops.object.shade_flat()

mat = bpy.data.materials.new("ocean_mat")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Base Color"].default_value = (0.08, 0.25, 0.42, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.15
    bsdf.inputs["Metallic"].default_value = 0.1
obj.data.materials.append(mat)

os.makedirs(os.path.dirname(r"{output}"), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=r"{output}", export_format='GLB',
    use_selection=True, export_apply=True)
size = os.path.getsize(r"{output}")
print(json.dumps({{"status": "ok", "file": r"{output}", "size_bytes": size,
    "vertices": len(obj.data.vertices)}}))
'''


def _script_compose(placements_json: str, output: str) -> str:
    # Escape single quotes in JSON for embedding in Python string
    safe_json = placements_json.replace("'", "\\'")
    return f'''
import bpy, json, os

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

placements = json.loads('{safe_json}')
for p in placements:
    glb_path = p.get("file", "")
    if not os.path.exists(glb_path):
        continue
    bpy.ops.import_scene.gltf(filepath=glb_path)
    imported = bpy.context.selected_objects
    for obj in imported:
        pos = p.get("position", [0,0,0])
        rot = p.get("rotation", [0,0,0])
        scale = p.get("scale", [1,1,1])
        obj.location = pos
        obj.rotation_euler = rot
        if isinstance(scale, list):
            obj.scale = scale
        else:
            obj.scale = (scale, scale, scale)

bpy.ops.object.select_all(action='SELECT')
os.makedirs(os.path.dirname(r"{output}"), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=r"{output}", export_format='GLB',
    use_selection=True, export_apply=True)
size = os.path.getsize(r"{output}")
print(json.dumps({{"status": "ok", "file": r"{output}", "size_bytes": size,
    "objects": len(placements)}}))
'''


# ── Adapter ─────────────────────────────────────────────────────────────────


class BlenderAdapter(BaseAdapter):
    """Adapter for headless Blender 3D asset generation."""

    def __init__(self) -> None:
        super().__init__("blender")

    def list_actions(self) -> dict[str, str]:
        return {
            "version":        "Check Blender version and capabilities",
            "create-terrain": "Generate low-poly terrain (--name, --style cliff|hills|island|flat, --size_x, --size_y, --height_scale, --seed, --output)",
            "create-tower":   "Generate celtic ruined tower (--name, --height, --radius, --segments, --ruined, --output)",
            "create-object":  "Generate object (--name, --type rock|crystal|menhir|tree|cabin|bush, --scale, --color r,g,b, --output)",
            "create-ocean":   "Generate ocean mesh with wave displacement (--name, --size_x, --size_y, --resolution, --output)",
            "batch-generate": "Generate assets from manifest JSON (--manifest path)",
            "scene-compose":  "Compose GLB assets into scene (--config path, --output)",
            "list-assets":    "List all generated 3D assets in assets/3d_models/",
            "open":           "Open file in Blender GUI (--file path)",
        }

    def health_probe(self) -> tuple[str, dict]:
        return "version", {}

    def run(self, action: str, **kwargs: Any) -> dict:
        match action:
            case "version":
                return self._version()
            case "create-terrain":
                return self._create_terrain(**kwargs)
            case "create-tower":
                return self._create_tower(**kwargs)
            case "create-object":
                return self._create_object(**kwargs)
            case "create-ocean":
                return self._create_ocean(**kwargs)
            case "batch-generate":
                return self._batch_generate(**kwargs)
            case "scene-compose":
                return self._scene_compose(**kwargs)
            case "list-assets":
                return self._list_assets()
            case "open":
                return self._open(**kwargs)
            case _:
                raise NotImplementedError(action)

    # ── Actions ────────────────────────────────────────────────────────────

    def _version(self) -> dict:
        result = _run_blender_script(_script_version(), timeout=30)
        if result.get("data"):
            return self.ok(result["data"])
        return self.error(
            result.get("stderr", "Blender failed to start"),
            data=result,
        )

    def _create_terrain(self, **kw: Any) -> dict:
        name = kw.get("name", "terrain")
        output = kw.get("output", str(ASSETS_DIR / f"{name}.glb"))
        script = _script_terrain(
            name=name,
            size_x=float(kw.get("size_x", 50)),
            size_y=float(kw.get("size_y", 50)),
            subdivisions=int(kw.get("subdivisions", 20)),
            height_scale=float(kw.get("height_scale", 5.0)),
            seed=int(kw.get("seed", 42)),
            style=kw.get("style", "cliff"),
            output=output,
        )
        result = _run_blender_script(script, timeout=60)
        if result.get("data"):
            return self.ok(result["data"])
        return self.error(
            result.get("stderr", "Terrain generation failed")[:500],
            data={"stdout": result.get("stdout", "")[-500:]},
        )

    def _create_tower(self, **kw: Any) -> dict:
        name = kw.get("name", "celtic_tower")
        output = kw.get("output", str(ASSETS_DIR / "menu_coast" / f"{name}.glb"))
        script = _script_tower(
            name=name,
            height=float(kw.get("height", 15.0)),
            radius=float(kw.get("radius", 2.0)),
            segments=int(kw.get("segments", 8)),
            ruined=str(kw.get("ruined", "true")).lower() == "true",
            output=output,
        )
        result = _run_blender_script(script, timeout=90)
        if result.get("data"):
            return self.ok(result["data"])
        return self.error(
            result.get("stderr", "Tower generation failed")[:500],
            data={"stdout": result.get("stdout", "")[-500:]},
        )

    def _create_object(self, **kw: Any) -> dict:
        name = kw.get("name", "object")
        obj_type = kw.get("type", "rock")
        color = kw.get("color", "0.5,0.5,0.5")
        r, g, b = [float(x) for x in color.split(",")]
        output = kw.get("output", str(ASSETS_DIR / f"{name}.glb"))

        if obj_type not in _OBJECT_TEMPLATES:
            return self.error(
                f"Unknown type '{obj_type}'. Available: {', '.join(_OBJECT_TEMPLATES)}"
            )

        script = _script_object(
            name=name,
            obj_type=obj_type,
            scale=float(kw.get("scale", 1.0)),
            r=r, g=g, b=b,
            output=output,
        )
        result = _run_blender_script(script, timeout=60)
        if result.get("data"):
            return self.ok(result["data"])
        return self.error(
            result.get("stderr", "Object generation failed")[:500],
            data={"stdout": result.get("stdout", "")[-500:]},
        )

    def _create_ocean(self, **kw: Any) -> dict:
        name = kw.get("name", "ocean")
        output = kw.get("output", str(ASSETS_DIR / "menu_coast" / f"{name}.glb"))
        script = _script_ocean(
            name=name,
            size_x=float(kw.get("size_x", 120)),
            size_y=float(kw.get("size_y", 80)),
            resolution=int(kw.get("resolution", 60)),
            output=output,
        )
        result = _run_blender_script(script, timeout=60)
        if result.get("data"):
            return self.ok(result["data"])
        return self.error(
            result.get("stderr", "Ocean generation failed")[:500],
            data={"stdout": result.get("stdout", "")[-500:]},
        )

    def _batch_generate(self, **kw: Any) -> dict:
        manifest_path = kw.get("manifest", "")
        if not manifest_path or not os.path.exists(manifest_path):
            return self.error(f"Manifest not found: {manifest_path}")

        with open(manifest_path) as f:
            manifest = json.load(f)

        results = []
        for item in manifest.get("assets", []):
            item_kw = {
                "name": item.get("name", "unnamed"),
                "type": item.get("type", "rock"),
                "scale": str(item.get("scale", 1.0)),
                "color": item.get("color", "0.5,0.5,0.5"),
                "output": item.get(
                    "output",
                    str(ASSETS_DIR / f"{item.get('name', 'unnamed')}.glb"),
                ),
            }
            r = self._create_object(**item_kw)
            results.append({
                "name": item_kw["name"],
                "status": r.get("status"),
                "data": r.get("data"),
            })

        return self.ok({"generated": len(results), "results": results})

    def _scene_compose(self, **kw: Any) -> dict:
        config_path = kw.get("config", "")
        output = kw.get("output", str(ASSETS_DIR / "composed_scene.glb"))

        if not config_path or not os.path.exists(config_path):
            return self.error(f"Config not found: {config_path}")

        with open(config_path) as f:
            config = json.load(f)

        placements_json = json.dumps(config.get("placements", []))
        script = _script_compose(placements_json, output)
        result = _run_blender_script(script, timeout=120)
        if result.get("data"):
            return self.ok(result["data"])
        return self.error(
            result.get("stderr", "Scene composition failed")[:500],
            data={"stdout": result.get("stdout", "")[-500:]},
        )

    def _list_assets(self) -> dict:
        _ensure_dirs()
        assets = []
        for f in ASSETS_DIR.rglob("*.glb"):
            assets.append({
                "name": f.stem,
                "path": str(f),
                "size_bytes": f.stat().st_size,
                "dir": str(f.parent.relative_to(ASSETS_DIR)),
            })
        return self.ok({"count": len(assets), "assets": assets})

    def _open(self, **kw: Any) -> dict:
        file_path = kw.get("file", "")
        if not file_path:
            return self.error("No file specified (--file path)")

        cmd = [BLENDER_EXE]
        if file_path.endswith((".glb", ".gltf")):
            cmd.extend([
                "--python-expr",
                f'import bpy; bpy.ops.import_scene.gltf(filepath=r"{file_path}")',
            ])
        else:
            cmd.append(file_path)

        subprocess.Popen(cmd)
        return self.ok({"message": f"Opened {file_path} in Blender GUI"})

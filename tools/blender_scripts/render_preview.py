"""Render a quick preview PNG of the cauldron GLB."""
import bpy, mathutils, os, sys

GLB = "c:/Users/PGNK2128/Godot-MCP/assets/3d_models/decor/cauldron_merlin.glb"
OUT = "c:/Users/PGNK2128/Godot-MCP/tools/autodev/captures/cauldron_preview.png"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

# Camera — 3/4 view
cam_data = bpy.data.cameras.new("Cam")
cam_obj = bpy.data.objects.new("Cam", cam_data)
bpy.context.scene.collection.objects.link(cam_obj)
cam_obj.location = (2.8, -2.8, 2.2)
cam_obj.rotation_euler = mathutils.Euler((1.05, 0.0, 0.78), 'XYZ')
bpy.context.scene.camera = cam_obj

# Key light
light = bpy.data.lights.new("Key", type='SUN')
light_obj = bpy.data.objects.new("Key", light)
bpy.context.scene.collection.objects.link(light_obj)
light_obj.location = (4, -2, 6)
light.energy = 4.0
light.color = (1.0, 0.95, 0.85)

# Fill light (cool)
fill = bpy.data.lights.new("Fill", type='SUN')
fill_obj = bpy.data.objects.new("Fill", fill)
bpy.context.scene.collection.objects.link(fill_obj)
fill_obj.location = (-3, 3, 3)
fill.energy = 1.5
fill.color = (0.6, 0.8, 1.0)

# World background
bpy.context.scene.world = bpy.data.worlds.new("World")
bpy.context.scene.world.use_nodes = True
bg = bpy.context.scene.world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.08, 0.07, 0.10, 1.0)
bg.inputs["Strength"].default_value = 0.5

scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.filepath = OUT
scene.render.image_settings.file_format = 'PNG'
scene.render.film_transparent = False

bpy.ops.render.render(write_still=True)
print(f"✓ Preview saved: {OUT}")

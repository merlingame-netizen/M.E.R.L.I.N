"""
Open menu_coast_scene.blend in camera view + Material Preview.
Usage: blender menu_coast_scene.blend --python open_menu_scene.py
This script runs AFTER the .blend is loaded — no new scene created.
"""
import bpy

# Force Material Preview + Camera view on ALL 3D viewports
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            for space in area.spaces:
                if space.type == 'VIEW_3D':
                    space.shading.type = 'MATERIAL'
                    space.region_3d.view_perspective = 'CAMERA'

# Set timeline to frame 30 (mid-animation)
bpy.context.scene.frame_current = 30

# Auto-play animation
bpy.ops.screen.animation_play()

print("[OPEN] Camera view + Material Preview + Animation playing")

"""Godot Integration — copy sprites into the Godot project and generate resources.

Handles:
- Copying sprite sheets to the project's sprites/ directory
- Generating multi-animation .tres SpriteFrames resources
- Creating a ready-to-use AnimatedSprite2D scene (.tscn)

Usage:
    from pixel_art.godot_integration import integrate_bestiole
    result = integrate_bestiole(source_image="bestiole.png", anatomy="quadruped")
"""

import os
import shutil
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple


# Default animation types for bestiole
ALL_ANIMATIONS = [
    'idle', 'walk', 'blink', 'sleep', 'alert',
    'happy', 'curious', 'sad', 'excited', 'scared',
]

GODOT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUTPUT_DIR = os.path.join(GODOT_ROOT, 'output', 'pixel_art')


@dataclass(frozen=True)
class AnimationDef:
    """Definition of a single animation within a SpriteFrames resource."""
    name: str
    sheet_path: str          # Godot res:// path to sprite sheet
    frame_count: int
    frame_width: int
    frame_height: int
    columns: int
    fps: float = 6.0
    loop: bool = True


def generate_multi_animation_tres(animations: List[AnimationDef]) -> str:
    """Generate a .tres SpriteFrames resource with multiple named animations.

    Each animation references its own sprite sheet texture via AtlasTextures.

    Args:
        animations: List of AnimationDef, one per animation type.

    Returns:
        Content of the .tres file as a string.
    """
    # Collect unique textures (one per sheet)
    texture_ids: Dict[str, str] = {}   # sheet_path -> ext_resource id
    ext_id = 1
    for anim in animations:
        if anim.sheet_path not in texture_ids:
            texture_ids[anim.sheet_path] = str(ext_id)
            ext_id += 1

    load_steps = len(texture_ids) + 1  # textures + resource

    # Header
    lines = [f'[gd_resource type="SpriteFrames" load_steps={load_steps} format=3]', '']

    # External resources (textures)
    for path, rid in sorted(texture_ids.items(), key=lambda x: int(x[1])):
        lines.append(f'[ext_resource type="Texture2D" path="{path}" id="{rid}"]')
    lines.append('')

    # Sub-resources (AtlasTextures per frame per animation)
    atlas_id_map: Dict[str, List[str]] = {}  # anim_name -> [atlas_ids]
    atlas_counter = 0

    for anim in animations:
        atlas_ids = []
        tex_id = texture_ids[anim.sheet_path]
        for i in range(anim.frame_count):
            col = i % anim.columns
            row = i // anim.columns
            x = col * anim.frame_width
            y = row * anim.frame_height
            aid = f"AtlasTexture_{atlas_counter}"
            lines.extend([
                f'[sub_resource type="AtlasTexture" id="{aid}"]',
                f'atlas = ExtResource("{tex_id}")',
                f'region = Rect2({x}, {y}, {anim.frame_width}, {anim.frame_height})',
                '',
            ])
            atlas_ids.append(aid)
            atlas_counter += 1
        atlas_id_map[anim.name] = atlas_ids

    # Resource section with all animations
    lines.append('[resource]')
    lines.append('animations = [')

    for idx, anim in enumerate(animations):
        atlas_ids = atlas_id_map[anim.name]
        if idx == 0:
            lines.append('{')
        lines.append(f'"name": &"{anim.name}",')
        lines.append(f'"speed": {anim.fps},')
        lines.append(f'"loop": {"true" if anim.loop else "false"},')
        lines.append('"frames": [')
        for aid in atlas_ids:
            lines.append('{')
            lines.append(f'"texture": SubResource("{aid}"),')
            lines.append('"duration": 1.0,')
            lines.append('},')
        lines.append(']')
        if idx < len(animations) - 1:
            lines.append('}, {')
        else:
            lines.append('}')

    lines.append(']')

    return '\n'.join(lines) + '\n'


def generate_animated_sprite_tscn(name: str, tres_res_path: str,
                                   default_animation: str = "idle") -> str:
    """Generate a .tscn scene with an AnimatedSprite2D node.

    Args:
        name: Node name.
        tres_res_path: Godot res:// path to the .tres SpriteFrames resource.
        default_animation: Animation to play on start.

    Returns:
        Content of the .tscn file as a string.
    """
    lines = [
        '[gd_scene load_steps=2 format=3]',
        '',
        f'[ext_resource type="SpriteFrames" path="{tres_res_path}" id="1"]',
        '',
        f'[node name="{name}" type="AnimatedSprite2D"]',
        'sprite_frames = ExtResource("1")',
        f'animation = &"{default_animation}"',
        f'autoplay = "{default_animation}"',
    ]
    return '\n'.join(lines) + '\n'


def _normalize_godot_path(path: str) -> str:
    """Ensure a path uses Godot res:// format."""
    path = path.replace('\\', '/')
    if not path.startswith('res://'):
        path = 'res://' + path
    return path


def integrate_bestiole(
    source_image: Optional[str] = None,
    anatomy: str = 'quadruped',
    animations: Optional[List[str]] = None,
    frame_count: int = 12,
    target_size: int = 128,
    fps: float = 6.0,
    sprites_subdir: str = 'sprites/pixel_art/bestiole',
    godot_root: Optional[str] = None,
    regenerate: bool = False,
    verbose: bool = True,
) -> dict:
    """Full integration pipeline: generate all animations and export to Godot.

    Two modes:
    - If regenerate=True (or sheets don't exist): runs direct_animate for each type
    - If regenerate=False and sheets exist: copies existing sheets from output/

    Args:
        source_image: Path to the source PNG (required if regenerate=True).
        anatomy: Creature type for animation presets.
        animations: List of animation types (default: all 10).
        frame_count: Frames per animation.
        target_size: Output sprite size in pixels.
        fps: Animation speed.
        sprites_subdir: Target directory within Godot project.
        godot_root: Godot project root (default: auto-detected).
        regenerate: Force re-generation of all animations.
        verbose: Print progress.

    Returns:
        Dict with paths to all generated files.
    """
    if animations is None:
        animations = list(ALL_ANIMATIONS)

    if godot_root is None:
        godot_root = GODOT_ROOT

    target_dir = os.path.join(godot_root, sprites_subdir)
    os.makedirs(target_dir, exist_ok=True)

    result = {
        'target_dir': target_dir,
        'sheets': {},
        'tres': None,
        'tscn': None,
    }

    if verbose:
        print(f"\n  GODOT INTEGRATION — bestiole")
        print(f"  {'=' * 40}")
        print(f"  Target: {sprites_subdir}/")
        print(f"  Animations: {len(animations)}")

    # Step 1: Ensure sprite sheets exist for all animations
    anim_defs = []
    for anim_type in animations:
        sheet_name = f"bestiole_{anim_type}_sheet.png"
        output_sheet = os.path.join(OUTPUT_DIR, sheet_name)
        target_sheet = os.path.join(target_dir, sheet_name)

        if regenerate or not os.path.exists(output_sheet):
            if source_image is None:
                raise ValueError(
                    f"Sheet {sheet_name} not found and no source_image provided. "
                    "Run the animation pipeline first or provide source_image."
                )
            if verbose:
                print(f"  Generating {anim_type}...")
            from .ingest.direct_animator import direct_animate
            from .forge_simple import forge
            frames = direct_animate(
                source_image,
                anatomy=anatomy,
                animation=anim_type,
                frame_count=frame_count,
                target_size=target_size,
                verbose=False,
            )
            forge(
                f"bestiole_{anim_type}",
                frames=frames,
                fps=int(fps),
                scale_gif=4,
                verbose=False,
            )

        # Copy sheet to Godot sprites dir
        if os.path.exists(output_sheet):
            shutil.copy2(output_sheet, target_sheet)
            result['sheets'][anim_type] = target_sheet
            if verbose:
                print(f"  [{anim_type:8s}] -> {sprites_subdir}/{sheet_name}")
        else:
            if verbose:
                print(f"  [{anim_type:8s}] SKIPPED (sheet not found)")
            continue

        # Build animation definition
        godot_sheet_path = _normalize_godot_path(f"{sprites_subdir}/{sheet_name}")
        anim_defs.append(AnimationDef(
            name=anim_type,
            sheet_path=godot_sheet_path,
            frame_count=frame_count,
            frame_width=target_size,
            frame_height=target_size,
            columns=frame_count,
            fps=fps,
            loop=True,
        ))

    if not anim_defs:
        raise RuntimeError("No animation sheets found or generated.")

    # Step 2: Generate multi-animation .tres SpriteFrames
    tres_content = generate_multi_animation_tres(anim_defs)
    tres_path = os.path.join(target_dir, 'bestiole_frames.tres')
    with open(tres_path, 'w', encoding='utf-8') as f:
        f.write(tres_content)
    result['tres'] = tres_path
    if verbose:
        print(f"  [.tres   ] bestiole_frames.tres ({len(anim_defs)} animations)")

    # Step 3: Generate AnimatedSprite2D scene
    tres_res = _normalize_godot_path(f"{sprites_subdir}/bestiole_frames.tres")
    tscn_content = generate_animated_sprite_tscn("Bestiole", tres_res, "idle")
    tscn_path = os.path.join(target_dir, 'bestiole_animated.tscn')
    with open(tscn_path, 'w', encoding='utf-8') as f:
        f.write(tscn_content)
    result['tscn'] = tscn_path
    if verbose:
        print(f"  [.tscn   ] bestiole_animated.tscn")

    # Step 4: Copy static frame 0 for icon/thumbnail
    static_src = os.path.join(OUTPUT_DIR, 'bestiole_idle.png')
    if os.path.exists(static_src):
        static_dst = os.path.join(target_dir, 'bestiole.png')
        shutil.copy2(static_src, static_dst)
        result['static'] = static_dst

    if verbose:
        total_files = len(result['sheets']) + 2  # sheets + tres + tscn
        print(f"\n  Done — {total_files} files in {sprites_subdir}/")

    return result


def integrate_sprite(frames, name, godot_project_root,
                     sprites_dir="sprites/pixel_art",
                     fps=4, columns=None, animation_name="default"):
    """Single-animation integration (backward compatible).

    Args:
        frames: List of PIL Images (RGBA, same size).
        name: Sprite name (used for filenames).
        godot_project_root: Path to the Godot project root.
        sprites_dir: Subdirectory within Godot project for sprites.
        fps: Animation speed.
        columns: Sprite sheet columns (default: all in one row).
        animation_name: Name of the animation.

    Returns:
        Dict with paths to generated files.
    """
    from .animation import SpriteSheet, export_godot_tres_file

    fw = frames[0].width
    fh = frames[0].height
    cols = columns or len(frames)

    target_dir = os.path.join(godot_project_root, sprites_dir)
    os.makedirs(target_dir, exist_ok=True)

    result = {}

    # Export sprite sheet
    sheet = SpriteSheet(frames, columns=cols)
    sheet_filename = f"{name}_sheet.png"
    sheet_path = os.path.join(target_dir, sheet_filename)
    sheet.export(sheet_path)
    result['sheet'] = sheet_path

    # Export single frame
    single_path = os.path.join(target_dir, f"{name}.png")
    frames[0].save(single_path, 'PNG')
    result['single'] = single_path

    # Generate .tres
    godot_sheet_path = f"{sprites_dir}/{sheet_filename}"
    tres_path = os.path.join(target_dir, f"{name}_frames.tres")
    export_godot_tres_file(
        tres_path,
        sheet_path=godot_sheet_path,
        frame_count=len(frames),
        fps=fps,
        columns=cols,
        frame_width=fw,
        frame_height=fh,
        animation_name=animation_name,
    )
    result['tres'] = tres_path

    # Generate .tscn
    tres_res = _normalize_godot_path(f"{sprites_dir}/{name}_frames.tres")
    tscn_content = generate_animated_sprite_tscn(name, tres_res, animation_name)
    tscn_path = os.path.join(target_dir, f"{name}_animated.tscn")
    with open(tscn_path, 'w', encoding='utf-8') as f:
        f.write(tscn_content)
    result['tscn'] = tscn_path

    return result

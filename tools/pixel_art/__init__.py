"""Merlin Pixel Forge — Pixel art generation toolkit for M.E.R.L.I.N."""

from .merlin_pixel_forge import GridSprite, render_grid, upscale, export_png
from .palettes import get_palette, PALETTES
from .effects import floyd_steinberg, bayer_dither, outline, shadow
from .animation import SpriteSheet, export_spritesheet, export_gif
from .previewer import generate_preview
from .godot_integration import integrate_sprite
from .forge import forge_sprite
from .ase_writer import write_ase, write_ase_from_grids
from .libresprite_bridge import forge_with_libresprite, run_libresprite_batch
from .forge_simple import forge
from .shape_sprite import ShapeSprite
from .low_poly_mesh import LowPolyMesh, Facet, GlowDot

# Character generator (parametric low-poly sprite generation)
from .generator import generate_character, animate_character, export_character
from .generator.character_spec import CharacterSpec, spec_from_json, spec_to_json

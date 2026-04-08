"""
N64 / Banjo-Kazooie Palette for M.E.R.L.I.N. Celtic Assets
Vertex-color-only aesthetic, 50-300 tris per asset.
"""

# Base Celtic palette (RGBA tuples 0-1)
PALETTE = {
    # Greens (forest, vegetation)
    "forest_dark":      (0.13, 0.35, 0.12, 1.0),
    "forest_mid":       (0.22, 0.50, 0.18, 1.0),
    "forest_light":     (0.35, 0.65, 0.25, 1.0),
    "moss":             (0.28, 0.45, 0.15, 1.0),
    "fern":             (0.18, 0.55, 0.22, 1.0),
    "spring_green":     (0.40, 0.72, 0.30, 1.0),
    "sage":             (0.45, 0.55, 0.35, 1.0),

    # Browns (wood, earth)
    "bark_dark":        (0.25, 0.15, 0.08, 1.0),
    "bark_mid":         (0.38, 0.22, 0.10, 1.0),
    "bark_light":       (0.50, 0.35, 0.18, 1.0),
    "earth":            (0.35, 0.25, 0.12, 1.0),
    "mud":              (0.30, 0.20, 0.10, 1.0),
    "sand":             (0.76, 0.65, 0.42, 1.0),
    "clay":             (0.55, 0.35, 0.20, 1.0),

    # Greys (stone, megaliths)
    "stone_dark":       (0.30, 0.30, 0.32, 1.0),
    "stone_mid":        (0.50, 0.50, 0.52, 1.0),
    "stone_light":      (0.68, 0.68, 0.70, 1.0),
    "granite":          (0.55, 0.52, 0.50, 1.0),
    "slate":            (0.35, 0.38, 0.42, 1.0),

    # Blues (water, mystical)
    "water_deep":       (0.10, 0.25, 0.55, 1.0),
    "water_mid":        (0.20, 0.45, 0.70, 1.0),
    "water_light":      (0.40, 0.65, 0.85, 1.0),
    "mystic_blue":      (0.25, 0.35, 0.75, 1.0),
    "ice":              (0.70, 0.82, 0.92, 1.0),

    # Purples (heather, magic)
    "heather":          (0.55, 0.25, 0.55, 1.0),
    "lavender":         (0.62, 0.45, 0.70, 1.0),
    "mystic_purple":    (0.40, 0.18, 0.55, 1.0),
    "twilight":         (0.30, 0.15, 0.45, 1.0),

    # Golds (sacred, ogham)
    "gold":             (0.80, 0.65, 0.15, 1.0),
    "amber":            (0.85, 0.55, 0.10, 1.0),
    "honey":            (0.75, 0.58, 0.25, 1.0),
    "sacred_gold":      (0.90, 0.75, 0.20, 1.0),

    # Reds/oranges (autumn, danger)
    "autumn_red":       (0.70, 0.22, 0.12, 1.0),
    "autumn_orange":    (0.80, 0.45, 0.12, 1.0),
    "berry":            (0.60, 0.10, 0.15, 1.0),
    "mushroom_red":     (0.75, 0.15, 0.10, 1.0),
    "mushroom_spot":    (0.90, 0.85, 0.75, 1.0),

    # Whites/creams
    "birch_white":      (0.88, 0.85, 0.78, 1.0),
    "snow":             (0.92, 0.93, 0.95, 1.0),
    "cream":            (0.90, 0.85, 0.70, 1.0),
    "bone":             (0.82, 0.78, 0.68, 1.0),

    # Blacks/darks
    "shadow":           (0.10, 0.08, 0.12, 1.0),
    "charcoal":         (0.18, 0.18, 0.20, 1.0),
    "void":             (0.05, 0.03, 0.08, 1.0),

    # Special (faction-aligned)
    "korrigan_green":   (0.15, 0.55, 0.30, 1.0),
    "druid_teal":       (0.12, 0.45, 0.42, 1.0),
    "ancient_bronze":   (0.55, 0.45, 0.25, 1.0),
    "fae_pink":         (0.85, 0.55, 0.65, 1.0),
    "niamh_silver":     (0.72, 0.75, 0.82, 1.0),
}

# Biome-specific color sets
BIOME_PALETTES = {
    "foret_broceliande": [
        "forest_dark", "forest_mid", "forest_light", "moss", "fern",
        "bark_dark", "bark_mid", "bark_light", "earth", "mushroom_red",
        "spring_green", "gold", "stone_mid",
    ],
    "landes_bruyere": [
        "heather", "lavender", "sage", "earth", "clay",
        "stone_mid", "stone_light", "autumn_orange", "honey",
        "fern", "moss", "bark_mid", "birch_white",
    ],
    "cotes_sauvages": [
        "water_deep", "water_mid", "water_light", "sand", "stone_dark",
        "stone_mid", "slate", "birch_white", "moss", "fern",
        "cream", "bark_light", "ice",
    ],
    "villages_celtes": [
        "bark_dark", "bark_mid", "bark_light", "stone_mid", "stone_light",
        "earth", "clay", "cream", "gold", "autumn_red",
        "forest_mid", "honey", "birch_white",
    ],
    "cercles_pierres": [
        "stone_dark", "stone_mid", "stone_light", "granite", "slate",
        "moss", "sacred_gold", "mystic_blue", "twilight", "earth",
        "bone", "shadow", "ancient_bronze",
    ],
    "marais_korrigans": [
        "mud", "moss", "fern", "water_deep", "korrigan_green",
        "bark_dark", "earth", "mushroom_red", "twilight", "shadow",
        "charcoal", "forest_dark", "heather",
    ],
    "collines_dolmens": [
        "stone_dark", "stone_mid", "granite", "earth", "moss",
        "forest_mid", "sage", "ancient_bronze", "gold", "clay",
        "bark_mid", "fern", "slate",
    ],
    "iles_mystiques": [
        "mystic_blue", "mystic_purple", "niamh_silver", "water_light",
        "sacred_gold", "fae_pink", "ice", "snow", "lavender",
        "birch_white", "twilight", "water_mid", "cream",
    ],
}

# N64 memory constraints
N64_CONSTRAINTS = {
    "max_tris_tiny": 80,       # Grass, small flowers
    "max_tris_small": 150,     # Bushes, small rocks
    "max_tris_medium": 250,    # Trees, structures
    "max_tris_large": 350,     # Characters, large structures (stretch goal)
    "max_texture_size": 64,    # 64x64 pixels max (but prefer vertex colors)
    "prefer_vertex_colors": True,
}

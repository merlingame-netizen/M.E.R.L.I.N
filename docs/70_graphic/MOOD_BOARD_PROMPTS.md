# Mood Board Prompts — Visual Direction v3

> **Statut 2026-04-25** : prompts prêts, génération Gemini bloquée (quota free-tier épuisé sur `gemini-2.5-flash-preview-image`).
> Les 4 prompts ci-dessous sont opérationnels. À ré-exécuter via :
> - `mcp__nano-banana__generate_image` (après reset quota free, ou avec clé facturable)
> - `python tools/cli.py nano-banana generate-image --prompt "..."`
> - Ou n'importe quel générateur (Midjourney, SDXL, Imagen)

Ces 4 images matérialisent les 16 décisions cardinales du document `VISUAL_DIRECTION_v3.md`.

---

## Prompt #1 — Rail 3D forêt de Brocéliande (scène canonique du gameplay)

**Objectif** : valider décisions 1, 2, 3, 5, 6, 9, 12, 13. Ambiance contemplative onirique, ornements diégétiques sur les pierres levées uniquement, présences sans corps.

```
PS1-era pre-rendered video game scene, low-resolution 320x240 dithered, vertex jitter low-poly aesthetic. A mystical druidic forest clearing in Brocéliande at dusk. Tall ancient standing stones (megaliths) with intricate Celtic knotwork engravings glow with subtle golden light — these are the only ornamented elements in the scene. Surrounding low-poly trees are angular, flat-shaded, untextured polygons in deep forest greens with no decoration. Heavy volumetric green-tinted fog cuts visibility. Subtle CRT scanlines and Bayer 4x4 dithering across the entire image. Affine texture warping on ground. Color palette dominated by deep moss green, gold accents on the stones, dark teal sky. No characters visible — only "presences" suggested by floating warm halos near the stones. Style references: Lunacid (KIRA, 2023), King's Field, Echo Night, Yume Nikki. Cinematic composition, 16:9, oneiric mystical Celtic atmosphere, contemplative.
```

---

## Prompt #2 — Carte typographique narrative (UI 2D centrale)

**Objectif** : valider décisions 4, 7, 8, 10, 14. Carte typographique + sigil de faction + glyphes Oghams + capitales Book of Kells + bitmap mono.

```
A 2D narrative game card UI, in the style of Citizen Sleeper but with Celtic druidic theme. Vertical card 3:4 aspect ratio. Cream parchment background with subtle wear and warm ivory tone. At the top: a large illuminated capital letter inspired by the Book of Kells in tarnished gold and deep brown ink, framed by interlaced Celtic knotwork. Center: typographic narrative text in a pixelated PS1-era bitmap monospace font, deep brown ink on parchment, three lines describing a choice. Bottom center: a stylized stone-carved silhouette of a raven (corvid totem) representing a faction, with subtle violet-purple glow around it. Three small buttons below for choices, each marked with an animated Ogham glyph (vertical line with diagonal cross-strokes) in tarnished gold. No illustration in the body — the typography IS the visual. Subtle Bayer dithering across the parchment. Mood: ritualistic, ancient, contemplative.
```

---

## Prompt #3 — Bascule cauchemar folklorique (moment clé narratif)

**Objectif** : valider décisions 2, 3, 13. Bascule cauchemar par moments, vertex jitter accentué, brume rouge, présence folklorique celtique.

```
A PS1-era retro horror video game screenshot capturing a "nightmare moment" in a Celtic folklore setting. Heavy aggressive vertex jitter and warping on geometry, hardcore Bayer 4x4 dithering. Camera at low angle on a dark forest path. Volumetric blood-red sinister fog dominates the scene. In the misty distance, an indistinct tall humanoid silhouette (Sluagh / dark Celtic spirit) — barely visible, threatening. Twisted bare low-poly tree branches frame the edges. Aggressive CRT scanlines (high opacity), chromatic aberration on edges. Color palette: deep crimson red, black, dim sickly green, occasional flickering gold. Tiny warm-yellow halo (the player presence) at center, vulnerable. Style references: Lunacid (KIRA, 2023), Iron Lung, Faith: Unholy Trinity, original Silent Hill PS1. Cinematic 16:9. Mood: ancient Celtic folklore horror, brief but intense.
```

---

## Prompt #4 — Écran de mort "Vision du corbeau"

**Objectif** : valider décision spéciale (écran de mort §3.2 du doc canonique). POV ascendant du corbeau totem, transition narrative onirique.

```
A close-up "vision of the raven" cinematic moment from a PS1-style mystical Celtic game — death scene. POV from a flying raven looking down at a tiny figure on a forest path far below, vertex-jittered low-poly geometry, Bayer dithering, subtle CRT scanlines. Stormy violet-grey sky filling most of the frame. The path and forest below shrink as the camera ascends. In tarnished celtic-gold capitals inspired by Book of Kells, a poetic line is overlaid: "Ton souffle a rejoint l'Awen" (text in upper portion). Bottom of frame shows distant low-poly trees and a small parchment scroll with a count of Anam (Celtic-style numerals). Color palette: muted violet, slate grey, gold accents, soft cloud whites. Mood: melancholic, contemplative, mythological passage. Style: Lunacid meets Spiritfarer meets Sable.
```

---

## Prompts complémentaires à générer plus tard (8 biomes)

Une fois les 4 références ci-dessus validées, générer 1 image par biome pour cristalliser les palettes du §2.3 :
1. Landes (gris-bleu mélancolique, bruyère)
2. Côtes (bleu pâle, sable doré, brume iodée)
3. Villages (brun chaud, fumée bleue)
4. Cercles mégalithes (gris pierre, mousse, lichen)
5. Marais (vert-noir, lueurs verdâtres)
6. Collines (vert pomme, ciel rose, vaporeux)
7. Îles (turquoise, basalte noir, magenta)
8. Forêt Brocéliande (vert profond, or filtrant) → déjà couvert par Prompt #1

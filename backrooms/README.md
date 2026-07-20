# Poolrooms — Backrooms Level 37 (Three.js, mobile-first)

A self-contained, visually rich, **mobile-playable** Three.js game set in the
**Poolrooms** (Backrooms Level 37): an endless liminal complex of shallow
turquoise pools, wet cream tiles and sourceless light. Wade the maze, collect
**5 bottles of almond water**, then reach the **emergency exit** — while an
entity stalks you through the water.

> This is a standalone web deliverable, independent of the Godot M.E.R.L.I.N.
> card game in the rest of this repository.

## Play

- **Mobile / touch:** left half of the screen = movement joystick, right half =
  drag to look, `RUN` to sprint (limited stamina), `PRENDRE` to grab. Everything
  runs in the browser from a single URL — no install.
- **Desktop:** `WASD` / `ZQSD` / arrows to move, mouse to look (click to lock the
  pointer), `Shift` to sprint, `E` to interact.

## Files

| File | Role |
|------|------|
| `index.html` | **Built, self-contained game** — Three.js is inlined, zero network dependencies. This is the deployable/playable artifact. |
| `game.js` | Human-readable game source (rendering, procedural level, entity AI, controls, audio). This is where the logic lives. |
| `shell.html` | HTML/CSS chrome: start menu, HUD, touch controls, end screens. |
| `vendor/three.module.js` | Vendored Three.js r170 (MIT). Third-party, not edited. |
| `build.py` | Concatenates `vendor/three.module.js` + `game.js` (wrapped in an IIFE) into `shell.html` → `index.html`. |

## Build

```bash
python3 build.py                 # regenerate index.html
python3 build.py artifact.html   # also emit a body-only variant (no <head>/<body>)
```

`game.js` is concatenated **after** Three.js into a single inline
`<script type="module">`, so every Three.js class is in scope by its bare name.
The game code is wrapped in an IIFE so none of its identifiers collide with
Three.js's. The result is one file that runs anywhere with **no CDN and no build
step at runtime** — which is exactly what lets it work under the strict Claude
Artifact CSP as well as on any static host.

## Run locally

```bash
python3 -m http.server 8099        # from this backrooms/ directory
# then open http://localhost:8099/index.html  (also reachable from a phone on the LAN)
```

## Deploy (optional)

`index.html` is a plain static page. It can be dropped onto any static host
(GitHub Pages, Vercel, Netlify, an S3 bucket…). Note the repository's GitHub
Pages is already used by the Godot web export (`web-export/` via
`.github/workflows/godot-export.yml`), so wiring a public URL for this page is
left as a deliberate, separate choice.

## Tech notes

- **Rendering:** WebGL2, manual color pipeline (linear scene render → custom
  bloom → ACES tone-map + grain + vignette + subtle chromatic aberration in a
  final fullscreen pass). Procedural canvas textures (tiles, normals, caustics,
  water) — no image assets. PMREM environment map for wet-tile / water
  reflections.
- **Level:** seeded (mulberry32) randomized-DFS maze, braided open for the
  columned pool-hall feel; walls & pillars as `InstancedMesh`; circle-vs-AABB
  collision.
- **Adaptive quality:** a rolling FPS monitor lowers device-pixel-ratio and
  disables bloom/grain on weak devices, and restores them when there's headroom.
- **Audio:** fully procedural WebAudio (reverberant drone, water, drips,
  footsteps, heartbeat proximity cue, win/lose stingers) — no audio files.

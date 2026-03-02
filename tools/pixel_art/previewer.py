"""HTML Sprite Previewer — generates an interactive HTML file for VS Code.

Features:
- Pixel grid overlay (toggle)
- Animation playback with FPS control
- Zoom (1x to 16x)
- Palette display with color codes
- All frames side by side
- Dark background for visibility

Usage:
    from previewer import generate_preview
    generate_preview(frames, palette, "my_sprite", output_dir)
"""

import os
import base64
import io
from PIL import Image


def _image_to_data_uri(img, scale=1):
    """Convert PIL Image to base64 data URI."""
    if scale > 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    b64 = base64.b64encode(buf.getvalue()).decode('ascii')
    return f"data:image/png;base64,{b64}"


def generate_preview(frames, palette, name="sprite", output_dir=".",
                     frame_width=None, frame_height=None, fps=4):
    """Generate an interactive HTML preview of a sprite with animation.

    Args:
        frames: List of PIL Images (RGBA) — animation frames.
        palette: Dict of {char: (R,G,B,A)} — the palette used.
        name: Sprite name (used in title and filename).
        output_dir: Where to write the HTML file.
        frame_width: Frame width (auto-detected from first frame).
        frame_height: Frame height (auto-detected from first frame).
        fps: Default animation speed.

    Returns:
        Path to the generated HTML file.
    """
    if not frames:
        raise ValueError("At least one frame required")

    fw = frame_width or frames[0].width
    fh = frame_height or frames[0].height

    # Encode all frames as data URIs (native size for canvas drawing)
    frame_uris = [_image_to_data_uri(f) for f in frames]

    # Build palette HTML
    palette_items = []
    for char, color in sorted(palette.items()):
        if char == '_':
            continue
        r, g, b = color[0], color[1], color[2]
        a = color[3] if len(color) == 4 else 255
        hex_color = f"#{r:02x}{g:02x}{b:02x}"
        palette_items.append(
            f'<div class="pal-item">'
            f'<span class="pal-swatch" style="background:{hex_color};opacity:{a/255}"></span>'
            f'<code>{char}</code> {hex_color}'
            f'</div>'
        )
    palette_html = '\n'.join(palette_items)

    # Frame URIs as JS array
    frame_js = ',\n    '.join(f'"{uri}"' for uri in frame_uris)

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>{name} — Pixel Art Preview</title>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    background: #1e1e1e; color: #ccc; font-family: 'Segoe UI', monospace;
    display: flex; flex-direction: column; align-items: center; padding: 20px;
    min-height: 100vh;
  }}
  h1 {{ color: #e0e0e0; font-size: 18px; margin-bottom: 12px; }}
  .info {{ color: #888; font-size: 12px; margin-bottom: 16px; }}

  .main {{ display: flex; gap: 24px; align-items: flex-start; flex-wrap: wrap; justify-content: center; }}

  .canvas-area {{
    display: flex; flex-direction: column; align-items: center;
    background: #2a2a2a; border-radius: 8px; padding: 16px;
    border: 1px solid #444;
  }}
  #spriteCanvas {{
    image-rendering: pixelated;
    image-rendering: crisp-edges;
    border: 1px solid #555;
    cursor: crosshair;
  }}

  .controls {{
    display: flex; gap: 10px; align-items: center; margin-top: 12px; flex-wrap: wrap;
    justify-content: center;
  }}
  .controls button {{
    background: #3a3a3a; color: #ddd; border: 1px solid #555; padding: 5px 12px;
    border-radius: 4px; cursor: pointer; font-size: 12px;
  }}
  .controls button:hover {{ background: #4a4a4a; }}
  .controls button.active {{ background: #0078d4; border-color: #0078d4; color: #fff; }}
  .controls label {{ font-size: 12px; color: #aaa; }}
  .controls input[type="range"] {{ width: 80px; }}
  .controls select {{ background: #3a3a3a; color: #ddd; border: 1px solid #555; padding: 4px; border-radius: 4px; }}

  .frame-strip {{
    display: flex; gap: 4px; margin-top: 12px; padding: 8px;
    background: #252525; border-radius: 4px;
  }}
  .frame-thumb {{
    image-rendering: pixelated; cursor: pointer; border: 2px solid transparent;
    border-radius: 2px;
  }}
  .frame-thumb.active {{ border-color: #0078d4; }}

  .sidebar {{ display: flex; flex-direction: column; gap: 16px; }}

  .palette-box {{
    background: #2a2a2a; border-radius: 8px; padding: 12px;
    border: 1px solid #444; max-width: 200px;
  }}
  .palette-box h3 {{ font-size: 13px; margin-bottom: 8px; color: #aaa; }}
  .pal-item {{
    display: flex; align-items: center; gap: 6px; padding: 2px 0;
    font-size: 11px;
  }}
  .pal-swatch {{
    width: 16px; height: 16px; border: 1px solid #555; border-radius: 2px;
    display: inline-block; flex-shrink: 0;
  }}
  .pal-item code {{ color: #e0a050; min-width: 12px; }}

  .pixel-info {{
    background: #2a2a2a; border-radius: 8px; padding: 12px;
    border: 1px solid #444; font-size: 12px; min-width: 180px;
  }}
  .pixel-info h3 {{ font-size: 13px; margin-bottom: 8px; color: #aaa; }}
  #pixelCoords {{ color: #88cc88; }}
  #pixelColor {{ color: #cc8888; }}
  #pixelSwatch {{ width: 24px; height: 24px; border: 1px solid #555; border-radius: 3px; margin-top: 4px; }}
</style>
</head>
<body>

<h1>{name}</h1>
<div class="info">{fw}x{fh} | {len(frames)} frame(s) | {fps} FPS</div>

<div class="main">
  <div class="canvas-area">
    <canvas id="spriteCanvas" width="{fw * 8}" height="{fh * 8}"></canvas>

    <div class="controls">
      <button id="btnPlay" class="active" onclick="togglePlay()">Pause</button>
      <label>FPS: <input type="range" id="fpsSlider" min="1" max="24" value="{fps}" oninput="changeFps(this.value)">
      <span id="fpsLabel">{fps}</span></label>
      <label>Zoom:
        <select id="zoomSelect" onchange="changeZoom(this.value)">
          <option value="2">2x</option>
          <option value="4">4x</option>
          <option value="6">6x</option>
          <option value="8" selected>8x</option>
          <option value="10">10x</option>
          <option value="12">12x</option>
          <option value="16">16x</option>
        </select>
      </label>
      <button id="btnGrid" onclick="toggleGrid()">Grid</button>
    </div>

    <div class="frame-strip" id="frameStrip"></div>
  </div>

  <div class="sidebar">
    <div class="pixel-info">
      <h3>Pixel Info</h3>
      <div>Position: <span id="pixelCoords">—</span></div>
      <div>Color: <span id="pixelColor">—</span></div>
      <div id="pixelSwatch" style="background:transparent;"></div>
    </div>

    <div class="palette-box">
      <h3>Palette ({len([k for k in palette if k != '_'])} colors)</h3>
      {palette_html}
    </div>
  </div>
</div>

<script>
const FRAMES = [
    {frame_js}
];
const FW = {fw}, FH = {fh};
let zoom = 8, showGrid = false, playing = true, currentFrame = 0;
let fps = {fps}, interval;

const canvas = document.getElementById('spriteCanvas');
const ctx = canvas.getContext('2d');
ctx.imageSmoothingEnabled = false;

// Load frame images
const frameImages = [];
let loaded = 0;
FRAMES.forEach((src, i) => {{
    const img = new Image();
    img.onload = () => {{
        loaded++;
        if (loaded === FRAMES.length) {{ buildStrip(); draw(); startAnim(); }}
    }};
    img.src = src;
    frameImages.push(img);
}});

function draw() {{
    canvas.width = FW * zoom;
    canvas.height = FH * zoom;
    ctx.imageSmoothingEnabled = false;
    // Checkerboard background
    for (let y = 0; y < FH; y++) {{
        for (let x = 0; x < FW; x++) {{
            ctx.fillStyle = (x + y) % 2 === 0 ? '#333' : '#2a2a2a';
            ctx.fillRect(x * zoom, y * zoom, zoom, zoom);
        }}
    }}
    ctx.drawImage(frameImages[currentFrame], 0, 0, FW * zoom, FH * zoom);
    if (showGrid) drawGrid();
    highlightActiveThumb();
}}

function drawGrid() {{
    ctx.strokeStyle = 'rgba(255,255,255,0.15)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= FW; x++) {{
        ctx.beginPath(); ctx.moveTo(x * zoom + 0.5, 0); ctx.lineTo(x * zoom + 0.5, FH * zoom); ctx.stroke();
    }}
    for (let y = 0; y <= FH; y++) {{
        ctx.beginPath(); ctx.moveTo(0, y * zoom + 0.5); ctx.lineTo(FW * zoom, y * zoom + 0.5); ctx.stroke();
    }}
}}

function startAnim() {{
    if (interval) clearInterval(interval);
    if (FRAMES.length > 1 && playing) {{
        interval = setInterval(() => {{
            currentFrame = (currentFrame + 1) % FRAMES.length;
            draw();
        }}, 1000 / fps);
    }}
}}

function togglePlay() {{
    playing = !playing;
    document.getElementById('btnPlay').textContent = playing ? 'Pause' : 'Play';
    document.getElementById('btnPlay').classList.toggle('active', playing);
    startAnim();
    if (!playing) draw();
}}

function changeFps(v) {{
    fps = parseInt(v);
    document.getElementById('fpsLabel').textContent = fps;
    startAnim();
}}

function changeZoom(v) {{
    zoom = parseInt(v);
    draw();
}}

function toggleGrid() {{
    showGrid = !showGrid;
    document.getElementById('btnGrid').classList.toggle('active', showGrid);
    draw();
}}

function buildStrip() {{
    const strip = document.getElementById('frameStrip');
    strip.innerHTML = '';
    FRAMES.forEach((src, i) => {{
        const img = document.createElement('img');
        img.src = src;
        img.width = FW * 3;
        img.height = FH * 3;
        img.className = 'frame-thumb' + (i === 0 ? ' active' : '');
        img.onclick = () => {{ currentFrame = i; draw(); }};
        img.title = 'Frame ' + i;
        strip.appendChild(img);
    }});
}}

function highlightActiveThumb() {{
    document.querySelectorAll('.frame-thumb').forEach((el, i) => {{
        el.classList.toggle('active', i === currentFrame);
    }});
}}

// Pixel info on hover
canvas.addEventListener('mousemove', (e) => {{
    const rect = canvas.getBoundingClientRect();
    const px = Math.floor((e.clientX - rect.left) / zoom);
    const py = Math.floor((e.clientY - rect.top) / zoom);
    if (px < 0 || px >= FW || py < 0 || py >= FH) return;

    document.getElementById('pixelCoords').textContent = px + ', ' + py;

    // Read pixel from a temp canvas at native size
    const tc = document.createElement('canvas');
    tc.width = FW; tc.height = FH;
    const tctx = tc.getContext('2d');
    tctx.drawImage(frameImages[currentFrame], 0, 0);
    const [r, g, b, a] = tctx.getImageData(px, py, 1, 1).data;
    const hex = '#' + [r,g,b].map(c => c.toString(16).padStart(2,'0')).join('');
    document.getElementById('pixelColor').textContent = hex + (a < 255 ? ' a=' + a : '');
    document.getElementById('pixelSwatch').style.background = a > 0 ? hex : 'transparent';
}});
</script>
</body>
</html>"""

    path = os.path.join(output_dir, f"{name}_preview.html")
    with open(path, 'w', encoding='utf-8') as f:
        f.write(html)
    return path

// Pixel Art Preview — VS Code Sidebar Extension (v2 — simple <img> approach)
// Part of Merlin Pixel Forge toolkit
const vscode = require('vscode');
const fs = require('fs');
const path = require('path');

// ------------------------------------------------------------------
// Helpers
// ------------------------------------------------------------------
function findProjectRoot() {
    const folders = vscode.workspace.workspaceFolders;
    if (!folders || folders.length === 0) return null;
    for (const f of folders) {
        const p = f.uri.fsPath;
        if (fs.existsSync(path.join(p, 'project.godot'))) return p;
        if (fs.existsSync(path.join(p, 'tools', 'pixel_art'))) return p;
    }
    return folders[0].uri.fsPath;
}

function outputDir(root) { return path.join(root, 'output', 'pixel_art'); }

function escapeHtml(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;')
        .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function timeAgo(ms) {
    const s = Math.floor(ms / 1000);
    if (s < 60) return s + 's ago';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    return Math.floor(s / 3600) + 'h ago';
}

// Suffixes to strip (longest first) when grouping files
const STRIP_SUFFIXES = [
    '_ls_ls_sheet', '_ls_sheet', '_verify_sheet', '_sheet_4x',
    '_gameboy_fs', '_gameboy_bayer', '_shadow_variant',
    '_sheet', '_outlined', '_preview', '_shadow',
    '_verify', '_gameboy', '_warm', '_ice', '_ls'
];

function extractSpriteName(basename) {
    let name = basename;
    let changed = true;
    while (changed) {
        changed = false;
        const dm = name.match(/_\d+x\d+$/);
        if (dm) { name = name.slice(0, -dm[0].length); changed = true; }
        for (const sfx of STRIP_SUFFIXES) {
            if (name.endsWith(sfx)) { name = name.slice(0, -sfx.length); changed = true; break; }
        }
    }
    return name;
}

function scanSprites(root) {
    const dir = outputDir(root);
    if (!fs.existsSync(dir)) return [];
    const sprites = new Map();

    for (const entry of fs.readdirSync(dir)) {
        const ext = path.extname(entry).toLowerCase();
        if (['.import', '.uid', '.tres', '.tscn'].includes(ext)) continue;
        const full = path.join(dir, entry);
        let st;
        try { st = fs.statSync(full); } catch { continue; }
        if (!st.isFile()) continue;

        const base = path.basename(entry, ext);
        const name = extractSpriteName(base);
        if (!sprites.has(name)) sprites.set(name, { name, files: {}, mtime: 0 });
        const sp = sprites.get(name);
        sp.mtime = Math.max(sp.mtime, st.mtimeMs);

        if (ext === '.ase' || ext === '.aseprite') sp.files.ase = full;
        else if (ext === '.gif') sp.files.gif = full;
        else if (ext === '.html') sp.files.preview = full;
        else if (ext === '.json') sp.files.json = full;
        else if (ext === '.png') {
            if (base.endsWith('_sheet') || base.includes('_ls_sheet') || base.includes('_verify_sheet'))
                sp.files.sheet = full;
            else if (base.endsWith('_outlined')) sp.files.outlined = full;
            else if (/_\d+x\d+$/.test(base)) sp.files.upscaled = full;
            else if (base === name) sp.files.png = full;
        }
    }

    return Array.from(sprites.values())
        .filter(s => Object.keys(s.files).length > 0)
        .sort((a, b) => b.mtime - a.mtime);
}

// ------------------------------------------------------------------
// PANEL 1: Sprite Preview — Simple <img> approach (GIF or PNG)
// ------------------------------------------------------------------
class SpritePreviewProvider {
    constructor(root) { this._root = root; this._view = null; this._currentSprite = null; }

    resolveWebviewView(webviewView) {
        this._view = webviewView;
        const outDir = outputDir(this._root);
        const roots = fs.existsSync(outDir) ? [vscode.Uri.file(outDir)] : [];
        webviewView.webview.options = { enableScripts: true, localResourceRoots: roots };
        webviewView.webview.onDidReceiveMessage(msg => this._onMessage(msg));
        this._update();
    }

    _onMessage(msg) {
        if (msg.type === 'select') { this._currentSprite = msg.name; this._update(); }
        else if (msg.type === 'libresprite') { this._openLS(msg.path); }
        else if (msg.type === 'open') {
            if (msg.path && fs.existsSync(msg.path))
                vscode.commands.executeCommand('vscode.open', vscode.Uri.file(msg.path));
        }
    }

    _openLS(asePath) {
        const exe = 'C:/Users/PGNK2128/LibreSprite/libresprite-v1.2/libresprite.exe';
        if (asePath && fs.existsSync(asePath) && fs.existsSync(exe)) {
            require('child_process').spawn(exe, [asePath], { detached: true, stdio: 'ignore' }).unref();
            vscode.window.showInformationMessage('Opening in LibreSprite: ' + path.basename(asePath));
        }
    }

    refresh() { this._update(); }
    selectSprite(name) { this._currentSprite = name; this._update(); }

    _update() {
        if (!this._view) return;
        const sprites = scanSprites(this._root);
        const wv = this._view.webview;

        let current = this._currentSprite
            ? sprites.find(s => s.name === this._currentSprite)
            : null;
        if (!current && sprites.length > 0) {
            current = sprites[0];
            this._currentSprite = current.name;
        }

        // Dropdown
        const opts = sprites.map(s => {
            const sel = s.name === this._currentSprite ? ' selected' : '';
            const anim = s.files.gif ? ' (anim)' : '';
            return '<option value="' + escapeHtml(s.name) + '"' + sel + '>'
                + escapeHtml(s.name) + anim + '</option>';
        }).join('');

        let body = '';
        if (!current) {
            body = '<p class="empty">No sprites found.<br>Run a forge script.</p>';
        } else {
            // Pick best image: GIF (animated) > upscaled PNG > base PNG > outlined
            const pick = current.files.gif || current.files.upscaled
                || current.files.png || current.files.outlined || current.files.sheet;
            const imgUri = pick ? wv.asWebviewUri(vscode.Uri.file(pick)).toString() : '';
            const isGif = !!current.files.gif && pick === current.files.gif;
            const fcount = Object.keys(current.files).length;
            const asePath = (current.files.ase || '').replace(/\\/g, '/');
            const prevPath = (current.files.preview || '').replace(/\\/g, '/');

            body = imgUri
                ? '<div class="img-wrap"><img id="mainImg" src="' + imgUri + '" class="sprite-img"></div>'
                : '<p class="empty">No image available</p>';

            body += '<div class="info">' + escapeHtml(current.name)
                + ' <span class="dim">' + fcount + ' files'
                + (isGif ? ' | animated' : '') + '</span></div>';

            body += '<div class="btns">';
            if (asePath)
                body += '<button data-act="libresprite" data-path="' + escapeHtml(asePath) + '">LibreSprite</button>';
            if (prevPath)
                body += '<button data-act="open" data-path="' + escapeHtml(prevPath) + '">HTML Preview</button>';
            body += '</div>';
        }

        this._view.webview.html = '<!DOCTYPE html><html><head><style>'
+ 'body{font-family:var(--vscode-font-family);font-size:12px;color:var(--vscode-foreground);'
+ 'background:var(--vscode-sideBar-background);padding:6px;margin:0}'
+ 'select{width:100%;padding:3px 5px;background:var(--vscode-input-background);'
+ 'color:var(--vscode-input-foreground);border:1px solid var(--vscode-input-border,#444);'
+ 'border-radius:3px;margin-bottom:6px;font-size:11px}'
+ '.img-wrap{text-align:center;background:#111;border:1px solid #333;border-radius:4px;'
+ 'padding:6px;margin-bottom:6px;max-height:180px;overflow:hidden}'
+ '.sprite-img{image-rendering:pixelated;image-rendering:crisp-edges;'
+ 'max-width:160px;max-height:160px;height:auto;display:block;margin:0 auto;object-fit:contain}'
+ '.info{font-size:11px;margin-bottom:4px}.dim{opacity:.5}'
+ '.btns{display:flex;gap:4px;flex-wrap:wrap}'
+ '.btns button{background:var(--vscode-button-secondaryBackground,#333);'
+ 'color:var(--vscode-button-secondaryForeground,#ccc);'
+ 'border:1px solid var(--vscode-panel-border,#444);border-radius:3px;'
+ 'padding:3px 8px;font-size:10px;cursor:pointer}'
+ '.btns button:hover{opacity:.85}'
+ '.empty{text-align:center;opacity:.5;font-style:italic;padding:30px 8px}'
+ '</style></head><body>'
+ '<select id="sel">' + opts + '</select>'
+ body
+ '<script>'
+ 'const V=acquireVsCodeApi();'
+ 'var sel=document.getElementById("sel");'
+ 'if(sel)sel.onchange=function(){V.postMessage({type:"select",name:sel.value})};'
+ 'document.addEventListener("click",function(e){'
+ 'var b=e.target.closest("button[data-act]");if(!b)return;'
+ 'V.postMessage({type:b.dataset.act,path:b.dataset.path})});'
+ ''
+ '</script></body></html>';
    }
}

// ------------------------------------------------------------------
// PANEL 2: Palette
// ------------------------------------------------------------------
class PaletteProvider {
    constructor(root) { this._root = root; this._view = null; }

    resolveWebviewView(wv) {
        this._view = wv;
        wv.webview.options = { enableScripts: false };
        this._update();
    }
    refresh() { this._update(); }

    _update() {
        if (!this._view) return;
        const sprites = scanSprites(this._root);
        const topName = sprites.length > 0 ? escapeHtml(sprites[0].name) : '';

        const pals = [
            { n: 'Celtic (M.E.R.L.I.N.)', c: ['#2d4832','#468c3c','#8bac50','#d2b48c','#8b5a2b','#4a3520','#c0c0c8','#b8860b','#654321','#1a1a1a'] },
            { n: 'Reigns', c: ['#1a1a2e','#e94560','#f5a623','#f7dc6f','#2ecc71','#5dade2','#ecf0f1','#8e44ad','#d35400','#2c3e50'] },
            { n: 'Game Boy', c: ['#0f380f','#306230','#8bac0f','#9bbc0f'] },
            { n: 'PICO-8', c: ['#000','#1d2b53','#7e2553','#008751','#ab5236','#5f574f','#c2c3c7','#fff1e8','#ff004d','#ffa300','#ffec27','#00e436','#29adff','#83769c','#ff77a8','#ffccaa'] },
        ];

        let html = '<!DOCTYPE html><html><head><style>'
            + 'body{font-family:var(--vscode-font-family);font-size:12px;color:var(--vscode-foreground);'
            + 'background:var(--vscode-sideBar-background);padding:8px}'
            + '.pb{margin-bottom:10px}.pn{font-size:11px;font-weight:600;margin-bottom:3px;opacity:.8}'
            + '.ps{display:flex;flex-wrap:wrap;gap:2px}'
            + '.sw{width:20px;height:20px;border-radius:2px;border:1px solid rgba(255,255,255,.15);cursor:pointer}'
            + '.sw:hover{border-color:var(--vscode-focusBorder);transform:scale(1.2)}'
            + '.hint{font-size:10px;opacity:.4;margin-bottom:10px}'
            + '</style></head><body>';

        if (topName) html += '<b>' + topName + '</b><div class="hint">Open .ase for full palette</div>';

        for (const p of pals) {
            html += '<div class="pb"><div class="pn">' + p.n + '</div><div class="ps">'
                + p.c.map(c => '<div class="sw" style="background:' + c + '" title="' + c + '"></div>').join('')
                + '</div></div>';
        }
        html += '</body></html>';
        this._view.webview.html = html;
    }
}

// ------------------------------------------------------------------
// PANEL 3: Gallery
// ------------------------------------------------------------------
class GalleryProvider {
    constructor(root) { this._root = root; this._view = null; this._previewRef = null; }
    setPreviewRef(p) { this._previewRef = p; }

    resolveWebviewView(wv) {
        this._view = wv;
        const outDir = outputDir(this._root);
        const roots = fs.existsSync(outDir) ? [vscode.Uri.file(outDir)] : [];
        wv.webview.options = { enableScripts: true, localResourceRoots: roots };
        wv.webview.onDidReceiveMessage(msg => {
            if (msg.type === 'select' && this._previewRef) this._previewRef.selectSprite(msg.name);
        });
        this._update();
    }
    refresh() { this._update(); }

    _update() {
        if (!this._view) return;
        const sprites = scanSprites(this._root);
        const wv = this._view.webview;

        if (sprites.length === 0) {
            this._view.webview.html = '<!DOCTYPE html><html><head><style>'
                + 'body{font-family:var(--vscode-font-family);color:var(--vscode-foreground);'
                + 'background:var(--vscode-sideBar-background);padding:20px;text-align:center;font-size:12px}'
                + '</style></head><body><p style="opacity:.5;font-style:italic">'
                + 'No sprites yet.</p></body></html>';
            return;
        }

        let cards = '';
        for (const s of sprites) {
            const thumb = s.files.gif || s.files.upscaled || s.files.png || s.files.outlined;
            const src = thumb ? wv.asWebviewUri(vscode.Uri.file(thumb)).toString() : '';
            const fc = Object.keys(s.files).length;
            const ago = timeAgo(Date.now() - s.mtime);
            const anim = s.files.gif ? ' | anim' : '';

            cards += '<div class="c" data-name="' + escapeHtml(s.name) + '">';
            if (src) cards += '<img src="' + src + '" class="th">';
            else cards += '<div class="th" style="background:#222;display:flex;align-items:center;'
                + 'justify-content:center;opacity:.3;font-size:16px">?</div>';
            cards += '<div><div class="n">' + escapeHtml(s.name) + '</div>'
                + '<div class="m">' + fc + ' files' + anim + ' | ' + ago + '</div></div></div>';
        }

        this._view.webview.html = '<!DOCTYPE html><html><head><style>'
            + 'body{font-family:var(--vscode-font-family);font-size:12px;color:var(--vscode-foreground);'
            + 'background:var(--vscode-sideBar-background);padding:6px}'
            + '.c{display:flex;align-items:center;gap:8px;padding:5px;border-radius:4px;cursor:pointer;'
            + 'margin-bottom:3px;border:1px solid transparent}'
            + '.c:hover{background:var(--vscode-list-hoverBackground);border-color:#444}'
            + '.th{width:40px;height:40px;border-radius:3px;image-rendering:pixelated;'
            + 'background:#1a1a1a;object-fit:contain}'
            + '.n{font-weight:600;font-size:12px}.m{font-size:10px;opacity:.5}'
            + '.hdr{font-size:10px;text-transform:uppercase;letter-spacing:.5px;opacity:.5;'
            + 'margin-bottom:5px;padding:0 5px}'
            + '</style></head><body>'
            + '<div class="hdr">' + sprites.length + ' sprite' + (sprites.length > 1 ? 's' : '') + '</div>'
            + cards
            + '<script>var V=acquireVsCodeApi();document.querySelectorAll(".c").forEach(function(c){'
            + 'c.addEventListener("click",function(){V.postMessage({type:"select",name:c.dataset.name})})})'
            + '</script></body></html>';
    }
}

// ------------------------------------------------------------------
// Activation
// ------------------------------------------------------------------
function activate(context) {
    const root = findProjectRoot();
    if (!root) { console.log('Pixel Art Preview: no project root'); return; }

    const preview = new SpritePreviewProvider(root);
    const palette = new PaletteProvider(root);
    const gallery = new GalleryProvider(root);
    gallery.setPreviewRef(preview);

    context.subscriptions.push(
        vscode.window.registerWebviewViewProvider('pixelArt.preview', preview),
        vscode.window.registerWebviewViewProvider('pixelArt.palette', palette),
        vscode.window.registerWebviewViewProvider('pixelArt.gallery', gallery)
    );

    const outDir = outputDir(root);
    if (fs.existsSync(outDir)) {
        const watcher = vscode.workspace.createFileSystemWatcher(
            new vscode.RelativePattern(outDir, '*.{png,ase,gif,json}')
        );
        const refreshAll = () => { preview.refresh(); gallery.refresh(); palette.refresh(); };
        watcher.onDidChange(refreshAll);
        watcher.onDidCreate(refreshAll);
        context.subscriptions.push(watcher);
    }

    context.subscriptions.push(
        vscode.commands.registerCommand('pixelArt.refresh', () => {
            preview.refresh(); gallery.refresh(); palette.refresh();
        }),
        vscode.commands.registerCommand('pixelArt.openInLibreSprite', () => {
            const sprites = scanSprites(root);
            if (sprites.length > 0 && sprites[0].files.ase) preview._openLS(sprites[0].files.ase);
        })
    );

    console.log('Pixel Art Preview activated — ' + outDir);
}

function deactivate() {}
module.exports = { activate, deactivate };

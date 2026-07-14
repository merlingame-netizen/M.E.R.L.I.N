#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""audio_control.py - Page HTML de controle de la bibliotheque audio M.E.R.L.I.N.

Genere un fichier HTML AUTONOME (audio embarque en base64 data-URI, zero serveur,
zero dependance, marche hors-ligne) permettant d'ecouter et de VALIDER chaque son
sans lancer le jeu. Pour chaque son : lecture, source (genere / procedural), LUFS,
true-peak, duree, et un verdict Garder / Re-generer + note. Bouton "copier mes
verdicts" -> resume a coller dans le chat pour que Claude relance les re-gens.

Usage :
  python tools/audio_control.py            # -> output/audio_control.html
  python tools/audio_control.py --open     # + ouvre dans Chrome
"""
import base64, io, json, os, sys, html, wave, contextlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "audio", "sfx")
MUSIC_DIRS = [os.path.join(ROOT, "music", "gameplay"), os.path.join(ROOT, "music", "intro")]
MANIFEST = os.path.join(SFX_DIR, "manifest.json")
OUT = os.path.join(ROOT, "output", "audio_control.html")

# Les 13 sons RICHES = generatifs (Stable Audio 3). Le reste des SFX = procedural v4.
GENERATIVE = {
    "stinger_echec", "stinger_partiel", "stinger_reussite", "stinger_eclatante",
    "stinger_fin_accomplissement", "stinger_fin_mort", "stinger_fin_corrompu",
    "magic_reveal", "draft_reveal", "whisper_threshold", "corruption_tick",
    "ink_wash", "question_transition",
}

# (titre section, [ids]) — ordre d'ecoute recommande.
SECTIONS = [
    ("Stingers de degre (generatif) - joues a CHAQUE beat", [
        "stinger_reussite", "stinger_echec", "stinger_partiel", "stinger_eclatante"]),
    ("Stingers de fin (generatif) - climax", [
        "stinger_fin_accomplissement", "stinger_fin_mort", "stinger_fin_corrompu"]),
    ("Revelations & transitions (generatif)", [
        "magic_reveal", "draft_reveal", "whisper_threshold", "corruption_tick",
        "ink_wash", "question_transition"]),
    ("Ticks UI (procedural v4 - doivent claquer sec)", [
        "card_pick", "card_pick__v2", "card_pick__v3", "card_play", "card_discard",
        "deal", "deal__v2", "deal__v3", "button_tap", "gauge_up", "gauge_down",
        "seal_stamp", "beat_turn", "slider_tick", "voice_blip", "ogham_chime"]),
]
MUSIC_IDS = ["gameplay_calm", "gameplay_falaises", "boot_eveil",
             "pad_choeur", "pad_etre", "pad_chevalier", "pad_compagnon", "pad_enfant"]


def _wav_meta(path):
    with contextlib.suppress(Exception):
        with contextlib.closing(wave.open(path, "rb")) as w:
            fr = w.getframerate() or 44100
            return {"dur": round(w.getnframes() / float(fr), 2),
                    "sr": fr, "ch": w.getnchannels()}
    return {}


def _find(path_dirs, sid):
    for d in path_dirs:
        p = os.path.join(d, sid + ".wav")
        if os.path.exists(p):
            return p
    return None


def _data_uri(path):
    with open(path, "rb") as f:
        return "data:audio/wav;base64," + base64.b64encode(f.read()).decode("ascii")


def _manifest():
    with contextlib.suppress(Exception):
        m = json.load(io.open(MANIFEST, encoding="utf-8"))
        # aplatit une eventuelle structure imbriquee
        flat = {}
        def walk(o):
            if isinstance(o, dict):
                for k, v in o.items():
                    if isinstance(v, dict) and ("lufs" in v or "true_peak" in v):
                        flat[k] = v
                    else:
                        walk(v)
            elif isinstance(o, list):
                for e in o:
                    if isinstance(e, dict) and e.get("id"):
                        flat[e["id"]] = e
                    else:
                        walk(e)
        walk(m)
        return flat
    return {}


def _card(sid, man, dirs):
    path = _find(dirs, sid)
    gen = sid in GENERATIVE
    meta = _wav_meta(path) if path else {}
    mm = man.get(sid, {})
    lufs = mm.get("lufs"); tp = mm.get("true_peak")
    badge = ("GENERE", "gen") if gen else ("PROCEDURAL", "proc")
    stats = []
    if meta.get("dur") is not None:
        stats.append("%.2fs" % meta["dur"])
    if lufs is not None:
        stats.append("%s LUFS" % lufs)
    if tp is not None:
        stats.append("TP %s" % tp)
    stats_s = " &middot; ".join(html.escape(str(s)) for s in stats) or "-"
    if path is None:
        src = ""
        missing = ' <span class="missing">(fichier absent)</span>'
    else:
        src = _data_uri(path)
        missing = ""
    return f'''
    <div class="card" data-id="{html.escape(sid)}">
      <div class="row1">
        <button class="play" onclick="play(this,'{html.escape(sid)}')" {'disabled' if not path else ''}>&#9654;</button>
        <div class="meta">
          <div class="name">{html.escape(sid)}{missing} <span class="badge {badge[1]}">{badge[0]}</span></div>
          <div class="stats">{stats_s}</div>
        </div>
      </div>
      <audio preload="none" src="{src}"></audio>
      <div class="verdict">
        <label class="opt keep"><input type="radio" name="v_{html.escape(sid)}" value="keep" checked> Garder</label>
        <label class="opt regen"><input type="radio" name="v_{html.escape(sid)}" value="regen"> Re-generer</label>
        <input class="note" type="text" placeholder="note (ex: trop court, trop metallique, plus grave...)">
      </div>
    </div>'''


def build():
    man = _manifest()
    sections_html = []
    for title, ids in SECTIONS:
        cards = "".join(_card(i, man, [SFX_DIR]) for i in ids)
        sections_html.append(f'<section><h2>{html.escape(title)}</h2><div class="grid">{cards}</div></section>')
    music_cards = "".join(_card(i, man, MUSIC_DIRS) for i in MUSIC_IDS)
    sections_html.append(f'<section><h2>Musique &amp; nappes</h2><div class="grid">{music_cards}</div></section>')
    body = "\n".join(sections_html)
    n_gen = len(GENERATIVE)
    return PAGE.replace("__BODY__", body).replace("__NGEN__", str(n_gen))


PAGE = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>M.E.R.L.I.N. - Controle Audio</title>
<style>
 :root{--bg:#14100C;--panel:#1E1A14;--surface:#2A2018;--cream:#E8DCC0;--gold:#C9A24B;
  --goldd:#8A6A2E;--green:#7FA65C;--violet:#7B4FA3;--dim:#9C8C6A;--border:#4A3B28;}
 *{box-sizing:border-box}
 body{margin:0;background:var(--bg);color:var(--cream);font-family:'Segoe UI',system-ui,sans-serif;
  font-size:15px;line-height:1.4}
 header{position:sticky;top:0;z-index:5;background:linear-gradient(180deg,#14100C,#14100Cd0);
  border-bottom:1px solid var(--border);padding:14px 20px;backdrop-filter:blur(4px)}
 h1{margin:0;font-size:20px;color:var(--gold);letter-spacing:1px}
 .sub{color:var(--dim);font-size:13px;margin-top:3px}
 main{padding:16px 20px 120px;max-width:1100px;margin:0 auto}
 h2{color:var(--gold);font-size:15px;border-left:3px solid var(--goldd);padding-left:10px;
  margin:26px 0 12px}
 .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:12px}
 .card{background:var(--panel);border:1px solid var(--border);border-radius:8px;padding:12px}
 .row1{display:flex;gap:12px;align-items:center}
 .play{flex:0 0 auto;width:44px;height:44px;border-radius:50%;border:1px solid var(--goldd);
  background:var(--surface);color:var(--gold);font-size:16px;cursor:pointer;transition:.12s}
 .play:hover{background:var(--goldd);color:#14100C}
 .play.playing{background:var(--green);color:#14100C;border-color:var(--green)}
 .play:disabled{opacity:.3;cursor:not-allowed}
 .meta{min-width:0}
 .name{font-weight:600;font-size:14px;word-break:break-word}
 .stats{color:var(--dim);font-size:12px;margin-top:2px}
 .badge{font-size:10px;padding:2px 6px;border-radius:4px;vertical-align:middle;margin-left:4px;letter-spacing:.5px}
 .badge.gen{background:#3a2d10;color:var(--gold);border:1px solid var(--goldd)}
 .badge.proc{background:#242018;color:var(--dim);border:1px solid var(--border)}
 .missing{color:var(--violet);font-size:11px}
 .verdict{margin-top:10px;display:flex;gap:8px;align-items:center;flex-wrap:wrap}
 .opt{font-size:12px;color:var(--dim);cursor:pointer;padding:3px 8px;border-radius:4px;border:1px solid transparent}
 .opt input{vertical-align:middle;margin-right:3px}
 .opt.keep input:checked ~ *,.card:has(.keep input:checked) .keep{color:var(--green)}
 .card:has(.regen input:checked){border-color:var(--gold)}
 .card:has(.regen input:checked) .regen{color:var(--gold);font-weight:600}
 .note{flex:1 1 120px;min-width:100px;background:var(--surface);border:1px solid var(--border);
  color:var(--cream);border-radius:4px;padding:5px 8px;font-size:12px}
 footer{position:fixed;bottom:0;left:0;right:0;background:#1E1A14;border-top:1px solid var(--border);
  padding:12px 20px;display:flex;gap:12px;align-items:center;justify-content:space-between}
 .fcount{color:var(--dim);font-size:13px}
 .btn{background:var(--gold);color:#14100C;border:none;border-radius:6px;padding:10px 16px;
  font-weight:600;cursor:pointer;font-size:14px}
 .btn:hover{background:#e0b85f}
 .btn.ghost{background:transparent;color:var(--gold);border:1px solid var(--goldd)}
 #copied{color:var(--green);font-size:13px;opacity:0;transition:.3s}
</style></head><body>
<header>
 <h1>M.E.R.L.I.N. &mdash; Controle Audio</h1>
 <div class="sub">Ecoute et valide chaque son sans lancer le jeu. __NGEN__ sons riches generes (Stable Audio 3), le reste procedural. Marque "Re-generer" + une note, puis copie tes verdicts.</div>
</header>
<main>__BODY__</main>
<footer>
 <div><span class="fcount" id="fcount"></span> <span id="copied">copie !</span></div>
 <div style="display:flex;gap:10px">
  <button class="btn ghost" onclick="stopAll()">Stop</button>
  <button class="btn" onclick="copyVerdicts()">Copier mes verdicts</button>
 </div>
</footer>
<script>
 var cur=null,curBtn=null;
 function stopAll(){if(cur){cur.pause();cur.currentTime=0;}if(curBtn){curBtn.classList.remove('playing');}cur=null;curBtn=null;}
 function play(btn,id){
   var card=btn.closest('.card');var au=card.querySelector('audio');
   if(cur===au){stopAll();return;}
   stopAll();cur=au;curBtn=btn;btn.classList.add('playing');
   au.currentTime=0;au.play();
   au.onended=function(){btn.classList.remove('playing');cur=null;curBtn=null;};
 }
 function refresh(){
   var regen=document.querySelectorAll('.regen input:checked').length;
   document.getElementById('fcount').textContent=regen+' son(s) marque(s) a re-generer';
 }
 document.addEventListener('change',refresh);refresh();
 function copyVerdicts(){
   var out=['# Verdicts audio M.E.R.L.I.N.',''];var any=false;
   document.querySelectorAll('.card').forEach(function(c){
     var id=c.dataset.id;var regen=c.querySelector('.regen input').checked;
     var note=c.querySelector('.note').value.trim();
     if(regen){any=true;out.push('- RE-GENERER '+id+(note?' : '+note:''));}
   });
   if(!any)out.push('(rien a re-generer : tout est garde)');
   var txt=out.join('\\n');
   navigator.clipboard.writeText(txt).then(function(){
     var c=document.getElementById('copied');c.style.opacity=1;setTimeout(function(){c.style.opacity=0;},1800);
   },function(){prompt('Copie manuelle :',txt);});
 }
 window.addEventListener('keydown',function(e){if(e.code==='Space'&&document.activeElement.tagName!=='INPUT'){e.preventDefault();}});
</script>
</body></html>"""


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    doc = build()
    with io.open(OUT, "w", encoding="utf-8") as f:
        f.write(doc)
    size = os.path.getsize(OUT)
    print("ecrit : %s (%.1f Mo)" % (OUT, size / 1e6))
    if "--open" in sys.argv:
        os.system('cmd.exe /c start chrome "%s"' % OUT)

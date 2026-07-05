#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""render_prose_report.py — JSON de probe_prose.gd → rapport HTML (DA flat MERLIN).

Affiche TOUTE la prose d'un run (intro, situations, combinaisons, résolutions
procédurales + LLM, épilogue) avec étiquettes pour que l'utilisateur contrôle et
dise quoi ajuster. Chaque bloc porte un identifiant (ex. « RÉSO-LLM B3 »).

    python tools/render_prose_report.py
"""
from __future__ import annotations
import html
import json
import sys
from pathlib import Path

DOWN = Path.home() / "Downloads"
JSON_PATH = DOWN / "merlin_prose_run.json"
HTML_PATH = DOWN / "merlin_prose_report.html"

DEG_CLASS = {"echec": "echec", "partiel": "partiel", "reussite": "reussite", "eclatante": "eclatante"}
DEG_LABEL = {"echec": "Échec", "partiel": "Partiel", "reussite": "Réussite", "eclatante": "Éclatante"}


def esc(s: object) -> str:
    return html.escape(str(s)) if s is not None else ""


def prose(label: str, text: str, kind: str) -> str:
    """kind: 'proc' (procédural) ou 'llm'."""
    if text and str(text).strip():
        body = esc(text).replace("\n", "<br>")
    else:
        body = '<span class="empty">(vide — non généré par le LLM)</span>'
    return (f'<div class="prose {kind}"><div class="ptag {kind}">{esc(label)}</div>'
            f'<div class="ptxt">{body}</div></div>')


def tags_html(tags: list) -> str:
    return '<div class="tags">' + "".join(f'<span class="tag">{esc(t)}</span>' for t in (tags or [])) + "</div>"


def syn_txt(s: int) -> str:
    if s > 0:
        return '<span class="syn pos">synergie +1 · combinaison cohérente</span>'
    if s < 0:
        return '<span class="syn neg">synergie −1 · combinaison dispersée</span>'
    return '<span class="syn zero">synergie 0 · neutre</span>'


CSS = """
:root{--bg:#1E1A14;--bg2:#17130D;--surface:#2A2018;--line:#3A3228;--text:#E8DCC0;--dim:#9C8C6A;
--ink:#2A2018;--inkdim:#6E5A3C;--gold:#C9A24B;--goldb:#E3C170;--green:#7FA65C;--violet:#7B4FA3;
--mono:'Consolas','SF Mono','Courier New',monospace;}
*{box-sizing:border-box;margin:0;padding:0}
body{background:var(--bg);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;line-height:1.6;padding:44px 20px;}
.wrap{max-width:940px;margin:0 auto;}
.hdr{border-bottom:2px solid var(--gold);padding-bottom:22px;}
.wordmark{font-family:var(--mono);font-size:13px;letter-spacing:9px;color:var(--gold);text-transform:uppercase;}
.hdr h1{font-size:26px;font-weight:600;margin:12px 0 6px;}
.hdr .meta{font-family:var(--mono);font-size:12px;color:var(--dim);}
.legend{display:flex;gap:14px;flex-wrap:wrap;background:var(--bg2);border:1px solid var(--line);padding:14px 18px;margin:24px 0;font-size:13px;}
.legend b{color:var(--goldb);}
.legend .chip{font-family:var(--mono);font-size:10px;padding:2px 8px;border-left:3px solid;text-transform:uppercase;letter-spacing:1px;}
.legend .chip.proc{border-color:var(--inkdim);color:var(--dim);}
.legend .chip.llm{border-color:var(--gold);color:var(--goldb);}
.badge{display:inline-block;font-family:var(--mono);font-size:11px;padding:3px 10px;border:1px solid var(--line);}
.badge.ok{color:var(--green);border-color:var(--green);}
.badge.warn{color:var(--goldb);border-color:var(--gold);}
.sec{margin:34px 0;}
.sec-title{font-family:var(--mono);font-size:12px;letter-spacing:3px;color:var(--gold);text-transform:uppercase;border-bottom:1px solid var(--line);padding-bottom:9px;margin-bottom:16px;}
.beat{background:var(--surface);border:1px solid var(--line);margin-bottom:24px;padding:0;}
.beat-head{display:flex;justify-content:space-between;align-items:center;padding:14px 20px;border-bottom:1px solid var(--line);flex-wrap:wrap;gap:8px;}
.beat-head .t{font-weight:600;font-size:15px;}
.beat-head .t small{color:var(--dim);font-family:var(--mono);font-size:11px;font-weight:400;}
.beat-body{padding:16px 20px;}
.row{margin:14px 0;}
.row-k{font-family:var(--mono);font-size:10px;letter-spacing:2px;text-transform:uppercase;color:var(--dim);margin-bottom:7px;}
.deg{font-family:var(--mono);font-size:11px;letter-spacing:1px;text-transform:uppercase;padding:4px 10px;border-left:3px solid;font-weight:700;}
.deg.eclatante{color:var(--green);border-color:var(--green);background:rgba(127,166,92,.10);}
.deg.reussite{color:var(--goldb);border-color:var(--gold);background:rgba(201,162,75,.10);}
.deg.partiel{color:#c4b48f;border-color:var(--inkdim);background:rgba(110,90,60,.18);}
.deg.echec{color:#bd95d6;border-color:var(--violet);background:rgba(123,79,163,.15);}
.syn{font-family:var(--mono);font-size:11px;margin-left:10px;}
.syn.pos{color:var(--green);} .syn.neg{color:var(--violet);} .syn.zero{color:var(--dim);}
.tags{display:flex;gap:5px;flex-wrap:wrap;}
.tag{font-family:var(--mono);font-size:10px;background:var(--bg2);border:1px solid var(--line);color:var(--dim);padding:2px 8px;}
.prose{margin:8px 0;}
.prose .ptag{font-family:var(--mono);font-size:9.5px;letter-spacing:1.5px;text-transform:uppercase;padding:3px 9px;display:inline-block;margin-bottom:-1px;border:1px solid;border-bottom:none;}
.prose.proc .ptag{color:var(--inkdim);border-color:var(--inkdim);background:rgba(110,90,60,.12);}
.prose.llm .ptag{color:#5a431d;border-color:var(--gold);background:var(--gold);}
.prose .ptxt{background:var(--text);color:var(--ink);padding:14px 16px;border:1px solid var(--inkdim);font-size:14.5px;line-height:1.7;}
.prose.llm .ptxt{border-color:var(--gold);border-left:4px solid var(--gold);}
.prose .empty{color:#9a3b3b;font-style:italic;font-family:var(--mono);font-size:13px;}
.combo{display:flex;gap:10px;flex-wrap:wrap;}
.card{background:var(--bg2);border:1px solid var(--line);padding:10px 12px;min-width:180px;flex:1;}
.card .nm{color:var(--goldb);font-weight:600;font-size:13px;margin-bottom:3px;}
.card .ev{color:var(--text);font-size:12px;font-style:italic;margin-bottom:6px;}
.objbox{background:rgba(201,162,75,.10);border-left:3px solid var(--gold);padding:12px 16px;margin:8px 0;color:var(--goldb);font-size:14px;}
footer{text-align:center;color:var(--dim);font-size:11px;font-family:var(--mono);border-top:1px solid var(--line);padding-top:20px;margin-top:40px;}
"""


def render(d: dict) -> str:
    llm_ready = bool(d.get("llm_ready"))
    model = d.get("model") or {}
    model_name = model.get("name") or model.get("model") or "Gemma 4 E2B"
    p: list = [f"""<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>M.E.R.L.I.N. — Prose du run (contrôle)</title><style>{CSS}</style></head><body><div class="wrap">"""]

    p.append(f"""<header class="hdr">
<div class="wordmark">M · E · R · L · I · N</div>
<h1>Prose du run — relecture &amp; ajustements</h1>
<div class="meta">généré {esc(d.get('generated_at',''))} &nbsp;·&nbsp; moteur {esc(model_name)} &nbsp;·&nbsp;
{'<span class="badge ok">LLM actif</span>' if llm_ready else '<span class="badge warn">LLM indisponible — procédural seul</span>'}
&nbsp; {'<span class="badge warn">capture partielle (run interrompu)</span>' if d.get('status') == 'interrupted' else '<span class="badge ok">run complet</span>'}</div>
</header>""")

    p.append("""<div class="legend">
<div><span class="chip proc">Procédural</span> &nbsp;texte garanti, affiché d'emblée en jeu (éditable dans <b>merlin_scenario.gd</b>)</div>
<div><span class="chip llm">LLM — combinaison</span> &nbsp;enrichissement génératif, remplace si arrivé à temps (prompt éditable)</div>
<div style="width:100%;color:var(--dim);font-size:12px;margin-top:4px">Pour ajuster : cite l'identifiant du bloc (ex. « RÉSO-LLM B3 trop long »).</div>
</div>""")

    intro = d.get("intro") or {}
    p.append('<section class="sec"><div class="sec-title">Intro de quête</div>')
    if intro.get("title"):
        p.append(f'<div style="font-size:18px;color:var(--goldb);margin-bottom:8px">« {esc(intro.get("title"))} »</div>')
    if intro.get("objectif"):
        p.append(f'<div class="objbox">✦ Objectif : {esc(intro.get("objectif"))}</div>')
    p.append(prose("INTRO — procédural", intro.get("procedural", ""), "proc"))
    p.append(prose("INTRO-LLM", intro.get("llm", ""), "llm"))
    p.append('</section>')

    p.append('<section class="sec"><div class="sec-title">Beats</div>')
    for b in d.get("beats", []):
        n = b.get("n", "?")
        deg = b.get("degree", "")
        dcl = DEG_CLASS.get(deg, "partiel")
        dlb = DEG_LABEL.get(deg, esc(b.get("label", deg)))
        p.append('<div class="beat">')
        p.append(f"""<div class="beat-head">
<div class="t">Beat {esc(n)} — {esc(b.get('type',''))} <small>diff {esc(b.get('difficulte',1))}</small></div>
<div><span class="deg {dcl}">{dlb}</span>{syn_txt(int(b.get('synergy',0)))}</div>
</div><div class="beat-body">""")
        p.append(f'<div class="row"><div class="row-k">Le moment appelle</div>{tags_html(b.get("required"))}</div>')
        p.append(f'<div class="row"><div class="row-k">Situation — procédural (SITU B{esc(n)})</div>{prose("affiché en jeu", b.get("situation",""), "proc")}</div>')
        combo = b.get("combo") or []
        cards = "".join(
            f'<div class="card"><div class="nm">{esc(c.get("name",""))}</div>'
            f'<div class="ev">{esc(c.get("evocation",""))}</div>{tags_html(c.get("tags"))}</div>'
            for c in combo)
        p.append(f'<div class="row"><div class="row-k">Combinaison jouée ({len(combo)} carte(s))</div><div class="combo">{cards}</div></div>')
        p.append('<div class="row"><div class="row-k">Résolution</div>')
        p.append(prose(f"RÉSO-PROC B{esc(n)}", b.get("resolution_procedural", ""), "proc"))
        p.append(prose(f"RÉSO-LLM B{esc(n)}", b.get("resolution_llm", ""), "llm"))
        p.append('</div>')
        p.append(f'<div class="row" style="color:var(--dim);font-family:var(--mono);font-size:11px">→ après ce beat : Vie {esc(b.get("integrite","?"))}/10 · Corruption {esc(b.get("corruption","?"))}/18</div>')
        p.append('</div></div>')
    p.append('</section>')

    epi = d.get("epilogue") or {}
    fin = d.get("final") or {}
    p.append('<section class="sec"><div class="sec-title">Épilogue</div>')
    if d.get("status") == "interrupted":
        p.append('<div style="background:rgba(201,162,75,.10);border-left:3px solid var(--gold);padding:10px 14px;margin-bottom:10px;font-size:13px;color:var(--goldb)">Run interrompu (le moteur a stallé avant la fin) — l\'épilogue n\'a pas été atteint. Les 3 épilogues procéduraux figurent dans le catalogue ci-dessous.</div>')
    p.append(f'<div style="font-family:var(--mono);font-size:12px;color:var(--dim);margin-bottom:8px">fin : <b style="color:var(--text)">{esc(epi.get("end_type","") or "—")}</b> · Vie {esc(fin.get("integrite","?"))}/10 · Corruption {esc(fin.get("corruption","?"))}/18 · {esc(fin.get("beats","?"))} beats</div>')
    p.append(prose("ÉPILOGUE — procédural", epi.get("procedural", ""), "proc"))
    p.append(prose("ÉPILOGUE-LLM", epi.get("llm", ""), "llm"))
    p.append('</section>')

    # --- Catalogue procédural complet (toutes les variantes authored) ---
    cat = d.get("catalog") or {}
    if cat:
        p.append('<section class="sec"><div class="sec-title">Catalogue procédural — toutes les variantes</div>')
        p.append('<div style="color:var(--dim);font-size:12px;margin-bottom:14px">Textes garantis (tirés au sort en jeu), éditables dans <b style="color:var(--goldb)">merlin_scenario.gd</b> — SITU_FALLBACKS_BY_BIOME / RESO_FALLBACKS / fallback_epilogue.</div>')
        # N2a — situations désormais nichées par BIOME : {biome: {type: [variantes]}}.
        for biome, by_type in (cat.get("situations") or {}).items():
            for typ, variants in (by_type or {}).items():
                p.append(f'<div class="row"><div class="row-k">Situation · {esc(biome)} · {esc(typ)}</div>')
                for i, v in enumerate(variants or []):
                    p.append(prose(f"SITU {esc(biome)}/{esc(typ)} #{i + 1}", v, "proc"))
                p.append('</div>')
        for deg, variants in (cat.get("resolutions") or {}).items():
            p.append(f'<div class="row"><div class="row-k">Résolution · {esc(DEG_LABEL.get(deg, deg))}</div>')
            for i, v in enumerate(variants or []):
                p.append(prose(f"RÉSO {esc(deg)} #{i + 1}", v, "proc"))
            p.append('</div>')
        epis = cat.get("epilogues") or {}
        if epis:
            p.append('<div class="row"><div class="row-k">Épilogues (par fin)</div>')
            for et, txt in epis.items():
                p.append(prose(f"ÉPILOGUE {esc(et)}", txt, "proc"))
            p.append('</div>')
        p.append('</section>')

    # --- Direction LLM (system prompt) ---
    sysp = d.get("system_prefix") or ""
    if sysp:
        p.append('<section class="sec"><div class="sec-title">Direction LLM — system prompt</div>')
        p.append(f'<div class="prose llm"><div class="ptag llm">SYSTEM-PREFIX</div><div class="ptxt">{esc(sysp).replace(chr(10), "<br>")}</div></div>')
        p.append('<div style="color:var(--dim);font-size:12px;margin-top:8px">Préfixe envoyé à CHAQUE génération. Le prompt spécifique de la résolution-combinaison est construit dans <b style="color:var(--goldb)">narrate_resolution()</b>.</div>')
        p.append('</section>')

    p.append(f'<footer>M.E.R.L.I.N. — prose capturée par probe_prose.gd · rendue par render_prose_report.py · {esc(d.get("generated_at",""))}</footer>')
    p.append('</div></body></html>')
    return "".join(p)


def main() -> int:
    if not JSON_PATH.exists():
        print(f"[ERR] {JSON_PATH} introuvable — lance d'abord probe_prose.gd")
        return 1
    data = json.loads(JSON_PATH.read_text(encoding="utf-8"))
    HTML_PATH.write_text(render(data), encoding="utf-8")
    n_beats = len(data.get("beats", []))
    print(f"[OK] {HTML_PATH} ({n_beats} beats, llm_ready={data.get('llm_ready')})")
    return 0


if __name__ == "__main__":
    sys.exit(main())

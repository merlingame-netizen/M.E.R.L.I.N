#!/usr/bin/env python3
"""La chronique imagée d'une partie : une page autonome, beat par beat, avec ses clichés.

    python3 tools/chronique_imagee.py --journal journal.json --selection selection.json \
        --cliches dossier/ --id p104 --sortie /chemin/docs/chroniques/p104

POURQUOI. Le journal de la sonde dit tout (textes, gestes, dé, marge, jauges, temps), les clichés
montrent tout, mais rien ne les tenait ensemble : la liseuse du Studio lit le journal sans les
images, et les images sans le journal sont des écrans muets. Ici la page est ÉCRITE une fois,
autonome (images en base64, aucun fichier à côté), et rangée dans docs/chroniques/<id>/ du dépôt
du jeu avec le journal — la liseuse du Studio y lit la même partie.

CE QUE LA PAGE DIT, dans l'ordre : les trois sentiers proposés et celui qui a été pris, l'intro,
puis chaque beat (la scène, le geste et ses tags, ce que le bot visait, le dé, le total contre le
DC, la marge, le degré, l'issue, les jauges avant et après, la durée du beat et l'attente du
moteur), les étals, les incidents, la fin, et un bilan chiffré. Les temps viennent de l'horloge de
la sonde : rien n'est estimé.
"""
from __future__ import annotations

import argparse
import re
import base64
import html
import json
import pathlib
import shutil
import statistics

DEGRE_FR = {"eclatante": "éclatante", "reussite": "réussite", "partiel": "partiel", "echec": "échec"}
COULEUR = {"eclatante": "#E8DCC0", "reussite": "#C9A24B", "partiel": "#8A6A2E", "echec": "#7B4FA3"}


def _img(chemin: pathlib.Path) -> str:
    try:
        return "data:image/png;base64," + base64.b64encode(chemin.read_bytes()).decode("ascii")
    except OSError:
        return ""


_BBCODE = re.compile(r"\[/?[a-z_]+(?:=[^\]]*)?\]")


def _s(v) -> str:
    # Le jeu écrit du BBCode ([center], [i], [color=…]) : la page le retire, elle ne l'affiche pas.
    return html.escape(_BBCODE.sub("", str(v if v is not None else "")).strip())


def _duree(s: float) -> str:
    s = int(round(s))
    if s < 60:
        return "%d s" % s
    return "%d min %02d s" % (s // 60, s % 60)


def _cliches(dossier: pathlib.Path) -> dict:
    """{ "beat_03": chemin, "beat_03_issue": chemin, "intro": …, "fin": … } — le numéro de prise
    (« 07_ ») est retiré : c'est le nom qui dit ce que montre l'image."""
    out = {}
    if dossier is None or not dossier.is_dir():
        return out
    for f in sorted(dossier.glob("*.png")):
        nom = f.stem
        if "_" in nom and nom.split("_", 1)[0].isdigit():
            nom = nom.split("_", 1)[1]
        out[nom] = f
    return out


def rendre(journal: dict, selection: dict, cliches: dict, ident: str) -> str:
    beats = journal.get("beats") or []
    fin = journal.get("fin") or {}
    sentiers = selection.get("sentiers") or journal.get("sentiers") or []
    pick = int(journal.get("pick", 0) or 0)
    durees = [float(b.get("duree_beat_s", 0)) for b in beats if b.get("duree_beat_s")]
    attentes = [float(b.get("attente_moteur_s", 0)) for b in beats if "attente_moteur_s" in b]
    degres = {}
    for b in beats:
        d = str(b.get("degre", ""))
        if d:
            degres[d] = degres.get(d, 0) + 1
    banc = sum(1 for b in beats if b.get("secours") or "secours" in str(b.get("provenance", "")))
    sans_jet = sum(1 for b in beats if b.get("geste_sur"))
    total_s = sum(durees) + 35.0 * max(len(durees) - 1, 0)   # la sonde lit 35 s chaque issue

    parts = []
    parts.append('''<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Chronique %s</title>
<style>
:root{--bg:#17130D;--ink:#E8DCC0;--dim:#9C8C6A;--gold:#C9A24B;--gold2:#8A6A2E;--violet:#7B4FA3;--cream:#E8DCC0;--panel:#1E1A14}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 Georgia,"Times New Roman",serif}
main{max-width:1100px;margin:0 auto;padding:28px 20px 80px}
h1{font-weight:normal;color:var(--gold);font-size:34px;margin:0 0 4px}
h2{font-weight:normal;color:var(--gold);font-size:22px;margin:40px 0 12px;border-bottom:1px solid #3A3228;padding-bottom:6px}
.mut{color:var(--dim)} .k{color:var(--gold)}
.bilan{display:flex;flex-wrap:wrap;gap:14px 28px;margin:14px 0 6px}
.bilan div b{display:block;font-size:22px;color:var(--cream)}
.sentiers{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}
.sentier{background:var(--panel);border:1px solid #3A3228;padding:14px 16px;border-radius:6px}
.sentier.pris{border-color:var(--gold)}
.sentier h3{margin:0 0 6px;font-weight:normal;color:var(--gold);font-size:19px}
.beat{background:var(--panel);border:1px solid #3A3228;border-radius:6px;padding:16px 18px;margin:18px 0}
.beat header{display:flex;flex-wrap:wrap;gap:8px 18px;align-items:baseline;margin-bottom:8px}
.beat header .n{font-size:20px;color:var(--gold)}
.badge{display:inline-block;padding:1px 8px;border-radius:10px;border:1px solid #3A3228;font-size:13px;color:var(--dim)}
.images{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:10px 0}
.images img{width:100%%;border:1px solid #3A3228;border-radius:4px;background:#000}
@media(max-width:800px){.images{grid-template-columns:1fr}}
.prose{margin:8px 0;white-space:pre-wrap}
.issue{margin:8px 0;padding:10px 14px;border-left:3px solid var(--gold2);white-space:pre-wrap}
.geste{display:flex;flex-wrap:wrap;gap:8px 22px;margin:8px 0;font-size:15px}
.geste span b{color:var(--cream)}
.temps{color:var(--dim);font-size:14px}
table{border-collapse:collapse;width:100%%;font-size:14px} td,th{padding:5px 8px;border-bottom:1px solid #3A3228;text-align:left} th{color:var(--dim);font-weight:normal}
.degre{font-weight:bold}
</style></head><body><main>''' % _s(ident))

    # ── en-tête et bilan
    titre = sentiers[pick]["titre"] if 0 <= pick < len(sentiers) else journal.get("titre", "Traversée")
    parts.append('<h1>%s</h1><div class="mut">Chronique %s · partie entièrement générée par le moteur du jeu · biome %s · %s</div>'
                 % (_s(titre), _s(ident), _s(journal.get("biome", selection.get("biome", ""))), _s(journal.get("t", selection.get("t", "")))))
    parts.append('<div class="bilan">')
    parts.append('<div><span class="mut">beats joués</span><b>%d</b></div>' % len(beats))
    parts.append('<div><span class="mut">durée de jeu</span><b>%s</b></div>' % _duree(total_s))
    if attentes:
        parts.append('<div><span class="mut">attente du moteur, médiane</span><b>%s</b></div>' % _duree(statistics.median(attentes)))
        parts.append('<div><span class="mut">attente au plus long</span><b>%s</b></div>' % _duree(max(attentes)))
    parts.append('<div><span class="mut">au banc</span><b>%d</b></div>' % banc)
    parts.append('<div><span class="mut">sans jet</span><b>%d</b></div>' % sans_jet)
    for k in ("eclatante", "reussite", "partiel", "echec"):
        if degres.get(k):
            parts.append('<div><span class="mut">%s</span><b style="color:%s">%d</b></div>' % (DEGRE_FR[k], COULEUR[k], degres[k]))
    parts.append('<div><span class="mut">fin</span><b>%s</b></div>' % _s(fin.get("type", "en cours")))
    parts.append('</div>')
    if selection.get("mur_ms"):
        parts.append('<div class="temps">Les trois sentiers ont été écrits en %s.</div>' % _duree(float(selection["mur_ms"]) / 1000.0))

    # ── les trois sentiers
    parts.append('<h2>Les trois sentiers que Merlin a rêvés</h2><div class="sentiers">')
    for i, st in enumerate(sentiers):
        parts.append('<div class="sentier%s"><h3>%s</h3><div>%s</div>%s</div>' % (
            " pris" if i == pick else "", _s(st.get("titre", "")), _s(st.get("pitch", "")),
            '<div class="mut" style="margin-top:8px">← pris%s</div>' % (" : " + _s(journal.get("motif_du_choix", "")) if journal.get("motif_du_choix") else "") if i == pick else ""))
    parts.append('</div>')

    # ── l'intro
    if journal.get("intro") or "intro" in cliches:
        parts.append('<h2>L\'ouverture</h2>')
        if "intro" in cliches:
            parts.append('<div class="images"><img src="%s" alt="ouverture"></div>' % _img(cliches["intro"]))
        if journal.get("intro"):
            parts.append('<div class="prose">%s</div><div class="temps">%s</div>' % (
                _s(journal["intro"]), "légende écrite par le modèle" if journal.get("intro_du_modele") else "cadrage en dur"))

    # ── les beats
    parts.append('<h2>La traversée, beat par beat</h2>')
    for b in beats:
        i = int(b.get("index", 0))
        deg = str(b.get("degre", ""))
        parts.append('<div class="beat"><header><span class="n">Beat %d</span><span class="badge">%s</span>'
                     % (i, _s(b.get("type", ""))))
        parts.append('<span class="badge">difficulté %s</span>' % _s(b.get("difficulte", "?")))
        prov = str(b.get("provenance", ""))
        if prov:
            parts.append('<span class="badge">%s</span>' % _s(prov))
        if b.get("secours"):
            parts.append('<span class="badge" style="color:var(--violet)">au banc</span>')
        parts.append('<span class="temps">intégrité %s → %s · corruption %s → %s · bourse %s</span></header>' % (
            _s(b.get("integrite_avant", "?")), _s(b.get("integrite_apres", "?")),
            _s(b.get("corruption_avant", "?")), _s(b.get("corruption_apres", "?")), _s(b.get("gwenneg_apres", "?"))))
        cl1 = cliches.get("beat_%02d" % i)
        cl2 = cliches.get("beat_%02d_issue" % i)
        if cl1 or cl2:
            parts.append('<div class="images">')
            if cl1:
                parts.append('<img src="%s" alt="beat %d, la scène">' % (_img(cl1), i))
            if cl2:
                parts.append('<img src="%s" alt="beat %d, le verdict et l\'issue">' % (_img(cl2), i))
            parts.append('</div>')
        parts.append('<div class="prose">%s</div>' % _s(b.get("narration", "")))
        req = b.get("tags_requis") or []
        if req:
            parts.append('<div class="temps">le lieu réclame : %s</div>' % _s(" · ".join(map(str, req))))
        g = b.get("geste") or {}
        if g:
            parts.append('<div class="geste"><span>tuile <b>%s</b> %s</span><span>rune <b>%s</b> %s</span>' % (
                _s(g.get("action", "")), _s("(" + ", ".join(map(str, g.get("action_tags") or [])) + ")" if g.get("action_tags") else ""),
                _s(g.get("trait", "")), _s("(" + ", ".join(map(str, g.get("trait_tags") or [])) + ")" if g.get("trait_tags") else "")))
            cb = b.get("choix_du_bot") or {}
            if cb:
                parts.append('<span class="mut">le bot visait : %s couvert(s), %s prévu%s</span>' % (
                    _s(cb.get("couverture", "?")), _s(DEGRE_FR.get(str(cb.get("degre_prevu", "")), cb.get("degre_prevu", "?"))),
                    ", geste sûr" if cb.get("geste_sur") else ""))
            parts.append('</div>')
        if deg:
            if b.get("geste_sur"):
                compte = "sans jet"
            elif b.get("total") is not None and b.get("dc"):
                de = int(b.get("de", 0) or 0)
                total = int(b.get("total", 0) or 0)
                compte = "%d + %d contre %d : %+d" % (de, total - de, int(b.get("dc", 0)), int(b.get("marge", total - int(b.get("dc", 0)))))
            else:
                compte = "dé %s" % _s(b.get("de", "?"))
            parts.append('<div class="geste"><span class="degre" style="color:%s">%s</span><span>%s</span>%s</div>' % (
                COULEUR.get(deg, "var(--dim)"), _s(DEGRE_FR.get(deg, deg)), _s(compte),
                '<span class="mut">%s</span>' % _s(b.get("phrase_geste", "")) if b.get("phrase_geste") else ""))
        if b.get("resolution"):
            parts.append('<div class="issue">%s</div>' % _s(b.get("resolution", "")))
        gen = b.get("gen") or {}
        temps = []
        if b.get("duree_beat_s"):
            temps.append("beat : %s" % _duree(float(b["duree_beat_s"])))
        if "attente_moteur_s" in b:
            temps.append("attente du moteur : %s" % _duree(float(b["attente_moteur_s"])))
        if gen:
            for k in ("tok_s", "tokens_s", "eval_tok_s"):
                if gen.get(k):
                    temps.append("%.1f tok/s" % float(gen[k]))
                    break
            if gen.get("prompt_ms") or gen.get("prompt_s"):
                temps.append("prompt : %s" % _duree(float(gen.get("prompt_s") or float(gen.get("prompt_ms", 0)) / 1000.0)))
        if temps:
            parts.append('<div class="temps">%s</div>' % _s(" · ".join(temps)))
        parts.append('</div>')

    # ── les étals, les incidents
    etals = journal.get("etals") or []
    if etals:
        parts.append('<h2>Les étals</h2><table><tr><th>après le beat</th><th>articles</th><th>achats</th></tr>')
        for e in etals:
            parts.append('<tr><td>%s</td><td>%s</td><td>%s</td></tr>' % (
                _s(e.get("apres_beat", "")), _s(", ".join(map(str, e.get("articles") or [])) or e.get("resume", "")), _s(e.get("achats", e.get("achete", "")))))
        parts.append('</table>')
    incidents = journal.get("incidents") or []
    if incidents:
        parts.append('<h2>Les incidents</h2><table><tr><th>beat</th><th>quoi</th></tr>')
        for inc in incidents:
            parts.append('<tr><td>%s</td><td>%s</td></tr>' % (_s(inc.get("beat", "")), _s(inc.get("quoi", ""))))
        parts.append('</table>')

    # ── la fin
    parts.append('<h2>La fin</h2>')
    if "fin" in cliches:
        parts.append('<div class="images"><img src="%s" alt="la fin"></div>' % _img(cliches["fin"]))
    parts.append('<div class="bilan"><div><span class="mut">issue</span><b>%s</b></div><div><span class="mut">intégrité</span><b>%s</b></div><div><span class="mut">corruption</span><b>%s</b></div></div>' % (
        _s(fin.get("type", "en cours")), _s(fin.get("integrite", "?")), _s(fin.get("corruption", "?"))))
    if fin.get("resume"):
        parts.append('<div class="prose">%s</div>' % _s(fin["resume"]))
    if fin.get("faits_marquants"):
        parts.append('<div class="mut">Faits marquants : %s</div>' % _s(" · ".join(map(str, fin["faits_marquants"]))))

    # ── le tableau des temps
    if beats:
        parts.append('<h2>Les temps, beat par beat</h2><table><tr><th>beat</th><th>type</th><th>degré</th><th>durée</th><th>attente du moteur</th><th>banc</th></tr>')
        for b in beats:
            parts.append('<tr><td>%d</td><td>%s</td><td style="color:%s">%s</td><td>%s</td><td>%s</td><td>%s</td></tr>' % (
                int(b.get("index", 0)), _s(b.get("type", "")), COULEUR.get(str(b.get("degre", "")), "inherit"),
                _s(DEGRE_FR.get(str(b.get("degre", "")), b.get("degre", ""))),
                _duree(float(b.get("duree_beat_s", 0))) if b.get("duree_beat_s") else "",
                _duree(float(b.get("attente_moteur_s", 0))) if "attente_moteur_s" in b else "",
                "oui" if b.get("secours") else ""))
        parts.append('</table>')
    parts.append('<div class="mut" style="margin-top:30px">Journal de la sonde probe_partie_journal.gd ; les temps sont ceux de son horloge. La lecture de chaque issue (35 s) est celle d\'un humain simulé.</div>')
    parts.append('</main></body></html>')
    return "\n".join(parts)


def main() -> int:
    p = argparse.ArgumentParser(description="La chronique imagée d'une partie")
    p.add_argument("--journal", required=True)
    p.add_argument("--selection", default="")
    p.add_argument("--cliches", default="")
    p.add_argument("--id", required=True)
    p.add_argument("--sortie", required=True, help="dossier de la chronique (docs/chroniques/<id>)")
    a = p.parse_args()
    journal = json.load(open(a.journal, encoding="utf-8"))
    selection = json.load(open(a.selection, encoding="utf-8")) if a.selection else {}
    cliches = _cliches(pathlib.Path(a.cliches)) if a.cliches else {}
    out = pathlib.Path(a.sortie)
    out.mkdir(parents=True, exist_ok=True)
    (out / "index.html").write_text(rendre(journal, selection, cliches, a.id), encoding="utf-8")
    shutil.copy(a.journal, out / "journal.json")
    if a.selection:
        shutil.copy(a.selection, out / "selection.json")
    print("chronique %s : %d beats, %d clichés → %s" % (a.id, len(journal.get("beats") or []), len(cliches), out / "index.html"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Rend le journal d'une partie (JSON + captures) en un document HTML autonome.

POURQUOI. `probe_partie_journal.gd` enregistre tout ce qu'une partie a vecu, mais un JSON de
plusieurs centaines de lignes ne se lit pas : on veut voir CE QUE LE JEU RACONTE, beat par beat,
et pouvoir juger sur piece. Ce script fait la traduction.

  python3 tools/journal_html.py journal.json --cliches dossier/ --sortie partie.html

Les images sont embarquees en data: — le fichier doit tenir seul (contrainte Artifact).
"""
from __future__ import annotations

import argparse
import base64
import html
import json
import pathlib
import re

# Degres du resolveur, avec leur libelle lisible. L'ordre compte : il sert aussi de legende.
DEGRES = {
    "eclatante": ("Éclatante", "eclat"),
    "reussite": ("Réussite", "reussite"),
    "partiel": ("Partiel", "partiel"),
    "echec": ("Échec", "echec"),
}


def bbcode(txt: str) -> str:
    """Le jeu ecrit en BBCode (Godot RichTextLabel). On garde l'italique et le centrage, on jette
    le reste : un document lisible n'a pas a montrer les balises du moteur."""
    t = html.escape(txt or "")
    t = re.sub(r"\[/?center\]", "", t)
    t = re.sub(r"\[i\](.*?)\[/i\]", r"<em>\1</em>", t, flags=re.S)
    t = re.sub(r"\[b\](.*?)\[/b\]", r"<strong>\1</strong>", t, flags=re.S)
    t = re.sub(r"\[color=[^\]]*\](.*?)\[/color\]", r"\1", t, flags=re.S)
    t = re.sub(r"\[/?[a-z][^\]]*\]", "", t)
    paras = [p.strip() for p in t.split("\n\n") if p.strip()]
    return "\n".join("<p>%s</p>" % p.replace("\n", "<br>") for p in paras)


def puces(items: list, vide: str) -> str:
    if not items:
        return '<p class="vide">%s</p>' % html.escape(vide)
    return "<ul>%s</ul>" % "".join("<li>%s</li>" % html.escape(str(i)) for i in items)


def tags(lst) -> str:
    if not lst:
        return ""
    return "".join('<span class="tag">%s</span>' % html.escape(str(t)) for t in lst)


def image(chemin: pathlib.Path) -> str:
    if not chemin.exists():
        return ""
    mime = "image/jpeg" if chemin.suffix.lower() in (".jpg", ".jpeg") else "image/png"
    b64 = base64.b64encode(chemin.read_bytes()).decode()
    return "data:%s;base64,%s" % (mime, b64)


def jauge(valeur: int, maxi: int, classe: str) -> str:
    pct = 0 if maxi <= 0 else max(0, min(100, round(100.0 * valeur / maxi)))
    return ('<span class="jauge %s"><span class="jauge-plein" style="width:%d%%"></span></span>'
            % (classe, pct))


def rendre(d: dict, dossier_cliches: pathlib.Path | None) -> str:
    choisi = d.get("choisi") or {}
    fin = d.get("fin") or {}
    beats = d.get("beats") or []
    cliches = {c["nom"]: pathlib.Path(c["fichier"]) for c in (d.get("cliches") or [])}
    # Les incidents portent le numero du beat pendant lequel ils sont survenus : on les remet a
    # leur place dans le recit plutot que de les entasser en fin de document.
    par_beat: dict = {}
    for inc in (d.get("incidents") or []):
        par_beat.setdefault(int(inc.get("beat", 0)), []).append(str(inc.get("quoi", "")))
    if dossier_cliches:
        for p in sorted(dossier_cliches.glob("*")):
            nom = re.sub(r"^\d+_", "", p.stem)
            cliches.setdefault(nom, p)

    # --- Les trois sentiers, celui joue marque -------------------------------------------
    sentiers = []
    for i, s in enumerate(d.get("sentiers") or []):
        pris = (i == int(d.get("pick", -1)))
        sentiers.append(
            '<li class="sentier%s"><span class="sentier-num">%d</span>'
            '<div><h3>%s</h3><p>%s</p>%s</div></li>' % (
                " pris" if pris else "", i,
                html.escape(s.get("titre", "")), html.escape(s.get("pitch", "")),
                '<p class="motif">%s</p>' % html.escape(d.get("motif_du_choix", ""))
                if pris and d.get("motif_du_choix") else ""))

    # --- Les beats ------------------------------------------------------------------------
    blocs = []
    for b in beats:
        deg = str(b.get("degre", ""))
        lib, cls = DEGRES.get(deg, ("En cours", "encours"))
        geste = b.get("geste") or {}
        iav, iap = int(b.get("integrite_avant", 0)), int(b.get("integrite_apres", b.get("integrite_avant", 0)))
        cav, cap = int(b.get("corruption_avant", 0)), int(b.get("corruption_apres", b.get("corruption_avant", 0)))
        dint, dcor = iap - iav, cap - cav
        img = ""
        cle = "beat_%02d" % int(b.get("index", 0))
        if cle in cliches:
            src = image(cliches[cle])
            if src:
                img = '<figure class="cliche"><img src="%s" alt="Le jeu au beat %d"></figure>' % (
                    src, int(b.get("index", 0)))
        marque = ('<p class="secours">Issue servie par le banc de secours — le modèle n\'a pas '
                  'rendu à temps.</p>') if b.get("secours") else ""
        # CE QUI ÉTAIT POSSIBLE, pas seulement ce qui a été joué : sans la main et les tuiles, on
        # lit une histoire, on ne contrôle pas un jeu. La carte choisie est marquée.
        choisi_a = str((b.get("geste") or {}).get("action", ""))
        choisi_t = str((b.get("geste") or {}).get("trait", ""))
        dispo = []
        for t in (b.get("tuiles") or []):
            nom = str(t.get("nom", ""))
            dispo.append('<span class="dispo%s">%s</span>' % (
                " pris" if nom == choisi_a else "", html.escape(nom)))
        for c in (b.get("main") or []):
            nom = str(c.get("nom", ""))
            cor = int(c.get("corruption", 0))
            dispo.append('<span class="dispo trait%s">%s%s</span>' % (
                " pris" if nom == choisi_t else "", html.escape(nom),
                (" +%d✦" % cor) if cor else ""))
        main_html = ('<div class="dispos"><span class="geste-l">Disponible</span>%s</div>'
                     % "".join(dispo)) if dispo else ""
        incs = par_beat.get(int(b.get("index", 0)), [])
        inc_html = ('<ul class="incidents">%s</ul>'
                    % "".join("<li>%s</li>" % html.escape(i) for i in incs)) if incs else ""
        blocs.append("""
<article class="beat">
  <div class="rail">
    <span class="beat-num">%(idx)02d</span>
    <span class="beat-type">%(type)s</span>
    <div class="rail-jauges">
      <span class="rail-l">PV</span>%(jint)s<span class="rail-v">%(iap)d</span>
      <span class="rail-l">Cor</span>%(jcor)s<span class="rail-v">%(cap)d</span>
    </div>
  </div>
  <div class="corps">
    <div class="narration">%(narration)s</div>
    %(img)s
    <div class="geste">
      <span class="geste-l">Geste</span>
      <span class="chip chip-action">%(action)s</span>
      <span class="chip chip-trait">%(trait)s</span>
      <span class="mecanique">dé %(de)d · difficulté %(diff)d</span>
      %(reqs)s
    </div>
    %(main)s
    %(incidents_beat)s
    <div class="issue">
      <span class="degre %(cls)s">%(lib)s</span>
      <span class="delta">%(dint)s PV · %(dcor)s corruption</span>
      %(marque)s
      %(resolution)s
    </div>
  </div>
</article>""" % {
            "idx": int(b.get("index", 0)),
            "type": html.escape(str(b.get("type", "") or "beat")),
            "jint": jauge(iap, 10, "j-int"), "jcor": jauge(cap, 18, "j-cor"),
            "iap": iap, "cap": cap,
            "narration": bbcode(str(b.get("narration", ""))) or '<p class="vide">Aucune narration enregistrée.</p>',
            "img": img,
            "action": html.escape(str(geste.get("action", "—"))),
            "trait": html.escape(str(geste.get("trait", "—"))),
            "de": int(b.get("de", 0)), "diff": int(b.get("difficulte", 0)),
            "reqs": ('<span class="reqs">demande %s</span>' % tags(b.get("tags_requis"))) if b.get("tags_requis") else "",
            "cls": cls, "lib": lib,
            "dint": ("%+d" % dint) if dint else "0",
            "dcor": ("%+d" % dcor) if dcor else "0",
            "resolution": bbcode(str(b.get("resolution", ""))),
            "marque": marque,
            "main": main_html,
            "incidents_beat": inc_html,
        })

    img_fin = ""
    if "fin" in cliches:
        src = image(cliches["fin"])
        if src:
            img_fin = '<figure class="cliche"><img src="%s" alt="Écran de fin"></figure>' % src

    verbes = fin.get("usage_verbes") or {}
    verbes_html = "".join(
        '<div class="verbe"><span>%s</span><b>%s</b></div>' % (html.escape(k), v)
        for k, v in sorted(verbes.items(), key=lambda kv: -int(kv[1])) if int(v) > 0)

    # Substitution par regex et NON par l'operateur % : la feuille de style est pleine de
    # pourcents litteraux (width:100%, 50%, @media) que le formatage % de Python prendrait pour
    # des marqueurs. Les doubler partout serait un piege permanent a la moindre retouche CSS.
    return _remplir(TEMPLATE, {
        "titre_quete": html.escape(choisi.get("titre", "Partie sans titre")),
        "pitch_quete": html.escape(choisi.get("pitch", "")),
        "biome": html.escape(str(d.get("biome", ""))),
        "date": html.escape(str(d.get("t", ""))[:16].replace("T", " à ")),
        "nb_beats": len(beats),
        "fin_type": html.escape(str(fin.get("type", "")) or "partie interrompue"),
        "integrite": int(fin.get("integrite", 0)),
        "corruption": int(fin.get("corruption", 0)),
        "sentiers": "".join(sentiers),
        "intro": (('<p class="secours">Cadrage servi par le banc de secours — la légende du modèle '
                   "n'était pas prête.</p>") if d.get("intro_du_modele") is False else "")
                 + (bbcode(str(d.get("intro", ""))) or '<p class="vide">Aucune ouverture enregistrée.</p>'),
        "beats": "".join(blocs) or '<p class="vide">Aucun beat joué.</p>',
        "img_fin": img_fin,
        "resume": bbcode(str(fin.get("resume", ""))),
        "faits": puces(fin.get("faits_marquants") or [], "Aucun fait marquant enregistré."),
        "choix": puces(fin.get("choix_cles") or [], "Aucun choix clé enregistré."),
        "pnj": puces(fin.get("pnj_rencontres") or [], "Aucune rencontre enregistrée."),
        "incidents": puces([i.get("quoi") for i in (d.get("incidents") or [])], "Aucun."),
        "verbes": verbes_html or '<p class="vide">Aucun verbe joué.</p>',
    })


def _remplir(gabarit: str, valeurs: dict) -> str:
    def cle(m):
        v = valeurs.get(m.group(1))
        if v is None:
            return m.group(0)
        return str(v)
    return re.sub(r"%\((\w+)\)[sd]", cle, gabarit)


TEMPLATE = """<title>%(titre_quete)s</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,600&family=Spectral:ital,wght@0,400;0,600;1,400&family=IBM+Plex+Mono:wght@400;600&display=swap">
<style>
:root{
  --pierre:#E9EBE4; --surface:#F4F5F0; --encre:#1A211C; --brume:#6B776E;
  --mousse:#4C6B54; --or:#9C7A33; --oxyde:#8A3B33; --trait:#CFD5CA;
  --d-eclat:#9C7A33; --d-reussite:#3E7D5A; --d-partiel:#7A7F6B; --d-echec:#8A3B33;
}
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --pierre:#131A15; --surface:#1B231D; --encre:#DDE3DA; --brume:#8D9A90;
    --mousse:#7FA588; --or:#C9A45E; --oxyde:#C4665C; --trait:#2C3730;
    --d-eclat:#C9A45E; --d-reussite:#6FB48C; --d-partiel:#9AA391; --d-echec:#C4665C;
  }
}
:root[data-theme="dark"]{
  --pierre:#131A15; --surface:#1B231D; --encre:#DDE3DA; --brume:#8D9A90;
  --mousse:#7FA588; --or:#C9A45E; --oxyde:#C4665C; --trait:#2C3730;
  --d-eclat:#C9A45E; --d-reussite:#6FB48C; --d-partiel:#9AA391; --d-echec:#C4665C;
}
*{box-sizing:border-box}
body{margin:0;background:var(--pierre);color:var(--encre);
  font:400 17px/1.65 Spectral,Georgia,serif;-webkit-font-smoothing:antialiased}
.page{max-width:62rem;margin:0 auto;padding:clamp(1.5rem,4vw,4rem) clamp(1rem,4vw,2.5rem) 6rem}
h1,h2,h3{font-family:Fraunces,Georgia,serif;font-weight:600;text-wrap:balance;margin:0}
.eyebrow{font:600 .72rem/1 "IBM Plex Mono",monospace;letter-spacing:.14em;
  text-transform:uppercase;color:var(--mousse)}
header.tete{border-bottom:2px solid var(--mousse);padding-bottom:2rem;margin-bottom:2.5rem}
header.tete h1{font-size:clamp(2.1rem,6vw,3.4rem);line-height:1.05;margin:.6rem 0 .5rem}
header.tete .pitch{font-style:italic;color:var(--brume);font-size:1.15rem;max-width:44ch}
.meta{display:flex;flex-wrap:wrap;gap:1.5rem;margin-top:1.5rem;
  font:400 .82rem/1.4 "IBM Plex Mono",monospace;color:var(--brume)}
.meta b{display:block;color:var(--encre);font-weight:600;font-size:1.05rem;
  font-variant-numeric:tabular-nums}
section{margin:3.5rem 0}
section>h2{font-size:1.5rem;margin-bottom:1.2rem;padding-bottom:.5rem;
  border-bottom:1px solid var(--trait)}
ol.sentiers{list-style:none;padding:0;margin:0;display:grid;gap:.9rem}
.sentier{display:flex;gap:1rem;padding:1.1rem 1.2rem;background:var(--surface);
  border:1px solid var(--trait);border-radius:3px}
.sentier.pris{border-color:var(--mousse);border-left:4px solid var(--mousse)}
.sentier-num{font:600 .8rem/1 "IBM Plex Mono",monospace;color:var(--brume);padding-top:.35rem}
.sentier h3{font-size:1.12rem}
.sentier p{margin:.3rem 0 0;color:var(--brume);font-size:.97rem}
.sentier .motif{margin-top:.7rem;padding-top:.7rem;border-top:1px dashed var(--trait);
  color:var(--encre);font-style:italic;font-size:.92rem}
.beat{display:grid;grid-template-columns:7.5rem 1fr;gap:1.5rem;padding:2rem 0;
  border-top:1px solid var(--trait)}
.rail{position:sticky;top:1rem;align-self:start}
.beat-num{display:block;font:600 2.2rem/1 Fraunces,Georgia,serif;color:var(--mousse);
  font-variant-numeric:tabular-nums}
.beat-type{display:block;margin-top:.2rem;font:400 .7rem/1.3 "IBM Plex Mono",monospace;
  letter-spacing:.08em;text-transform:uppercase;color:var(--brume)}
.rail-jauges{margin-top:1rem;display:grid;grid-template-columns:auto 1fr auto;
  gap:.35rem .4rem;align-items:center;
  font:400 .68rem/1 "IBM Plex Mono",monospace;color:var(--brume)}
.rail-v{font-variant-numeric:tabular-nums;color:var(--encre)}
.jauge{display:block;height:4px;background:var(--trait);border-radius:2px;overflow:hidden}
.jauge-plein{display:block;height:100%;background:var(--mousse)}
.j-cor .jauge-plein{background:var(--oxyde)}
.narration{max-width:64ch}
.narration p{margin:0 0 .9rem}
.geste{display:flex;flex-wrap:wrap;align-items:center;gap:.5rem;margin:1.2rem 0;
  padding:.8rem 1rem;background:var(--surface);border:1px solid var(--trait);border-radius:3px;
  font:400 .8rem/1.4 "IBM Plex Mono",monospace}
.geste-l{color:var(--brume);letter-spacing:.1em;text-transform:uppercase;font-size:.68rem}
.chip{padding:.2rem .6rem;border:1px solid var(--mousse);border-radius:2px;font-weight:600}
.chip-trait{border-style:dashed}
.mecanique,.reqs{color:var(--brume);font-variant-numeric:tabular-nums}
.tag{display:inline-block;margin-left:.3rem;padding:.1rem .4rem;background:var(--trait);
  border-radius:2px;font-size:.72rem}
.issue{border-left:3px solid var(--trait);padding-left:1rem;max-width:64ch}
.degre{display:inline-block;font:600 .72rem/1 "IBM Plex Mono",monospace;letter-spacing:.1em;
  text-transform:uppercase;padding:.3rem .6rem;border-radius:2px;color:var(--pierre)}
.eclat{background:var(--d-eclat)} .reussite{background:var(--d-reussite)}
.partiel{background:var(--d-partiel)} .echec{background:var(--d-echec)}
.encours{background:var(--brume)}
.delta{margin-left:.7rem;font:400 .78rem/1 "IBM Plex Mono",monospace;color:var(--brume);
  font-variant-numeric:tabular-nums}
.issue p{margin:.8rem 0 0}
.cliche{margin:1.2rem 0}
.cliche img{width:100%;height:auto;border:1px solid var(--trait);border-radius:3px;display:block}
.grille{display:grid;grid-template-columns:repeat(auto-fit,minmax(15rem,1fr));gap:1.5rem}
.grille h3{font-size:1rem;margin-bottom:.5rem;color:var(--mousse)}
.grille ul{margin:0;padding-left:1.1rem}
.grille li{margin-bottom:.4rem;font-size:.95rem}
.verbes{display:flex;flex-wrap:wrap;gap:.6rem}
.verbe{padding:.4rem .8rem;background:var(--surface);border:1px solid var(--trait);
  border-radius:2px;font:400 .8rem/1 "IBM Plex Mono",monospace}
.verbe b{margin-left:.4rem;font-variant-numeric:tabular-nums}
.vide{color:var(--brume);font-style:italic}
.ouverture{max-width:64ch;font-size:1.06rem;padding:1.3rem 1.5rem;background:var(--surface);
  border-left:3px solid var(--or);border-radius:0 3px 3px 0}
.ouverture p{margin:0 0 .8rem}.ouverture p:last-child{margin:0}
.dispos{display:flex;flex-wrap:wrap;align-items:center;gap:.4rem;margin:-.6rem 0 1.1rem;
  padding:.6rem 1rem;font:400 .74rem/1.5 "IBM Plex Mono",monospace}
.dispo{padding:.15rem .5rem;border:1px solid var(--trait);border-radius:2px;color:var(--brume)}
.dispo.trait{border-style:dashed}
.dispo.pris{border-color:var(--mousse);color:var(--encre);font-weight:600;background:var(--surface)}
.incidents{margin:0 0 1.1rem;padding-left:1.1rem;color:var(--brume);
  font:400 .82rem/1.6 "IBM Plex Mono",monospace}
.secours{margin:.7rem 0 0;padding:.45rem .7rem;background:var(--oxyde);color:var(--pierre);
  border-radius:2px;font:600 .74rem/1.4 "IBM Plex Mono",monospace}
footer{margin-top:4rem;padding-top:1.5rem;border-top:1px solid var(--trait);
  font:400 .78rem/1.6 "IBM Plex Mono",monospace;color:var(--brume)}
@media(max-width:40rem){
  .beat{grid-template-columns:1fr;gap:.8rem}
  .rail{position:static;display:flex;align-items:baseline;gap:.8rem}
  .beat-num{font-size:1.6rem}.rail-jauges{margin:0 0 0 auto}
}
</style>
<div class="page">
<header class="tete">
  <p class="eyebrow">Journal de partie · M.E.R.L.I.N.</p>
  <h1>%(titre_quete)s</h1>
  <p class="pitch">%(pitch_quete)s</p>
  <div class="meta">
    <span>Biome<b>%(biome)s</b></span>
    <span>Beats joués<b>%(nb_beats)d</b></span>
    <span>Fin<b>%(fin_type)s</b></span>
    <span>Intégrité<b>%(integrite)d / 10</b></span>
    <span>Corruption<b>%(corruption)d</b></span>
    <span>Jouée le<b>%(date)s</b></span>
  </div>
</header>

<section>
  <h2>Les trois sentiers proposés</h2>
  <ol class="sentiers">%(sentiers)s</ol>
</section>

<section>
  <h2>L'ouverture</h2>
  <div class="ouverture">%(intro)s</div>
</section>

<section>
  <h2>Le déroulé</h2>
  %(beats)s
</section>

<section>
  <h2>La clôture</h2>
  %(img_fin)s
  <div class="issue">%(resume)s</div>
  <div class="grille" style="margin-top:2rem">
    <div><h3>Faits marquants</h3>%(faits)s</div>
    <div><h3>Choix clés</h3>%(choix)s</div>
    <div><h3>Rencontres</h3>%(pnj)s</div>
    <div><h3>Incidents de partie</h3>%(incidents)s</div>
  </div>
  <h3 style="margin-top:2rem;font-family:Fraunces,serif;font-size:1rem;color:var(--mousse)">Verbes joués</h3>
  <div class="verbes">%(verbes)s</div>
</section>

<footer>
  Partie jouée par un harnais automatique sur la VM Oracle, en rendu réel, avec le modèle
  embarqué dans le jeu. Les trois sentiers, les narrations et les résolutions sont écrits par ce
  modèle — rien n'est pré-rédigé.<br><br>
  <strong>Ce que le harnais ne fait pas :</strong> il ne joue pas bien. Les gestes (action + trait)
  tournent en rotation, sans stratégie, et devant un pacte il prend systématiquement la
  <em>première</em> option — celle qui coûte de la corruption. Une fin corrompue dit donc autant
  sur cette politique de choix que sur l'équilibrage du jeu. Lire ce document comme un relevé de
  ce que le jeu PRODUIT, jamais comme une mesure de sa difficulté.
</footer>
</div>
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("journal")
    ap.add_argument("--cliches", default="")
    ap.add_argument("--sortie", required=True)
    a = ap.parse_args()
    d = json.loads(pathlib.Path(a.journal).read_text(encoding="utf-8"))
    dossier = pathlib.Path(a.cliches) if a.cliches else None
    if dossier is not None and not dossier.is_dir():
        dossier = None
    pathlib.Path(a.sortie).write_text(rendre(d, dossier), encoding="utf-8")
    print("écrit : %s (%d beats)" % (a.sortie, len(d.get("beats") or [])))


if __name__ == "__main__":
    main()

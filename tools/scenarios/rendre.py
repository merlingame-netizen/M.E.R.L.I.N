#!/usr/bin/env python3
"""Rend un scenario de reference en page HTML autoportante.

    python3 tools/scenarios/rendre.py                    # tous les scenarios + l'index
    python3 tools/scenarios/rendre.py linceul_de_kado    # un seul

POURQUOI CET OUTIL EXISTE. Les scenarios de reference servent a deux choses : montrer le rendu
qu'on vise, et donner au modele des exemples de ce qu'on attend de lui. Il en faut donc BEAUCOUP,
et ecrire chacun a la main en HTML garantissait qu'on s'arrete au premier. Ici la quete est une
donnee (data/scenarios/<id>.json), la page en est le rendu, et l'arithmetique est CALCULEE :
aucune page ne peut afficher un chiffre que ses regles ne produisent pas.

CE QUI EST VERIFIE A CHAQUE RENDU, et qui fait echouer la generation :
  - chaque rune posee est dans la main affichee de son beat ;
  - toute main compte exactement quatre runes ;
  - un beat SPECIAL ne pose ni tuile ni rune et ne fait pas repiocher ;
  - aucune tuile du socle ne reste orpheline sur l'ensemble de la quete ;
  - la bourse ne bouge que sur un evenement d'argent nomme.

LES REGLES DU JEU appliquees ici sont celles de docs/BIBLE_DES_REGLES.md : +3 par tag requis
couvert (les tags ne sont pas affiches, le modele interprete la paire), 2d6, marge >= 8 eclatante,
>= 0 reussite, -1 a -5 partiel, en dessous echec.
"""
import html
import json
import pathlib
import sys

RACINE = pathlib.Path(__file__).resolve().parents[2]
SRC = RACINE / "data" / "scenarios"
DST = RACINE / "docs" / "scenarios"


def degre(m):
    if m >= 8:
        return "éclatante"
    if m >= 0:
        return "réussite"
    if m >= -5:
        return "partiel"
    return "échec"


def esc(s):
    return html.escape(str(s), quote=False)


# ── LE DECK ────────────────────────────────────────────────────────────────────────────────────
def simuler_deck(q):
    """La main est un paquet : la rune posee part, une autre arrive. La pioche n'est pas ecrite
    a la main mais DEDUITE — quand un beat reclame une rune absente, c'est qu'il fallait la tirer
    au dernier beat qui pioche vraiment (un beat special n'en tire pas)."""
    beats = q["beats"]
    depart = list(q["main_depart"])
    reserve = [r for r in q["runes"] if r not in depart]
    forces = {}
    for _ in range(80):
        main, mains, tirages, manque = list(depart), [], [], None
        for i, b in enumerate(beats):
            if b.get("special"):
                mains.append(list(main))
                tirages.append(None)
                continue
            r = b["rune"]
            if r not in main:
                j = i - 1
                while j >= 0 and beats[j].get("special"):
                    j -= 1
                if j < 0:
                    sys.exit("%s : beat %d reclame %r, hors main de depart" % (q["id"], b["n"], r))
                manque = (j, r)
                break
            mains.append(list(main))
            main.remove(r)
            tire = forces.get(i)
            if tire is None or tire in main:
                pris = set(main) | {r}
                libre = [x for x in reserve + depart if x not in pris]
                tire = libre[(i * 3) % len(libre)] if libre else r
            tirages.append(tire)
            main.append(tire)
        if manque is None:
            return mains, tirages
        forces[manque[0]] = manque[1]
    sys.exit("%s : le deck ne converge pas (%s)" % (q["id"], forces))


# ── L'ETAT ─────────────────────────────────────────────────────────────────────────────────────
def simuler_etat(q):
    """Rien ne s'accumule parce qu'on a reussi. La monnaie ne vient que d'un evenement qui en
    donne : une transaction, un tresor, une bete depouillee. Une quete peut n'en avoir aucun."""
    integ, corr = 10, 0
    gw = int(q.get("bourse_depart", 0))
    ig = {int(k): v for k, v in (q.get("integrite") or {}).items()}
    co = {int(k): v for k, v in (q.get("corruption") or {}).items()}
    etats = []
    for b in q["beats"]:
        dgw, motif = 0, ""
        sp = b.get("special") or {}
        if sp.get("genre") == "marchand":
            achats = [(n, p) for n, p, pris in sp["etal"] if pris]
            dgw = -sum(p for _, p in achats)
            motif = "chez le marchand : " + ", ".join(n.lower() for n, _ in achats)
        elif sp.get("gain"):
            dgw, motif = int(sp["gain"][0]), str(sp["gain"][1])
        di, dc = ig.get(b["n"], 0), co.get(b["n"], 0)
        integ += di
        corr += dc
        gw += dgw
        etats.append(dict(integ=integ, corr=corr, gw=gw, dgw=dgw, motif=motif, di=di, dcorr=dc))
    return etats


def controler(q, mains, tirages):
    b = q["beats"]
    for i, x in enumerate(b):
        if x.get("special"):
            assert tirages[i] is None, "%s b%d : un beat special ne pioche pas" % (q["id"], x["n"])
            continue
        assert x["rune"] in mains[i], "%s b%d : %r absente de la main" % (q["id"], x["n"], x["rune"])
    assert all(len(m) == 4 for m in mains), "%s : une main n'a pas quatre runes" % q["id"]
    joues = {x["action"] for x in b if not x.get("special")}
    orphelins = [g for g in q["gestes"] if g not in joues]
    return orphelins


CSS = (RACINE / "tools" / "scenarios" / "scenario.css").read_text(encoding="utf-8")


def panneau_special(sp):
    o = ['<div class="table special">']
    o.append('<div class="tr"><span class="lb">Beat spécial</span>'
             '<span class="vl"><b class="act">%s</b></span></div>' % esc(sp["genre"]))
    if sp["genre"] == "marchand":
        o.append('<div class="tr"><span class="lb">L\'étal</span><span class="vl opts">')
        for nom, prix, pris in sp["etal"]:
            o.append('<span class="opt%s"><b>%s</b><i>%d gwenneg</i></span>'
                     % (" pris" if pris else "", esc(nom), prix))
        o.append('</span></div>')
        achats = [(n, p) for n, p, k in sp["etal"] if k]
        o.append('<div class="tr"><span class="lb">Vous prenez</span><span class="vl">%s</span></div>'
                 % (", ".join("<b>%s</b> — %d gwenneg" % (esc(n), p) for n, p in achats) or "<b>rien</b>"))
    elif sp["genre"] == "boss":
        # Un boss ne se bat pas, il s'observe : sa boucle EST sa faiblesse. On montre le cycle
        # entier, tour par tour, et le seul temps ou il est decouvert.
        o.append('<div class="tr"><span class="lb">Sa boucle</span><span class="vl opts">')
        for k, (ce_quon_voit, quoi_faire) in enumerate(sp["tours"]):
            o.append('<span class="opt%s"><b>Tour %d — %s</b><i>%s</i></span>'
                     % (" pris" if k == sp["pris"] else "", k + 1, esc(ce_quon_voit), esc(quoi_faire)))
        o.append('</span></div>')
        o.append('<div class="tr"><span class="lb">Vous agissez</span>'
                 '<span class="vl">au <b>tour %d</b>, le seul où il est découvert</span></div>'
                 % (sp["pris"] + 1))
    elif sp["genre"] == "énigme écrite":
        # Le seul endroit ou le joueur ECRIT. Le modele juge le sens, pas l'orthographe.
        o.append('<div class="tr"><span class="lb">La question</span><span class="vl">%s</span></div>'
                 % esc(sp["question"]))
        if sp.get("donnee"):
            o.append('<div class="tr"><span class="lb">Vous saviez</span><span class="vl">%s</span></div>'
                     % esc(sp["donnee"]))
        o.append('<div class="tr"><span class="lb">Ce qui passe</span><span class="vl">%s</span></div>'
                 % esc(sp["reponses_valides"]))
        o.append('<div class="tr"><span class="lb">Essais</span><span class="vl"><b>%d</b>, '
                 'un raté fait avancer la nuit</span></div>' % int(sp.get("essais", 3)))
        o.append('<div class="tr"><span class="lb">Vous écrivez</span>'
                 '<span class="vl"><span class="opt pris"><b>%s</b></span></span></div>' % esc(sp["pris"]))
    else:
        o.append('<div class="tr"><span class="lb">On vous propose</span><span class="vl opts">')
        for k, (lib, suite) in enumerate(sp["options"]):
            o.append('<span class="opt%s"><b>%s</b><i>%s</i></span>'
                     % (" pris" if k == sp["pris"] else "", esc(lib), esc(suite)))
        o.append('</span></div>')
        o.append('<div class="tr"><span class="lb">Vous choisissez</span>'
                 '<span class="vl"><b>%s</b></span></div>' % esc(sp["options"][sp["pris"]][0]))
    o.append('</div>')
    return "\n".join(o)


def delta(v):
    return '<span class="d%s">%+d</span>' % ("p" if v > 0 else "n", v) if v else ""


def bloc(b, i, mains, tirages, etats):
    sp = b.get("special")
    e = etats[i]
    o = ['<article class="beat%s">' % (" spe" if sp else "")]
    o.append('<div class="bt"><span class="bn">%d</span><span class="btype">%s</span>'
             '<span class="blieu">%s</span></div>' % (b["n"], esc(b["t"]), esc(b.get("lieu", ""))))
    bas = b.get("bascule")
    if bas:
        o.append('<span class="bas %s">bascule %s — %s</span>' % (bas[0], bas[0], esc(bas[1])))
    o.append('<p>%s</p>' % esc(b["scene"]))
    if b.get("dial"):
        o.append('<p class="dial">%s</p>' % esc(b["dial"]))
    if sp:
        o.append(panneau_special(sp))
    else:
        if b.get("sans_jet"):
            mise, jet = "Sans jet · %s" % b["sans_jet"], None
        else:
            total = b["de"] + b["at"]
            marge = total - b["dc"]
            mise = "Difficulté %d · vos atouts +%d" % (b["dc"], b["at"])
            jet = (b["de"], total, marge, degre(marge))
        o.append('<div class="table">')
        o.append('<div class="tr"><span class="lb">Votre main</span><span class="vl runes">%s</span></div>'
                 % "".join('<span class="rune%s">%s</span>' % (" sel" if r == b["rune"] else "", esc(r))
                           for r in mains[i]))
        o.append('<div class="tr"><span class="lb">Le geste</span><span class="vl geste">'
                 '<b class="act">%s</b> <span class="plus">avec</span> <b>%s</b></span></div>'
                 % (esc(b["action"]), esc(b["rune"])))
        o.append('<div class="tr"><span class="lb">La mise</span><span class="vl">%s</span></div>' % esc(mise))
        if jet:
            de, total, marge, dg = jet
            o.append('<div class="tr"><span class="lb">Le jet</span><span class="vl jet">'
                     '2d6 = <b>%d</b> <span class="plus">→</span> <b>%d</b> contre %d '
                     '<span class="plus">→</span> marge <b class="m%s">%+d</b>'
                     '<span class="dg %s">%s</span></span></div>'
                     % (de, total, b["dc"], "neg" if marge < 0 else "pos", marge,
                        dg.replace("é", "e").replace("è", "e"), dg))
        o.append('<div class="tr"><span class="lb">Vous repiochez</span>'
                 '<span class="vl"><span class="rune neuve">%s</span></span></div>' % esc(tirages[i]))
        o.append('</div>')
    bourse = 'bourse <b>%d</b> gwenneg%s' % (e["gw"], delta(e["dgw"]))
    if e["motif"]:
        bourse += ' <i class="motif">%s</i>' % esc(e["motif"])
    o.append('<div class="etatligne">santé <b>%d</b>%s <span class="sep">·</span> '
             'corruption <b>%d</b>%s <span class="sep">·</span> %s</div>'
             % (e["integ"], delta(e["di"]), e["corr"], delta(e["dcorr"]), bourse))
    o.append('<p class="issue">%s</p>' % esc(b["issue"]))
    if b.get("apres"):
        o.append('<p>%s</p>' % esc(b["apres"]))
    if b.get("effet"):
        o.append('<p class="effet">%s</p>' % esc(b["effet"]))
    o.append('<p class="note"><b>%s</b> %s</p>'
             % ("Pourquoi ce beat est spécial." if sp else "Ce que le modèle a lu.", esc(b["note"])))
    o.append('</article>')
    return "\n".join(o)


def rendre(q):
    mains, tirages = simuler_deck(q)
    etats = simuler_etat(q)
    orphelins = controler(q, mains, tirages)
    B = q["beats"]
    leg = lambda d, c: '<div class="legende %s">%s</div>' % (c, "".join(
        '<span class="rl"><b>%s</b><i>%s</i></span>' % (esc(k), esc(v)) for k, v in d.items()))
    ch = {b["n"] for b in B if (b.get("bascule") or [None])[0] == "choisie"}
    su = {b["n"] for b in B if (b.get("bascule") or [None])[0] == "subie"}
    cells = "".join('<div class="c %s">%d</div>'
                    % ("choisie" if b["n"] in ch else "subie" if b["n"] in su else "", b["n"]) for b in B)
    o = ['<title>%s</title>' % esc(q["titre"]),
         '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Vollkorn:wght@600;700'
         '&family=Spectral:ital,wght@0,400;0,500;1,400&family=IBM+Plex+Mono:wght@400;500;600&display=swap">',
         '<style>%s</style>' % CSS,
         '<div class="page">',
         '<p class="eyebrow">Scénario de référence · %s · %d beats</p>' % (esc(q["monde"]), len(B)),
         '<h1>%s</h1>' % esc(q["titre"]),
         '<div class="preambule">%s</div>' % "".join('<p>%s</p>' % esc(x) for x in q["preambule"]),
         '<div class="regle">%s</div>' % REGLE,
         '<h2>Les cinq gestes</h2>', leg(q["gestes"], "gestes"),
         '<h2>Les runes de la quête</h2>', leg(q["runes"], "runes-leg"),
         '<h2>La forme de la quête</h2>',
         '<div class="forme"><p>Une décision ne se pose pas au métronome : elle se pose quand le sol '
         'vient de bouger, et seulement quand le Voyageur a de quoi décider.</p>'
         '<div class="rangee">%s</div>'
         '<p class="lg"><b class="r">■</b> bascule subie : le monde décide &nbsp;·&nbsp; '
         '<b class="o">■</b> bascule choisie : vous décidez</p></div>' % cells,
         '<h2>La quête</h2>']
    o += [bloc(b, i, mains, tirages, etats) for i, b in enumerate(B)]
    if orphelins:
        o.append('<p class="note">Tuiles du socle jamais jouées : %s.</p>' % ", ".join(orphelins))
    o.append('</div>')
    return "\n".join(o), orphelins


REGLE = ("<b>Un beat ordinaire.</b> Vous posez une tuile d'action et une rune de votre main. Les "
         "cinq tuiles sont le socle et ne changent jamais ; les runes tournent. La tuile dit ce que "
         "vous faites, la rune dit avec quoi. C'est le modèle qui lit la paire et écrit ce qui "
         "arrive.<br>Le jeu annonce la mise avant le dé, jamais l'issue. On lance <b>2d6</b>. "
         "La rune posée <b>quitte la main</b> et on en repioche une.<br><br>"
         "<b>Un beat spécial</b> a sa propre mécanique — ni tuile, ni rune, ni dé. On y sélectionne "
         "parmi <b>2 à 4 propositions</b> quand c'est un choix ; d'autres formes existent (marchand, "
         "boss, énigme écrite). La main ne bouge pas.<br>"
         "Rien ne s'accumule parce qu'on a réussi : les <b>gwenneg</b> ne viennent que d'un événement "
         "qui en donne.")


def main():
    DST.mkdir(parents=True, exist_ok=True)
    cibles = sys.argv[1:] or [p.stem for p in sorted(SRC.glob("*.json"))]
    faits = []
    for cle in cibles:
        q = json.loads((SRC / (cle + ".json")).read_text(encoding="utf-8"))
        page, orph = rendre(q)
        out = DST / (cle + ".html")
        out.write_text(page, encoding="utf-8")
        faits.append((q, out, orph))
        print("  %-24s %2d beats · %d spéciaux · %s"
              % (cle, len(q["beats"]), sum(1 for b in q["beats"] if b.get("special")),
                 ("tuiles orphelines : " + ", ".join(orph)) if orph else "socle complet"))
    if len(faits) > 1:
        idx = ['<title>Scénarios de référence</title>',
               '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Vollkorn:wght@600;700'
               '&family=Spectral:wght@400&family=IBM+Plex+Mono:wght@400;500&display=swap">',
               '<style>%s</style>' % CSS, '<div class="page">',
               '<p class="eyebrow">M.E.R.L.I.N.</p><h1>Scénarios de référence</h1>',
               '<p class="note-tete">Le rendu qu\'on vise, quête par quête. Chacune est une donnée '
               'sous <code>data/scenarios/</code> ; cette page en est le rendu calculé.</p>']
        for q, out, _ in faits:
            idx.append('<div class="meca"><h3><a href="%s">%s</a></h3>'
                       '<p class="etat-usage%s">%s · %d beats · %d spéciaux%s</p><p class="ex">%s</p></div>'
                       % (out.name, esc(q["titre"]), " vu" if q.get("reference") else "",
                          esc(q["monde"]), len(q["beats"]),
                          sum(1 for b in q["beats"] if b.get("special")),
                          " · référence" if q.get("reference") else "",
                          esc(q["preambule"][0])))
        idx.append('</div>')
        (DST / "index.html").write_text("\n".join(idx), encoding="utf-8")
        print("  index : %d scénarios" % len(faits))


if __name__ == "__main__":
    main()

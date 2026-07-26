#!/usr/bin/env python3
"""Tableau de contrôle visuel d'un run — HTML autonome.

Consomme le transcript produit par l'instrumentation de `board_narration.gd`
(`MERLIN_TRANSCRIPT=<chemin>`) et en tire une page de contrôle destinée au
game designer : tout un run en un écran.

La page est bâtie sur une seule idée : **la scission**. Pour chaque carte, la
colonne de gauche montre ce que le joueur a réellement sous les yeux ; celle de
droite montre ce que le moteur applique sans le dire. C'est cet écart qui se
contrôle, pas la prose.

Palette et typographie reprennent l'identité du jeu (bible §10.2 : fond
terminal, vert terminal, ambre druide, cyan liminal, rouge rune, violet chaos ;
monospace pour le HUD, sérif pour la narration). Monde sombre assumé.

La page est entièrement autonome : aucun script, aucune police, aucune image
externe. Les graphiques sont du SVG généré ici.

Usage :
  python tools/render_run_dashboard.py \
      --input run_transcript.json --out docs/30_jdr/RUN_DASHBOARD.html
"""

from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path

FACTIONS = ["druides", "anciens", "korrigans", "niamh", "ankou"]

# Couleurs de faction dérivées des Pôles de la bible §3.2
# (Ordre = or/ambre, Chaos = violet/feu, Liminal = cyan/brume).
FACTION_COLOR = {
    "druides": "#FFB347",
    "anciens": "#C98A3C",
    "korrigans": "#9B59FF",
    "niamh": "#00D4FF",
    "ankou": "#FF3366",
}

ACT_LABEL = {"standard": "Standard", "shop": "Marchand",
             "event": "Événement", "boss": "Climax"}
ACT_COLOR = {"standard": "#7b8194", "shop": "#FFB347",
             "event": "#00D4FF", "boss": "#FF3366"}

WORD = re.compile(r"[a-zà-ÿœ]+", re.IGNORECASE)


def esc(s) -> str:
    return html.escape(str(s if s is not None else ""))


def num(v, default=0):
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return default


def effect_fr(e: dict) -> tuple:
    """(texte, signe) — signe ∈ {pos, neg, neutre} pour la couleur sémantique."""
    t = e.get("type", "?")
    a = num(e.get("amount"))
    if t == "ADD_REPUTATION":
        return (f"{e.get('faction', '?')} {a:+d}", "pos" if a >= 0 else "neg")
    if t == "HEAL_LIFE":
        return (f"vie +{a}", "pos")
    if t == "DAMAGE_LIFE":
        return (f"vie −{a}", "neg")
    if t == "ADD_ANAM":
        return (f"Anam {a:+d}", "pos" if a >= 0 else "neg")
    if t == "ADD_ESSENCE":
        return (f"essence {a:+d}", "pos" if a >= 0 else "neg")
    return (f"{t} {a}".strip(), "neutre")


def toks(s: str) -> set:
    return {w.lower() for w in WORD.findall(s or "") if len(w) > 4}


def jaccard(a: set, b: set) -> float:
    return len(a & b) / len(a | b) if (a or b) else 0.0


# ───────────────────────────────────────────────────────────── graphiques ──

def sparkline_life(points: list, w: int = 640, h: int = 120) -> str:
    """Courbe de vie : aire remplie, grille discrète, dernier point accentué."""
    if len(points) < 2:
        return ""
    lo, hi = 0, 100
    pad_l, pad_r, pad_t, pad_b = 34, 12, 12, 22
    iw, ih = w - pad_l - pad_r, h - pad_t - pad_b

    def x(i): return pad_l + iw * i / (len(points) - 1)
    def y(v): return pad_t + ih * (1 - (v - lo) / (hi - lo))

    line = " ".join(f"{'M' if i == 0 else 'L'}{x(i):.1f},{y(v):.1f}"
                    for i, v in enumerate(points))
    area = line + f" L{x(len(points)-1):.1f},{y(lo):.1f} L{x(0):.1f},{y(lo):.1f} Z"
    grid = "".join(
        f'<line x1="{pad_l}" y1="{y(g):.1f}" x2="{w-pad_r}" y2="{y(g):.1f}" '
        f'class="grid"/><text x="{pad_l-8}" y="{y(g)+4:.1f}" class="axis">{g}</text>'
        for g in (0, 50, 100))
    dots = "".join(
        f'<circle cx="{x(i):.1f}" cy="{y(v):.1f}" r="{4 if i == len(points)-1 else 2.5}" '
        f'class="{"dot-end" if i == len(points)-1 else "dot"}"/>'
        for i, v in enumerate(points))
    labels = "".join(
        f'<text x="{x(i):.1f}" y="{h-6}" class="axis mid">{"départ" if i == 0 else i}</text>'
        for i in range(len(points)))
    return (f'<svg viewBox="0 0 {w} {h}" class="chart" role="img" '
            f'aria-label="Vie du voyageur carte par carte">'
            f'<defs><linearGradient id="lifeFill" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="#00FF88" stop-opacity=".28"/>'
            f'<stop offset="1" stop-color="#00FF88" stop-opacity="0"/></linearGradient></defs>'
            f'{grid}<path d="{area}" fill="url(#lifeFill)"/>'
            f'<path d="{line}" class="life-line"/>{dots}{labels}</svg>')


def faction_bars(start: dict, end: dict) -> str:
    rows = []
    for f in FACTIONS:
        a, b = num(start.get(f)), num(end.get(f))
        delta = b - a
        wa, wb = min(a, 100), min(b, 100)
        sign = "pos" if delta > 0 else ("neg" if delta < 0 else "flat")
        rows.append(
            f'<div class="fac-row">'
            f'<span class="fac-name">{esc(f)}</span>'
            f'<span class="fac-track">'
            f'<span class="fac-base" style="width:{wa}%"></span>'
            f'<span class="fac-fill" style="width:{wb}%;background:{FACTION_COLOR[f]}"></span>'
            f'<span class="fac-mark" style="left:50%" title="seuil 50"></span>'
            f'</span>'
            f'<span class="fac-val tab">{a} → <strong>{b}</strong></span>'
            f'<span class="fac-delta tab {sign}">{delta:+d}</span>'
            f'</div>')
    return "".join(rows)


def graine_html(graine: dict) -> str:
    """Les cinq contraintes tirées avant génération. Sans elles, deux scénarios
    d'un même archétype se ressemblent."""
    if not graine:
        return ""
    chips = "".join(f'<span class="seed"><span class="seed-k">{esc(k.replace("_", " "))}</span>'
                    f'{esc(v)}</span>' for k, v in graine.items())
    return f'<div class="graine"><span class="graine-lbl">graine de variation</span>{chips}</div>'


# ─────────────────────────────────────────────────────────────── sections ──

CHECK_LABEL = {"white": "blanche", "contextuel": "contextuelle",
               "red": "ROUGE", "fatal": "FATALE"}


def check_chip(ck: dict) -> str:
    """L'epreuve telle qu'elle est telegraphiee au joueur, avant son choix."""
    if not ck:
        return ""
    t = str(ck.get("type", "white"))
    lbl = CHECK_LABEL.get(t, t)
    cls = "red" if t in ("red", "fatal") else ("ctx" if t == "contextuel" else "white")
    return (f'<span class="check {cls}">{esc(ck.get("stat", ""))} · {esc(lbl)}'
            f' · échec −{num(ck.get("fail_damage"))} PV</span>')


def build_cards(cards: list, resols: dict, total: int) -> str:
    out = []
    for c in cards:
        idx = c.get("acte_index")
        r = resols.get(idx, {})
        demande = c.get("acte_type_demande", "standard")
        servi = c.get("acte_type_servi", "standard")
        degraded = demande != servi
        hud = c.get("hud", {})
        after = r.get("hud_apres_choix", {})
        after_dice = r.get("hud_apres_des_du_destin", {})
        chosen = num(r.get("option_choisie"), -1)

        opts = []
        for i, o in enumerate(c.get("options_visibles", [])):
            eff = [effect_fr(e) for e in o.get("effets_caches", [])]
            chips = "".join(f'<span class="chip {s}">{esc(t)}</span>' for t, s in eff) \
                or '<span class="chip neutre">aucun effet</span>'
            out_cls = " picked" if i == chosen else ""
            grad = str(o.get("gradient", ""))
            grad_html = (f'<span class="grad {esc(grad)}">{esc(grad)}</span>' if grad else "")
            opts.append(
                f'<li class="opt{out_cls}">'
                f'<span class="opt-n">{i+1}</span>'
                f'<span class="opt-label">{esc(o.get("label"))}</span>'
                f'{grad_html}{check_chip(o.get("epreuve_telegraphiee", {}))}'
                f'<span class="opt-eff engine">{chips}</span>'
                f'</li>')
        opts_html = "".join(opts)

        life_before, life_after = num(hud.get("vie"), 100), num(after.get("vie"), 100)
        dl = life_after - life_before
        dl_cls = "pos" if dl > 0 else ("neg" if dl < 0 else "flat")

        deltas = []
        for f in FACTIONS:
            d = num(after.get("factions_backend", {}).get(f)) - num(hud.get("factions_backend", {}).get(f))
            if d:
                deltas.append(f'<span class="chip pos" style="--c:{FACTION_COLOR[f]}">{f} {d:+d}</span>')
        dice = []
        for f in FACTIONS:
            d = num(after_dice.get("factions_backend", {}).get(f)) - num(after.get("factions_backend", {}).get(f))
            if d:
                dice.append(f'<span class="chip {"pos" if d > 0 else "neg"}">{f} {d:+d}</span>')

        # La resolution : ce qui se produit apres le choix. C'est le beat qui
        # manquait — le joueur agissait et rien ne lui repondait.
        outcome = str(r.get("texte_resolution", "") or "").strip()
        src = str(r.get("source_resolution", ""))
        ep = r.get("epreuve", {}) or {}
        if src.startswith("echec"):
            res_tag, res_cls = "l'épreuve échoue", " fail"
        elif src.startswith("variante"):
            res_tag, res_cls = f"ce qui se produit — {esc(src.split(':')[-1])}", " variant"
        else:
            res_tag, res_cls = "ce qui se produit", ""
        resolution_html = (
            f'<div class="resolution{res_cls}"><span class="res-tag">{res_tag}</span>'
            f'<p class="narrative res-text">{esc(outcome)}</p></div>'
            if outcome else
            '<div class="resolution missing"><span class="res-tag">ce qui se produit</span>'
            '<p class="res-text missing-text">Rien. Le joueur agit, le moteur applique ses '
            'effets en silence, et la carte suivante arrive sans rapport.</p></div>')
        if ep and str(ep.get("stat", "")):
            ok = bool(ep.get("succes"))
            epreuve_html = (
                f'<dt>Épreuve</dt><dd class="tab">{esc(ep.get("stat"))} niveau '
                f'{num(ep.get("niveau"))} · {num(round(float(ep.get("chance", 0)) * 100))} % '
                f'de réussite · jet {float(ep.get("jet", 0)):.2f} → '
                f'<strong class="{"pos" if ok else "neg"}">'
                f'{"réussite" if ok else "échec"}</strong>'
                + ("" if ok else f' · −{num(ep.get("degats"))} PV') + '</dd>')
        else:
            epreuve_html = ""

        badge = (f'<span class="act-badge" style="--ac:{ACT_COLOR.get(demande, "#7b8194")}">'
                 f'{ACT_LABEL.get(demande, demande)}</span>')
        warn = (f'<p class="warn">Acte « {esc(demande)} » demandé, carte de type '
                f'« {esc(servi)} » servie — le pool ne contient aucune carte pour cet acte.</p>'
                if degraded else "")

        out.append(f"""
<article class="card{' is-degraded' if degraded else ''}">
  <header class="card-head">
    <span class="card-n tab">{idx:02d}</span>
    {badge}
    <span class="card-id engine tab">{esc(c.get('carte_id'))}</span>
    <span class="card-hud tab">Carte {idx} / {total} · vie {life_before} · Anam {num(hud.get('anam_affiche'))}</span>
  </header>
  <div class="split">
    <section class="screen">
      <h4 class="col-label">À l'écran</h4>
      <p class="narrative">{esc(c.get('texte'))}</p>
      {f'<p class="merlin">« {esc(c.get("dialogue_merlin"))} »</p>' if (c.get('dialogue_merlin') or '').strip() else ''}
      <ol class="opts">{opts_html}</ol>
      {resolution_html}
    </section>
    <section class="engine-col">
      <h4 class="col-label engine">Moteur</h4>
      {warn}
      <dl class="kv">
        <dt>Choix retenu</dt><dd>option {chosen+1} — {esc(r.get('label_choisi'))}
            {f'<span class="grad {esc(r.get("gradient"))}">{esc(r.get("gradient"))}</span>' if r.get('gradient') else ''}</dd>
        {epreuve_html}
        <dt>Vie</dt><dd class="tab">{life_before} → <strong>{life_after}</strong>
            <span class="delta {dl_cls}">{dl:+d}</span></dd>
        <dt>Réputations</dt><dd>{''.join(deltas) or '<span class="chip neutre">inchangées</span>'}</dd>
        <dt>Dé du destin</dt><dd>{''.join(dice) or '<span class="chip neutre">aucun effet</span>'}</dd>
      </dl>
      <p class="hidden-note">Aucun de ces chiffres n'est montré au joueur.</p>
    </section>
  </div>
</article>""")
    return "".join(out)


def build_flags(data: dict, cards: list, resols: dict) -> str:
    """Ce qu'il faut regarder — établi sur ce run, pas sur une liste figée."""
    flags = []
    scripted = bool((data.get("scenario", {}) or {}).get("titre"))
    total = len(data.get("sequence_actes", [])) or max(len(cards), 1)

    degraded = [c for c in cards if c.get("acte_type_demande") != c.get("acte_type_servi")]
    if degraded and not scripted:
        which = ", ".join(ACT_LABEL.get(c["acte_type_demande"], c["acte_type_demande"])
                          for c in degraded)
        flags.append(("critique", f"{len(degraded)} actes sans contenu propre",
                      f"Les actes {which} servent une carte narrative ordinaire : "
                      "aucune carte du pool ne porte de champ <code>act_type</code>."))

    # Épreuves : ce que le système de checks a réellement produit.
    eps = [r.get("epreuve", {}) for r in resols.values() if (r.get("epreuve") or {}).get("stat")]
    if eps:
        fails = [e for e in eps if not e.get("succes")]
        dmg = sum(num(e.get("degats")) for e in fails)
        lvl = "alerte" if not (0.25 <= len(fails) / len(eps) <= 0.55) else "info"
        flags.append((lvl, f"{len(fails)} épreuves ratées sur {len(eps)}",
                      f"Coût total {dmg} PV. À stat 1 la chance de réussite est de 60 % : "
                      f"on attend environ {round(len(eps) * 0.4)} échecs sur ce run. "
                      "Un écart durable signale un tirage biaisé, pas un défaut d'écriture."))
    elif scripted:
        flags.append(("critique", "Aucune épreuve résolue",
                      "Les options portent un <code>check</code> mais le moteur ne l'a pas lu : "
                      "le gradient prudente / équilibrée / audacieuse n'a aucun effet mécanique."))

    # Résolutions : le beat qui manquait.
    sans_res = [c["acte_index"] for c in cards
                if not str(resols.get(c["acte_index"], {}).get("texte_resolution", "")).strip()]
    if sans_res:
        flags.append(("critique", f"{len(sans_res)} cartes sans résolution",
                      f"Cartes {', '.join(str(i) for i in sans_res)} : le joueur agit et rien "
                      "ne lui répond. C'est le manquement constaté le 2026-07-26."))

    # Branchement narratif : les variantes d'état se sont-elles déclenchées ?
    variants = [r for r in resols.values()
                if str(r.get("source_resolution", "")).startswith("variante")]
    if variants:
        which = ", ".join(str(r.get("source_resolution", "")).split(":")[-1] for r in variants)
        flags.append(("info", f"{len(variants)} résolution(s) conditionnées par l'état",
                      f"Déclenchées par : {esc(which)}. C'est le branchement narratif à "
                      "l'œuvre — même carte, même option, texte différent."))
    elif scripted:
        flags.append(("alerte", "Aucune variante d'état déclenchée",
                      "Le scénario en porte, mais aucune condition n'a été remplie sur ce run. "
                      "Attendu quand l'autoplay choisit toujours la première option."))

    if num(data.get("anam_gagne")) == 0:
        flags.append(("critique", "Aucune récompense accordée",
                      "<code>calculate_run_rewards</code> n'est appelé que sur victoire ou mort. "
                      f"La victoire exige 25 cartes pour un scénario qui en compte {total} : "
                      "aucun calcul n'a lieu, le joueur repart avec 0 Anam."))

    n_eff = sum(len(o.get("effets_caches", []))
                for c in cards for o in c.get("options_visibles", []))
    flags.append(("alerte", f"{n_eff} effets appliqués sans être montrés",
                  "Le HUD n'affiche que le compteur de cartes, la vie et l'Anam. "
                  "Les cinq réputations bougent à chaque carte sans jamais apparaître — "
                  "la décision du 2026-07-26 (tout afficher) n'est pas encore câblée."))

    # Quasi-doublons : sur un scénario écrit, ce serait une faute d'écriture.
    pairs = []
    for i in range(len(cards)):
        for j in range(i + 1, len(cards)):
            sim = jaccard(toks(cards[i].get("texte", "")), toks(cards[j].get("texte", "")))
            if sim > 0.30:
                pairs.append((sim, cards[i], cards[j]))
    for sim, a, b in sorted(pairs, reverse=True)[:2]:
        flags.append(("alerte", f"Cartes {a['acte_index']} et {b['acte_index']} quasi identiques",
                      f"Recouvrement lexical de {sim:.0%}. "
                      + ("Sur un scénario écrit d'avance, c'est une faute d'écriture."
                         if scripted else
                         "Deux quasi-jumelles du pool sont sorties dans le même run.")))

    # Écart entre effet déclaré et vie appliquée.
    for c in cards:
        r = resols.get(c.get("acte_index"), {})
        if not r:
            continue
        applied = r.get("effets_appliques", r.get("effets_declares", []))
        declared = sum(-num(e.get("amount")) if e.get("type") == "DAMAGE_LIFE"
                       else (num(e.get("amount")) if e.get("type") == "HEAL_LIFE" else 0)
                       for e in applied)
        actual = num(r.get("hud_apres_choix", {}).get("vie"), -999) - num(c.get("hud", {}).get("vie"), -999)
        if declared != actual:
            flags.append(("alerte",
                          f"Carte {c['acte_index']} : vie appliquée {actual:+d}, attendue {declared:+d}",
                          "Un effet non déclaré s'est ajouté — passif de biome, talent passif "
                          "ou dé du destin — sans que rien ne l'annonce au joueur."))

    # Réputation déclarée vs appliquée : au plafond 100, un gain vaut zéro alors
    # que le modèle d'équilibrage le compte 0.4 PV-eq le point.
    perdus = []
    for c in cards:
        r = resols.get(c.get("acte_index"), {})
        if not r:
            continue
        avant = c.get("hud", {}).get("factions_backend", {})
        apres = r.get("hud_apres_choix", {}).get("factions_backend", {})
        for e in r.get("effets_appliques", r.get("effets_declares", [])):
            if e.get("type") != "ADD_REPUTATION":
                continue
            f = e.get("faction", "")
            declare, reel = num(e.get("amount")), num(apres.get(f)) - num(avant.get(f))
            if declare > 0 and reel < declare:
                perdus.append((c["acte_index"], f, declare, reel))
    if perdus:
        detail = ", ".join(f"carte {i} {f} {d:+d} → {r:+d}" for i, f, d, r in perdus[:4])
        flags.append(("critique", f"{len(perdus)} gains de réputation absorbés par le plafond",
                      f"{detail}. Le modèle d'équilibrage compte chaque point 0,4 PV-équivalent : "
                      "au plafond de 100 il n'en vaut plus rien, et l'EV calculée de l'option "
                      "s'effondre sans que rien ne le signale au joueur."))

    order = {"critique": 0, "alerte": 1, "info": 2}
    flags.sort(key=lambda f: order.get(f[0], 9))
    return "".join(
        f'<li class="flag {lvl}"><span class="flag-tag">{lvl}</span>'
        f'<h4>{esc(title)}</h4><p>{body}</p></li>'
        for lvl, title, body in flags)


CSS = """
:root{
  --ground:#0A0A12; --ground-2:#11111c; --ground-3:#171724;
  --ink:#d9dce6; --ink-dim:#7b8194; --ink-faint:#565c6e;
  --terminal:#00FF88; --amber:#FFB347; --cyan:#00D4FF;
  --rune:#FF3366; --chaos:#9B59FF; --stone:#2a2a3a;
  --mono:ui-monospace,"JetBrains Mono","Fira Code",Menlo,Consolas,monospace;
  --serif:"Iowan Old Style",Georgia,"Times New Roman",serif;
  --r:3px;
}
*{box-sizing:border-box}
body{margin:0;background:var(--ground);color:var(--ink);
  font-family:var(--mono);font-size:14px;line-height:1.55;
  -webkit-font-smoothing:antialiased}
.tab{font-variant-numeric:tabular-nums}
.wrap{max-width:1180px;margin:0 auto;padding:40px 24px 80px;
  display:flex;flex-direction:column;gap:34px}

/* En-tête */
.masthead{border-bottom:1px solid var(--stone);padding-bottom:22px;
  display:flex;flex-direction:column;gap:10px}
.eyebrow{font-size:11px;letter-spacing:.18em;text-transform:uppercase;
  color:var(--terminal)}
h1{margin:0;font-size:30px;line-height:1.15;font-weight:600;text-wrap:balance;
  letter-spacing:-.01em}
.sub{color:var(--ink-dim);max-width:68ch;font-size:13px}
.meta{display:flex;flex-wrap:wrap;gap:8px;margin-top:4px}
.pill{border:1px solid var(--stone);border-radius:99px;padding:3px 11px;
  font-size:11px;color:var(--ink-dim)}
.pill strong{color:var(--ink);font-weight:600}

/* Vitals */
.vitals{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px}
.tile{background:var(--ground-2);border:1px solid var(--stone);border-radius:var(--r);
  padding:14px 16px;display:flex;flex-direction:column;gap:5px}
.tile .k{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:var(--ink-faint)}
.tile .v{font-size:25px;font-weight:600;line-height:1}
.tile .n{font-size:11px;color:var(--ink-dim)}
.tile.bad .v{color:var(--rune)} .tile.good .v{color:var(--terminal)}
.tile.warn .v{color:var(--amber)}

/* Panneaux */
.panel{background:var(--ground-2);border:1px solid var(--stone);border-radius:var(--r);
  padding:20px 22px;display:flex;flex-direction:column;gap:14px}
.panel h2{margin:0;font-size:12px;letter-spacing:.16em;text-transform:uppercase;
  color:var(--ink-dim);font-weight:600}
.duo{display:grid;grid-template-columns:1.25fr 1fr;gap:16px;align-items:start}
@media(max-width:860px){.duo{grid-template-columns:1fr}}

/* Graphiques */
.chart{width:100%;height:auto;overflow:visible}
.grid{stroke:var(--stone);stroke-width:1}
.axis{fill:var(--ink-faint);font-size:10px;font-family:var(--mono);text-anchor:end}
.axis.mid{text-anchor:middle}
.life-line{fill:none;stroke:var(--terminal);stroke-width:2;
  stroke-linejoin:round;stroke-linecap:round}
.dot{fill:var(--ground);stroke:var(--terminal);stroke-width:1.5}
.dot-end{fill:var(--terminal);stroke:var(--ground);stroke-width:2}

/* Factions */
.fac-row{display:grid;grid-template-columns:74px 1fr 92px 44px;gap:10px;align-items:center;
  font-size:12px}
.fac-name{color:var(--ink-dim)}
.fac-track{position:relative;height:8px;background:var(--ground-3);border-radius:99px;
  overflow:hidden;display:block}
.fac-base{position:absolute;inset-block:0;left:0;background:var(--stone);border-radius:99px}
.fac-fill{position:absolute;inset-block:0;left:0;border-radius:99px;opacity:.9}
.fac-mark{position:absolute;top:-2px;bottom:-2px;width:1px;background:var(--ink-faint)}
.fac-val{color:var(--ink-dim)} .fac-val strong{color:var(--ink)}
.fac-delta{text-align:right}
.pos{color:var(--terminal)} .neg{color:var(--rune)} .flat{color:var(--ink-faint)}

/* Cartes */
.timeline{display:flex;flex-direction:column;gap:14px}
.card{background:var(--ground-2);border:1px solid var(--stone);border-radius:var(--r);
  overflow:hidden}
.card.is-degraded{border-left:2px solid var(--amber)}
.card-head{display:flex;align-items:center;gap:12px;padding:11px 16px;
  background:var(--ground-3);border-bottom:1px solid var(--stone);flex-wrap:wrap}
.card-n{font-size:12px;color:var(--ink-faint)}
.act-badge{font-size:10px;letter-spacing:.12em;text-transform:uppercase;
  color:var(--ac);border:1px solid var(--ac);border-radius:99px;padding:2px 9px}
.card-id{font-size:11px;color:var(--ink-faint)}
.card-hud{margin-left:auto;font-size:11px;color:var(--ink-dim)}
.split{display:grid;grid-template-columns:1fr 1fr}
@media(max-width:860px){.split{grid-template-columns:1fr}}
.screen{padding:18px 20px;border-right:1px solid var(--stone)}
@media(max-width:860px){.screen{border-right:0;border-bottom:1px solid var(--stone)}}
.engine-col{padding:18px 20px;background:#0d0d16}
.col-label{margin:0 0 12px;font-size:10px;letter-spacing:.16em;text-transform:uppercase;
  color:var(--ink-faint);font-weight:600}
.col-label.engine{color:var(--cyan)}
.narrative{font-family:var(--serif);font-size:17px;line-height:1.6;color:#efe6d2;
  margin:0 0 12px;max-width:52ch}
.merlin{font-family:var(--serif);font-style:italic;color:var(--amber);margin:0 0 12px}
.opts{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:6px}
.opt{display:grid;grid-template-columns:20px 1fr;gap:9px;align-items:baseline;
  padding:7px 9px;border:1px solid var(--stone);border-radius:var(--r);
  background:var(--ground)}
.opt.picked{border-color:var(--terminal);background:rgba(0,255,136,.05)}
.opt-n{color:var(--ink-faint);font-size:11px}
.opt-label{font-family:var(--serif);font-size:15px;color:#efe6d2}
.opt-eff{grid-column:2;display:flex;flex-wrap:wrap;gap:5px;margin-top:5px}
.chip{font-size:10px;padding:2px 7px;border-radius:99px;border:1px solid var(--stone);
  color:var(--ink-dim);white-space:nowrap}
.chip.pos{color:var(--terminal);border-color:rgba(0,255,136,.3)}
.chip.neg{color:var(--rune);border-color:rgba(255,51,102,.3)}
.chip.neutre{color:var(--ink-faint)}
.kv{margin:0;display:grid;grid-template-columns:auto 1fr;gap:7px 14px;font-size:12px}
.kv dt{color:var(--ink-faint)}
.kv dd{margin:0;display:flex;flex-wrap:wrap;gap:5px;align-items:baseline}
.delta{margin-left:6px}
.warn{margin:0 0 12px;font-size:12px;color:var(--amber);
  border-left:2px solid var(--amber);padding-left:10px}
.resolution{margin-top:14px;padding:12px 14px;border-left:2px solid var(--amber);
  background:rgba(255,179,71,.05);border-radius:0 var(--r) var(--r) 0}
.resolution.missing{border-left-color:var(--rune);background:rgba(255,51,102,.05)}
.res-tag{font-size:9px;letter-spacing:.16em;text-transform:uppercase;color:var(--amber)}
.resolution.missing .res-tag{color:var(--rune)}
.res-text{margin:6px 0 0;font-size:15px;line-height:1.55}
.missing-text{font-family:var(--mono);font-size:12px;color:var(--ink-dim);font-style:italic}
.hidden-note{margin:14px 0 0;font-size:11px;color:var(--ink-faint);font-style:italic}

/* Gradient d'option + épreuve télégraphiée (v4.1) */
.opt{grid-template-columns:20px 1fr auto}
.grad{font-size:9px;letter-spacing:.1em;text-transform:uppercase;
  padding:2px 8px;border-radius:99px;border:1px solid var(--stone);color:var(--ink-dim);
  white-space:nowrap;align-self:center}
.grad.prudente{color:#7fd6a4;border-color:rgba(127,214,164,.35)}
.grad.equilibree{color:var(--cyan);border-color:rgba(0,212,255,.32)}
.grad.audacieuse{color:var(--amber);border-color:rgba(255,179,71,.4)}
.check{grid-column:2;justify-self:start;font-size:10px;margin-top:5px;
  padding:2px 8px;border-radius:var(--r);border:1px solid var(--stone);
  color:var(--ink-dim);white-space:nowrap}
.check.ctx{color:var(--cyan);border-color:rgba(0,212,255,.3)}
.check.red{color:var(--rune);border-color:rgba(255,51,102,.45);
  background:rgba(255,51,102,.07);font-weight:600}
.resolution.fail{border-left-color:var(--rune);background:rgba(255,51,102,.06)}
.resolution.fail .res-tag{color:var(--rune)}
.resolution.variant{border-left-color:var(--chaos);background:rgba(155,89,255,.07)}
.resolution.variant .res-tag{color:var(--chaos)}
.kv .pos{color:var(--terminal)} .kv .neg{color:var(--rune)}

/* Graine de variation + essence + intro */
.essence{font-family:var(--serif);font-style:italic;font-size:16px;color:var(--amber);
  margin:2px 0 0;max-width:60ch}
.graine{display:flex;flex-wrap:wrap;gap:7px;align-items:center;margin-top:8px}
.graine-lbl{font-size:9px;letter-spacing:.16em;text-transform:uppercase;
  color:var(--chaos)}
.seed{font-size:11px;padding:3px 10px;border-radius:99px;
  border:1px solid rgba(155,89,255,.32);color:var(--ink);white-space:nowrap}
.seed-k{color:var(--ink-faint);margin-right:6px;font-size:9px;
  letter-spacing:.1em;text-transform:uppercase}
.intro-parchemin{font-family:var(--serif);font-size:15px;line-height:1.65;
  color:#efe6d2;max-width:66ch;margin:12px 0 0;padding-left:14px;
  border-left:2px solid var(--stone)}

/* Alertes */
.flags{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:10px}
.flag{background:var(--ground-3);border-radius:var(--r);padding:13px 16px;
  border-left:2px solid var(--ink-faint)}
.flag.critique{border-left-color:var(--rune)}
.flag.alerte{border-left-color:var(--amber)}
.flag.info{border-left-color:var(--cyan)}
.flag-tag{font-size:9px;letter-spacing:.16em;text-transform:uppercase;color:var(--ink-faint)}
.flag.critique .flag-tag{color:var(--rune)}
.flag.alerte .flag-tag{color:var(--amber)}
.flag.info .flag-tag{color:var(--cyan)}
.flag h4{margin:3px 0 5px;font-size:14px;font-weight:600}
.flag p{margin:0;font-size:12.5px;color:var(--ink-dim);max-width:80ch}
code{background:var(--ground);padding:1px 5px;border-radius:2px;font-size:11.5px;
  color:var(--cyan)}
.tablewrap{overflow-x:auto}
table.series{width:100%;border-collapse:collapse;font-size:12px}
table.series th{text-align:left;font-weight:600;color:var(--ink-faint);font-size:10px;
  letter-spacing:.13em;text-transform:uppercase;padding:6px 10px 6px 0;
  border-bottom:1px solid var(--stone)}
table.series td{padding:8px 10px 8px 0;border-bottom:1px solid #1c1c28;vertical-align:middle}
.narr-cell{font-family:var(--serif);font-size:14px;color:#efe6d2}
.seq{display:inline-flex;gap:4px}
.seq-chip{font-size:10px;padding:2px 6px;border-radius:2px;border:1px solid var(--sc);
  color:var(--sc);font-variant-numeric:tabular-nums}
.vchecks{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:6px}
.vcheck{display:flex;gap:10px;align-items:baseline;flex-wrap:wrap;font-size:12.5px;
  padding:7px 10px;border-radius:var(--r);background:var(--ground-3)}
.vtag{font-size:9px;letter-spacing:.14em;text-transform:uppercase;min-width:64px}
.vcheck.ok .vtag{color:var(--terminal)} .vcheck.ko .vtag{color:var(--rune)}
.vdetail{color:var(--ink-faint);font-size:11.5px}
.foot{border-top:1px solid var(--stone);padding-top:18px;font-size:11px;
  color:var(--ink-faint);display:flex;flex-direction:column;gap:5px}
"""


def build_series(series_dir: Path, pool_size: int = 12) -> str:
    """Panneau de série : ce que le moteur produit sur plusieurs exécutions.

    C'est la réponse à « aucun scénario ne doit se ressembler », mesurée sur
    des runs réels et non sur un fichier.
    """
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "crd", Path(__file__).with_name("check_run_diversity.py"))
    crd = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(crd)

    runs = crd.load_runs(series_dir)
    if len(runs) < 2:
        return ""
    res = crd.analyse(runs, pool_size)

    # Une couleur par parcours distinct : deux runs de meme couleur ont tire
    # exactement les memes cartes dans le meme ordre.
    palette = ["#00D4FF", "#FFB347", "#9B59FF", "#00FF88", "#FF3366", "#C98A3C"]
    seqs, seq_color = {}, {}
    for r in runs:
        key = tuple(r["cartes"])
        if key not in seqs:
            seqs[key] = len(seqs)
        seq_color[r["nom"]] = palette[seqs[key] % len(palette)]

    rows = []
    for r in runs:
        chips = "".join(
            f'<span class="seq-chip">{esc(c.replace("fr_broceliande_", ""))}</span>'
            for c in r["cartes"])
        rows.append(
            f'<tr><td class="engine">{esc(r["nom"])}</td>'
            f'<td class="narr-cell">{esc(r["titre"] or "—")}</td>'
            f'<td><span class="seq" style="--sc:{seq_color[r["nom"]]}">{chips}</span></td>'
            f'<td class="tab">{esc(r["vie_finale"])}</td>'
            f'<td class="tab">{esc(r["anam"])}</td></tr>')

    checks = []
    for ok, label, detail in crd.verdict_lines(res):
        cls = "ok" if ok else "ko"
        tag = "conforme" if ok else "échec"
        extra = "" if ok else f'<span class="vdetail">{esc(detail)}</span>'
        checks.append(
            f'<li class="vcheck {cls}"><span class="vtag">{tag}</span>'
            f'<span class="vlabel">{esc(label)}</span>{extra}</li>')

    n_ko = sum(1 for ok, _, _ in crd.verdict_lines(res) if not ok)
    headline = (f"{res['parcours_distincts']} parcours distincts sur {res['n']} runs"
                if res["parcours_distincts"] < res["n"]
                else f"{res['n']} runs, {res['n']} parcours distincts")

    return f"""
  <section class="panel">
    <h2>Série de runs — ce que le moteur produit vraiment</h2>
    <p class="sub" style="font-size:12.5px;margin:0">
      {esc(headline)} · recouvrement lexical moyen entre runs
      <strong>{res['jaccard_moyen']:.0%}</strong> (max {res['jaccard_max']:.0%}) ·
      {res['cartes_vues']}/{res['pool']} cartes du pool vues ·
      {res['labels_distincts']} libellés d'action distincts sur {res['labels_total']} proposés.
      Deux runs de même couleur ont tiré exactement les mêmes cartes, dans le même ordre.
    </p>
    <div class="tablewrap">
      <table class="series">
        <thead><tr><th>Run</th><th>Titre proposé</th><th>Cartes tirées</th><th>Vie</th><th>Anam</th></tr></thead>
        <tbody>{''.join(rows)}</tbody>
      </table>
    </div>
    <ul class="vchecks">{''.join(checks)}</ul>
    <p class="sub" style="font-size:12px;margin:0">
      {'Aucun critère de diversité ne passe.' if n_ko == len(checks) else
       f'{len(checks) - n_ko}/{len(checks)} critères de diversité conformes.'}
      Mesuré par <code>tools/check_run_diversity.py</code> sur les transcripts des runs ci-dessus.
    </p>
  </section>"""


def render(data: dict, series_dir=None) -> str:
    entries = data.get("entrees", [])
    cards = [e for e in entries if e.get("evenement") == "carte_affichee"]
    resols = {e.get("acte_index"): e for e in entries if e.get("evenement") == "resolution"}
    start = next((e for e in entries if e.get("evenement") == "debut_run"), {})
    end = next((e for e in entries if e.get("evenement") == "fin_run"), {})
    h0, hN = start.get("hud", {}), end.get("hud", {})

    life = [num(h0.get("vie"), 100)]
    for c in cards:
        r = resols.get(c.get("acte_index"), {})
        life.append(num(r.get("hud_apres_des_du_destin", {}).get("vie"),
                        num(r.get("hud_apres_choix", {}).get("vie"), life[-1])))

    sc = data.get("scenario", {}) or {}
    total = len(data.get("sequence_actes", [])) or max(len(cards), 1)
    anam = num(data.get("anam_gagne"))
    n_played = num(data.get("cartes_jouees"))
    degraded = sum(1 for c in cards if c.get("acte_type_demande") != c.get("acte_type_servi"))
    scen = h0.get("scenario_actif") or "aucun"
    n_eff = sum(len(o.get("effets_caches", []))
                for c in cards for o in c.get("options_visibles", []))

    series_html = build_series(Path(series_dir)) if series_dir else ""

    return f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Run {esc(data.get('biome'))} — tableau de contrôle</title>
<style>{CSS}</style></head><body>
<div class="wrap">

  <header class="masthead">
    <span class="eyebrow">M.E.R.L.I.N. · contrôle de run</span>
    <h1>{esc(sc.get('titre') or 'Un run entier, de la première carte au butin')}</h1>
    <p class="sub">Capturé pendant une partie réelle du moteur, pas reconstitué.
      Chaque carte est présentée en deux colonnes : ce que le joueur a sous les
      yeux, et ce que le moteur applique sans le dire. C'est cet écart qui se contrôle.</p>
    {f'<p class="essence">{esc(sc.get("essence"))}</p>' if sc.get('essence') else ''}
    <div class="meta">
      <span class="pill">biome <strong>{esc(data.get('biome'))}</strong></span>
      <span class="pill">archétype <strong>{esc(sc.get('archetype') or scen or 'pool')}</strong></span>
      <span class="pill">longueur <strong>{total} cartes</strong></span>
      <span class="pill">issue <strong>{esc(data.get('issue'))}</strong></span>
      <span class="pill">actes <strong>{' · '.join(ACT_LABEL.get(a, a) for a in data.get('sequence_actes', []))}</strong></span>
    </div>
    {graine_html(sc.get('graine', {}))}
    {f'<p class="intro-parchemin">{esc(sc.get("intro"))}</p>' if sc.get('intro') else ''}
  </header>

  <section class="vitals">
    <div class="tile"><span class="k">Cartes jouées</span>
      <span class="v tab">{n_played}</span><span class="n">sur {total} au scénario</span></div>
    <div class="tile {'bad' if life[-1] < 40 else 'good'}"><span class="k">Vie finale</span>
      <span class="v tab">{life[-1]}</span><span class="n">départ 100 · creux {min(life)}</span></div>
    <div class="tile {'bad' if anam == 0 else 'good'}"><span class="k">Anam gagné</span>
      <span class="v tab">{anam}</span><span class="n">premier déblocage du Grimoire : 10</span></div>
    <div class="tile {'warn' if degraded else 'good'}"><span class="k">Actes dégradés</span>
      <span class="v tab">{degraded}</span><span class="n">sur {len(cards)} cartes</span></div>
    <div class="tile warn"><span class="k">Effets cachés</span>
      <span class="v tab">{n_eff}</span><span class="n">appliqués sans être montrés</span></div>
  </section>

  <div class="duo">
    <section class="panel">
      <h2>Vie du voyageur</h2>
      {sparkline_life(life)}
      <p class="sub" style="font-size:12px">La barre de vie n'a jamais approché
        le seuil d'alerte. Rien n'a été mis en jeu sur ce run.</p>
    </section>
    <section class="panel">
      <h2>Réputations — invisibles en jeu</h2>
      {faction_bars(h0.get('factions_backend', {}), hN.get('factions_backend', {}))}
      <p class="sub" style="font-size:12px">Le trait central marque le seuil 50,
        qui débloque une section du Grimoire. Aucun de ces chiffres n'apparaît à l'écran.</p>
    </section>
  </div>

  {series_html}

  <section class="panel">
    <h2>Ce qu'il faut regarder</h2>
    <ul class="flags">{build_flags(data, cards, resols)}</ul>
  </section>

  <section class="timeline">{build_cards(cards, resols, total)}</section>

  <footer class="foot">
    <span>Généré par <code>tools/render_run_dashboard.py</code> depuis le transcript
      d'un run réel — instrumentation <code>MERLIN_TRANSCRIPT</code> de
      <code>board_narration.gd</code>.</span>
    <span>Rejouer un run et régénérer :
      <code>MERLIN_AUTOPLAY=1 MERLIN_TRANSCRIPT=run.json godot --headless --path . scenes/BoardNarration.tscn --quit-after 30000</code></span>
  </footer>
</div>
</body></html>"""


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--series", default=None,
                    help="repertoire de transcripts pour le panneau de serie")
    args = ap.parse_args()
    data = json.load(open(args.input, encoding="utf-8"))
    Path(args.out).write_text(render(data, args.series), encoding="utf-8")
    print(f"Tableau de controle ecrit : {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

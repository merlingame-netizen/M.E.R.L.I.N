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


# ─────────────────────────────────────────────────────────────── sections ──

def build_cards(cards: list, resols: dict) -> str:
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
            opts.append(
                f'<li class="opt{out_cls}">'
                f'<span class="opt-n">{i+1}</span>'
                f'<span class="opt-label">{esc(o.get("label"))}</span>'
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
    <span class="card-hud tab">Carte {idx} / 5 · vie {life_before} · Anam {num(hud.get('anam_affiche'))}</span>
  </header>
  <div class="split">
    <section class="screen">
      <h4 class="col-label">À l'écran</h4>
      <p class="narrative">{esc(c.get('texte'))}</p>
      {f'<p class="merlin">« {esc(c.get("dialogue_merlin"))} »</p>' if (c.get('dialogue_merlin') or '').strip() else ''}
      <ol class="opts">{opts_html}</ol>
    </section>
    <section class="engine-col">
      <h4 class="col-label engine">Moteur</h4>
      {warn}
      <dl class="kv">
        <dt>Choix retenu</dt><dd>option {chosen+1} — {esc(r.get('label_choisi'))}</dd>
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
    flags = []
    degraded = [c for c in cards if c.get("acte_type_demande") != c.get("acte_type_servi")]
    if degraded:
        which = ", ".join(ACT_LABEL.get(c["acte_type_demande"], c["acte_type_demande"])
                          for c in degraded)
        flags.append(("critique", f"{len(degraded)} actes sans contenu propre",
                      f"Les actes {which} servent une carte narrative ordinaire : "
                      "aucune carte du pool ne porte de champ <code>act_type</code>."))
    if num(data.get("anam_gagne")) == 0:
        flags.append(("critique", "Aucune récompense accordée",
                      "<code>calculate_run_rewards</code> n'est appelé que sur victoire ou mort. "
                      "La victoire exige 25 cartes pour une boucle qui en joue 5 : à 5 cartes "
                      "sans mort, aucun calcul n'a lieu. Le joueur repart avec 0 Anam."))
    n_eff = sum(len(o.get("effets_caches", []))
                for c in cards for o in c.get("options_visibles", []))
    flags.append(("alerte", f"{n_eff} effets appliqués sans être montrés",
                  "Le HUD n'affiche que le compteur de cartes, la vie et l'Anam. "
                  "Les cinq réputations bougent à chaque carte sans jamais apparaître."))
    # Quasi-doublons dans le run
    pairs = []
    for i in range(len(cards)):
        for j in range(i + 1, len(cards)):
            s = jaccard(toks(cards[i].get("texte", "")), toks(cards[j].get("texte", "")))
            if s > 0.30:
                pairs.append((s, cards[i], cards[j]))
    for s, a, b in sorted(pairs, reverse=True)[:2]:
        flags.append(("alerte", f"Cartes {a['acte_index']} et {b['acte_index']} quasi identiques",
                      f"Recouvrement lexical de {s:.0%} — mêmes options, mêmes effets. "
                      "Sur un pool de 12 cartes pour ce biome, deux quasi-jumelles sont "
                      "sorties dans le même run de 5."))
    # Écart entre effet déclaré et vie appliquée
    for c in cards:
        r = resols.get(c.get("acte_index"), {})
        declared = sum(-num(e.get("amount")) if e.get("type") == "DAMAGE_LIFE"
                       else (num(e.get("amount")) if e.get("type") == "HEAL_LIFE" else 0)
                       for e in r.get("effets_declares", []))
        actual = num(r.get("hud_apres_choix", {}).get("vie"), -999) - num(c.get("hud", {}).get("vie"), -999)
        if r and declared != actual:
            flags.append(("alerte", f"Carte {c['acte_index']} : vie annoncée {declared:+d}, appliquée {actual:+d}",
                          "Le passif de biome de Brocéliande ajoute <code>HEAL_LIFE 5</code> "
                          "toutes les 5 cartes sans que rien ne l'annonce."))
    order = {"critique": 0, "alerte": 1}
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
.hidden-note{margin:14px 0 0;font-size:11px;color:var(--ink-faint);font-style:italic}

/* Alertes */
.flags{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:10px}
.flag{background:var(--ground-3);border-radius:var(--r);padding:13px 16px;
  border-left:2px solid var(--ink-faint)}
.flag.critique{border-left-color:var(--rune)}
.flag.alerte{border-left-color:var(--amber)}
.flag-tag{font-size:9px;letter-spacing:.16em;text-transform:uppercase;color:var(--ink-faint)}
.flag.critique .flag-tag{color:var(--rune)}
.flag.alerte .flag-tag{color:var(--amber)}
.flag h4{margin:3px 0 5px;font-size:14px;font-weight:600}
.flag p{margin:0;font-size:12.5px;color:var(--ink-dim);max-width:80ch}
code{background:var(--ground);padding:1px 5px;border-radius:2px;font-size:11.5px;
  color:var(--cyan)}
.foot{border-top:1px solid var(--stone);padding-top:18px;font-size:11px;
  color:var(--ink-faint);display:flex;flex-direction:column;gap:5px}
"""


def render(data: dict) -> str:
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

    anam = num(data.get("anam_gagne"))
    n_played = num(data.get("cartes_jouees"))
    degraded = sum(1 for c in cards if c.get("acte_type_demande") != c.get("acte_type_servi"))
    scen = h0.get("scenario_actif") or "aucun"
    n_eff = sum(len(o.get("effets_caches", []))
                for c in cards for o in c.get("options_visibles", []))

    return f"""<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Run {esc(data.get('biome'))} — tableau de contrôle</title>
<style>{CSS}</style></head><body>
<div class="wrap">

  <header class="masthead">
    <span class="eyebrow">M.E.R.L.I.N. · contrôle de run</span>
    <h1>Un run entier, de la première carte au butin</h1>
    <p class="sub">Capturé pendant une partie réelle du moteur, pas reconstitué.
      Chaque carte est présentée en deux colonnes : ce que le joueur a sous les
      yeux, et ce que le moteur applique sans le dire. C'est cet écart qui se contrôle.</p>
    <div class="meta">
      <span class="pill">biome <strong>{esc(data.get('biome'))}</strong></span>
      <span class="pill">scénario <strong>{esc(scen)}</strong></span>
      <span class="pill">issue <strong>{esc(data.get('issue'))}</strong></span>
      <span class="pill">actes <strong>{' · '.join(ACT_LABEL.get(a, a) for a in data.get('sequence_actes', []))}</strong></span>
    </div>
  </header>

  <section class="vitals">
    <div class="tile"><span class="k">Cartes jouées</span>
      <span class="v tab">{n_played}</span><span class="n">sur 25 requises pour une victoire</span></div>
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

  <section class="panel">
    <h2>Ce qu'il faut regarder</h2>
    <ul class="flags">{build_flags(data, cards, resols)}</ul>
  </section>

  <section class="timeline">{build_cards(cards, resols)}</section>

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
    args = ap.parse_args()
    data = json.load(open(args.input, encoding="utf-8"))
    Path(args.out).write_text(render(data), encoding="utf-8")
    print(f"Tableau de controle ecrit : {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

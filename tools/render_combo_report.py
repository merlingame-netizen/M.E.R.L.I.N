#!/usr/bin/env python3
"""v10.6 (user 2026-06-06) — Rend le JSON de probe_combos.gd en HTML de controle-lecture.
Lit ~/Downloads/merlin_combos_report.json -> ecrit ~/Downloads/merlin_combos_report.html.
But : lire d'un coup, par scenario, chaque beat avec ses 2 cartes (nom+evocation+tags+archetype)
et la prose LLM vs procedurale, pour juger la qualite des histoires et iterer sur le prompt.

    python tools/render_combo_report.py
"""
from __future__ import annotations

import html
import json
from pathlib import Path

IN_PATH = Path.home() / "Downloads" / "merlin_combos_report.json"
OUT_PATH = Path.home() / "Downloads" / "merlin_combos_report.html"

DEGREE_COLOR = {
    "echec": "#D04848",
    "partiel": "#D8A030",
    "reussite": "#E8C45A",
    "eclatante": "#F4E0A8",
}
ARCHETYPE_COLOR = {
    "Offensif": "#C0533A", "Défensif": "#4E7A6A", "Social": "#B58A3A",
    "Mystique": "#6B5A9C", "Corrompu": "#8B4FA3",
}


def esc(s: object) -> str:
    return html.escape(str(s))


def render_card(card: dict) -> str:
    arch = str(card.get("archetype", ""))
    acol = ARCHETYPE_COLOR.get(arch, "#6B5A9C")
    tags = ", ".join(esc(t) for t in card.get("tags", []))
    return f"""
      <div class="card">
        <div class="card-name">{esc(card.get('name', ''))}
          <span class="rarity">{esc(card.get('rarity', ''))}</span></div>
        <div class="card-evo">« {esc(card.get('evocation', ''))} »</div>
        <div class="card-meta">
          <span class="tags">{tags}</span>
          <span class="arch" style="background:{acol}">{esc(arch)}</span>
        </div>
      </div>"""


def render_beat(beat: dict) -> str:
    deg = str(beat.get("degree", ""))
    dcol = DEGREE_COLOR.get(deg, "#9C8C6A")
    cards_html = "".join(render_card(c) for c in beat.get("combo", []))
    syn = int(beat.get("synergy", 0))
    syn_txt = "neutre" if syn == 0 else ("+ synergie" if syn > 0 else "− dissonance")
    llm = str(beat.get("resolution_llm", "")).strip()
    proc = str(beat.get("resolution_procedural", "")).strip()
    llm_block = (
        f'<div class="prose llm"><span class="ptag">LLM</span>{esc(llm)}</div>'
        if llm else '<div class="prose empty">— pas de prose LLM (moteur indispo) —</div>'
    )
    return f"""
    <div class="beat">
      <div class="beat-head">
        <span class="beat-n">Beat {esc(beat.get('n', '?'))} · {esc(beat.get('type', ''))}</span>
        <span class="degree" style="color:{dcol}">{esc(beat.get('label', deg))}</span>
        <span class="cov">couverture {esc(beat.get('coverage', ''))} · {esc(syn_txt)}</span>
        <span class="req">tags requis : {', '.join(esc(t) for t in beat.get('required', []))}</span>
      </div>
      <div class="situation">{esc(beat.get('situation', ''))}</div>
      <div class="combo">{cards_html}</div>
      {llm_block}
      <div class="prose proc"><span class="ptag">PROCÉDURAL</span>{esc(proc)}</div>
    </div>"""


def render_scenario(scen: dict) -> str:
    beats = "".join(render_beat(b) for b in scen.get("beats", []))
    return f"""
  <section class="scenario">
    <h2>{esc(scen.get('title', ''))}</h2>
    <p class="pitch">{esc(scen.get('pitch', ''))}</p>
    {beats}
  </section>"""


def main() -> None:
    if not IN_PATH.exists():
        print(f"JSON introuvable : {IN_PATH} — lancer d'abord probe_combos.gd")
        return
    data = json.loads(IN_PATH.read_text(encoding="utf-8"))
    scenarios = "".join(render_scenario(s) for s in data.get("scenarios", []))
    model = data.get("model", {})
    model_name = model.get("name", model.get("model", "?")) if isinstance(model, dict) else "?"
    head = f"""<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
<title>MERLIN — Contrôle-lecture combos</title>
<style>
  body {{ background:#14100C; color:#E8DCC0; font-family:'Segoe UI',system-ui,sans-serif;
         margin:0; padding:24px 32px; line-height:1.5; }}
  h1 {{ color:#C9A24B; font-size:22px; letter-spacing:1px; margin:0 0 4px; }}
  .sub {{ color:#9C8C6A; font-size:12px; margin-bottom:24px; }}
  .scenario {{ margin-bottom:40px; }}
  h2 {{ color:#C9A24B; font-size:18px; border-bottom:1px solid #3A2E20; padding-bottom:6px; }}
  .pitch {{ color:#B5A07A; font-style:italic; margin:4px 0 16px; }}
  .beat {{ background:#1E1812; border:1px solid #3A2E20; border-radius:8px;
           padding:14px 16px; margin-bottom:16px; }}
  .beat-head {{ display:flex; flex-wrap:wrap; gap:14px; align-items:baseline;
                font-size:12px; margin-bottom:8px; }}
  .beat-n {{ color:#C9A24B; font-weight:600; }}
  .degree {{ font-weight:700; }}
  .cov, .req {{ color:#9C8C6A; }}
  .situation {{ color:#C8BC9A; font-size:14px; margin-bottom:10px;
                border-left:3px solid #6E5A3C; padding-left:10px; }}
  .combo {{ display:flex; gap:12px; flex-wrap:wrap; margin-bottom:10px; }}
  .card {{ background:#E8DCC0; color:#2A2018; border-radius:6px; padding:8px 10px;
           flex:1 1 280px; max-width:420px; }}
  .card-name {{ font-weight:700; font-size:13px; }}
  .rarity {{ float:right; font-size:10px; color:#6E5A3C; font-weight:400; text-transform:uppercase; }}
  .card-evo {{ font-style:italic; font-size:12px; color:#4A3B28; margin:3px 0 6px; }}
  .card-meta {{ display:flex; justify-content:space-between; align-items:center; font-size:11px; }}
  .tags {{ color:#6E5A3C; }}
  .arch {{ color:#E8DCC0; padding:1px 8px; border-radius:10px; font-size:10px;
           letter-spacing:1px; text-transform:uppercase; }}
  .prose {{ font-size:14px; padding:8px 12px; border-radius:6px; margin-top:6px; }}
  .prose .ptag {{ display:inline-block; font-size:9px; letter-spacing:1px; padding:1px 6px;
                  border-radius:3px; margin-right:8px; vertical-align:middle; }}
  .llm {{ background:#22301E; }}
  .llm .ptag {{ background:#7FA65C; color:#14100C; }}
  .proc {{ background:#2A2018; color:#9C8C6A; }}
  .proc .ptag {{ background:#6E5A3C; color:#E8DCC0; }}
  .empty {{ color:#8A6A2E; font-style:italic; }}
</style></head><body>
<h1>M · E · R · L · I · N — Contrôle-lecture des combos</h1>
<div class="sub">généré {esc(data.get('generated_at', ''))} · moteur {esc(model_name)} ·
  LLM {'actif' if data.get('llm_ready') else 'indispo'} · {esc(data.get('rule', ''))} ·
  statut {esc(data.get('status', ''))}</div>"""
    OUT_PATH.write_text(head + scenarios + "</body></html>", encoding="utf-8")
    n_beats = sum(len(s.get("beats", [])) for s in data.get("scenarios", []))
    print(f"HTML écrit : {OUT_PATH} ({len(data.get('scenarios', []))} scénarios, {n_beats} beats)")


if __name__ == "__main__":
    main()

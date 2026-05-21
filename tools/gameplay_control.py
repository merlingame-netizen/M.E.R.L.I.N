"""Generate ONE master HTML that lets the user control everything about the
gameplay across all archived runs, very visually.

Reads ~/Downloads/batch_runs/run_*.json and produces a single HTML at
~/Downloads/gameplay_control.html with :

  1. Sticky header : title + global KPI strip
  2. Toolbar : filter (seed substring, anchor substring, min success rate)
     + sort (seed / anchor / success / éclats / wall-time)
  3. Variety dimensions card row (4 axes: content / tone / ambiance / length)
  4. Cross-run heatmap : canonical summary recurrence + anchor distribution
  5. Run grid : one card per run with mini-timeline (16 outcome dots),
     anchor, KPIs ; click "Open replay" to inline-expand the full cinematic
     replay (rendered via render_html_cinematic body fragment).

All client-side ; no server, no external deps. Vanilla JS filter/sort.

Usage :
    python tools/gameplay_control.py
    python tools/gameplay_control.py --in ~/Downloads/batch_runs/ --out X.html
"""

from __future__ import annotations

import argparse
import collections
import json
import logging
import re
import statistics
import sys
from html import escape as html_escape
from pathlib import Path

# Import the cinematic renderer + helpers from the simulator module so we
# can produce inline per-run replay bodies without duplicating code.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from simulate_human_run_v731 import render_html_cinematic  # noqa: E402

log = logging.getLogger("gameplay_control")

DEFAULT_IN = Path.home() / "Downloads" / "batch_runs"
DEFAULT_OUT = Path.home() / "Downloads" / "gameplay_control.html"


CSS = """<style>
:root {
  --bg:#1a1208; --bg-soft:#221a0c; --gold:#d4a84a; --gold-dim:#8b7028;
  --parchment:#ede0c0; --text:#ede0c0; --text-dim:#a89878;
  --good:#6fbf73; --warn:#d4a84a; --bad:#c25a4a; --binary:#a47edc;
}
* { box-sizing:border-box; }
body { background:var(--bg); color:var(--text); font-family:'Segoe UI','Inter',sans-serif;
       margin:0; padding:0; line-height:1.55; }

header.gc-head {
  position:sticky; top:0; z-index:90; background:rgba(15,10,5,0.92);
  backdrop-filter:blur(6px); border-bottom:1px solid var(--gold-dim);
  padding:14px 24px;
}
header.gc-head .row { display:flex; justify-content:space-between; align-items:center; flex-wrap:wrap; gap:12px; max-width:1400px; margin:0 auto; }
header.gc-head h1 { font-family:'Cinzel','Georgia',serif; color:var(--gold); margin:0;
                    font-size:18px; letter-spacing:2px; font-weight:600; }
header.gc-head .kpi-strip { display:flex; gap:14px; flex-wrap:wrap; }
header.gc-head .ks-stat { display:flex; flex-direction:column; gap:2px; min-width:80px; }
header.gc-head .ks-val { color:var(--gold); font-weight:600; font-size:18px; font-family:'Cinzel','Georgia',serif; }
header.gc-head .ks-lbl { color:var(--text-dim); font-size:9px; text-transform:uppercase; letter-spacing:1px; }

main.gc-main { max-width:1400px; margin:0 auto; padding:24px; }

.toolbar { display:flex; gap:12px; flex-wrap:wrap; align-items:center; margin:18px 0 24px 0;
           padding:12px 16px; background:var(--bg-soft); border:1px solid var(--gold-dim); border-radius:8px; }
.toolbar input, .toolbar select {
  background:#0d0805; color:var(--text); border:1px solid var(--gold-dim);
  padding:6px 10px; border-radius:4px; font-size:13px; font-family:inherit;
}
.toolbar input::placeholder { color:var(--text-dim); }
.toolbar label { font-size:11px; color:var(--text-dim); text-transform:uppercase; letter-spacing:1px; }
.toolbar button { background:var(--gold); color:var(--bg); border:none; padding:6px 14px;
                  border-radius:4px; font-weight:600; cursor:pointer; font-size:12px; }
.toolbar button:hover { background:var(--parchment); }

h2.section { font-family:'Cinzel','Georgia',serif; color:var(--gold); letter-spacing:1px;
             font-size:16px; text-transform:uppercase; margin:32px 0 14px 0;
             padding-bottom:6px; border-bottom:1px solid var(--gold-dim); }

.dim-grid { display:grid; grid-template-columns:repeat(4, 1fr); gap:14px; }
@media (max-width:900px) { .dim-grid { grid-template-columns:repeat(2, 1fr); } }
.dim-card { background:linear-gradient(135deg, var(--bg-soft) 0%, rgba(20,14,6,0.9) 100%);
            border:1px solid var(--gold-dim); border-radius:8px; padding:14px; }
.dim-card .dim-name { font-family:'Cinzel','Georgia',serif; color:var(--gold); font-size:11px;
                      letter-spacing:2px; text-transform:uppercase; margin-bottom:6px; }
.dim-card .dim-score { font-size:24px; color:var(--gold); font-weight:600; font-family:'Cinzel','Georgia',serif; }
.dim-card .dim-detail { color:var(--text-dim); font-size:11px; margin-top:4px; }
.dim-card .dim-verdict-OK   { color:var(--good); }
.dim-card .dim-verdict-WARN { color:var(--warn); }
.dim-card .dim-verdict-BAD  { color:var(--bad); }

.heatmap { background:var(--bg-soft); border:1px solid var(--gold-dim); border-radius:8px;
           padding:12px 16px; margin:14px 0; overflow-x:auto; }
.heatmap table { border-collapse:collapse; min-width:100%; font-size:11px; }
.heatmap th { color:var(--gold); text-align:left; padding:4px 8px; font-weight:600; }
.heatmap td { padding:3px 6px; text-align:center; color:var(--text); }
.heatmap td.hit-1 { background:rgba(212,168,74,0.15); }
.heatmap td.hit-2 { background:rgba(212,168,74,0.35); }
.heatmap td.hit-3 { background:rgba(212,168,74,0.55); }
.heatmap td.hit-4 { background:rgba(212,168,74,0.75); color:var(--bg); }
.heatmap td.hit-5 { background:var(--gold); color:var(--bg); font-weight:600; }

.run-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(360px, 1fr)); gap:18px; }
.run-card { background:linear-gradient(155deg, #2a2010 0%, #1f1808 75%, #18120a 100%);
            border:1px solid var(--gold-dim); border-radius:10px; padding:16px;
            box-shadow:0 4px 12px rgba(0,0,0,0.3); }
.run-card.hidden { display:none; }
.run-card .rc-head { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:10px; gap:12px; }
.run-card .rc-seed { font-family:'Cinzel','Georgia',serif; color:var(--gold); font-weight:600; font-size:14px; }
.run-card .rc-anchor { color:var(--parchment); font-size:11px; margin-top:2px; font-style:italic; }
.run-card .rc-mini-timeline { display:flex; gap:3px; margin:10px 0; flex-wrap:wrap; }
.run-card .rc-dot { width:14px; height:14px; border-radius:3px; background:var(--gold-dim);
                    border:1px solid #0d0805; cursor:default; position:relative; }
.run-card .rc-dot.r-success { background:var(--good); }
.run-card .rc-dot.r-partial { background:var(--warn); }
.run-card .rc-dot.r-failure { background:var(--bad); }
.run-card .rc-dot.binary { box-shadow:inset 0 0 0 2px var(--binary); }
.run-card .rc-stats { display:flex; flex-wrap:wrap; gap:10px; font-size:11px; color:var(--text-dim); margin:8px 0; }
.run-card .rc-stats b { color:var(--gold); }
.run-card .rc-open { background:transparent; color:var(--gold); border:1px solid var(--gold);
                     padding:6px 12px; border-radius:4px; cursor:pointer; font-size:11px;
                     font-family:'Cinzel','Georgia',serif; letter-spacing:1px; text-transform:uppercase; }
.run-card .rc-open:hover { background:var(--gold); color:var(--bg); }
.run-card .rc-replay { display:none; margin-top:18px; padding-top:18px;
                       border-top:1px dashed var(--gold-dim); }
.run-card.expanded .rc-replay { display:block; }
.run-card.expanded { grid-column:1 / -1; }

/* Inline replay : strip the outer body/hero (already in card), keep only scenes content */
.rc-replay iframe { width:100%; height:1400px; border:none; background:transparent; }
</style>"""


JS = """<script>
(function() {
  var input = document.getElementById('filter-input');
  var anchorSel = document.getElementById('filter-anchor');
  var sortSel = document.getElementById('sort-select');
  var clearBtn = document.getElementById('clear-filters');
  var grid = document.getElementById('run-grid');
  var cards = Array.from(grid.querySelectorAll('.run-card'));

  function applyFilter() {
    var q = (input.value || '').toLowerCase();
    var a = (anchorSel.value || '').toLowerCase();
    var shown = 0;
    cards.forEach(function(c) {
      var seed = (c.dataset.seed || '').toLowerCase();
      var anchor = (c.dataset.anchor || '').toLowerCase();
      var matchQ = !q || seed.indexOf(q) >= 0 || anchor.indexOf(q) >= 0;
      var matchA = !a || a === '__all__' || anchor === a;
      if (matchQ && matchA) { c.classList.remove('hidden'); shown++; }
      else c.classList.add('hidden');
    });
    document.getElementById('result-count').textContent = shown;
  }

  function applySort() {
    var key = sortSel.value;
    var visible = cards.slice();
    visible.sort(function(a, b) {
      var av = parseFloat(a.dataset[key]) || 0;
      var bv = parseFloat(b.dataset[key]) || 0;
      if (key === 'seed') return av - bv;
      return bv - av;  // desc for other keys
    });
    visible.forEach(function(c) { grid.appendChild(c); });
  }

  input.addEventListener('input', applyFilter);
  anchorSel.addEventListener('change', applyFilter);
  sortSel.addEventListener('change', applySort);
  clearBtn.addEventListener('click', function() {
    input.value = ''; anchorSel.value = '__all__'; applyFilter();
  });

  grid.addEventListener('click', function(ev) {
    var btn = ev.target.closest('.rc-open');
    if (!btn) return;
    var card = btn.closest('.run-card');
    var expanded = card.classList.toggle('expanded');
    btn.textContent = expanded ? 'Fermer le replay' : 'Ouvrir le replay';
    if (expanded) card.scrollIntoView({ behavior:'smooth', block:'start' });
  });

  applyFilter();
})();
</script>"""


def load_runs(directory: Path) -> list[dict]:
    runs: list[dict] = []
    for p in sorted(directory.glob("run_*.json")):
        try:
            d = json.loads(p.read_text(encoding="utf-8"))
            d["_source_file"] = p.name
            runs.append(d)
        except (json.JSONDecodeError, OSError) as exc:
            log.warning("skipped %s : %s", p.name, exc)
    return runs


def variety_summary(runs: list[dict]) -> dict:
    """Compact 4-dim variety summary (mirrors variety_report.py but inline)."""
    abs_re = re.compile(
        r"\b(la\s+trame|l[''’]?echo|le\s+voile|le\s+silence\s+se\s+fait)\b",
        re.IGNORECASE,
    )
    named_re = re.compile(
        r"\b(Merlin|Niamh|le\s+druide|le\s+korrigan|la\s+vieille|"
        r"le\s+sanglier|le\s+marchand|le\s+gardien)\b",
        re.IGNORECASE,
    )
    anchors = collections.Counter()
    total_beats = 0
    named_hits = 0
    abs_hits = 0
    prose_lens: list[int] = []
    binary_count = 0
    poles = collections.Counter()
    emotions = collections.Counter()
    summaries_per_run: list[set[str]] = []
    for r in runs:
        anchors[(r.get("anchor_motif") or "").strip().lower()] += 1
        run_summaries: set[str] = set()
        for b in r.get("cards_played", []) or []:
            total_beats += 1
            txt = (b.get("prose_long") or "") + " " + (b.get("resolution_prose") or "")
            if named_re.search(txt):
                named_hits += 1
            if abs_re.search(txt):
                abs_hits += 1
            prose_lens.append(len(b.get("prose_long") or ""))
            if int(b.get("cardinality", 3)) == 2:
                binary_count += 1
            poles[b.get("pole", "?").lower()] += 1
            emotions[b.get("emotion", "?").lower()] += 1
            run_summaries.add((b.get("summary") or "")[:80].strip())
        summaries_per_run.append(run_summaries)
    overlaps: list[float] = []
    for i in range(len(summaries_per_run)):
        for j in range(i + 1, len(summaries_per_run)):
            a, b = summaries_per_run[i], summaries_per_run[j]
            if a and b:
                overlaps.append(len(a & b) / len(a | b))
    named_rate = 100 * named_hits / max(1, total_beats)
    abs_rate = 100 * abs_hits / max(1, total_beats)
    binary_rate = 100 * binary_count / max(1, total_beats)
    jacc = (sum(overlaps) / len(overlaps)) if overlaps else 0.0
    pl = prose_lens or [0]
    pl_sorted = sorted(pl)
    return {
        "n_runs": len(runs),
        "n_beats": total_beats,
        "unique_anchors": len([a for a in anchors if a]),
        "total_anchors": sum(anchors.values()),
        "anchors_top": anchors.most_common(8),
        "jaccard_avg": jacc,
        "named_rate": named_rate,
        "abstract_rate": abs_rate,
        "binary_rate": binary_rate,
        "pole_dist": poles.most_common(),
        "emotion_dist": emotions.most_common(),
        "prose_min": pl_sorted[0],
        "prose_median": statistics.median(pl) if pl else 0,
        "prose_max": pl_sorted[-1],
        "prose_mean": round(statistics.mean(pl), 0) if pl else 0,
    }


def render_dim_card(name: str, score: str, detail: str, verdict: str) -> str:
    return (
        f"<div class='dim-card'>"
        f"<div class='dim-name'>{name}</div>"
        f"<div class='dim-score dim-verdict-{verdict}'>{score}</div>"
        f"<div class='dim-detail'>{detail}</div>"
        f"</div>"
    )


def render_heatmap(runs: list[dict]) -> str:
    """Canonical-summary recurrence : which beats appear across many runs."""
    e = html_escape
    counts = collections.Counter()
    for r in runs:
        seen: set[str] = set()
        for b in r.get("cards_played", []) or []:
            s = (b.get("summary") or "")[:60]
            if s and s not in seen:
                counts[s] += 1
                seen.add(s)
    top = counts.most_common(15)
    if not top:
        return "<p class='note'>aucune carte</p>"
    rows: list[str] = []
    rows.append("<table>")
    rows.append("<tr><th>Summary (60 premiers chars)</th><th>Occurrences (runs)</th></tr>")
    for summary, n in top:
        cls = f"hit-{min(5, n)}"
        rows.append(f"<tr><td>{e(summary)}</td><td class='{cls}'>{n}</td></tr>")
    rows.append("</table>")
    return "<div class='heatmap'>" + "".join(rows) + "</div>"


def render_run_card(run: dict) -> str:
    """One card per run : mini-timeline + KPIs + 'Open replay' inline body."""
    e = html_escape
    beats = run.get("cards_played", []) or []
    seed = run.get("seed", "-")
    anchor = (run.get("anchor_motif") or "").strip() or "(sans ancre)"
    # KPIs
    out = collections.Counter(b.get("dc_result") for b in beats)
    success = out.get("success", 0)
    binary = sum(1 for b in beats if int(b.get("cardinality", 3)) == 2)
    final_state = beats[-1].get("state_after", {}) if beats else {}
    eclats = int(final_state.get("eclats", 0) or 0)
    life = final_state.get("life", 80)
    karma = final_state.get("karma", 0)
    total_chars = sum(len(b.get("prose_long") or "") for b in beats)
    success_rate = 100 * success / max(1, len(beats))
    # Wall time
    wall = run.get("timings_s", {}).get("total", 0)

    # Mini-timeline 16 dots
    dots: list[str] = []
    for b in beats:
        r = b.get("dc_result", "")
        bclass = " binary" if int(b.get("cardinality", 3)) == 2 else ""
        beat_n = b.get("beat", "?")
        verb_n = b.get("chosen_option", {}).get("verb", "")
        title = f"B{beat_n} {verb_n} {r}"
        dots.append(f"<div class='rc-dot r-{r}{bclass}' title='{e(title)}'></div>")
    mini_tl = "".join(dots)

    # Pre-render via cinematic renderer. Use the FULL HTML (with CSS) as the
    # iframe srcdoc so the inner document carries its own styling -
    # extracting just the body would inherit no CSS in the srcdoc sandbox.
    # Strip the cinema-rail because it would float over the outer page.
    cinematic_html = render_html_cinematic(run)
    cinematic_html = re.sub(
        r"<nav class='cinema-rail'>.*?</nav>",
        "",
        cinematic_html,
        flags=re.DOTALL,
    )
    body_inner_escaped = (
        cinematic_html
        .replace("&", "&amp;")
        .replace('"', "&quot;")
        .replace("'", "&apos;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )

    return (
        f"<div class='run-card' data-seed='{seed}' data-anchor='{e(anchor.lower())}' "
        f"data-success='{success_rate:.1f}' data-eclats='{eclats}' "
        f"data-binary='{binary}' data-walltime='{wall}'>"
        f"<div class='rc-head'>"
        f"<div><div class='rc-seed'>Seed {seed}</div>"
        f"<div class='rc-anchor'>« {e(anchor)} »</div></div>"
        f"<button class='rc-open'>Ouvrir le replay</button>"
        f"</div>"
        f"<div class='rc-mini-timeline'>{mini_tl}</div>"
        f"<div class='rc-stats'>"
        f"<span><b>{success}</b>/{len(beats)} success ({success_rate:.0f}%)</span>"
        f"<span><b>{binary}</b> binaires</span>"
        f"<span><b>{eclats}</b> éclats</span>"
        f"<span><b>{life}</b> vie</span>"
        f"<span><b>{karma}</b> karma</span>"
        f"<span><b>{wall}</b>s wall</span>"
        f"<span><b>{total_chars}</b> chars prose</span>"
        f"</div>"
        f"<div class='rc-replay'>"
        f"<iframe srcdoc=\"{body_inner_escaped}\" sandbox='allow-same-origin'></iframe>"
        f"</div>"
        f"</div>"
    )


def render_dashboard(runs: list[dict]) -> str:
    e = html_escape
    var = variety_summary(runs)
    n = var["n_runs"]
    nb = var["n_beats"]

    h: list[str] = []
    h.append("<!DOCTYPE html><html lang='fr'><head><meta charset='utf-8'>")
    h.append("<title>MERLIN · Gameplay Control · Master Dashboard</title>")
    h.append(CSS)
    # Embed the cinematic CSS too, since iframe srcdoc inherits no styles.
    # Actually iframe srcdoc is a SEPARATE document. We need the CSS inside
    # each iframe's srcdoc. The cinematic html already has its CSS, but we
    # stripped to body. Patch : include the CSS inside the srcdoc body.
    h.append("</head><body>")

    # Header (sticky).
    h.append("<header class='gc-head'><div class='row'>")
    h.append("<h1>Gameplay Control · Marche druidique</h1>")
    h.append("<div class='kpi-strip'>")
    h.append(f"<div class='ks-stat'><div class='ks-val'>{n}</div><div class='ks-lbl'>runs</div></div>")
    h.append(f"<div class='ks-stat'><div class='ks-val'>{nb}</div><div class='ks-lbl'>beats</div></div>")
    h.append(f"<div class='ks-stat'><div class='ks-val'>{var['binary_rate']:.0f}%</div><div class='ks-lbl'>binary</div></div>")
    h.append(f"<div class='ks-stat'><div class='ks-val'>{var['named_rate']:.0f}%</div><div class='ks-lbl'>perso nommé</div></div>")
    h.append(f"<div class='ks-stat'><div class='ks-val'>{var['abstract_rate']:.0f}%</div><div class='ks-lbl'>mot banni</div></div>")
    h.append(f"<div class='ks-stat'><div class='ks-val'>{var['unique_anchors']}</div><div class='ks-lbl'>anchors uniques</div></div>")
    h.append("</div></div></header>")

    h.append("<main class='gc-main'>")

    # Toolbar.
    anchors_options = sorted({(r.get("anchor_motif") or "").strip().lower() for r in runs if (r.get("anchor_motif") or "").strip()})
    h.append("<div class='toolbar'>")
    h.append("<label>Filtre :</label>")
    h.append("<input id='filter-input' type='text' placeholder='seed ou anchor...' />")
    h.append("<label>Anchor :</label>")
    h.append("<select id='filter-anchor'>")
    h.append("<option value='__all__'>(tous)</option>")
    for a in anchors_options:
        h.append(f"<option value='{e(a)}'>{e(a)}</option>")
    h.append("</select>")
    h.append("<label>Tri :</label>")
    h.append("<select id='sort-select'>")
    h.append("<option value='seed'>Seed (croissant)</option>")
    h.append("<option value='success'>Success rate</option>")
    h.append("<option value='eclats'>Éclats</option>")
    h.append("<option value='binary'>Binaires</option>")
    h.append("<option value='walltime'>Wall time</option>")
    h.append("</select>")
    h.append("<button id='clear-filters'>Reset</button>")
    h.append(f"<span style='margin-left:auto;color:var(--text-dim);font-size:12px;'>"
             f"<span id='result-count'>{n}</span> runs affichés</span>")
    h.append("</div>")

    # 4-dim variety summary.
    h.append("<h2 class='section'>Variété sur l'ensemble</h2>")
    named_verdict = "OK" if var["named_rate"] > 30 else ("WARN" if var["named_rate"] > 15 else "BAD")
    abs_verdict = "OK" if var["abstract_rate"] < 10 else ("WARN" if var["abstract_rate"] < 25 else "BAD")
    jacc_verdict = "OK" if var["jaccard_avg"] < 0.15 else ("WARN" if var["jaccard_avg"] < 0.30 else "BAD")
    bin_verdict = "OK" if 10 <= var["binary_rate"] <= 20 else "WARN"

    h.append("<div class='dim-grid'>")
    h.append(render_dim_card(
        "Contenu",
        f"{var['unique_anchors']}/{var['total_anchors']}",
        f"anchors uniques · Jaccard summary {var['jaccard_avg']:.2f} (cible &lt;0.15)",
        jacc_verdict,
    ))
    h.append(render_dim_card(
        "Ton",
        f"{var['named_rate']:.0f}%",
        f"perso nommé (cible &gt;30%) · mot banni {var['abstract_rate']:.0f}% (cible &lt;10%)",
        named_verdict,
    ))
    h.append(render_dim_card(
        "Ambiance",
        f"{var['binary_rate']:.0f}%",
        f"binary rate (cible ~14%) · {len(var['pole_dist'])} pôles · {len(var['emotion_dist'])} émotions",
        bin_verdict,
    ))
    h.append(render_dim_card(
        "Longueur",
        f"{var['prose_median']:.0f}",
        f"chars prose median · range {var['prose_min']}-{var['prose_max']} · mean {var['prose_mean']:.0f}",
        "OK",
    ))
    h.append("</div>")

    # Heatmap of recurrent summaries.
    h.append("<h2 class='section'>Recoupement de cartes entre runs</h2>")
    h.append("<p style='color:var(--text-dim);font-size:11px;'>")
    h.append("Cartes qui apparaissent dans plusieurs runs — plus la teinte est dorée, plus la carte est récurrente.")
    h.append("</p>")
    h.append(render_heatmap(runs))

    # Run grid.
    h.append(f"<h2 class='section'>Runs ({n})</h2>")
    h.append("<div class='run-grid' id='run-grid'>")
    for r in runs:
        h.append(render_run_card(r))
    h.append("</div>")

    h.append("</main>")
    h.append(JS)
    h.append("</body></html>")
    return "".join(h)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
    parser = argparse.ArgumentParser(description="Gameplay control master dashboard")
    parser.add_argument("--in", dest="in_dir", type=Path, default=DEFAULT_IN, help="Archive dir")
    parser.add_argument("--out", dest="out_html", type=Path, default=DEFAULT_OUT, help="Output HTML")
    args = parser.parse_args()

    if not args.in_dir.exists():
        log.error("Archive dir not found : %s", args.in_dir)
        return 1
    runs = load_runs(args.in_dir)
    if not runs:
        log.error("No run_*.json in %s", args.in_dir)
        return 1
    log.info("Loaded %d runs", len(runs))

    html = render_dashboard(runs)
    args.out_html.write_text(html, encoding="utf-8")
    log.info("Wrote dashboard : %s (%d bytes)", args.out_html, len(html))
    return 0


if __name__ == "__main__":
    sys.exit(main())

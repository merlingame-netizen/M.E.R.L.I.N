"""Read all archived v731 runs from ~/Downloads/batch_runs/ and produce a
comparison HTML measuring 4 variety dimensions :

  1. CONTENT   - anchor motifs, type+rarity, canonical-summary overlap
  2. TONE      - char/word counts, named-character presence, abstract-noun
                 count (la trame / l'echo / le voile etc), question mark rate
  3. AMBIANCE  - pole distribution, emotion distribution, tags acquired
  4. LENGTH    - prose_long, bridge, resolution char-count distributions
                 with min/median/max/percentiles

Output : ~/Downloads/variety_report.html (dark theme, distribution bars,
per-run table, top-N most/least varied beats).

Usage :
    python tools/variety_report.py
    python tools/variety_report.py --in ~/Downloads/batch_runs/
    python tools/variety_report.py --out ~/Downloads/variety_X.html
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

log = logging.getLogger("variety_report")

DEFAULT_IN = Path.home() / "Downloads" / "batch_runs"
DEFAULT_OUT = Path.home() / "Downloads" / "variety_report.html"

# Tone heuristics : abstract-noun ban list (Phase 17 ban patterns).
ABSTRACT_NOUNS = re.compile(
    r"\b(la\s+trame|l[''’]?echo|le\s+voile|le\s+silence\s+se\s+fait|"
    r"la\s+resonance|le\s+chant\s+secret|l[''’]?empreinte)\b",
    re.IGNORECASE,
)
NAMED_CHARS = re.compile(
    r"\b(Merlin|Niamh|le\s+druide\s+voyageur|le\s+korrigan|la\s+vieille|"
    r"le\s+sanglier|le\s+marchand|le\s+gardien|une\s+vieille|un\s+druide)\b",
    re.IGNORECASE,
)
QUESTION = re.compile(r"\?")
SENTENCE_END = re.compile(r"[.!?]+\s+")


def load_runs(directory: Path) -> list[dict]:
    runs: list[dict] = []
    for p in sorted(directory.glob("run_*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            data["_source_file"] = p.name
            runs.append(data)
        except (json.JSONDecodeError, OSError) as exc:
            log.warning("Skipped %s : %s", p.name, exc)
    return runs


def _sentences(text: str) -> list[str]:
    if not text:
        return []
    return [s.strip() for s in SENTENCE_END.split(text) if s.strip()]


def compute_content(runs: list[dict]) -> dict:
    """Content variety : anchors, type+rarity mix, summary overlap."""
    anchors_per_run: list[str] = []
    type_rarity = collections.Counter()
    all_summaries: list[set[str]] = []
    for r in runs:
        anchors_per_run.append((r.get("anchor_motif") or "").strip().lower())
        beats = r.get("cards_played", []) or []
        run_summaries: set[str] = set()
        for b in beats:
            type_rarity[(b.get("type", "?"), b.get("rarity", "?"))] += 1
            run_summaries.add((b.get("summary") or "")[:80].strip())
        all_summaries.append(run_summaries)

    # Jaccard pairwise overlap
    overlaps: list[float] = []
    for i, a in enumerate(all_summaries):
        for j, b in enumerate(all_summaries):
            if j <= i or not a or not b:
                continue
            union = a | b
            overlaps.append(len(a & b) / max(1, len(union)))
    return {
        "unique_anchors": len(set(anchors_per_run)),
        "total_anchors": len(anchors_per_run),
        "anchors_top": collections.Counter(anchors_per_run).most_common(8),
        "type_rarity": type_rarity.most_common(),
        "summary_pairwise_jaccard_avg": (sum(overlaps) / len(overlaps)) if overlaps else 0.0,
        "summary_pairwise_jaccard_max": max(overlaps) if overlaps else 0.0,
    }


def compute_tone(runs: list[dict]) -> dict:
    """Tone variety : sentence length, abstract-noun rate, named chars, ?-rate."""
    all_proses: list[str] = []
    named_hits = 0
    abstract_hits = 0
    question_hits = 0
    for r in runs:
        for b in r.get("cards_played", []) or []:
            txt = (b.get("prose_long") or "") + " " + (b.get("resolution_prose") or "")
            all_proses.append(txt)
            if NAMED_CHARS.search(txt):
                named_hits += 1
            if ABSTRACT_NOUNS.search(txt):
                abstract_hits += 1
            if QUESTION.search(txt):
                question_hits += 1
    total = max(1, sum(len(r.get("cards_played", []) or []) for r in runs))
    word_lens: list[int] = []
    sent_lens: list[float] = []
    for p in all_proses:
        words = p.split()
        if words:
            word_lens.append(len(words))
        sents = _sentences(p)
        for s in sents:
            sent_lens.append(len(s.split()))
    return {
        "n_beats": total,
        "named_char_rate": 100 * named_hits / total,
        "abstract_noun_rate": 100 * abstract_hits / total,
        "question_rate": 100 * question_hits / total,
        "avg_words_per_beat": (sum(word_lens) / len(word_lens)) if word_lens else 0,
        "median_sentence_words": statistics.median(sent_lens) if sent_lens else 0,
        "p90_sentence_words": (
            statistics.quantiles(sent_lens, n=10)[-1] if len(sent_lens) >= 10 else 0
        ),
    }


def compute_ambiance(runs: list[dict]) -> dict:
    """Ambiance variety : pole + emotion distribution, tags acquired."""
    pole_dist = collections.Counter()
    emotion_dist = collections.Counter()
    all_tags = collections.Counter()
    binary_count = 0
    total_beats = 0
    for r in runs:
        for b in r.get("cards_played", []) or []:
            total_beats += 1
            pole_dist[b.get("pole", "?").lower()] += 1
            emotion_dist[b.get("emotion", "?").lower()] += 1
            if int(b.get("cardinality", 3)) == 2:
                binary_count += 1
            for t in b.get("state_after", {}).get("tags", []) or []:
                all_tags[t] += 1
    return {
        "pole_dist": pole_dist.most_common(),
        "emotion_dist": emotion_dist.most_common(),
        "tags_top": all_tags.most_common(15),
        "unique_tags": len(all_tags),
        "binary_rate": 100 * binary_count / max(1, total_beats),
        "total_beats": total_beats,
    }


def compute_length(runs: list[dict]) -> dict:
    """Length variety : char counts per prose field."""
    prose_long: list[int] = []
    bridge: list[int] = []
    resolution: list[int] = []
    for r in runs:
        for b in r.get("cards_played", []) or []:
            prose_long.append(len(b.get("prose_long") or ""))
            br = b.get("transition_prose_llm") or b.get("transition_prose") or ""
            if br:
                bridge.append(len(br))
            resolution.append(len(b.get("resolution_prose") or ""))

    def stats(xs: list[int]) -> dict:
        if not xs:
            return {"n": 0}
        sxs = sorted(xs)
        return {
            "n": len(xs),
            "min": min(xs),
            "p25": sxs[len(sxs) // 4],
            "median": statistics.median(xs),
            "p75": sxs[(3 * len(sxs)) // 4],
            "max": max(xs),
            "mean": round(statistics.mean(xs), 1),
            "stdev": round(statistics.stdev(xs), 1) if len(xs) >= 2 else 0,
        }

    return {
        "prose_long": stats(prose_long),
        "bridge": stats(bridge),
        "resolution": stats(resolution),
    }


def _bar(parts: list[tuple[str, int, str]], width_px: int = 600) -> str:
    e = html_escape
    total = sum(p[1] for p in parts) or 1
    out = ["<div class='dist-bar'>"]
    for klass, count, lbl in parts:
        pct = 100 * count / total
        if pct > 0:
            out.append(
                f"<div class='dist-seg {klass}' style='width:{pct:.1f}%;' "
                f"title='{e(lbl)}: {count} ({pct:.0f}%)'>"
                f"{e(lbl) if pct > 8 else ''}</div>"
            )
    out.append("</div>")
    return "".join(out)


CSS = """<style>
:root { --bg:#1a1208; --bg-soft:#221a0c; --gold:#d4a84a; --gold-dim:#8b7028;
        --parchment:#ede0c0; --text:#ede0c0; --text-dim:#a89878;
        --good:#6fbf73; --warn:#d4a84a; --bad:#c25a4a; }
body { background:var(--bg); color:var(--text); font-family:'Segoe UI','Inter',sans-serif;
       max-width:1200px; margin:0 auto; padding:24px; line-height:1.55; }
h1 { color:var(--gold); font-family:'Cinzel','Georgia',serif; letter-spacing:1.5px;
     border-bottom:2px solid var(--gold-dim); padding-bottom:10px; }
h2 { color:var(--gold); font-family:'Cinzel','Georgia',serif; margin-top:32px;
     border-bottom:1px solid var(--gold-dim); padding-bottom:6px; letter-spacing:0.5px; }
h3 { color:var(--parchment); margin-top:24px; font-size:14px; letter-spacing:1px; text-transform:uppercase; }
.grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(200px, 1fr)); gap:12px; margin:16px 0; }
.kard { background:linear-gradient(135deg, var(--bg-soft) 0%, rgba(20,14,6,0.9) 100%);
        border:1px solid var(--gold-dim); border-radius:8px; padding:14px; }
.kard .lbl { color:var(--text-dim); font-size:10px; text-transform:uppercase; letter-spacing:1px; margin-bottom:4px; }
.kard .val { color:var(--gold); font-size:22px; font-weight:600; font-family:'Cinzel','Georgia',serif; }
.kard .sub { color:var(--parchment); font-size:11px; margin-top:2px; }
table { width:100%; border-collapse:collapse; margin:10px 0; font-size:12px; }
th, td { padding:6px 10px; text-align:left; border-bottom:1px solid var(--gold-dim); }
th { color:var(--gold); font-family:'Cinzel','Georgia',serif; letter-spacing:0.5px; }
.dist-bar { display:flex; height:22px; background:rgba(20,14,6,0.8); border:1px solid var(--gold-dim); border-radius:5px; overflow:hidden; margin:8px 0; }
.dist-seg { display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:600; color:var(--bg); white-space:nowrap; padding:0 6px; }
.dist-1 { background:#6fbf73; }
.dist-2 { background:#d4a84a; }
.dist-3 { background:#a47edc; }
.dist-4 { background:#c25a4a; color:var(--text); }
.dist-5 { background:#7b9bc4; }
.dist-6 { background:#8b7028; color:var(--text); }
.dist-7 { background:#5a8a5a; }
.dist-8 { background:#a89878; color:var(--bg); }
.note { color:var(--text-dim); font-size:11px; font-style:italic; }
.metric-good { color:var(--good); font-weight:600; }
.metric-warn { color:var(--warn); font-weight:600; }
.metric-bad  { color:var(--bad);  font-weight:600; }
.banner { background:linear-gradient(90deg, #2a1f0e, #1f1608);
          border:1px solid var(--gold-dim); border-left:4px solid var(--gold);
          padding:12px 18px; margin:14px 0 24px 0; border-radius:6px;
          color:var(--parchment); }
.banner .title { color:var(--gold); font-weight:600; font-size:14px; margin-bottom:6px; font-family:'Cinzel','Georgia',serif; }
</style>"""


def render(runs: list[dict], content: dict, tone: dict, ambiance: dict, length: dict) -> str:
    e = html_escape
    n_runs = len(runs)
    parts: list[str] = []
    parts.append("<!DOCTYPE html><html lang='fr'><head><meta charset='utf-8'>")
    parts.append(f"<title>MERLIN - Rapport de variete ({n_runs} runs)</title>")
    parts.append(CSS)
    parts.append("</head><body>")
    parts.append(f"<h1>MERLIN - Rapport de variete sur {n_runs} runs LLM</h1>")
    parts.append("<div class='banner'>")
    parts.append("<div class='title'>4 dimensions auditées</div>")
    parts.append(
        "<div>1. Contenu (anchors, type/rarity, recouvrement summary) - "
        "2. Ton/subtilité (longueur, perso nommés, mots abstraits banis) - "
        "3. Ambiance (pôles, émotions, tags, binary rate) - "
        "4. Longueur (prose_long / bridge / resolution distributions).</div>"
    )
    parts.append("</div>")

    # --- 1. CONTENT ---
    parts.append("<h2>1. Contenu</h2>")
    parts.append("<div class='grid'>")
    parts.append(
        f"<div class='kard'><div class='lbl'>Anchors uniques</div>"
        f"<div class='val'>{content['unique_anchors']}<span style='font-size:13px;color:var(--text-dim);'>/{content['total_anchors']}</span></div>"
        f"<div class='sub'>{100*content['unique_anchors']/max(1,content['total_anchors']):.0f}% variete</div></div>"
    )
    jacc_avg = content['summary_pairwise_jaccard_avg']
    jacc_class = 'metric-good' if jacc_avg < 0.15 else ('metric-warn' if jacc_avg < 0.3 else 'metric-bad')
    parts.append(
        f"<div class='kard'><div class='lbl'>Recouvrement summary (Jaccard pairwise avg)</div>"
        f"<div class='val {jacc_class}'>{jacc_avg:.2f}</div>"
        f"<div class='sub'>cible &lt;0.15 = runs distincts ; max obs={content['summary_pairwise_jaccard_max']:.2f}</div></div>"
    )
    parts.append("</div>")
    parts.append("<h3>Top anchor motifs</h3>")
    parts.append("<table><tr><th>Anchor</th><th>Occurrences</th></tr>")
    for anchor, n in content["anchors_top"]:
        parts.append(f"<tr><td>{e(anchor) or '<em>(vide)</em>'}</td><td>{n}</td></tr>")
    parts.append("</table>")
    parts.append("<h3>Distribution type + rarete</h3>")
    parts.append("<table><tr><th>Type</th><th>Rarity</th><th>Count</th></tr>")
    for (tp, rar), n in content["type_rarity"]:
        parts.append(f"<tr><td>{e(tp)}</td><td>{e(rar)}</td><td>{n}</td></tr>")
    parts.append("</table>")

    # --- 2. TONE ---
    parts.append("<h2>2. Ton / subtilite</h2>")
    parts.append("<div class='grid'>")
    named_class = 'metric-good' if tone['named_char_rate'] > 30 else ('metric-warn' if tone['named_char_rate'] > 15 else 'metric-bad')
    parts.append(
        f"<div class='kard'><div class='lbl'>Beats avec personnage nomme</div>"
        f"<div class='val {named_class}'>{tone['named_char_rate']:.0f}%</div>"
        f"<div class='sub'>cible &gt;30% (Phase 17 : concretude)</div></div>"
    )
    abs_class = 'metric-good' if tone['abstract_noun_rate'] < 10 else ('metric-warn' if tone['abstract_noun_rate'] < 25 else 'metric-bad')
    parts.append(
        f"<div class='kard'><div class='lbl'>Beats avec mot abstrait banni</div>"
        f"<div class='val {abs_class}'>{tone['abstract_noun_rate']:.0f}%</div>"
        f"<div class='sub'>cible &lt;10% (la trame, le voile, l'echo, ...)</div></div>"
    )
    parts.append(
        f"<div class='kard'><div class='lbl'>Mots moyens / beat</div>"
        f"<div class='val'>{tone['avg_words_per_beat']:.0f}</div>"
        f"<div class='sub'>median phrase = {tone['median_sentence_words']:.0f} mots ; p90 = {tone['p90_sentence_words']:.0f}</div></div>"
    )
    parts.append(
        f"<div class='kard'><div class='lbl'>Beats avec '?'</div>"
        f"<div class='val'>{tone['question_rate']:.0f}%</div>"
        f"<div class='sub'>questions narratives = invitation au choix</div></div>"
    )
    parts.append("</div>")

    # --- 3. AMBIANCE ---
    parts.append("<h2>3. Ambiance</h2>")
    parts.append("<div class='grid'>")
    parts.append(
        f"<div class='kard'><div class='lbl'>Tags uniques</div>"
        f"<div class='val'>{ambiance['unique_tags']}</div>"
        f"<div class='sub'>total beats = {ambiance['total_beats']}</div></div>"
    )
    bin_class = 'metric-good' if 10 <= ambiance['binary_rate'] <= 20 else 'metric-warn'
    parts.append(
        f"<div class='kard'><div class='lbl'>Binary rate</div>"
        f"<div class='val {bin_class}'>{ambiance['binary_rate']:.0f}%</div>"
        f"<div class='sub'>cible ~14% (pool 13/90)</div></div>"
    )
    parts.append("</div>")
    parts.append("<h3>Repartition des poles</h3>")
    pole_parts = [
        ("dist-1", n, p) for p, n in ambiance["pole_dist"]
    ]
    parts.append(_bar([(f"dist-{1+i%8}", n, p) for i, (p, n) in enumerate(ambiance["pole_dist"])]))
    parts.append("<h3>Repartition des emotions</h3>")
    parts.append(_bar([(f"dist-{1+i%8}", n, em) for i, (em, n) in enumerate(ambiance["emotion_dist"])]))
    parts.append("<h3>Top tags acquis</h3>")
    parts.append("<table><tr><th>Tag</th><th>Count</th></tr>")
    for tag, n in ambiance["tags_top"]:
        parts.append(f"<tr><td>{e(tag)}</td><td>{n}</td></tr>")
    parts.append("</table>")

    # --- 4. LENGTH ---
    parts.append("<h2>4. Longueur</h2>")
    parts.append("<table><tr><th>Champ</th><th>n</th><th>min</th><th>p25</th><th>median</th><th>p75</th><th>max</th><th>mean</th><th>stdev</th></tr>")
    for key, lbl in [("prose_long", "prose_long (carte)"), ("bridge", "bridge (transition)"), ("resolution", "resolution_prose")]:
        s = length[key]
        if s.get("n", 0) == 0:
            parts.append(f"<tr><td>{lbl}</td><td colspan='8'><em>aucune donnee</em></td></tr>")
        else:
            parts.append(
                f"<tr><td>{lbl}</td><td>{s['n']}</td><td>{s['min']}</td><td>{s['p25']}</td>"
                f"<td>{s['median']}</td><td>{s['p75']}</td><td>{s['max']}</td>"
                f"<td>{s['mean']}</td><td>{s['stdev']}</td></tr>"
            )
    parts.append("</table>")

    # --- Per-run table ---
    parts.append("<h2>Runs individuels</h2>")
    parts.append("<table><tr><th>Run</th><th>Seed</th><th>Anchor</th><th>Cards</th><th>Binary</th>"
                 "<th>Outcomes S/P/F</th><th>Eclats</th><th>Total prose chars</th></tr>")
    for r in runs:
        seed = r.get("seed", "-")
        anchor = (r.get("anchor_motif") or "")[:40]
        beats = r.get("cards_played", []) or []
        binary = sum(1 for b in beats if int(b.get("cardinality", 3)) == 2)
        out_c = collections.Counter(b.get("dc_result") for b in beats)
        final = beats[-1].get("state_after", {}) if beats else {}
        total_chars = sum(len(b.get("prose_long") or "") for b in beats)
        parts.append(
            f"<tr><td>{e(r.get('_source_file',''))}</td><td>{seed}</td>"
            f"<td>{e(anchor)}</td><td>{len(beats)}</td><td>{binary}</td>"
            f"<td>{out_c.get('success',0)}/{out_c.get('partial',0)}/{out_c.get('failure',0)}</td>"
            f"<td>{final.get('eclats', 0)}</td><td>{total_chars}</td></tr>"
        )
    parts.append("</table>")

    parts.append("</body></html>")
    return "".join(parts)


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")
    parser = argparse.ArgumentParser(description="Variety report from batch runs")
    parser.add_argument("--in", dest="in_dir", type=Path, default=DEFAULT_IN, help="Archive dir")
    parser.add_argument("--out", dest="out_html", type=Path, default=DEFAULT_OUT, help="Output HTML")
    args = parser.parse_args()

    if not args.in_dir.exists():
        log.error("Archive dir not found : %s", args.in_dir)
        return 1
    runs = load_runs(args.in_dir)
    if not runs:
        log.error("No run_*.json found in %s", args.in_dir)
        return 1
    log.info("Loaded %d runs from %s", len(runs), args.in_dir)

    content = compute_content(runs)
    tone = compute_tone(runs)
    ambiance = compute_ambiance(runs)
    length = compute_length(runs)

    html = render(runs, content, tone, ambiance, length)
    args.out_html.write_text(html, encoding="utf-8")
    log.info("Wrote variety report : %s (%d bytes)", args.out_html, len(html))
    return 0


if __name__ == "__main__":
    sys.exit(main())

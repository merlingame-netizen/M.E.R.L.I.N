#!/usr/bin/env python3
"""Assemble la page HTML de presentation (audio embarque en base64).

La page est autonome : aucune requete reseau, l'audio est inline. C'est un
lecteur simple — un socle, trois roles, et des boutons qui changent le titulaire
de chaque role selon la meteo, la saison ou le moment. Un seul titulaire par
role est audible a la fois : on entend un remplacement, pas un empilement.

Usage :
    python3 tools/audio/build_web_page.py --stems audio/music/menu --out /tmp/page.html
"""
import argparse, base64, html, json, os, re, subprocess, sys

# DEBITS EN CONSTANT, PLUS EN VBR — parce qu'il faut tenir un budget.
# En VBR le total partait bien au-dela de la limite de 16 Mo d'un artefact ; en
# debit fixe on sait ce qu'on paie.
#
# Budget : la page doit tenir sous 16 Mo. 195,9 s x debit / 8, le tout inflate de
# 33 % par le base64. Le socle et le mix de repli pesent 3,1 Mo, les douze parties
# de role 7,1 Mo, soit 13,6 Mo une fois encodes.
#
# menu_theme ne sert que de repli <audio> quand le Web Audio est refuse ; le socle
# est ce qu'on entend vraiment, donc les deux gardent le meilleur debit.
STEMS = {"menu_theme": "64k", "bed": "64k"}

# Les parties de role sont encodees en MONO et bien plus bas. Trois raisons :
# elles sont douze, elles sont sparses (le halo joue 48 notes en 195 s), et
# chacune ne porte qu'UN instrument — un signal a bande etroite, exactement ce
# que le MP3 code le mieux a bas debit.
# 24 kHz et non 32 : en dessous de 32 kHz le MP3 bascule en MPEG-2 Layer III, dont
# la grille de debits descend a 8 kbit/s. En MPEG-1 le plancher est a 32 kbit/s, et
# LAME remontait silencieusement les 20 kbit/s demandes — les douze couches
# pesaient alors 10 Mo au lieu de 6, et la page depassait la limite de 16 Mo.
# Debits MPEG-2 valides : 8, 16, 24, 32, 40, 48... Toute autre valeur est arrondie.
PART_BITRATE = "24k"
PART_RATE = "24000"

# Enveloppe de document complete. Indispensable pour un fichier autonome : sans
# <meta charset>, le navigateur devine l'encodage et casse tous les accents. Les
# plateformes d'hebergement fournissent leur propre <head>, d'ou l'option --embedded.
DOC_HEAD = """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="color-scheme" content="light dark">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="format-detection" content="telephone=no">
<title>{title}</title>
</head>
<body>
"""
DOC_TAIL = "\n</body>\n</html>\n"


def make_standalone(body: str) -> str:
    """Extrait le <title> du corps et batit un document HTML complet."""
    m = re.search(r"<title>(.*?)</title>\s*", body, re.S)
    title = m.group(1).strip() if m else "Palette Broceliande"
    if m:
        body = body[:m.start()] + body[m.end():]
    return DOC_HEAD.format(title=title) + body + DOC_TAIL
TEMPLATE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "page_template.html")


def build_activity() -> dict:
    """Exporte QUI JOUE QUAND, piste par piste, pupitre par pupitre.

    Pas d'analyse audio : la partition est connue. Pour chaque piste (socle et
    chaque candidat de role), on fusionne les notes de chaque instrument en
    intervalles [debut, fin]. Le lecteur allume les pupitres en suivant
    l'horloge du socle — exact a la milliseconde, la ou une detection au
    spectre devinerait."""
    import sys as _sys
    _here = os.path.dirname(os.path.abspath(__file__))
    if _here not in _sys.path:
        _sys.path.insert(0, _here)
    from arrange_menu import build_bed, build_role
    from casting_menu import CANDIDATES

    def merge(evs):
        per: dict = {}
        for e in evs:
            per.setdefault(e["inst"], []).append(
                (round(e["at"], 2), round(e["at"] + e["dur"], 2)))
        out = {}
        for inst, spans in per.items():
            spans.sort()
            m = [list(spans[0])]
            for a, b in spans[1:]:
                if a <= m[-1][1] + 0.35:          # fusionne les silences < 350 ms
                    m[-1][1] = max(m[-1][1], b)
                else:
                    m.append([a, b])
            out[inst] = [[round(a, 2), round(b, 2)] for a, b in m]
        return out

    act = {"bed": merge(build_bed())}
    for role, cands in CANDIDATES.items():
        for cid in cands:
            evs = build_role(role, cid)
            if evs:
                act[f"{role}__{cid}"] = merge(evs)
    return act


def load_casting(stems_dir: str) -> dict:
    """Lit casting.json a cote des pistes. Absent = page sans panneau de contexte."""
    path = os.path.join(stems_dir, "casting.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def render_provenance(stems_dir: str) -> str:
    """Transforme provenance.json en bloc d'attestation lisible dans la page.

    Sans rapport, on l'ecrit noir sur blanc plutot que d'afficher un bloc vide :
    une attestation absente ne doit jamais passer pour une attestation vide."""
    path = os.path.join(stems_dir, "provenance.json")
    if not os.path.exists(path):
        return ('<div class="prov"><div class="prov-head"><h3>Attestation du rendu</h3>'
                '<span class="pill">indisponible</span></div><div class="prov-body">'
                '<p>Aucun <code>provenance.json</code> a cote des stems : impossible '
                "d'attester de la provenance de cet audio.</p></div></div>")
    with open(path, encoding="utf-8") as fh:
        rep = json.load(fh)
    e = html.escape
    src = rep.get("sound_source", {})
    sampled = bool(src.get("external_samples"))
    out = [f'<div class="prov"><div class="prov-head"><h3>Attestation du rendu</h3>'
           f'<span class="pill {"sampled" if sampled else "synth"}">'
           f'{"échantillons extraits" if sampled else "synthèse — aucune source externe"}'
           f'</span></div><div class="prov-body">',
           f'<p>{e(src.get("statement", ""))}</p>', '<dl class="prov-rows">',
           f'<div><dt>Outil</dt><dd>{e(rep.get("tool", "?"))}</dd></div>',
           f'<div><dt>Rendu le</dt><dd>{e(rep.get("rendered_at", "?"))}</dd></div>']
    comp = rep.get("composition", {})
    out.append(f'<div><dt>Composition</dt><dd>{e(str(comp.get("key")))} · '
               f'{comp.get("bpm")} BPM · {comp.get("bars")} mesures · '
               f'boucle {comp.get("loop_seconds")} s</dd></div>')
    if sampled:
        sf = src.get("source_file") or {}
        out.append(f'<div><dt>Fichier source</dt><dd>{e(str(sf.get("filename", "?")))}</dd></div>')
        out.append(f'<div><dt>SHA-256 source</dt><dd>{e(str(sf.get("sha256", "?")))}</dd></div>')
        out.append(f'<div><dt>Extrait le</dt><dd>{e(str(src.get("extracted_at", "?")))}</dd></div>')
    else:
        out.append('<div><dt>Source externe</dt><dd>aucune</dd></div>')
    out.append('</dl>')

    if sampled and src.get("fonts"):
        rows = "".join(
            f'<tr><td class="k"><b>{e(role)}</b></td><td class="k">{e(str(f.get("id")))}</td>'
            f'<td>{e(str(f.get("group")))}</td><td class="k">{e(str(f.get("samp_offset")))}</td>'
            f'<td class="k">{e(str(f.get("base_note")))}</td>'
            f'<td class="k">{e(str(f.get("sample_rate")))}</td></tr>'
            for role, f in src["fonts"].items())
        out.append('<details open><summary>Échantillon utilisé par font</summary>'
                   '<div class="scroller"><table><thead><tr><th>Font</th><th>ID</th>'
                   '<th>Groupe AGSC</th><th>Offset SAMP</th><th>Note</th><th>Fréq.</th>'
                   f'</tr></thead><tbody>{rows}</tbody></table></div></details>')

    outs = rep.get("outputs", {})
    if outs:
        rows = "".join(f'<tr><td class="k">{e(f)}</td><td class="k">{e(m["sha256"])}</td></tr>'
                       for f, m in outs.items())
        out.append('<details><summary>Empreintes des fichiers produits '
                   f'({len(outs)})</summary><div class="scroller"><table><thead><tr>'
                   '<th>Fichier</th><th>SHA-256</th></tr></thead>'
                   f'<tbody>{rows}</tbody></table></div></details>')
    out.append('</div></div>')
    return "\n".join(out)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stems", default="audio/music/menu")
    ap.add_argument("--out", default="palette_broceliande.html")
    ap.add_argument("--embedded", action="store_true",
                    help="omet <!doctype>/<head> : pour les hebergeurs qui fournissent "
                         "leur propre enveloppe. Par defaut la page est autonome.")
    ap.add_argument("--template", default=None,
                    help="gabarit a utiliser (defaut : page_template.html). "
                         "app_template.html donne le lecteur pilotable.")
    ap.add_argument("--quality", default=None,
                    help="force la qualite VBR LAME pour toutes les pistes (0=meilleur, 9=pire)")
    args = ap.parse_args()

    import imageio_ffmpeg
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    tmp = os.path.join(os.path.dirname(args.out) or ".", "_web_tmp")
    os.makedirs(tmp, exist_ok=True)

    # MP3 et non OGG : Safari ne sait pas decoder Vorbis via decodeAudioData,
    # ce qui donne un silence complet sur iOS et macOS.
    # N'EMBARQUER QUE CE QUE LE GABARIT UTILISE. menu_theme n'est qu'un repli
    # pour les pages sans Web Audio ; le lecteur pilotable ne s'en sert pas et
    # ne le nomme nulle part. Il pesait pourtant 2,55 Mo d'OGG, soit ~3,4 Mo une
    # fois en base64 — de quoi faire passer la page de 12,6 a 16,0 Mo, contre une
    # limite de 16. On lit donc le gabarit AVANT d'encoder quoi que ce soit.
    tpl_probe = args.template or TEMPLATE
    if not os.path.isabs(tpl_probe):
        _here = os.path.dirname(os.path.abspath(__file__))
        tpl_probe = tpl_probe if os.path.exists(tpl_probe) else os.path.join(_here, tpl_probe)
    with open(tpl_probe, encoding="utf-8") as fh:
        _tpl_src = fh.read()

    audio = {}
    for name, rate in STEMS.items():
        if name != "bed" and name not in _tpl_src:
            print(f"  · {name} non utilise par le gabarit — non embarque")
            continue
        src = os.path.join(args.stems, f"{name}.ogg")
        dst = os.path.join(tmp, f"{name}.mp3")
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", src,
                        "-c:a", "libmp3lame", "-b:a", args.quality or rate, dst], check=True)
        with open(dst, "rb") as fh:
            audio[name] = base64.b64encode(fh.read()).decode()
        os.remove(dst)

    # ── PARTIES DE ROLE ──────────────────────────────────────────────────────
    cast = load_casting(args.stems)
    for role, cands in (cast.get("candidates") or {}).items():
        for entry in cands:
            name = f"{role}__{entry['id']}"
            src = os.path.join(args.stems, entry.get("file", name + ".ogg"))
            if not os.path.exists(src):
                print(f"  ! {name} absent", file=sys.stderr)
                continue
            dst = os.path.join(tmp, name + ".mp3")
            subprocess.run([ff, "-y", "-loglevel", "error", "-i", src, "-ac", "1",
                            "-ar", PART_RATE, "-c:a", "libmp3lame",
                            "-b:a", PART_BITRATE, dst], check=True)
            with open(dst, "rb") as fh:
                audio["P_" + name] = base64.b64encode(fh.read()).decode()
            os.remove(dst)

    # ── EFFETS D'AMBIANCE ────────────────────────────────────────────────────
    # Boucles courtes et un one-shot, synthetiques (sfx_ambiance.py). Mono a
    # debit modere : ce sont des textures, pas des instruments.
    for e in (cast.get("sfx") or []):
        src = os.path.join(args.stems, e["file"])
        if not os.path.exists(src):
            print(f"  ! effet {e['id']} absent", file=sys.stderr)
            continue
        dst = os.path.join(tmp, "fx_" + e["id"] + ".mp3")
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", src, "-ac", "1",
                        "-ar", "32000", "-c:a", "libmp3lame", "-b:a", "40k", dst],
                       check=True)
        with open(dst, "rb") as fh:
            audio["FX_" + e["id"]] = base64.b64encode(fh.read()).decode()
        os.remove(dst)

    # boucle silencieuse : sert a basculer la session audio iOS en "playback",
    # sans quoi le commutateur silencieux de l'iPhone coupe tout le Web Audio
    sil = os.path.join(tmp, "silence.mp3")
    subprocess.run([ff, "-y", "-loglevel", "error", "-f", "lavfi",
                    "-i", "anullsrc=r=44100:cl=mono", "-t", "1.0",
                    "-c:a", "libmp3lame", "-b:a", "32k", sil], check=True)
    with open(sil, "rb") as fh:
        audio["__silence"] = base64.b64encode(fh.read()).decode()
    os.remove(sil)
    os.rmdir(tmp)

    tpl_path = args.template or TEMPLATE
    if not os.path.isabs(tpl_path):
        here = os.path.dirname(os.path.abspath(__file__))
        tpl_path = tpl_path if os.path.exists(tpl_path) else os.path.join(here, tpl_path)
    with open(tpl_path, encoding="utf-8") as fh:
        tpl = fh.read()
    if "__AUDIO_JSON__" not in tpl:
        print("template sans marqueur __AUDIO_JSON__", file=sys.stderr)
        return 1
    page = tpl.replace("__AUDIO_JSON__", json.dumps(audio))
    page = page.replace("__CASTING_JSON__", json.dumps(cast, ensure_ascii=False))
    if "__ACTIVITY_JSON__" in page:
        act = build_activity()
        n_spans = sum(len(v) for t in act.values() for v in t.values())
        print(f"  activite : {len(act)} pistes, {n_spans} intervalles")
        page = page.replace("__ACTIVITY_JSON__", json.dumps(act))
    if "__PROVENANCE__" in page:
        page = page.replace("__PROVENANCE__", render_provenance(args.stems))
    if not args.embedded:
        page = make_standalone(page)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write(page)
    print(f"[page] {args.out}  ({os.path.getsize(args.out)/1024/1024:.2f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

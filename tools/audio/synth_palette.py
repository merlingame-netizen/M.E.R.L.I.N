#!/usr/bin/env python3
"""
Rendu du theme de menu M.E.R.L.I.N. — « Broceliande », version orchestrale.

    partition  score_menu.py      40 mesures a 49 BPM, conduite des voix, ornements
    pupitres   arrange_menu.py    le socle, plus l'ecriture des trois roles
    casting    casting_menu.py    qui tient quel role selon meteo/saison/moment
    lutherie   orchestra.py       modeles d'instruments synthetises
    ce fichier                    rendu, salle, mastering, boucle, attestation

Aucun echantillon externe par defaut : toute la matiere est synthetisee (chemin
"reconstruction" de docs/80_sound/30_music/MUSIC_TOOLCHAIN_PALETTE_PRIME.md §5).
--samples rejoue la meme partition avec des instruments enregistres sous CC0,
--bank avec des echantillons extraits d'une copie de jeu fournie par vous.

Sortie, tous cales sur la meme boucle :
  - `bed.ogg`, le socle, toujours audible
  - une piste par (role, candidat) : `chant__ocarina.ogg`, `corde__oud.ogg`, ...
    dont UNE SEULE par role est audible a la fois — c'est un remplacement,
    pas un empilement
  - `menu_theme.ogg`, le mix par defaut (socle + les trois titulaires)
  - `casting.json`, qui dit quel candidat prend quel role selon le contexte

Usage :
    python3 tools/audio/synth_palette.py --samples samples/ --out audio/music/menu
    python3 tools/audio/synth_palette.py --samples samples/ --only corde__oud
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import subprocess
import sys
import time
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import casting_menu as casting
import orchestra as orc
from arrange_menu import build_bed, build_events, build_role, summary
from score_menu import BPM, LOOP_LEN, LOOP_SAMPLES, N_BARS

TOOL_VERSION = "4.0.0"
SR = orc.SR
# LONGUEUR TOTALE DU RENDU, EN ECHANTILLONS — et la marge de queue en decoule.
#
# Meme raison que LOOP_SAMPLES dans score_menu.py : la longueur de travail passe
# dans des dizaines de FFT, et il ne faut donc que des petits facteurs premiers.
# 9 437 184 = 2^17 x 3^2 x 2^3 ... en clair : 2^20 x 9 = 9 437 184, que des
# facteurs 2 et 3.
#
# La marge de queue qui en resulte, 18,08 s, doit couvrir le pire cumul : une
# note qui finit apres le point de boucle (+1 s), sa reverbe ambiante (9 s) et
# ses reprises de delai (4,7 s). A 11 s la couture restait a 0,0115, sur la
# partie dont les notes debordent le plus.
def _next_5smooth(n: int) -> int:
    """Le plus petit entier 5-lisse (2^a 3^b 5^c) >= n — pour des FFT rapides."""
    best = None
    a = 1
    while a <= n * 2:
        b = a
        while b <= n * 2:
            c = b
            while c < n:
                c *= 5
            if best is None or c < best:
                best = c
            b *= 3
        a *= 2
    return best


# A l'echelle 1,0 la valeur historique est conservee (2^20 x 3^2). A une autre
# echelle (rendu de nuit MERLIN_TEMPO_SCALE=0,8), la boucle depasse ce total :
# on prend le premier 5-lisse au-dela de boucle + ~17,7 s de queue — a 0,8
# cela donne 11 664 000 = 2^7 x 3^6 x 5^3, queue de 19,6 s.
from score_menu import TEMPO_SCALE as _TS
TOTAL_SAMPLES = (9_437_184 if _TS == 1.0
                 else _next_5smooth(LOOP_SAMPLES + 780_000))
TAIL = (TOTAL_SAMPLES - LOOP_SAMPLES) / SR              # 18,08 s a l'echelle 1
BANK = None
SAMPLES = None      # banque multi-echantillons (instruments reellement enregistres)

# Quand une banque d'echantillons est fournie, elle expose 7 roles. Voici comment
# les pupitres s'y rabattent.
BANK_ROLE = {
    "strings_low": "pad_fm", "strings_mid": "pad_fm", "viola": "pad_fm",
    "contrabass": "sub", "horn": "pad_fm", "trombone": "pad_fm", "tuba": "sub",
    "bassoon": "pad_fm", "pad_fm": "pad_fm", "biniou_drone": "pad_fm",
    "strings_high": "choir", "strings_tremolo": "choir", "brass_ff": "choir",
    "trumpet": "choir", "choir": "choir", "violin_solo": "choir",
    "sub": "sub",
    "flute": "whistle", "oboe": "whistle", "clarinet": "whistle",
    "cor_anglais": "whistle", "piccolo": "whistle", "tin_whistle": "whistle",
    "bombarde": "whistle", "biniou": "whistle",
    "harp": "harp", "celtic_guitar": "harp", "pizzicato": "harp",
    "celesta_bell": "bell", "glockenspiel": "bell", "celesta": "bell",
    "timpani": "taiko", "taiko": "taiko", "bodhran": "taiko", "cymbal": "taiko",
    "tam_tam": "taiko", "snare_roll": "taiko",
}

INSTRUMENTS = {n: getattr(orc, n) for n in (
    "strings_low", "strings_mid", "strings_high", "strings_tremolo", "pizzicato",
    "contrabass", "viola", "violin_solo",
    "horn", "brass_ff", "trumpet", "trombone", "tuba",
    "flute", "oboe", "clarinet", "bassoon", "cor_anglais", "piccolo",
    "bombarde", "biniou", "biniou_drone", "tin_whistle",
    "harp", "celtic_guitar", "glockenspiel", "celesta_bell", "celesta",
    "timpani", "taiko", "bodhran", "choir", "pad_fm", "sub",
    "oud",
)}
# instruments sans hauteur definie : signature (duree, vel, seed)
UNPITCHED = {"cymbal": orc.cymbal_swell, "tam_tam": orc.tam_tam, "snare_roll": orc.snare_roll}

# Les instruments de distribution n'ont pas tous un modele synthetise : la
# plupart n'existent que sous forme d'enregistrement. Sans banque, ils se
# rabattent sur le pupitre le plus proche pour que l'ecriture reste verifiable.
for _li in {i for cands in casting.CANDIDATES.values()
            for (i, _g, _s, _l) in cands.values()}:
    if _li not in INSTRUMENTS and _li not in UNPITCHED:
        _fb = orc.LAYER_FALLBACK.get(_li)
        if _fb in UNPITCHED:
            UNPITCHED[_li] = UNPITCHED[_fb]
        elif _fb:
            INSTRUMENTS[_li] = INSTRUMENTS[_fb]

_note_cache: dict = {}


def midi_hz(m: float) -> float:
    return 440.0 * (2.0 ** ((m - 69.0) / 12.0))


def render_note(ev: dict) -> np.ndarray:
    """Rend un evenement. Les notes identiques sont mises en cache : la harpe et
    les percussions repetent beaucoup, et un pupitre de cordes coute cher."""
    inst, dur, vel = ev["inst"], ev["dur"], ev["vel"]
    if BANK is not None:
        role = BANK_ROLE.get(inst, "pad_fm")
        return BANK.render(role, midi_hz(ev["midi"]), dur)

    # Instrument reellement enregistre quand la banque en dispose. Le reste
    # reste synthetise : le couple breton (aucune bibliotheque libre n'a de
    # bombarde ni de biniou), la nappe FM froide et le sub — qui sont
    # electroniques par choix, pas par defaut.
    if SAMPLES is not None and SAMPLES.has(inst):
        # le seed entre dans la cle : sans lui, deux notes identiques
        # partageraient le meme rendu et la variation par note serait annulee
        key = ("S", inst, round(ev["midi"], 1), round(dur, 2),
               round(vel / 0.04) * 0.04, ev["seed"] % 24)
        if key in _note_cache:
            return _note_cache[key]
        sig = SAMPLES.render(inst, ev["midi"], dur, vel, seed=ev["seed"])
        if len(_note_cache) < 4000:
            _note_cache[key] = sig
        return sig

    # quantification pour le cache : imperceptible, mais tres rentable
    key = (inst, round(ev["midi"], 1), round(dur, 2), round(vel / 0.04) * 0.04, ev["seed"] % 16)
    if key in _note_cache:
        return _note_cache[key]

    if inst in UNPITCHED:
        sig = UNPITCHED[inst](dur, vel=vel, seed=ev["seed"])
    else:
        sig = INSTRUMENTS[inst](midi_hz(ev["midi"]), dur, vel=vel, seed=ev["seed"])
    sig = sig * orc.GAIN.get(inst, 1.0)
    if len(_note_cache) < 4000:
        _note_cache[key] = sig
    return sig


def render_stem(events: list[dict], n: int, verbose: bool = True) -> tuple[np.ndarray, np.ndarray]:
    """Retourne (direct stereo, depart de reverbe stereo) pour un stem."""
    dry = np.zeros((2, n))
    wet = np.zeros((2, n))
    for k, ev in enumerate(events):
        sig = render_note(ev)
        if sig.size == 0:
            continue
        i = int(ev["at"] * SR)
        if i >= n:
            continue
        l, r, send = orc.place(sig, ev["inst"], n, i)
        seg = min(len(l), n - i)
        dry[0, i:i + seg] += l[:seg]
        dry[1, i:i + seg] += r[:seg]
        wet[0, i:i + seg] += l[:seg] * send
        wet[1, i:i + seg] += r[:seg] * send
        if verbose and k and k % 100 == 0:
            print(f"      {k}/{len(events)} notes", flush=True)
    return dry, wet


def finish(dry, wet, halls, hall=0.95, amb=0.0, delay=0.0):
    """Salle proche + nappe ambiante + delai, puis repli de queue (boucle nette).

    Le reproche « trop synthetique » vient rarement des instruments eux-memes :
    il vient de ce qu'il y a AUTOUR. Une seule reverbe courte et nette laisse
    chaque note isolee dans le vide. Ici trois couches se superposent :
      - la salle proche (4 s), qui situe les pupitres sur une scene
      - une nappe longue et sombre (9 s), qui fond les notes entre elles
      - un delai a reinjection amortie, qui les etale encore
    """
    (ir_l, ir_r), (amb_l, amb_r) = halls
    out = dry
    out[0] += orc.convolve(wet[0], ir_l) * hall
    out[1] += orc.convolve(wet[1], ir_r) * hall
    if amb > 0:
        out[0] += orc.convolve(wet[0], amb_l) * amb
        out[1] += orc.convolve(wet[1], amb_r) * amb
    if delay > 0:
        for c in (0, 1):
            out[c] += orc.feedback_delay(wet[c], 0.789 + 0.041 * c, 0.44, 2600.0) * delay
    loop_n = LOOP_SAMPLES               # jamais int(LOOP_LEN * SR) : un arrondi
    tail_n = out.shape[1] - loop_n      # a l'echantillon pres decale la boucle
    head = out[:, :loop_n].copy()
    head[:, :tail_n] += out[:, loop_n:]
    return head


# ═══════════════════════════════════════════════════════════════════════════════
# MASTERING
# ═══════════════════════════════════════════════════════════════════════════════

def air(x: np.ndarray, gain_db: float = 3.0, fc: float = 4200.0,
        low_cut_db: float = 7.5, low_fc: float = 200.0) -> np.ndarray:
    """Basculement de master : shelf haut pour la brillance, shelf bas pour porter.

    Le shelf bas avait ete cale a -4 dB sur les modeles synthetises, qui empilaient
    45 % de l'energie sous 300 Hz. Avec les enregistrements reels le probleme
    s'inverse : VSCO-2 CE n'a AUCUN echantillon de contrebasse (le dossier existe
    mais il est vide), donc les contrebasses sont des violoncelles transposes vers
    le bas — sans le fondamental. Le shelf est devenu un RELEVEMENT de +2,5 dB.

    Puis le ralentissement a 58 BPM l'a rendu insuffisant : allonger toutes les
    figures d'accompagnement (guitare 3,4 -> 5,0 s, harpe 2,6 -> 3,6 s) ajoute du
    medium tenu sans rien ajouter dans le grave, et la part sous 300 Hz est
    retombee de 28,7 % a 15,3 %. Mesure a l'appui sur le mix rendu : +5 dB de
    plus a 200 Hz la ramenent a 21,4 %, dans la fourchette 20-35 % visee.

    Applique identiquement au mix et a chaque stem, pour que la somme reste egale."""
    n = x.shape[-1]
    spec = np.fft.rfft(x, axis=-1)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    r2 = (f / fc) ** 2
    hi = 1.0 + (10 ** (gain_db / 20.0) - 1.0) * r2 / (1.0 + r2)
    l2 = (f / low_fc) ** 2
    lo = 1.0 + (10 ** (low_cut_db / 20.0) - 1.0) / (1.0 + l2)
    return np.fft.irfft(spec * hi * lo, n, axis=-1)


def limit(x: np.ndarray, ceiling: float = 0.72, target_rms_db: float = -18.0) -> np.ndarray:
    """Cale le RMS sur une cible, PUIS protege la crete.

    Vorbis reconstruit des pics inter-echantillons 1 a 2 dB au-dessus du PCM
    source : normaliser au plafond ferait clipper a la lecture."""
    rms = float(np.sqrt((x ** 2).mean()))
    if rms > 0:
        x = x * (10 ** (target_rms_db / 20.0) / rms)
    y = np.tanh(x * 1.9) / 1.9
    peak = float(np.abs(y).max())
    if peak > ceiling:
        y = y * (ceiling / peak)
    return y


def peak_rms(x: np.ndarray, win: float = 0.5) -> float:
    """RMS de la fenetre la plus forte, et non RMS globale.

    Une partie de role est SPARSE : le halo joue 48 notes tres espacees en 196 s.
    Sa RMS globale est dominee par le silence, si bien que la caler sur une cible
    ferait exploser les notes pour compenser tout le vide autour. On mesure donc
    le niveau QUAND LA PARTIE SONNE.

    Fenetre de 500 ms : verifie sur trois bouffees de 400 ms noyees dans 20 s de
    silence contre un bruit continu de meme amplitude — la RMS globale les
    separait d'un facteur 4, cette mesure d'un facteur 1,1."""
    m = x.mean(axis=0) if x.ndim > 1 else x
    n = int(win * SR)
    if len(m) <= n:
        return float(np.sqrt((m ** 2).mean()))
    e = np.cumsum(np.concatenate([[0.0], m.astype(np.float64) ** 2]))
    starts = np.arange(0, len(m) - n, max(1, n // 8))
    return float(np.sqrt(np.max((e[starts + n] - e[starts]) / n)))


def write_wav(path: str, stereo: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    pcm = (np.clip(stereo.T, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def to_ogg(wav_path: str, ogg_path: str, quality: str = "4") -> None:
    import imageio_ffmpeg
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-y", "-loglevel", "error",
                    "-i", wav_path, "-c:a", "libvorbis", "-q:a", quality, ogg_path], check=True)


def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for blk in iter(lambda: fh.read(1 << 20), b""):
            h.update(blk)
    return h.hexdigest()


# ═══════════════════════════════════════════════════════════════════════════════
# RENDU D'UNE PARTIE
# ═══════════════════════════════════════════════════════════════════════════════

SEND = {                      # (reverbe ambiante, delai) par partie
    "bed":   (0.50, 0.20),
    "chant": (0.44, 0.24),
    "corde": (0.40, 0.18),
    "halo":  (0.68, 0.32),
    # Le pouls part le plus SEC des quatre. Une percussion tres reverberee perd
    # sa fonction : c'est elle qui donne le point d'appui rythmique, et une
    # queue longue le noie. Le milieu ajoutera sa propre reverbe a la lecture.
    "pulse": (0.22, 0.10),
}


def render_part(events: list[dict], n: int, halls, send: tuple[float, float],
                verbose: bool = False) -> np.ndarray:
    dry, wet = render_stem(events, n, verbose=verbose)
    out = finish(dry, wet, halls, hall=0.88, amb=send[0], delay=send[1])
    del dry, wet
    return orc.tape_wobble(out, seed=3)


# ═══════════════════════════════════════════════════════════════════════════════
# ATTESTATION
# ═══════════════════════════════════════════════════════════════════════════════

def write_provenance(out_dir: str, names: list[str], stats: dict, cast: dict) -> dict:
    rep = {
        "tool": f"synth_palette.py {TOOL_VERSION}",
        "rendered_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "composition": {"key": "D dorian", "bpm": round(BPM, 3), "bars": N_BARS,
                        "loop_seconds": round(LOOP_LEN, 3), "sample_rate": SR,
                        "form": "ouverture / air nu / air orne / refrain / harmonise / "
                                "developpement / plein / coda",
                        "instruments": stats["instruments"],
                        "note_events": stats["events"],
                        "roles": list(cast["roles"]),
                        "casting_parts": sum(len(v) for v in cast["candidates"].values())},
        "mode": "hybrid" if SAMPLES is not None else "synthesized",
    }
    if SAMPLES is not None:
        used = sorted({e["inst"] for e in build_events()} |
                      {c["instrument"] for v in cast["candidates"].values() for c in v})
        recorded = [i for i in used if SAMPLES.has(i)]
        synth_only = [i for i in used if not SAMPLES.has(i)]
        rep["sound_source"] = {
            "kind": "recorded_libraries", "external_samples": True,
            "libraries": SAMPLES.libraries,
            "recorded_instruments": recorded,
            "synthesized_instruments": synth_only,
            # une attestation fausse est pire qu'une absente : les alias
            # rejouent les echantillons d'un AUTRE instrument, traites
            "aliased_instruments": {
                "music_box": "celesta (enveloppe pincee)",
                "oud": "celtic_guitar (double choeur desaccorde + passe-bas "
                       "— aucune banque d'oud a licence libre n'existe)",
            },
            "statement": f"{len(recorded)} pupitres sur {len(used)} rejouent des "
                         "instruments reellement enregistres, issus de bibliotheques "
                         "sous CC0 (domaine public, usage commercial compris, sans "
                         "attribution requise). "
                         + (f"Les {len(synth_only)} autres sont des modeles synthetises, "
                            "faute de source libre." if synth_only else "")
                         + " AUCUN echantillon issu de Metroid Prime n'est utilise.",
        }
    else:
        rep["sound_source"] = {
            "kind": "synthesis", "external_samples": False,
            "statement": "Aucun echantillon externe. Chaque pupitre est un modele "
                         "synthetise et la salle est une reverbe a convolution sur "
                         "reponses impulsionnelles generees.",
        }
    rep["outputs"] = {}
    for name in names:
        f = os.path.join(out_dir, f"{name}.ogg")
        if os.path.exists(f):
            rep["outputs"][f"{name}.ogg"] = {"sha256": sha256_file(f),
                                             "bytes": os.path.getsize(f)}

    with open(os.path.join(out_dir, "provenance.json"), "w", encoding="utf-8") as fh:
        json.dump(rep, fh, indent=2, ensure_ascii=False)

    src, c = rep["sound_source"], rep["composition"]
    MODE = {"synthesis": "SYNTHETISE (aucune source externe)",
            "recorded_libraries": "HYBRIDE (instruments enregistres CC0 + synthese)"}
    lines = ["# Provenance du rendu audio", "",
             f"- **Mode** : {MODE.get(src.get('kind'), '?')}",
             f"- **Outil** : {rep['tool']}", f"- **Rendu le** : {rep['rendered_at']}",
             f"- **Composition** : {c['key']}, {c['bpm']:.0f} BPM, {c['bars']} mesures, "
             f"boucle {c['loop_seconds']} s",
             f"- **Effectif** : {c['instruments']} instruments, {c['note_events']} evenements",
             f"- **Distribution** : {len(c['roles'])} roles, {c['casting_parts']} parties", "",
             f"> {src['statement']}", ""]
    if src.get("kind") == "recorded_libraries":
        lines += ["## Bibliothèques utilisées", "",
                  "| Bibliothèque | Auteur | Licence | Source |", "|---|---|---|---|"]
        for lib in src.get("libraries", []):
            lines.append(f"| {lib.get('name')} | {lib.get('author')} | "
                         f"`{lib.get('license')}` | {lib.get('url')} |")
        rec, syn = src["recorded_instruments"], src["synthesized_instruments"]
        lines += ["", f"## Pupitres enregistrés ({len(rec)})", "",
                  ", ".join(f"`{i}`" for i in rec), "",
                  f"## Pupitres synthétisés ({len(syn)})", "",
                  ", ".join(f"`{i}`" for i in syn) or "_aucun_", ""]
    lines += ["## Fichiers produits", "", "| Fichier | SHA-256 | Octets |", "|---|---|---|"]
    for f, meta in rep["outputs"].items():
        lines.append(f"| `{f}` | `{meta['sha256']}` | {meta['bytes']} |")
    lines.append("")
    with open(os.path.join(out_dir, "PROVENANCE.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    return rep


# ═══════════════════════════════════════════════════════════════════════════════

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="audio/music/menu")
    ap.add_argument("--keep-wav", action="store_true")
    ap.add_argument("--samples", default=None,
                    help="banque multi-echantillons (sortie de build_sample_bank.py)")
    ap.add_argument("--only", default=None,
                    help="ne rend que ces parties (bed, chant__ocarina, ...), separees "
                         "par des virgules. Le niveau de reference est relu dans "
                         "casting.json, donc la partie ressort au meme niveau.")
    args = ap.parse_args()

    global SAMPLES
    if args.samples:
        from sample_bank import MultiSampleBank
        SAMPLES = MultiSampleBank(args.samples)

    t_start = time.time()
    cast = casting.manifest()
    bed = build_bed()
    stats = summary(build_events())
    print(f"[synth] {N_BARS} mesures @ {BPM:.0f} BPM = {LOOP_LEN:.2f}s")
    print(f"[synth] socle {len(bed)} notes, {len(casting.all_parts())} parties de role")

    n = TOTAL_SAMPLES
    halls = (orc.stereo_hall(seconds=4.2, decay=5.2, damp=3100.0, seed=7, width=0.24),
             orc.stereo_hall(seconds=9.0, decay=3.1, damp=1300.0, seed=23, width=0.28))

    only = [s.strip() for s in args.only.split(",")] if args.only else None
    ref_path = os.path.join(args.out, "casting.json")
    ref = {}
    if only and os.path.exists(ref_path):
        with open(ref_path, encoding="utf-8") as fh:
            ref = json.load(fh).get("levels", {})
    if only and not ref:
        raise SystemExit("--only exige un casting.json issu d'un rendu complet.")

    os.makedirs(args.out, exist_ok=True)
    outputs: dict = {}
    levels: dict = dict(ref)
    keep: dict = {}

    def wanted(name: str) -> bool:
        return only is None or name in only

    # ── LE SOCLE ─────────────────────────────────────────────────────────────
    if wanted("bed"):
        print("[synth] socle …", flush=True)
        sig = render_part(bed, n, halls, SEND["bed"], verbose=True)
        levels["bed"] = {"peak_rms": peak_rms(sig), "rms": float(np.sqrt((sig ** 2).mean()))}
        keep["bed"] = sig
    _note_cache.clear()

    # ── LES ROLES ────────────────────────────────────────────────────────────
    # Le titulaire par defaut est rendu EN PREMIER : son niveau devient la cible
    # de tous les autres candidats du role. C'est ce qui garantit qu'un changement
    # de distribution ne s'entende pas comme un changement de volume.
    for role in cast["roles"]:
        default = casting.DEFAULT[role]
        order = [default] + [c for c in casting.CANDIDATES[role] if c != default]
        target = None
        for cand in order:
            name = f"{role}__{cand}"
            if not wanted(name):
                if levels.get(name) and cand == default:
                    target = levels[name]["rms"]
                continue
            sig = render_part(build_role(role, cand), n, halls, SEND[role])
            # ON APPARIE SUR LA RMS, PAS SUR LA FENETRE LA PLUS FORTE.
            #
            # peak_rms() est le bon outil pour comparer des parties de DENSITES
            # differentes — c'est pour ca qu'il existe. Mais deux candidats d'un
            # meme role portent exactement les memes notes aux memes instants :
            # leurs densites sont identiques, et leurs RMS directement comparables.
            #
            # Surtout, la RMS est ce qui SURVIT au master : limit() recale chaque
            # sortie sur une RMS cible. Apparier les cretes puis laisser le master
            # renormaliser en RMS defaisait une partie de l'appariement — mesure a
            # l'appui, les cinq candidats du role `corde` sortaient sur 2,52 dB,
            # le psalterion (son tenu, donc RMS elevee pour ses cretes) 2,4 dB
            # sous la guitare.
            p = float(np.sqrt((sig ** 2).mean()))
            if cand == default:
                target = p
            elif target:
                sig = sig * (target / max(p, 1e-9))     # meme niveau percu
            levels[name] = {"peak_rms": peak_rms(sig),
                            "rms": float(np.sqrt((sig ** 2).mean()))}
            keep[name] = sig
            print(f"[synth]   {role:6s} {cand:14s} {len(build_role(role, cand)):3d} notes",
                  flush=True)
        _note_cache.clear()

    # ── LE MIX PAR DEFAUT ────────────────────────────────────────────────────
    # Il ne sert qu'a deux choses : le repli <audio> de la page, et le cas simple
    # cote jeu. Il vaut EXACTEMENT socle + les trois titulaires.
    mix = None
    if only is None:
        mix = keep["bed"].astype(np.float64).copy()
        for role in cast["roles"]:
            mix += keep[f"{role}__{casting.DEFAULT[role]}"]
        mix_rms = float(np.sqrt((mix ** 2).mean()))
        outputs["menu_theme"] = limit(air(mix))
    else:
        mix_rms = ref.get("__mix", {}).get("rms")
        if not mix_rms:
            raise SystemExit("casting.json sans niveau de mix : refaites un rendu complet.")

    # chaque partie garde son niveau RELATIF au mix : la somme doit redonner le mix
    for name, sig in keep.items():
        off = 20.0 * np.log10(max(levels[name]["rms"], 1e-9) / max(mix_rms, 1e-9))
        levels[name]["rel_db"] = round(off, 2)
        outputs[name] = limit(air(sig), ceiling=0.72, target_rms_db=-18.0 + off)
    keep.clear()
    levels["__mix"] = {"rms": mix_rms}

    for name, sig in outputs.items():
        wav = os.path.join(args.out, f"{name}.wav")
        ogg = os.path.join(args.out, f"{name}.ogg")
        write_wav(wav, sig)
        to_ogg(wav, ogg)
        print(f"[synth] {ogg}  ({os.path.getsize(ogg)/1024:.0f} KB)")
        if not args.keep_wav:
            os.remove(wav)

    cast["levels"] = levels
    cast["loop_seconds"] = round(LOOP_LEN, 3)
    cast["bpm"] = round(BPM, 3)
    # PRESERVER CE QUE D'AUTRES OUTILS ONT ECRIT. sfx_ambiance.py declare ses
    # effets dans casting.json ; reecrire le fichier depuis manifest() les
    # effacait en silence — un rendu --only faisait disparaitre la section
    # Effets de la page. On recopie les cles etrangeres au rendu.
    if os.path.exists(ref_path):
        with open(ref_path, encoding="utf-8") as fh:
            prev = json.load(fh)
        for k, v in prev.items():
            if k not in cast:
                cast[k] = v
    with open(ref_path, "w", encoding="utf-8") as fh:
        json.dump(cast, fh, indent=2, ensure_ascii=False)

    if only is None:
        rep = write_provenance(args.out, list(outputs), stats, cast)
        print(f"[prov ] mode = {rep['mode'].upper()} — "
              f"{len(rep['sound_source'].get('recorded_instruments', []))} pupitres enregistres")
    else:
        n_up = refresh_provenance_hashes(args.out, list(outputs))
        print(f"[prov ] {n_up} empreinte(s) reactualisee(s)")
    print(f"[synth] OK — boucle {LOOP_LEN:.3f}s, {len(outputs)} fichiers "
          f"({time.time()-t_start:.0f}s)")
    return 0


def refresh_provenance_hashes(out_dir: str, names: list[str]) -> int:
    """Reactualise les empreintes qu'un rendu partiel vient de reecrire.

    Sans ca, PROVENANCE.md continuerait d'annoncer le SHA-256 de la version
    precedente. Une attestation fausse est pire qu'une absente."""
    pj = os.path.join(out_dir, "provenance.json")
    if not os.path.exists(pj):
        return 0
    with open(pj, encoding="utf-8") as fh:
        rep = json.load(fh)
    outs = rep.setdefault("outputs", {})
    changed = 0
    for name in names:
        f = os.path.join(out_dir, f"{name}.ogg")
        if not os.path.exists(f):
            continue
        entry = {"sha256": sha256_file(f), "bytes": os.path.getsize(f)}
        if outs.get(f"{name}.ogg") != entry:
            outs[f"{name}.ogg"] = entry
            changed += 1
    rep["partial_rerender"] = {
        "at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "parts": sorted(names),
        "note": "Rendu partiel : seules ces parties ont ete refaites.",
    }
    with open(pj, "w", encoding="utf-8") as fh:
        json.dump(rep, fh, indent=2, ensure_ascii=False)
    md = os.path.join(out_dir, "PROVENANCE.md")
    if os.path.exists(md):
        with open(md, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
        for i, line in enumerate(lines):
            for name in names:
                if line.startswith(f"| `{name}.ogg` |"):
                    e = outs[f"{name}.ogg"]
                    lines[i] = f"| `{name}.ogg` | `{e['sha256']}` | {e['bytes']} |"
        pr = rep["partial_rerender"]
        lines += ["", "## Rendu partiel", "", f"- **Le** : {pr['at']}",
                  f"- **Parties refaites** : {', '.join('`' + n + '`' for n in pr['parts'])}",
                  "", f"> {pr['note']}", ""]
        with open(md, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines))
    return changed


if __name__ == "__main__":
    sys.exit(main())

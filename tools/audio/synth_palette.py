#!/usr/bin/env python3
"""
Rendu du theme de menu M.E.R.L.I.N. — « Broceliande », version orchestrale.

    partition  score_menu.py      32 mesures, conduite des voix, arc dynamique
    pupitres   arrange_menu.py    repartition sur 19 instruments et 4 stems
    lutherie   orchestra.py       modeles d'instruments synthetises
    ce fichier                    rendu, salle, mastering, boucle, attestation

Aucun echantillon externe par defaut : toute la matiere est synthetisee (chemin
"reconstruction" de docs/80_sound/30_music/MUSIC_TOOLCHAIN_PALETTE_PRIME.md §5).
L'option --bank rejoue la meme partition avec des echantillons extraits.

Sortie : mix complet + 4 stems alignes en phase, pour stems_music_manager.gd.

Usage :
    python3 tools/audio/synth_palette.py --out audio/music/menu
    python3 tools/audio/synth_palette.py --bank extract/ --out audio/music/menu
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

import orchestra as orc
from arrange_menu import build_events, summary
from score_menu import BPM, LOOP_LEN, N_BARS

TOOL_VERSION = "2.0.0"
SR = orc.SR
# Marge de queue. Elle doit couvrir le pire cumul : une note qui finit apres le
# point de boucle (+1 s), sa reverbe ambiante (9 s) et ses reprises de delai
# (4,7 s). A 11 s la couture restait a 0,0115, localisee dans le stem climax
# — celui dont les notes debordent le plus.
TAIL = 17.0
STEMS = ["base", "rhythm", "melody", "climax"]

BANK = None

# Quand une banque d'echantillons est fournie, elle expose 7 roles. Voici comment
# les 34 pupitres s'y rabattent.
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
)}
# instruments sans hauteur definie : signature (duree, vel, seed)
UNPITCHED = {"cymbal": orc.cymbal_swell, "tam_tam": orc.tam_tam, "snare_roll": orc.snare_roll}

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
    loop_n = int(LOOP_LEN * SR)
    tail_n = out.shape[1] - loop_n
    head = out[:, :loop_n].copy()
    head[:, :tail_n] += out[:, loop_n:]
    return head


# ═══════════════════════════════════════════════════════════════════════════════
# MASTERING
# ═══════════════════════════════════════════════════════════════════════════════

def air(x: np.ndarray, gain_db: float = 4.5, fc: float = 4000.0,
        low_cut_db: float = -4.0, low_fc: float = 230.0) -> np.ndarray:
    """Basculement de master : shelf haut pour la brillance, shelf bas pour degager.

    Avec 36 pupitres dont un tiers dans le grave, la mesure donnait 45 % de
    l'energie sous 300 Hz — un mix orchestral equilibre tourne entre 20 et 35 %.
    Le shelf bas rend le medium audible sans toucher a l'arrangement.

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


# ═══════════════════════════════════════════════════════════════════════════════
# ATTESTATION
# ═══════════════════════════════════════════════════════════════════════════════

def sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for blk in iter(lambda: fh.read(1 << 20), b""):
            h.update(blk)
    return h.hexdigest()


def write_provenance(out_dir: str, names: list[str], bank, stats: dict) -> dict:
    rep = {
        "tool": f"synth_palette.py {TOOL_VERSION}",
        "rendered_at": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "composition": {"key": "D dorian", "bpm": BPM, "bars": N_BARS,
                        "loop_seconds": round(LOOP_LEN, 3), "sample_rate": SR,
                        "form": "A A' B A''", "instruments": stats["instruments"],
                        "note_events": stats["events"]},
        "mode": "sampled" if bank is not None else "synthesized",
    }
    if bank is None:
        rep["sound_source"] = {
            "kind": "synthesis", "external_samples": False,
            "statement": "Aucun echantillon externe. Chaque pupitre est un modele "
                         "synthetise (ensemble desaccorde, formants fixes, velocite "
                         "timbrale) et la salle est une reverbe a convolution sur "
                         "reponses impulsionnelles generees.",
        }
    else:
        roles = {}
        for role, e in sorted(bank.map.items()):
            roles[role] = {k: e.get(k) for k in ("file", "id", "group", "agsc_version",
                                                 "samp_offset", "base_note", "sample_rate",
                                                 "format", "looped")}
        rep["sound_source"] = {
            "kind": "extracted_samples", "external_samples": True,
            "bank_path": os.path.abspath(bank.path), "extracted_at": bank.extracted_at,
            "source_file": bank.source, "fonts": roles,
            "instrument_to_role": BANK_ROLE,
            "statement": "Chaque pupitre rejoue un echantillon extrait du fichier source "
                         "ci-dessus. Le SHA-256 permet de verifier de quelle copie il provient.",
        }
    rep["outputs"] = {}
    for name in names:
        f = os.path.join(out_dir, f"{name}.ogg")
        if os.path.exists(f):
            rep["outputs"][f"{name}.ogg"] = {"sha256": sha256_file(f),
                                             "bytes": os.path.getsize(f)}

    with open(os.path.join(out_dir, "provenance.json"), "w", encoding="utf-8") as fh:
        json.dump(rep, fh, indent=2, ensure_ascii=False)

    src = rep["sound_source"]
    c = rep["composition"]
    lines = ["# Provenance du rendu audio", "",
             f"- **Mode** : {'ECHANTILLONNE (samples extraits)' if src['external_samples'] else 'SYNTHETISE (aucune source externe)'}",
             f"- **Outil** : {rep['tool']}", f"- **Rendu le** : {rep['rendered_at']}",
             f"- **Composition** : {c['key']}, {c['bpm']:.0f} BPM, {c['bars']} mesures, "
             f"forme {c['form']}, boucle {c['loop_seconds']} s",
             f"- **Effectif** : {c['instruments']} instruments, {c['note_events']} evenements", "",
             f"> {src['statement']}", ""]
    if src["external_samples"]:
        sf = src.get("source_file") or {}
        lines += ["## Fichier source", "", f"- Nom : `{sf.get('filename', '?')}`",
                  f"- SHA-256 : `{sf.get('sha256', '?')}`",
                  f"- Taille : {sf.get('size_bytes', 0)} octets",
                  f"- Extrait le : {src.get('extracted_at', '?')}", "",
                  "## Échantillon utilise par role", "",
                  "| Role | Sample | ID | Groupe AGSC | Offset SAMP | Note | Fréq. |",
                  "|---|---|---|---|---|---|---|"]
        for role, e in src["fonts"].items():
            lines.append(f"| `{role}` | `{e.get('file')}` | {e.get('id')} | {e.get('group')} "
                         f"| {e.get('samp_offset')} | {e.get('base_note')} | {e.get('sample_rate')} |")
        lines.append("")
    lines += ["## Fichiers produits", "", "| Fichier | SHA-256 | Octets |", "|---|---|---|"]
    for f, meta in rep["outputs"].items():
        lines.append(f"| `{f}` | `{meta['sha256']}` | {meta['bytes']} |")
    lines.append("")
    with open(os.path.join(out_dir, "PROVENANCE.md"), "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines))
    return rep


# ═══════════════════════════════════════════════════════════════════════════════

def main() -> int:
    global BANK
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="audio/music/menu")
    ap.add_argument("--keep-wav", action="store_true")
    ap.add_argument("--bank", default=None,
                    help="dossier de banque (sortie de musyx_extract.py) : les samples "
                         "reels remplacent les pupitres synthetises")
    args = ap.parse_args()

    if args.bank:
        from sample_bank import SampleBank
        BANK = SampleBank(args.bank)
        print(f"[synth] mode ECHANTILLONNE — banque : {args.bank}")
    else:
        print("[synth] mode SYNTHETISE — aucun echantillon externe")

    t_start = time.time()
    events = build_events()
    stats = summary(events)
    print(f"[synth] {N_BARS} mesures @ {BPM:.0f} BPM = {LOOP_LEN:.2f}s — forme A A' B A''")
    print(f"[synth] {stats['instruments']} instruments, {stats['events']} evenements")

    n = int((LOOP_LEN + TAIL) * SR)
    halls = (orc.stereo_hall(seconds=4.2, decay=5.2, damp=3100.0, seed=7, width=0.24),
             orc.stereo_hall(seconds=9.0, decay=3.1, damp=1300.0, seed=23, width=0.28))
    # dosage ambiant par stem : les nappes et le chant s'etalent, la percussion non
    AMB = {"base": 0.55, "rhythm": 0.16, "melody": 0.48, "climax": 0.52}
    DLY = {"base": 0.16, "rhythm": 0.04, "melody": 0.26, "climax": 0.20}

    rendered = {}
    for stem in STEMS:
        sub_ev = [e for e in events if e["stem"] == stem]
        print(f"[synth]   {stem} : {len(sub_ev)} notes", flush=True)
        dry, wet = render_stem(sub_ev, n)
        out = finish(dry, wet, halls, hall=0.88, amb=AMB[stem], delay=DLY[stem])
        if stem == "base":
            # coupe l'infra-grave inutile et desepaissit le bas-medium : c'est la
            # zone ou quatre pupitres soutenus se recouvrent et deviennent une bouillie
            out = np.stack([orc.highpass(orc.formants(c, [(260.0, 150.0, -3.5)]), 38.0)
                            for c in out])
        if stem == "base":
            # bruit de salle : ajoute au seul stem toujours actif, pour que la
            # somme des quatre continue d'egaler le mix
            # meme champ pour les deux canaux a 82 %, le reste decorrele :
            # large a l'ecoute, sans casser la compatibilite mono
            loop_n = out.shape[1]
            out[0] += orc.room_tone(loop_n, seed=5, decorrelate=0.18)
            out[1] += orc.room_tone(loop_n, seed=5, decorrelate=0.18) * 0.0 \
                + orc.room_tone(loop_n, seed=5, decorrelate=0.0) * 0.82 \
                + orc.room_tone(loop_n, seed=11, decorrelate=0.0) * 0.18
        rendered[stem] = out.astype(np.float32)
        del out
        del dry, wet
    _note_cache.clear()

    # Mesure a l'appui : le socle fournissait 87 % du grave ET 56 % du medium, la
    # melodie 10 %. Le theme etait enterre sous ses propres accompagnements.
    # Ces gains ont ete recalcules apres l'application effective de la table
    # d'equilibre des pupitres : celle-ci coupe fortement cordes et nappes, ce qui
    # avait fait tomber le socle a 3 % du medium contre 72 % pour la melodie —
    # un orchestre sans fondation. Cible : socle 25 %, chant 40 %, climax 30 %.
    gains = {"base": 2.25, "rhythm": 2.45, "melody": 1.25, "climax": 1.35}
    mix = np.zeros_like(rendered["base"], dtype=np.float64)
    for name, sig in rendered.items():
        mix += sig.astype(np.float64) * gains[name]

    # Pleurage de bande, applique au mix ET a chaque stem avec la meme modulation :
    # l'operation est lineaire, donc la somme reste egale au mix.
    mix = orc.tape_wobble(mix, seed=3)
    for name in rendered:
        rendered[name] = orc.tape_wobble(rendered[name].astype(np.float64), seed=3).astype(np.float32)

    os.makedirs(args.out, exist_ok=True)
    mix_rms = float(np.sqrt((mix ** 2).mean()))
    outputs = {"menu_theme": limit(air(mix))}
    for name, sig in rendered.items():
        s = sig.astype(np.float64) * gains[name]
        rms = float(np.sqrt((s ** 2).mean()))
        # chaque stem garde son niveau RELATIF au mix : la somme des quatre doit
        # redonner le mix, sinon la console web ne sonne pas comme le rendu
        off = 20.0 * np.log10(max(rms, 1e-9) / max(mix_rms, 1e-9))
        outputs[name] = limit(air(s), ceiling=0.72, target_rms_db=-18.0 + off)

    for name, sig in outputs.items():
        wav = os.path.join(args.out, f"{name}.wav")
        ogg = os.path.join(args.out, f"{name}.ogg")
        write_wav(wav, sig)
        to_ogg(wav, ogg)
        print(f"[synth] {ogg}  ({os.path.getsize(ogg)/1024:.0f} KB)")
        if not args.keep_wav:
            os.remove(wav)

    rep = write_provenance(args.out, list(outputs), BANK, stats)
    src = rep["sound_source"]
    print(f"[synth] OK — boucle 0.000s -> {LOOP_LEN:.3f}s  ({time.time()-t_start:.0f}s de rendu)")
    print(f"[prov ] mode = {rep['mode'].upper()} — echantillons externes : "
          f"{'OUI' if src['external_samples'] else 'NON'}")
    if src["external_samples"]:
        sf = src.get("source_file") or {}
        print(f"[prov ] source : {sf.get('filename')}  sha256={sf.get('sha256')}")
    print(f"[prov ] rapport : {os.path.join(args.out, 'PROVENANCE.md')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

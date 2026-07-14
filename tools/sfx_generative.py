# -*- coding: utf-8 -*-
"""SFX GENERATIF M.E.R.L.I.N. — sons RICHES via Stable Audio (gratuit, HF Space).

Pipeline HYBRIDE (BIBLE §22) : les 12 ticks UI secs restent en synthese physique
procedurale (tools/sfx_forge.py, ne PAS regenerer ici — le generatif floute leur
transitoire). Cet outil ne genere QUE les 13 sons "riches" (7 stingers de degre/fin
+ 6 evenements atmospheriques) via un modele texte->audio, puis les post-traite avec
EXACTEMENT la meme norme de loudness que la forge v4 (tools/sfx_normalize.py :
pyloudnorm par categorie + true-peak -14 dBFS), pour que generatif et procedural
soient homogenes une fois melanges dans le bus SFX.

Space principal : stabilityai/stable-audio-3 (endpoint /infer, variante 'small-sfx').
Auth : HF_TOKEN via huggingface_hub.get_token() (compte Mhax69 present sur le poste).
Quota : ZeroGPU gratuit -> quand epuise ('exceeded your GPU quota'), l'outil s'ARRETE
proprement et note les id restants (jamais de boucle qui brule le quota).

Sorties :
    output/gen_sfx/<id>_gen.wav   raw Space (44.1k stereo)  -> permet de re-post-traiter
                                   sans re-depenser de quota
    output/gen_sfx/<id>.wav        staged mono 16-bit 44.1k normalise (drop-in candidat)
    output/gen_sfx/manifest.json   id -> prompt/seed/duree/categorie/LUFS/true-peak/statut

Le drop-in dans audio/sfx/ + validate + commit est fait par le COORDINATEUR apres le P0.
Cet outil ne touche NI scripts/ NI merlin_audio.gd NI Godot. 100% headless, pur-python.

Usage (interpreteur Store-safe obligatoire) :
    PY="C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe"
    "$PY" tools/sfx_generative.py --all              # genere tout le pending (jusqu'au quota)
    "$PY" tools/sfx_generative.py --all --max 4      # limite a 4 generations ce run (menager le quota)
    "$PY" tools/sfx_generative.py --id stinger_reussite --force   # (re)genere un id
    "$PY" tools/sfx_generative.py --list             # etat : done / pending / raw-only
    "$PY" tools/sfx_generative.py --prompts          # dump le manifest de prompts (a ajuster)
    "$PY" tools/sfx_generative.py --restage          # re-post-traite depuis les raw (0 GPU)
    "$PY" tools/sfx_generative.py --space fantaxy/Sound-AI-SFX --all   # bascule Space fallback
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import time
from pathlib import Path

import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from tools import sfx_normalize as norm  # noqa: E402

OUT_DIR = ROOT / "output" / "gen_sfx"
MANIFEST_PATH = OUT_DIR / "manifest.json"
SR = norm.SR

# ── Norme de loudness par CATEGORIE — MIROIR de sfx_forge v4 (single source) ───
# Import primaire depuis la forge (reste en phase automatiquement) ; fallback code
# en dur si l'import echoue (GPO/chemins), pour garder l'outil autonome.
try:
    from tools.sfx_forge import TARGETS as _FORGE_TARGETS, CREST_CAPS as _FORGE_CRESTS
    TARGETS = dict(_FORGE_TARGETS)
    CREST_CAPS = dict(_FORGE_CRESTS)
    _NORM_SRC = "sfx_forge"
except Exception:  # pragma: no cover — filet si l'import de la forge casse
    TARGETS = {"tick": -26.5, "foley": -26.5, "drone": -25.0, "accent": -25.5,
               "impact": -26.0, "stinger": -24.5, "ending": -24.5}
    CREST_CAPS = {"tick": 12.5, "foley": 12.5, "drone": 11.0, "accent": 11.5,
                  "impact": 12.0, "stinger": 11.0, "ending": 11.0}
    _NORM_SRC = "hardcoded-fallback"

# ── Direction sonore : ton merveilleux-inquietant celtique (JDR) ───────────────
# Chaque prompt = single sound effect descriptif + negatif anti-musique.
# La categorie MAPPE 1:1 sur le registre RECIPES de sfx_forge (meme cible LUFS),
# pour que le son generatif s'aligne exactement sur son equivalent procedural.
_NEG = "Single sound effect, no music, no melody, no speech, close, short."
_NEG_LONG = "Single sound effect, no music, no melody, no speech, close."
_NEG_VOICE = "Single soft sound, no music, no melody, close."  # voice_blip = syllabe soufflee : ne PAS interdire la voix

# NOTE COMPORTEMENT (observe 2026-07-14) : le Space PLANCHE la duree a la seconde
# ENTIERE inferieure (2.2/2.4/2.6 -> 2.0s ; 1.8/1.4/1.2 -> 1.0s ; 3.0 -> 3.0s).
# => TOUJOURS demander une duree ENTIERE. Une valeur fractionnaire raccourcit le
# rendu (ex: 1.8 devient 1.0s), ce qui a coupe les swells au premier batch.

MANIFEST_PROMPTS: dict[str, dict] = {
    # ── 7 STINGERS ────────────────────────────────────────────────────────────
    "stinger_echec": {
        "prompt": "Dissonant celtic strings falling, single dark ominous hit with a low "
                  "drone, foreboding failure. " + _NEG,
        "duration": 2.2, "seed": 4101, "category": "stinger"},
    "stinger_partiel": {
        "prompt": "Uncertain celtic harp with a soft muted bell, single hesitant "
                  "half-resolved tone, bittersweet. " + _NEG,
        "duration": 2.2, "seed": 4102, "category": "stinger"},
    "stinger_reussite": {
        "prompt": "Warm resolved celtic harp and glowing low drone chord, single full "
                  "hopeful bloom, rich and rounded, gentle bell shimmer. " + _NEG,
        "duration": 2.0, "seed": 4153, "category": "stinger"},
    "stinger_eclatante": {
        "prompt": "Radiant crystalline bell and harp burst, single triumphant shimmering "
                  "bloom. " + _NEG,
        "duration": 2.6, "seed": 4104, "category": "stinger"},
    # ── 3 STINGERS DE FIN ─────────────────────────────────────────────────────
    "stinger_fin_accomplissement": {
        "prompt": "Serene celtic singing bowl and harp over a soft drone, single sustained "
                  "sacred resolve, luminous and complete. " + _NEG_LONG,
        "duration": 3.0, "seed": 4111, "category": "ending"},
    "stinger_fin_mort": {
        "prompt": "Deep grave celtic drone with a single low bell toll, sombre final "
                  "passing, mournful. " + _NEG_LONG,
        "duration": 3.0, "seed": 4112, "category": "ending"},
    "stinger_fin_corrompu": {
        "prompt": "Distorted detuned bell and dark whisper swell, single corrupted decaying "
                  "tone, unsettling and wrong. " + _NEG_LONG,
        "duration": 3.0, "seed": 4113, "category": "ending"},
    # ── 6 EVENEMENTS ATMOSPHERIQUES ───────────────────────────────────────────
    "draft_reveal": {
        "prompt": "Mystical celtic chime arpeggio revealing, single wondrous sparkling "
                  "flourish, enchanted. " + _NEG,
        "duration": 2.0, "seed": 4201, "category": "accent"},
    "whisper_threshold": {
        "prompt": "Eerie corrupted whisper rising, breathy airy unsettling swell, wordless. "
                  + _NEG,
        "duration": 1.0, "seed": 4202, "category": "drone"},
    "corruption_tick": {
        "prompt": "Small dissonant metallic bell tick with a dark drift, single unsettling "
                  "ping. " + _NEG,
        "duration": 1.0, "seed": 4203, "category": "impact"},
    "ink_wash": {
        "prompt": "Soft wet quill ink wash stroke on parchment, single gentle brush, "
                  "close and intimate. " + _NEG,
        "duration": 1.0, "seed": 4204, "category": "foley"},
    "question_transition": {
        "prompt": "Soft mystical airy drone swell, single contemplative shimmer, magical "
                  "thinking. " + _NEG,
        "duration": 2.0, "seed": 4205, "category": "drone"},
    # ── 5 TICKS UI ORGANIQUES (R161) — bascule procedural -> generatif ─────────
    # Retour audio round 2 : « trop robotique/digital ». Ces id existaient en synthese
    # physique (sfx_forge) ; on les rejoue en generatif ORGANIQUE. Sons COURTS -> `max_len_ms`
    # coupe au transitoire (onset) puis plafonne la longueur (le Space plancher a 1s ; on
    # taille ensuite). Categorie = MEME cible LUFS que la forge (homogeneite du bus SFX).
    "button_tap": {
        "prompt": "Single dry wooden knock, hollow tock on wood, close mic, no reverb. " + _NEG,
        "duration": 1, "seed": 4301, "category": "tick", "max_len_ms": 320},
    "gauge_up": {
        "prompt": "Mystical rising ethereal shimmer, soft magical celtic chime bloom ascending, "
                  "airy. " + _NEG_LONG,
        "duration": 2, "seed": 4302, "category": "accent", "max_len_ms": 1200},
    "gauge_down": {
        "prompt": "Mystical descending soft ethereal tone, gentle magical celtic fade downward. "
                  + _NEG_LONG,
        "duration": 2, "seed": 4303, "category": "accent", "max_len_ms": 1200},
    "slider_tick": {
        "prompt": "Soft organic wooden tick, subtle dry click, no digital. " + _NEG,
        "duration": 1, "seed": 4304, "category": "tick", "max_len_ms": 220},
    "voice_blip": {
        "prompt": "Breathy distant echoing voice syllable, windy ethereal whisper, far away, soft. "
                  + _NEG_VOICE,
        "duration": 1, "seed": 4305, "category": "tick", "max_len_ms": 160},
    # ── DEJA GENERE par le coordinateur (raw present) — pour reference/restage ──
    "magic_reveal": {
        "prompt": "Mystical celtic magic reveal, single shimmering enchanted bloom with a "
                  "soft bell. " + _NEG,
        "duration": 2.0, "seed": 4200, "category": "accent"},
}

# Spaces de secours (meme gradio_client + env token). Introspecter via view_api si
# on bascule : l'ordre des positionnels /infer peut differer.
FALLBACK_SPACES = ["fantaxy/Sound-AI-SFX", "hkchengrex/MMAudio", "declare-lab/TangoFlux"]

FADE_MS = 10.0  # fade in/out final (8-15 ms demande) anti-click sur coupe brute du Space


# ══════════════════════════════════════════════════════════════════════════════
#  IO audio robuste
# ══════════════════════════════════════════════════════════════════════════════

def _load_wav_mono(path: Path) -> tuple[np.ndarray, int]:
    """Lit un WAV (int16/int32/float32/uint8), downmix mono float64 [-1, 1]."""
    sr, data = wavfile.read(str(path))
    data = np.asarray(data)
    if data.dtype == np.int16:
        x = data.astype(np.float64) / 32768.0
    elif data.dtype == np.int32:
        x = data.astype(np.float64) / 2147483648.0
    elif data.dtype == np.uint8:
        x = (data.astype(np.float64) - 128.0) / 128.0
    else:  # float32 / float64
        x = data.astype(np.float64)
    if x.ndim == 2:  # stereo -> mono
        x = x.mean(axis=1)
    return x, int(sr)


def _fade_edges(x: np.ndarray, ms: float) -> np.ndarray:
    """Fade lineaire tete/queue (reduit l'amplitude -> ne depasse jamais le true-peak)."""
    n = int(ms * SR / 1000.0)
    if x.size <= 2 * n or n < 1:
        return x
    y = x.copy()
    ramp = np.linspace(0.0, 1.0, n)
    y[:n] *= ramp
    y[-n:] *= ramp[::-1]
    return y


def _postprocess(raw_path: Path, category: str,
                 max_len_ms: float | None = None) -> tuple[np.ndarray, dict]:
    """downmix -> resample 44.1k -> [onset-cap] -> highpass 30 Hz + trim + crest + loudness
    + TP -14 (norme forge v4) -> fade 10 ms. Retourne (audio float64, stats).

    `max_len_ms` (R161) : pour un son COURT dont le Space a rendu 1s floute, on coupe au
    1er transitoire (onset, -40 dB sous le pic) puis on plafonne la longueur -> tick net."""
    x, sr = _load_wav_mono(raw_path)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr).astype(np.float64)
    if max_len_ms is not None and x.size:
        peak: float = float(np.max(np.abs(x)))
        if peak > 1e-9:
            thr: float = peak * (10 ** (-40.0 / 20.0))  # onset = 1er echantillon a -40 dB sous le pic
            above = np.flatnonzero(np.abs(x) > thr)
            onset: int = int(above[0]) if above.size else 0
            n_max: int = max(1, int(max_len_ms * SR / 1000.0))
            x = x[onset:onset + n_max]
    target = TARGETS[category]
    audio, stats = norm.normalize(
        x, target_lufs=target, peak_ceiling_db=-14.0, trim=True,
        hp_hz=30.0, crest_cap_db=CREST_CAPS[category], fade_edges=True)
    audio = _fade_edges(audio, FADE_MS)
    # stats honnetes APRES le fade final
    stats = {
        "lufs": round(norm.measure_lufs(audio), 2),
        "true_peak_db": round(norm.true_peak_dbfs(audio), 2),
        "peak_db": round(norm.peak_dbfs(audio), 2),
        "dc": round(norm.dc_offset(audio), 6),
        "duration_s": round(audio.size / SR, 3),
        "samples": int(audio.size),
        "target_lufs": target,
        "crest_cap_db": CREST_CAPS[category],
    }
    return audio, stats


# ══════════════════════════════════════════════════════════════════════════════
#  Client HF Space + detection quota
# ══════════════════════════════════════════════════════════════════════════════

class QuotaExhausted(Exception):
    """Leve quand ZeroGPU refuse pour cause de quota epuise -> arret propre."""


def _is_quota_error(msg: str) -> bool:
    m = msg.lower()
    return ("gpu quota" in m or "exceeded your gpu" in m
            or ("quota" in m and "exceeded" in m)
            or "you have exceeded" in m)


def _make_client(space: str):
    os.environ["HF_TOKEN"] = __import__("huggingface_hub").get_token() or ""
    from gradio_client import Client
    return Client(space)


def _infer(client, prompt: str, duration: float, seed: int) -> str:
    """Un appel /infer (variante small-sfx). Retourne le chemin wav local du Space."""
    return client.predict("small-sfx", prompt, float(duration), 8, 1.0,
                          "pingpong", int(seed), api_name="/infer")


def _generate_raw(client, space: str, spec: dict, raw_path: Path,
                  retries: int = 2) -> None:
    """Appelle le Space avec retry cold-start. Leve QuotaExhausted si quota epuise."""
    last = None
    for attempt in range(retries + 1):
        try:
            out = _infer(client, spec["prompt"], spec["duration"], spec["seed"])
            raw_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(out, raw_path)
            return
        except Exception as e:  # noqa: BLE001
            last = e
            msg = str(e)
            if _is_quota_error(msg):
                raise QuotaExhausted(msg) from e
            wait = 30 * (attempt + 1)
            print(f"   ! erreur (tentative {attempt + 1}/{retries + 1}) : "
                  f"{msg[:160]}")
            if attempt < retries:
                print(f"   ... cold-start probable, retry dans {wait}s")
                time.sleep(wait)
    raise RuntimeError(f"echec apres {retries + 1} tentatives : {last}")


# ══════════════════════════════════════════════════════════════════════════════
#  Manifest + etat
# ══════════════════════════════════════════════════════════════════════════════

def _staged(sfx_id: str) -> Path:
    return OUT_DIR / f"{sfx_id}.wav"


def _raw(sfx_id: str) -> Path:
    return OUT_DIR / f"{sfx_id}_gen.wav"


def _load_manifest() -> dict:
    if MANIFEST_PATH.exists():
        try:
            return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def _write_manifest(man: dict) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    payload = {
        "_meta": {
            "space": man.get("_meta", {}).get("space", "stabilityai/stable-audio-3"),
            "loudness_backend": norm.loudness_backend(),
            "norm_source": _NORM_SRC,
            "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        },
        **{k: v for k, v in man.items() if k != "_meta"},
    }
    MANIFEST_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False),
                             encoding="utf-8")


def _state(sfx_id: str) -> str:
    if _staged(sfx_id).exists():
        return "done"
    if _raw(sfx_id).exists():
        return "raw-only"
    return "pending"


# ══════════════════════════════════════════════════════════════════════════════
#  Actions
# ══════════════════════════════════════════════════════════════════════════════

def action_list() -> None:
    print(f"{'ID':32s} {'CAT':9s} {'STATE':9s} DUR  SEED")
    for sid, spec in MANIFEST_PROMPTS.items():
        print(f"{sid:32s} {spec['category']:9s} {_state(sid):9s} "
              f"{spec['duration']:.1f}  {spec['seed']}")
    done = sum(1 for s in MANIFEST_PROMPTS if _state(s) == "done")
    raw = sum(1 for s in MANIFEST_PROMPTS if _state(s) == "raw-only")
    pend = sum(1 for s in MANIFEST_PROMPTS if _state(s) == "pending")
    print(f"\n  done={done}  raw-only={raw}  pending={pend}  total={len(MANIFEST_PROMPTS)}")


def action_prompts() -> None:
    print(json.dumps({k: {"prompt": v["prompt"], "seed": v["seed"],
                          "duration": v["duration"], "category": v["category"]}
                      for k, v in MANIFEST_PROMPTS.items()},
                     indent=2, ensure_ascii=False))


def _stage_from_raw(sfx_id: str, man: dict) -> None:
    """Post-traite le raw existant -> staged (0 GPU)."""
    spec = MANIFEST_PROMPTS[sfx_id]
    audio, stats = _postprocess(_raw(sfx_id), spec["category"], spec.get("max_len_ms"))
    norm.write_wav16(audio, _staged(sfx_id))
    man[sfx_id] = {"prompt": spec["prompt"], "seed": spec["seed"],
                   "duration_req": spec["duration"], "category": spec["category"],
                   "source": "restaged-from-raw", **stats}
    print(f"OK  {sfx_id:30s} [restage] LUFS {stats['lufs']:+.1f} "
          f"(cible {stats['target_lufs']:+.0f}) TP {stats['true_peak_db']:+.1f} "
          f"{stats['duration_s']:.2f}s")


def action_restage() -> None:
    man = _load_manifest()
    n = 0
    for sfx_id in MANIFEST_PROMPTS:
        if _raw(sfx_id).exists():
            _stage_from_raw(sfx_id, man)
            n += 1
    _write_manifest(man)
    print(f"\n  restage: {n} son(s) re-post-traite(s) depuis raw. Manifest ecrit.")


def action_generate(space: str, only: str | None, force: bool, max_gen: int) -> None:
    man = _load_manifest()
    man.setdefault("_meta", {})["space"] = space
    ids = [only] if only else list(MANIFEST_PROMPTS.keys())
    if only and only not in MANIFEST_PROMPTS:
        print(f"ERREUR: id inconnu '{only}'. --list pour les ids.")
        sys.exit(2)

    client = None
    generated, staged_free, skipped, remaining = [], [], [], []
    quota_hit = False

    for sfx_id in ids:
        spec = MANIFEST_PROMPTS[sfx_id]
        # 1) deja staged -> skip (sauf --force)
        if _staged(sfx_id).exists() and not force:
            skipped.append(sfx_id)
            print(f"..  {sfx_id:30s} deja staged, skip")
            continue
        # 2) raw present (ex: magic_reveal_gen.wav) -> post-traiter, 0 GPU
        if _raw(sfx_id).exists() and not force:
            _stage_from_raw(sfx_id, man)
            staged_free.append(sfx_id)
            _write_manifest(man)
            continue
        # 3) plafond de generations ce run (menager le quota)
        if max_gen >= 0 and len(generated) >= max_gen:
            remaining.append(sfx_id)
            continue
        # 4) appel Space (consomme du quota)
        if client is None:
            print(f"-> connexion au Space '{space}' ...")
            client = _make_client(space)
        print(f"~>  {sfx_id:30s} generation ({spec['duration']:.1f}s, seed {spec['seed']}) ...")
        try:
            _generate_raw(client, space, spec, _raw(sfx_id))
        except QuotaExhausted as q:
            quota_hit = True
            remaining.append(sfx_id)
            print(f"\n[QUOTA] ZeroGPU epuise sur '{space}'. Arret propre.")
            print(f"[QUOTA] message: {str(q)[:220]}")
            break
        except Exception as e:  # noqa: BLE001
            print(f"XX  {sfx_id:30s} echec non-quota: {str(e)[:180]} -> skip cet id")
            remaining.append(sfx_id)
            continue
        audio, stats = _postprocess(_raw(sfx_id), spec["category"], spec.get("max_len_ms"))
        norm.write_wav16(audio, _staged(sfx_id))
        man[sfx_id] = {"prompt": spec["prompt"], "seed": spec["seed"],
                       "duration_req": spec["duration"], "category": spec["category"],
                       "source": "generated", **stats}
        generated.append(sfx_id)
        _write_manifest(man)
        print(f"OK  {sfx_id:30s} [gen] LUFS {stats['lufs']:+.1f} "
              f"(cible {stats['target_lufs']:+.0f}) TP {stats['true_peak_db']:+.1f} "
              f"{stats['duration_s']:.2f}s")
        time.sleep(2)  # politesse anti-hammering

    _write_manifest(man)

    # id encore pending apres ce run (pour demain)
    still_pending = [s for s in MANIFEST_PROMPTS if _state(s) == "pending"]
    print("\n" + "=" * 66)
    print(f"  RESUME  space={space}  norm={_NORM_SRC}/{norm.loudness_backend()}")
    print(f"  genere ce run (GPU)   : {generated or '-'}")
    print(f"  stage depuis raw (0 GPU): {staged_free or '-'}")
    print(f"  skip (deja staged)    : {skipped or '-'}")
    print(f"  quota epuise          : {'OUI' if quota_hit else 'non'}")
    print(f"  ENCORE PENDING (demain): {still_pending or '-'}")
    print(f"  manifest              : {MANIFEST_PATH}")
    print("=" * 66)


# ══════════════════════════════════════════════════════════════════════════════

def main() -> None:
    ap = argparse.ArgumentParser(description="SFX generatif riche M.E.R.L.I.N. (Stable Audio, gratuit).")
    ap.add_argument("--all", action="store_true", help="genere tout le pending (jusqu'au quota)")
    ap.add_argument("--id", type=str, default=None, help="genere un seul id")
    ap.add_argument("--list", action="store_true", help="etat done/pending/raw-only")
    ap.add_argument("--prompts", action="store_true", help="dump le manifest de prompts")
    ap.add_argument("--restage", action="store_true", help="re-post-traite depuis les raw (0 GPU)")
    ap.add_argument("--force", action="store_true", help="regenere meme si deja staged")
    ap.add_argument("--max", type=int, default=-1, help="plafond de generations GPU ce run")
    ap.add_argument("--space", type=str, default="stabilityai/stable-audio-3",
                    help="Space HF (fallback: %s)" % ", ".join(FALLBACK_SPACES))
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if args.list:
        action_list(); return
    if args.prompts:
        action_prompts(); return
    if args.restage:
        action_restage(); return
    if args.id or args.all:
        action_generate(args.space, args.id, args.force, args.max); return
    ap.print_help()


if __name__ == "__main__":
    main()

# -*- coding: utf-8 -*-
"""MUSIQUE GENERATIVE M.E.R.L.I.N. — vraies compositions celtiques (BIBLE §22, R161).

Les nappes de gameplay procedurales (tools/music_forge.py : drone + cloches
pentatoniques + vent) etaient jugees « trop pauvres » (retour utilisateur audio
round 2 : « les sons de gameplay doivent etre des MUSIQUES, une VRAIE composition »).
Cet outil genere de vraies compositions instrumentales via le MEME Space que le
SFX generatif — stabilityai/stable-audio-3 — mais avec la variante 'small-music'
(durees longues OK, jusqu'a ~45-60s), puis les rend BOUCLABLES (crossfade seamless
tete/queue) et les normalise a la MEME cible que music_forge (-24 LUFS, plafond
true-peak -12 dBFS) pour rester homogene avec le reste du bed musical.

Auth : HF_TOKEN via huggingface_hub.get_token() (reutilise sfx_generative._make_client).
Quota : ZeroGPU gratuit -> arret propre + note des id restants (jamais de boucle
qui brule le quota). Le raw brut est cache -> re-post-traitement (--restage) 0 GPU.

Sorties :
    output/gen_music/<id>_gen.wav   raw Space (stereo, ~44.1k) -> restage sans quota
    output/gen_music/<id>.wav        staged mono 16-bit 44.1k, bouclable, normalise -24 LUFS
    output/gen_music/manifest.json   id -> prompt/seed/duree/LUFS/true-peak/seamless

Le drop-in dans music/gameplay/ (--drop) copie le staged sur la piste du jeu ;
merlin_game._setup_gameplay_music force LOOP_FORWARD au runtime (le WAV doit juste
etre seamless — c'est le role du crossfade tete/queue).

Usage (interpreteur Store-safe) :
    PY="C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe"
    "$PY" tools/music_generative.py --all                 # genere les 2 pistes (jusqu'au quota)
    "$PY" tools/music_generative.py --id gameplay_calm --force
    "$PY" tools/music_generative.py --restage             # re-post-traite depuis raw (0 GPU)
    "$PY" tools/music_generative.py --drop                # copie staged -> music/gameplay/
    "$PY" tools/music_generative.py --list
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
import time
from pathlib import Path

import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))
from tools import sfx_normalize as norm  # noqa: E402
from tools.sfx_generative import (  # noqa: E402  — reutilise le client + la detection quota + l'IO
    QuotaExhausted, _is_quota_error, _load_wav_mono, _make_client,
)

OUT_DIR = ROOT / "output" / "gen_music"
DROP_DIR = ROOT / "music" / "gameplay"
MANIFEST_PATH = OUT_DIR / "manifest.json"
SR = norm.SR

# ── Cible loudness — MIROIR de music_forge (un seul niveau pour tout le bed) ────
MUSIC_TARGET_LUFS = -24.0
MUSIC_PEAK_CEILING = -12.0
CROSSFADE_S = 3.0   # crossfade tete/queue equal-power -> boucle seamless (comme music_forge)

# ── Direction : vraie composition celtique instrumentale, bouclable, sans voix ──
# cfg_scale eleve (7.0) : la variante small-music suit VRAIMENT le prompt d'instrumentation
# (harpe/flute/cordes) — cfg=1.0 (defaut Space) convient au texture-SFX mais pas a la musique.
MANIFEST_PROMPTS: dict[str, dict] = {
    "gameplay_calm": {
        "prompt": "celtic instrumental music, layered harp and soft strings, ethereal flute, "
                  "mystical ancient forest, gentle flowing rhythm, wondrous and slightly eerie, "
                  "loopable, no vocals",
        "duration": 45, "seed": 5101},
    "gameplay_falaises": {
        "prompt": "celtic instrumental music, windswept sea cliffs, harp and low bowed strings, "
                  "distant flute, melancholic and vast, slow tide rhythm, loopable, no vocals",
        "duration": 45, "seed": 5102},
}

SPACE = "stabilityai/stable-audio-3"
VARIANT = "small-music"
STEPS = 8         # defaut du Space (ZeroGPU rapide) ; monter risque timeout/quota
CFG_SCALE = 7.0   # guidance forte : suit l'instrumentation celtique demandee
SAMPLER = "pingpong"


# ══════════════════════════════════════════════════════════════════════════════

def _staged(mid: str) -> Path:
    return OUT_DIR / f"{mid}.wav"


def _raw(mid: str) -> Path:
    return OUT_DIR / f"{mid}_gen.wav"


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
            "space": SPACE, "variant": VARIANT, "steps": STEPS, "cfg_scale": CFG_SCALE,
            "sampler": SAMPLER, "loudness_backend": norm.loudness_backend(),
            "target_lufs": MUSIC_TARGET_LUFS, "peak_ceiling_db": MUSIC_PEAK_CEILING,
            "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        },
        **{k: v for k, v in man.items() if k != "_meta"},
    }
    MANIFEST_PATH.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def _make_seamless(x: np.ndarray, fade_s: float) -> np.ndarray:
    """Crossfade equal-power tete<-queue (comme music_forge._make_seamless) : la fin se
    fond dans le debut, on jette les `fade_s` dernieres secondes -> raccord de boucle sans clic."""
    n = x.size
    nf = int(SR * fade_s)
    if nf * 2 >= n:
        return x
    blend = np.linspace(0.0, 1.0, nf)
    g_tail = np.sqrt(blend)          # poids du debut (montant)
    g_head = np.sqrt(1.0 - blend)    # poids de la queue (descendant)
    out = x.copy()
    out[:nf] = x[:nf] * g_tail + x[n - nf:] * g_head
    return out[:n - nf]


def _postprocess(raw_path: Path) -> tuple[np.ndarray, dict]:
    """downmix mono -> resample 44.1k -> crossfade seamless -> loudness -24 LUFS / TP -12
    (SANS trim ni fade de bord : preserve le raccord de boucle). Retourne (audio, stats)."""
    x, sr = _load_wav_mono(raw_path)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr).astype(np.float64)
    x = _make_seamless(x, CROSSFADE_S)
    audio, _ = norm.normalize(
        x, target_lufs=MUSIC_TARGET_LUFS, peak_ceiling_db=MUSIC_PEAK_CEILING,
        trim=False, crest_cap_db=None, fade_edges=False)
    # verifie l'amplitude au raccord de boucle (fin -> debut) : doit etre continue
    seam = float(abs(audio[0] - audio[-1])) if audio.size else 0.0
    stats = {
        "lufs": round(norm.measure_lufs(audio), 2),
        "true_peak_db": round(norm.true_peak_dbfs(audio), 2),
        "peak_db": round(norm.peak_dbfs(audio), 2),
        "dc": round(norm.dc_offset(audio), 6),
        "duration_s": round(audio.size / SR, 3),
        "samples": int(audio.size),
        "loop_seam_delta": round(seam, 5),  # |sample[0] - sample[-1]| ~ 0 => boucle sans clic
        "target_lufs": MUSIC_TARGET_LUFS,
    }
    return audio, stats


def _infer(client, spec: dict) -> str:
    return client.predict(VARIANT, spec["prompt"], float(spec["duration"]),
                          STEPS, CFG_SCALE, SAMPLER, int(spec["seed"]), api_name="/infer")


def _generate_raw(client, spec: dict, raw_path: Path, retries: int = 2) -> None:
    last = None
    for attempt in range(retries + 1):
        try:
            out = _infer(client, spec)
            raw_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(out, raw_path)
            return
        except Exception as e:  # noqa: BLE001
            last = e
            msg = str(e)
            if _is_quota_error(msg):
                raise QuotaExhausted(msg) from e
            wait = 30 * (attempt + 1)
            print(f"   ! erreur (tentative {attempt + 1}/{retries + 1}) : {msg[:160]}")
            if attempt < retries:
                print(f"   ... cold-start probable, retry dans {wait}s")
                time.sleep(wait)
    raise RuntimeError(f"echec apres {retries + 1} tentatives : {last}")


def _stage_from_raw(mid: str, man: dict, source: str) -> dict:
    spec = MANIFEST_PROMPTS[mid]
    audio, stats = _postprocess(_raw(mid))
    norm.write_wav16(audio, _staged(mid))
    man[mid] = {"prompt": spec["prompt"], "seed": spec["seed"],
                "duration_req": spec["duration"], "source": source, **stats}
    print(f"OK  {mid:22s} [{source}] LUFS {stats['lufs']:+.1f} (cible {MUSIC_TARGET_LUFS:+.0f}) "
          f"TP {stats['true_peak_db']:+.1f}  {stats['duration_s']:.1f}s  seam {stats['loop_seam_delta']:.4f}")
    return stats


# ══════════════════════════════════════════════════════════════════════════════

def action_list() -> None:
    for mid, spec in MANIFEST_PROMPTS.items():
        state = "done" if _staged(mid).exists() else ("raw-only" if _raw(mid).exists() else "pending")
        print(f"{mid:22s} {state:9s} {spec['duration']}s  seed {spec['seed']}")


def action_restage() -> None:
    man = _load_manifest()
    n = 0
    for mid in MANIFEST_PROMPTS:
        if _raw(mid).exists():
            _stage_from_raw(mid, man, "restaged-from-raw")
            n += 1
    _write_manifest(man)
    print(f"\n  restage: {n} piste(s) re-post-traitee(s) depuis raw.")


def action_drop() -> None:
    DROP_DIR.mkdir(parents=True, exist_ok=True)
    n = 0
    for mid in MANIFEST_PROMPTS:
        s = _staged(mid)
        if s.exists():
            shutil.copyfile(s, DROP_DIR / f"{mid}.wav")
            print(f"drop-in : {mid}.wav -> {DROP_DIR / (mid + '.wav')}")
            n += 1
        else:
            print(f"(skip) {mid} : pas de staged")
    print(f"\n  {n} piste(s) copiee(s) dans {DROP_DIR}")


def action_generate(only: str | None, force: bool) -> None:
    man = _load_manifest()
    ids = [only] if only else list(MANIFEST_PROMPTS.keys())
    if only and only not in MANIFEST_PROMPTS:
        print(f"ERREUR: id inconnu '{only}'. --list pour les ids.")
        sys.exit(2)
    client = None
    generated, staged_free, skipped, remaining = [], [], [], []
    quota_hit = False
    for mid in ids:
        spec = MANIFEST_PROMPTS[mid]
        if _staged(mid).exists() and not force:
            skipped.append(mid)
            print(f"..  {mid:22s} deja staged, skip")
            continue
        if _raw(mid).exists() and not force:
            _stage_from_raw(mid, man, "restaged-from-raw")
            _write_manifest(man)
            staged_free.append(mid)
            continue
        if client is None:
            print(f"-> connexion au Space '{SPACE}' (variante {VARIANT}) ...")
            client = _make_client(SPACE)
        print(f"~>  {mid:22s} generation ({spec['duration']}s, seed {spec['seed']}, "
              f"steps {STEPS}, cfg {CFG_SCALE}) ...")
        try:
            _generate_raw(client, spec, _raw(mid))
        except QuotaExhausted as q:
            quota_hit = True
            remaining.append(mid)
            print(f"\n[QUOTA] ZeroGPU epuise. Arret propre. {str(q)[:200]}")
            break
        except Exception as e:  # noqa: BLE001
            print(f"XX  {mid:22s} echec non-quota: {str(e)[:180]} -> skip")
            remaining.append(mid)
            continue
        _stage_from_raw(mid, man, "generated")
        generated.append(mid)
        _write_manifest(man)
        time.sleep(2)
    _write_manifest(man)
    still_pending = [m for m in MANIFEST_PROMPTS
                     if not _staged(m).exists() and not _raw(m).exists()]
    print("\n" + "=" * 60)
    print(f"  genere ce run (GPU)   : {generated or '-'}")
    print(f"  stage depuis raw (0 GPU): {staged_free or '-'}")
    print(f"  skip (deja staged)    : {skipped or '-'}")
    print(f"  quota epuise          : {'OUI' if quota_hit else 'non'}")
    print(f"  ENCORE PENDING (demain): {still_pending or '-'}")
    print("=" * 60)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description="Musique generative celtique M.E.R.L.I.N. (small-music).")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--id", type=str, default=None)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--restage", action="store_true")
    ap.add_argument("--drop", action="store_true", help="copie staged -> music/gameplay/")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    if args.list:
        action_list(); return
    if args.restage:
        action_restage(); return
    if args.drop:
        action_drop(); return
    if args.id or args.all:
        action_generate(args.id, args.force); return
    ap.print_help()


if __name__ == "__main__":
    main()

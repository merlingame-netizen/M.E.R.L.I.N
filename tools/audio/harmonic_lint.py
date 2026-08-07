#!/usr/bin/env python3
"""Linter harmonique — des regles musicales DETERMINEES, mesurees sur la
partition complete (socle + tous les candidats), resonances comprises.

Quatre regles, chacune justifiee :

R1  MODE. Toute classe de hauteur appartient a re dorien. C'est la promesse
    du morceau ; une note hors mode est un bug, pas une couleur.

R2  RUGOSITE SENSORIELLE (Plomp & Levelt 1965, partiels sommes selon
    Sethares 1993). Chaque note sonnante est modelisee par 6 harmoniques
    d'amplitudes decroissantes ; la dissonance percue est la somme des
    rugosites de toutes les paires de partiels. C'est LE modele etabli de
    « agreable a l'oreille » : il predit les creux de dissonance aux rapports
    de frequence entiers. On mesure par tranche de croche, RESONANCES
    INCLUSES — une cloche qui sonne encore fait partie de l'accord, que la
    partition le dise ou non.

R3  DISSONANCES CARACTERISEES (contrepoint d'ecole, adapte au modal). Le
    do sur re mineur est la 7e modale — l'idiome meme du folk dorien ; le
    flaguer serait du zele scolaire. Ce qui blesse l'oreille, ce sont les
    classes d'intervalles 1 (seconde mineure / septieme majeure) et 6
    (triton) contre une note de l'accord. Une telle dissonance doit etre
    breve (<= 1 temps) et se resoudre par mouvement conjoint.

R4  RESONANCE TRAVERSANTE. Une note dont la queue (duree + release de
    l'instrument) traverse un changement d'accord doit appartenir AUSSI a
    l'accord suivant. Sinon elle salit l'harmonie d'apres — c'est la cause
    principale du « pas harmonique » : l'allongement des releases (juste par
    ailleurs) a fait sonner l'accord precedent dans le suivant.

    python3 tools/audio/harmonic_lint.py            # rapport complet
    python3 tools/audio/harmonic_lint.py --json     # sortie machine
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from score_menu import BAR, BEAT, N_BARS, CHORDS, PROGRESSION  # noqa: E402
from arrange_menu import build_bed, build_role, t_of  # noqa: E402
from casting_menu import CANDIDATES  # noqa: E402
from sample_bank import MultiSampleBank  # noqa: E402

DORIAN_D = {2, 4, 5, 7, 9, 11, 0}          # re dorien en classes de hauteur

# Release effective par instrument — DOIT suivre sample_bank.ENV/KIND.
KIND = MultiSampleBank.KIND
ENV = MultiSampleBank.ENV


def release_of(inst: str) -> float:
    return ENV[KIND.get(inst, "sustained")]["r"]


def harsh(pc: int, pcs: set) -> bool:
    """Vrai si pc forme une seconde mineure ou un triton avec l'accord."""
    for q in pcs:
        d = abs(pc - q) % 12
        if min(d, 12 - d) in (1, 6):
            return True
    return False


def chord_at_bar(bar: int) -> tuple[set, str]:
    name = PROGRESSION[min(bar, N_BARS) - 1]
    pcs, _root = CHORDS[name]
    return {p % 12 for p in pcs}, name


def chord_boundaries() -> list[float]:
    """Instants ou l'accord CHANGE reellement."""
    out = []
    prev = None
    for bar in range(1, N_BARS + 1):
        name = PROGRESSION[bar - 1]
        if name != prev:
            out.append(t_of(bar, 1.0))
            prev = name
    return out


# ── R2 : rugosite de Plomp-Levelt ────────────────────────────────────────────

def _pl_pair(f1: float, f2: float, a1: float, a2: float) -> float:
    """Rugosite d'une paire de partiels (parametrisation de Sethares)."""
    if f2 < f1:
        f1, f2 = f2, f1
    s = 0.24 / (0.021 * f1 + 19.0)
    x = s * (f2 - f1)
    return a1 * a2 * (np.exp(-3.5 * x) - np.exp(-5.75 * x))


def roughness(midis: list[float]) -> float:
    """Dissonance sensorielle d'un ensemble de notes, 6 harmoniques chacune."""
    partials: list[tuple[float, float]] = []
    for m in midis:
        f0 = 440.0 * 2 ** ((m - 69) / 12)
        for k in range(1, 7):
            partials.append((f0 * k, 0.88 ** (k - 1)))
    total = 0.0
    for i in range(len(partials)):
        for j in range(i + 1, len(partials)):
            total += _pl_pair(partials[i][0], partials[j][0],
                              partials[i][1], partials[j][1])
    return float(total)


def full_score() -> dict[str, list[dict]]:
    parts = {"bed": build_bed()}
    for role, cands in CANDIDATES.items():
        for cid in cands:
            evs = build_role(role, cid)
            if evs:
                parts[f"{role}__{cid}"] = evs
    return parts


def lint(verbose: bool = True) -> dict:
    parts = full_score()
    findings = {"mode": [], "rough": [], "foreign": [], "ringover": []}

    # ── R1 : mode ────────────────────────────────────────────────────────────
    for name, evs in parts.items():
        for e in evs:
            if e["inst"] in ("bodhran", "taiko", "slit_drum", "ocean_drum",
                             "tam_tam", "cymbal", "snare_roll"):
                continue                      # percussions non accordees
            if int(round(e["midi"])) % 12 not in DORIAN_D:
                findings["mode"].append((name, e["inst"], e["midi"], e["at"]))

    # ── R3 + R4, par partie ─────────────────────────────────────────────────
    bounds = chord_boundaries()
    for name, evs in parts.items():
        by_inst: dict = {}
        for e in sorted(evs, key=lambda x: x["at"]):
            by_inst.setdefault(e["inst"], []).append(e)
        for inst, line in by_inst.items():
            if inst in ("bodhran", "taiko", "slit_drum", "ocean_drum",
                        "tam_tam", "cymbal", "snare_roll", "timpani"):
                continue
            rel = release_of(inst)
            for i, e in enumerate(line):
                bar = int((e["at"] + 0.06) // BAR) + 1
                pcs, _ = chord_at_bar(bar)
                pc = int(round(e["midi"])) % 12
                if pc not in pcs and harsh(pc, pcs):
                    ok_dur = e["dur"] <= BEAT * 1.05
                    nxt = line[i + 1] if i + 1 < len(line) else None
                    ok_res = nxt is not None and abs(nxt["midi"] - e["midi"]) <= 2
                    if not (ok_dur and ok_res):
                        findings["foreign"].append(
                            (name, inst, e["midi"], round(e["at"], 2),
                             round(e["dur"], 2)))
                end = e["at"] + e["dur"] + rel
                for b in bounds:
                    if e["at"] < b - 0.05 and end > b + 0.60:
                        nb = int((b + 0.06) // BAR) + 1
                        npcs, _ = chord_at_bar(nb)
                        if pc not in npcs and harsh(pc, npcs):
                            findings["ringover"].append(
                                (name, inst, e["midi"], round(e["at"], 2),
                                 round(end - b, 2)))
                        break

    # ── R2 : rugosite du mix par defaut, par croche ─────────────────────────
    from casting_menu import DEFAULT
    active = list(parts["bed"])
    for role, cid in DEFAULT.items():
        active += parts.get(f"{role}__{cid}", [])
    ref = roughness([50, 57, 62, 65, 69])       # l'accord du morceau, grave->aigu
    step = BEAT / 2
    slices = []
    t = 0.0
    while t < N_BARS * BAR:
        sounding = [e["midi"] for e in active
                    if e["at"] <= t < e["at"] + e["dur"] + release_of(e["inst"]) * 0.6
                    and e["inst"] not in ("bodhran", "taiko", "slit_drum",
                                          "ocean_drum", "tam_tam", "cymbal",
                                          "snare_roll", "timpani")]
        if len(sounding) >= 2:
            slices.append((t, roughness(sounding) / max(ref, 1e-9)))
        t += step
    r_vals = [r for _t, r in slices]
    med = float(np.median(r_vals)) if r_vals else 1.0
    hot = [(round(t, 2), round(r / med, 2)) for t, r in slices if r > 2.5 * med]
    findings["rough"] = hot

    rep = {
        "mode_violations": len(findings["mode"]),
        "foreign_unresolved": len(findings["foreign"]),
        "ring_over_changes": len(findings["ringover"]),
        "roughness_median": round(float(np.median(r_vals)), 2) if r_vals else 0,
        "roughness_p95": round(float(np.percentile(r_vals, 95)), 2) if r_vals else 0,
        "roughness_hot_slices": len(hot),
        "slices": len(slices),
    }
    if verbose:
        print("── LINT HARMONIQUE ──")
        print(f"  R1 mode        : {rep['mode_violations']} note(s) hors re dorien")
        print(f"  R3 etrangeres  : {rep['foreign_unresolved']} non resolues")
        print(f"  R4 resonances  : {rep['ring_over_changes']} traversent un "
              f"changement d'accord avec une note etrangere a l'accord suivant")
        print(f"  R2 rugosite    : mediane {rep['roughness_median']}x, p95 "
              f"{rep['roughness_p95']}x l'accord de reference — "
              f"{rep['roughness_hot_slices']}/{rep['slices']} tranches > 2,5x la mediane")
        for k in ("foreign", "ringover"):
            if findings[k]:
                print(f"  · pires {k} :")
                for row in findings[k][:8]:
                    print(f"      {row}")
    rep["_detail"] = {k: v[:40] for k, v in findings.items()}
    return rep


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    rep = lint(verbose=not a.json)
    if a.json:
        print(json.dumps(rep, ensure_ascii=False))
    clean = (rep["mode_violations"] == 0 and rep["foreign_unresolved"] == 0
             and rep["ring_over_changes"] == 0 and rep["roughness_hot_slices"] == 0)
    sys.exit(0 if clean else 1)

# -*- coding: utf-8 -*-
"""forge_batch.py : premier batch reel E4B (R172).

Enchaine des `scenario_forge.py generate --model e4b` varies (biomes, envergures,
titres/promesses distincts), avec reprise sure : un scenario deja produit PASS est
saute au relancement. Resume final : PASS/FAIL, duree, chemin de chaque scenario.

Usage :
    python tools/forge_batch.py            # le plan complet (20 scenarios, ~6 h)
    python tools/forge_batch.py --limit 3  # tranche courte de controle
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

PY = sys.executable
FORGE = str(Path(__file__).with_name("scenario_forge.py"))
STATE_DIR = Path.home() / "AppData" / "Local" / "merlin_forge"
SUMMARY = STATE_DIR / "batch_night1_summary.json"

# 20 commandes : titres et promesses varies (sobres, canon §13), brèves dominantes
# pour confirmer les taux R172 avant de scaler. Seeds distincts = squelettes distincts.
PLAN: list[dict] = [
    {"biome": "foret",    "tier": "breve",   "seed": 101, "title": "La Souche aux Clous",       "promesse": "qui plante un clou dans la souche doit revenir le reprendre"},
    {"biome": "falaises", "tier": "breve",   "seed": 102, "title": "Le Banc de Brume",          "promesse": "ce que la brume cache au large finit toujours par accoster"},
    {"biome": "foret",    "tier": "breve",   "seed": 103, "title": "Les Trois Gues",            "promesse": "le troisieme gue ne se traverse qu'en rendant ce qu'on doit"},
    {"biome": "falaises", "tier": "breve",   "seed": 104, "title": "La Cloche Engloutie",       "promesse": "une cloche sonnee sous l'eau appelle quelqu'un de precis"},
    {"biome": "foret",    "tier": "breve",   "seed": 105, "title": "Le Verger de Personne",     "promesse": "les fruits de ce verger murissent pour un proprietaire absent"},
    {"biome": "falaises", "tier": "breve",   "seed": 106, "title": "L'Escalier de Maree",       "promesse": "la mer remonte ces marches une nuit par saison, et cette nuit approche"},
    {"biome": "foret",    "tier": "breve",   "seed": 107, "title": "La Borne Effacee",          "promesse": "la limite effacee entre deux terres reclame d'etre retracee"},
    {"biome": "falaises", "tier": "breve",   "seed": 108, "title": "Le Filet du Dimanche",      "promesse": "un filet tendu un jour interdit prend autre chose que du poisson"},
    {"biome": "foret",    "tier": "breve",   "seed": 109, "title": "Les Souliers du Noye",      "promesse": "des souliers secs au bord de l'etang attendent que quelqu'un les chausse"},
    {"biome": "falaises", "tier": "breve",   "seed": 110, "title": "La Corne de Rappel",        "promesse": "la corne du guetteur sonne seule quand un serment se rompt"},
    {"biome": "foret",    "tier": "breve",   "seed": 111, "title": "Le Charbonnier Froid",      "promesse": "une meule eteinte depuis dix ans fume a nouveau"},
    {"biome": "falaises", "tier": "breve",   "seed": 112, "title": "Les Ecailles du Matin",     "promesse": "les ecailles trouvees au seuil viennent d'une bete qu'on ne peche pas"},
    {"biome": "foret",    "tier": "breve",   "seed": 113, "title": "La Table des Absents",      "promesse": "une place mise chaque soir pour quelqu'un qui n'arrive jamais"},
    {"biome": "falaises", "tier": "breve",   "seed": 114, "title": "Le Sel des Adieux",         "promesse": "le sel jete au depart d'un navire retombe quand il faut le pleurer"},
    {"biome": "foret",    "tier": "periple", "seed": 115, "title": "Le Chemin des Ruches",      "promesse": "les abeilles desertent les ruches dans l'ordre exact du chemin"},
    {"biome": "falaises", "tier": "periple", "seed": 116, "title": "La Passe des Neuf Feux",    "promesse": "neuf feux guident la passe, et l'un d'eux ment"},
    {"biome": "foret",    "tier": "periple", "seed": 117, "title": "L'Encre du Vieux Saule",    "promesse": "ce qui s'ecrit avec la seve du saule s'accomplit de travers"},
    {"biome": "falaises", "tier": "periple", "seed": 118, "title": "Le Recif aux Serments",     "promesse": "les serments jetes au recif reviennent a la nage"},
    {"biome": "foret",    "tier": "odyssee", "seed": 119, "title": "La Grande Cueillette",      "promesse": "tout ce que la foret prete a l'automne, elle le recompte au premier gel"},
    {"biome": "falaises", "tier": "odyssee", "seed": 120, "title": "Le Convoi de Quart de Nuit", "promesse": "un convoi passe au large chaque quart de nuit, plus proche a chaque fois"},
]


def out_path(job: dict) -> Path:
    return STATE_DIR / f"gen_{job['biome']}_{job['tier']}_{job['seed']}_scenario.json"


def already_pass(job: dict) -> bool:
    p = out_path(job)
    if not p.exists():
        return False
    try:
        return json.loads(p.read_text(encoding="utf-8")).get("qc") == "PASS"
    except Exception:
        return False


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0, help="ne traiter que N scenarios du plan")
    args = ap.parse_args()
    plan = PLAN[: args.limit] if args.limit else PLAN

    results: list[dict] = []
    t_batch = time.time()
    for i, job in enumerate(plan, 1):
        tag = f"{job['biome']}/{job['tier']}/seed{job['seed']}"
        if already_pass(job):
            print(f"[BATCH {i}/{len(plan)}] {tag} : deja PASS, saute")
            results.append({**job, "verdict": "PASS", "cached": True, "s": 0})
            continue
        print(f"[BATCH {i}/{len(plan)}] {tag} : {job['title']}", flush=True)
        t0 = time.time()
        cmd = [PY, FORGE, "generate", "--model", "e4b",
               "--biome", job["biome"], "--tier", job["tier"], "--seed", str(job["seed"]),
               "--title", job["title"], "--promesse", job["promesse"]]
        rc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                            errors="replace")
        dur = round(time.time() - t0, 1)
        verdict = "PASS" if rc.returncode == 0 else "FAIL"
        print(f"    -> {verdict} en {dur}s")
        if rc.returncode != 0:
            tail = (rc.stdout or "")[-400:] + (rc.stderr or "")[-200:]
            print("    detail:", tail.replace("\n", " | ")[-300:])
        results.append({**job, "verdict": verdict, "cached": False, "s": dur,
                        "out": str(out_path(job))})
        SUMMARY.write_text(json.dumps({
            "done": i, "total": len(plan),
            "pass": sum(1 for r in results if r["verdict"] == "PASS"),
            "wall_s": round(time.time() - t_batch, 1),
            "results": results,
        }, ensure_ascii=False, indent=1), encoding="utf-8")

    npass = sum(1 for r in results if r["verdict"] == "PASS")
    print(f"\n[BATCH] termine : {npass}/{len(plan)} PASS en "
          f"{round((time.time() - t_batch) / 60)} min. Resume : {SUMMARY}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

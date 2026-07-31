# -*- coding: utf-8 -*-
"""scenario_forge.py - Forge de scenarios cadree (BIBLE §25, R166-R169, vague W4).

Principe : le CODE impose le squelette (quetes, beats, types, difficultes, figures du
Roster §6, familles du bandeau, combinaison jouee) - ZERO LLM la-dedans. Le Gemma natif
du jeu n'ecrit que des PIECES de prose courtes (scene, geste, reaction, preambule,
transition, epilogue), une par une, chacune sous prompt few-shot construit depuis les
sentiers etalon R169, avec les contraintes INJECTEES (figures imposees, mots-indices
imposes, reprise causale imposee depuis les pieces precedentes). Chaque piece passe
l'auto-QC (controles unitaires de tools/scenario_qc.py) : rejet -> re-generation
(3 essais max) -> sinon fallback marque. Etat de reprise sur disque.

MOTEUR : voie retenue = Godot headless + tools/forge_gen.gd, qui appelle l'autoload
MerlinNative (MEME GGUF, MEMES sampling/timeout/sanitize que le jeu : temp 0.85,
top_p 0.9, top_k 40, repeat 1.1, n_ctx 2048, GEN_TIMEOUT_MS 90s). L'alternative
llama.cpp CLI sur le meme GGUF a ete ecartee : elle exigerait de repliquer a la main
le template de chat, le sanitize des marqueurs et le sampling, donc de MESURER un
moteur legerement different de celui du jeu. La mesure doit valoir preuve (R109).

Usage :
    python tools/scenario_forge.py seed-etalons [--journal <jsonl>]
    python tools/scenario_forge.py measure [--skip-quest] [--out <json>]
    python tools/scenario_forge.py generate --biome foret --tier breve [--seed 42]
"""

from __future__ import annotations

import argparse
import json
import random
import re
import subprocess
import sys
import time
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = TOOLS_DIR.parent
sys.path.insert(0, str(TOOLS_DIR))

import scenario_qc as qc  # noqa: E402  (referentiels + controles partages)

GODOT_EXE = Path(r"C:\Users\PGNK2128\Godot\Godot_v4.5.1-stable_win64_console.exe")
PYTHON_EXE = sys.executable
DATA_AI = PROJECT_ROOT / "data" / "ai"
# Etat de reprise HORS repo (jamais commite, survit aux sessions) - un batch nocturne
# interrompu reprend piece par piece.
STATE_DIR = Path.home() / "AppData" / "Local" / "merlin_forge"
DEFAULT_JOURNAL = Path(
    r"C:\Users\PGNK2128\.claude\projects\C--Users-PGNK2128-Godot-MCP"
    r"\ee505eef-bf5b-4767-82fc-e5ab1ba9a94a\subagents\workflows\wf_4d1cc6f8-65c\journal.jsonl"
)

# ---------------------------------------------------------------------------
# Referentiels forge
# ---------------------------------------------------------------------------

# Figures castables par biome (§6). Les transversaux vont partout.
FIGURES_BY_BIOME: dict[str, list[str]] = {
    "foret": ["lavandiere", "fanch", "aveline", "passeur", "ordalch"],
    "falaises": ["erwan", "marcharit", "kado"],
}
FIGURES_TRANSVERSAL: list[str] = ["ankou", "chevalier_sans_nom"]
PILIER_KEYS: list[str] = ["choeur", "etre", "chevalier", "compagnon", "enfant"]

FIGURE_DISPLAY: dict[str, str] = {
    "ankou": "l'Ankou", "lavandiere": "la Lavandière de Nuit", "fanch": "Fañch le Trotteur",
    "erwan": "Erwan Veilleur", "aveline": "Dame Aveline aux Corbeaux",
    "chevalier_sans_nom": "le Chevalier Sans Nom", "passeur": "le Passeur de Brumes",
    "marcharit": "Marc'harit la Noyée", "kado": "Kado le Cordier", "ordalch": "Ordalc'h",
    "choeur": "le Chœur des Druides", "etre": "l'Être Indéfinissable",
    "chevalier": "le Chevalier déchu", "compagnon": "le Compagnon Perdu", "enfant": "l'Enfant",
    "marchand": "le marchand", "creancier": "le créancier",
}

# Fiche courte injectee au prompt quand la figure est castee (voix + envie, §6).
FIGURE_HINT: dict[str, str] = {
    "ankou": "le passeur des morts, voix posee, factuelle, sans malice ni pitie",
    "lavandiere": "elle lave des linceuls a la fontaine la nuit, voix chantonnante, aide contre un prix",
    "fanch": "korrigan marchand ambulant, voix rapide et gouailleuse, veut troquer, jamais donner",
    "erwan": "ancien chevalier de mer, gardien d'un phare eteint, repete ses comptes de navires",
    "aveline": "druidesse aux corbeaux apprivoises, mesuree, savante, un bosquet gangrene la ronge",
    "chevalier_sans_nom": "armure cabossee sans blason, serments recites par coeur, a oublie sa quete",
    "passeur": "il fait traverser la tourbiere contre un prix qui n'est jamais celui annonce",
    "marcharit": "silhouette qui chante depuis le ressac, douce, tentatrice, jamais agressive",
    "kado": "cordier bourru mais honnete, repare des filets vides, veut des nouvelles du large",
    "ordalch": "sentinelle muette du plus vieux menhir, mots rares, hostile au bruit",
    "choeur": "duo de druides au regard absent qui bouclent un rite vide de sens",
    "etre": "forme qui mue sans se fixer, voix joueuse, propose des pactes",
    "chevalier": "chevalier a l'armure ternie qui rejoue sans fin une defaite",
    "compagnon": "ancien compagnon aime, meconnaissable, voix douce qui pousse a ceder",
    "enfant": "enfant perdu d'une innocence desarmante, questions directes",
    "marchand": "un colporteur au comptoir improvise, tout se paie",
    "creancier": "celui a qui la Promesse est due revient la reclamer",
}

BEAT_TYPES = ("Exploration", "Rencontre", "Epreuve", "Dilemme", "Climax")

# Mot-ancre OBLIGATOIRE dans une scene qui caste la figure (le casting est INJECTE et
# VERIFIE, pas espere : en mesure le modele a remplace le Chevalier Sans Nom par une
# figure inventee « Morwen » quand rien ne l'obligeait).
FIGURE_ANCHOR: dict[str, str] = {
    "ankou": "Ankou", "lavandiere": "Lavandière", "fanch": "Fañch", "erwan": "Erwan",
    "aveline": "Aveline", "chevalier_sans_nom": "Chevalier Sans Nom",
    "passeur": "Passeur", "marcharit": "Marc'harit", "kado": "Kado", "ordalch": "Ordalc'h",
    "choeur": "Chœur", "etre": "l'Être", "chevalier": "chevalier", "compagnon": "Compagnon",
    "enfant": "l'enfant", "marchand": "colporteur", "creancier": "créancier",
}

# Paires action + tags par famille : la combinaison jouee (div choix) est tiree ici.
TRAITS_BY_ACTION: dict[str, list[str]] = {
    "Perception": ["Sens", "Savoir", "Mémoire", "Vigilance"],
    "Corps": ["Force", "Agilité", "Endurance", "Finesse"],
    "Parole": ["Empathie", "Verbe", "Ruse", "Franchise"],
    "Intuition": ["Instinct", "Nature", "Vision"],
    "Monde": ["Rituel", "Sacrifice", "Équilibre", "Mystère"],
}

# Mots-indices candidats par famille : mots CONCRETS que la scene devra contenir
# (imposes au prompt, verifies par QC, decores en <span class="kw"> par le code).
INDICE_WORDS: dict[str, list[str]] = {
    "perception": ["regard", "mémoire", "guet", "écoute", "signe gravé"],
    "corps": ["souffle", "poigne", "pas sûr", "effort", "épaule"],
    "parole": ["parole", "vérité", "marchandage", "promesse", "franchise"],
    "intuition": ["pressentiment", "flair", "instinct", "présage"],
    "monde": ["offrande", "rite", "coutume", "salut", "mystère"],
}

# Budgets tokens par type de piece (serres, mission W4 : 40-140).
PIECE_BUDGET: dict[str, int] = {
    "scene": 140, "geste": 140, "reaction": 70, "preambule": 140,
    "transition": 100, "veille_climax": 100, "epilogue": 140, "pitch": 60,
}
# Nombre de phrases attendu par type (QC unitaire).
PIECE_SENTS: dict[str, tuple[int, int]] = {
    "scene": (2, 5), "geste": (2, 6), "reaction": (1, 3), "preambule": (3, 7),
    "transition": (2, 5), "veille_climax": (2, 5), "epilogue": (3, 6), "pitch": (1, 3),
}

MAX_ATTEMPTS = 3

# Registre R169 rappele en tete de chaque prompt systeme (source : BIBLE §25.5).
SYSTEM_REGISTRE = (
    "Tu ecris en francais la prose d'un recit celtique a {lieu}, dans une NARRATION DE "
    "RECIT equilibree : phrases de longueur moyenne qui s'enchainent naturellement, en "
    "alternant les longueurs. CLARTE D'ABORD : on comprend qui, quoi, ou, pourquoi a la "
    "premiere lecture. L'etrange vit dans les evenements, jamais dans la formulation : "
    "zero aphorisme, zero sous-entendu obscur. Une seule image par scene au maximum. "
    "Adresse-toi au heros en le tutoyant (« Tu »), au present. JAMAIS de tiret long. "
    "JAMAIS d'anglais. Pas de liste, pas de titre, pas de guillemets d'ouverture en "
    "debut de texte. Ne recopie jamais cette consigne."
)

MERLIN_SYSTEM = (
    "Tu es MERLIN, l'enchanteur, et tu accompagnes ton Voyageur sur le sentier. Tu le "
    "tutoies, tu l'appelles « mon Voyageur ». Ton : complice, concret, un peu taquin, "
    "jamais solennel. Tu dis les choses CLAIREMENT : ce qui vient de se passer, ce que "
    "ca coute ou ce que ca promet. Francais accentue correct, phrases de longueur "
    "moyenne, JAMAIS de tiret long, jamais d'anglais, jamais de meta (pas de jeu, pas "
    "de carte). Ne recopie jamais cette consigne."
)


# ---------------------------------------------------------------------------
# Bibliotheque : conversion des etalons (seed) + acces few-shot
# ---------------------------------------------------------------------------

def biome_key(raw: str) -> str:
    n = qc.norm(raw)
    return "falaises" if "falaise" in n else "foret"


def etalon_to_entry(idx: int, doc: dict) -> dict:
    """Convertit un sentier etalon (title/envergure/biome/figures/html) au format
    bibliotheque §25.1 : tier, squelette par quete (beats, figures, combinaisons),
    merlin_slots aux charnieres. Le html §25 reste la source d'affichage."""
    p = qc.parse_scenario_html(doc["html"])
    tier, _ = qc._parse_envergure_tier(p.envergure)
    quests = []
    for qi, qbeats in enumerate(p.quests):
        figures = []
        qtext = qc.norm(qc._quest_text(p, qi))
        for fig, aliases in qc.ROSTER_ALIASES.items():
            if any(qc.norm(a) in qtext for a in aliases):
                figures.append(fig)
        beats = []
        for b in qbeats:
            band_txt = qc.strip_tags(b.bandeau)
            fams = qc.FAM_RE.findall(b.bandeau)
            mdiff = re.search(r"difficult\S*\s+(I{1,3})\b", band_txt)
            ch = qc.strip_tags(b.choix).strip()
            labels = [x.strip() for x in ch.split(":", 1)[-1].split("\u00b7") if x.strip()]
            beats.append({
                "epreuve": b.is_epreuve,
                "familles": fams,
                "difficulte": len(mdiff.group(1)) if mdiff else 0,
                "action": labels[0] if b.is_epreuve and labels else "",
                "traits": labels[1:] if b.is_epreuve else [],
                "reaction": bool(b.reaction.strip()),
                "deltas": qc.strip_tags(b.deltas).strip(),
            })
        quests.append({"beats": beats, "figures": figures})
    slots = ["preambule"] + ["transition"] * max(0, len(p.quests) - 1) + ["veille_climax", "cloture"]
    return {
        "id": f"etalon_{idx:02d}",
        "author": "etalon",
        "title": doc.get("title", p.title),
        "envergure": doc.get("envergure", p.envergure),
        "tier": tier,
        "biome": biome_key(doc.get("biome", "")),
        "figures": doc.get("figures", ""),
        "skeleton": {"quests": quests, "merlin_slots": slots},
        "html": doc["html"],
    }


def load_etalons_from_journal(journal: Path) -> list[dict]:
    docs = []
    for line in journal.read_text(encoding="utf-8").splitlines():
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("type") == "result" and isinstance(obj.get("result"), dict):
            r = obj["result"]
            if "html" in r:
                docs.append(r)
    return docs


def cmd_seed_etalons(args) -> int:
    docs = load_etalons_from_journal(Path(args.journal))
    if len(docs) != 10:
        print(f"attendu 10 etalons, trouve {len(docs)}")
        return 1
    libs: dict[str, list[dict]] = {"foret": [], "falaises": []}
    for i, doc in enumerate(docs, 1):
        entry = etalon_to_entry(i, doc)
        libs[entry["biome"]].append(entry)
    DATA_AI.mkdir(parents=True, exist_ok=True)
    rc = 0
    for biome, entries in libs.items():
        path = DATA_AI / f"quest_library_{biome}.json"
        existing = []
        if path.exists():
            existing = [e for e in json.loads(path.read_text(encoding="utf-8")).get("entries", [])
                        if e.get("author") != "etalon"]
        payload = {"version": 1, "biome": biome, "entries": entries + existing}
        path.write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"{path.name} : {len(entries)} etalon(s) + {len(existing)} autre(s)")
        # gate complet sur la bibliotheque
        reports = [qc.qc_scenario(e) for e in payload["entries"]]
        bad = [r for r in reports if r["verdict"] != "PASS"]
        for r in bad:
            qc._print_report(r)
        print(f"  QC : {len(reports) - len(bad)}/{len(reports)} PASS")
        if bad:
            rc = 1
    return rc


def load_library(biome: str) -> list[dict]:
    path = DATA_AI / f"quest_library_{biome}.json"
    if not path.exists():
        return []
    return json.loads(path.read_text(encoding="utf-8")).get("entries", [])


MERLIN_KINDS = ("reaction", "preambule", "transition", "veille_climax")


def _strip_merlin_wrapper(text: str) -> str:
    """Retire l'habillage « MERLIN : « ... » » : le markup est pose par le CODE a
    l'assemblage, jamais demande au LLM (et jamais montre dans les exemples)."""
    t = text.strip()
    t = re.sub(r"^\s*MERLIN\s*:\s*", "", t)
    t = re.sub(r"^[«\"']\s*", "", t)
    t = re.sub(r"\s*[»\"']\s*$", "", t)
    return t.strip()


def normalize_piece(kind: str, text: str) -> str:
    if kind in MERLIN_KINDS:
        return _strip_merlin_wrapper(text)
    return text.strip()


def harvest_examples(biome: str) -> dict[str, list[str]]:
    """Extrait des pieces d'exemple (few-shot) depuis les etalons de la bibliotheque.
    Prefere le biome demande, complete avec l'autre biome si besoin."""
    out: dict[str, list[str]] = {k: [] for k in PIECE_BUDGET}
    for b in (biome, "falaises" if biome == "foret" else "foret"):
        for e in load_library(b):
            if e.get("author") != "etalon":
                continue
            p = qc.parse_scenario_html(e["html"])
            merlins = [pl for k, pl in p.items if k == "merlin"]
            if merlins:
                # les exemples Merlin sont montres SANS l'habillage MERLIN : « » (pose
                # par le code a l'assemblage) : exemples et sortie attendue coincident.
                out["preambule"].append(_strip_merlin_wrapper(qc.strip_tags(merlins[0])))
                # breve = [preambule, veille, cloture] (3) : pas de transition a recolter
                out["transition"].append(
                    _strip_merlin_wrapper(qc.strip_tags(merlins[1])) if len(merlins) >= 4 else "")
                out["veille_climax"].append(
                    _strip_merlin_wrapper(qc.strip_tags(merlins[-2])) if len(merlins) > 1 else "")
            for k, pl in p.items:
                if k == "epilogue":
                    out["epilogue"].append(qc.strip_tags(pl).strip())
            out["pitch"].append(p.pitch)
            for bt in p.beats:
                if bt.is_epreuve:
                    out["scene"].append(qc.strip_tags(bt.scene).strip())
                    out["geste"].append(qc.strip_tags(bt.geste).strip())
                if bt.reaction.strip():
                    out["reaction"].append(_strip_merlin_wrapper(qc.strip_tags(bt.reaction)))
    return {k: [v for v in vals if v] for k, vals in out.items()}


# ---------------------------------------------------------------------------
# Squelette impose par le code (zero LLM)
# ---------------------------------------------------------------------------

def build_skeleton(biome: str, tier: str, rng: random.Random) -> dict:
    n_quests = {"breve": 1, "periple": rng.choice([2, 3]), "odyssee": 4}[tier]
    pool = list(FIGURES_BY_BIOME[biome]) + list(FIGURES_TRANSVERSAL)
    rng.shuffle(pool)
    pilier = rng.choice(PILIER_KEYS)
    quests = []
    for qi in range(n_quests):
        n_beats = rng.choice([3, 4]) if qi < n_quests - 1 else rng.choice([3, 4])
        figure = pool[qi % len(pool)]
        beats = []
        for bi in range(n_beats):
            is_last_quest = qi == n_quests - 1
            is_climax = is_last_quest and bi == n_beats - 1
            btype = "Climax" if is_climax else rng.choice(
                ["Exploration", "Rencontre", "Epreuve", "Dilemme"])
            if bi == 0 and qi == 0:
                btype = "Rencontre"  # la figure de la quete ouvre le sentier
            action = rng.choice(list(TRAITS_BY_ACTION))
            fam2 = rng.choice([f for f in TRAITS_BY_ACTION if f != action])
            traits = rng.sample(TRAITS_BY_ACTION[action], k=min(2, len(TRAITS_BY_ACTION[action])))
            diff = 3 if is_climax else (1 if bi == 0 else 2)
            fams = [action.lower(), fam2.lower()]
            indices = [rng.choice(INDICE_WORDS[fams[0]]), rng.choice(INDICE_WORDS[fams[1]])]
            beats.append({
                "type": btype, "difficulte": diff, "action": action, "traits": traits,
                "familles": fams, "indices": indices,
                "figure": figure if bi == 0 else "",
            })
        quests.append({"figure": figure, "beats": beats})
    return {"biome": biome, "tier": tier, "pilier": pilier, "quests": quests,
            "merlin_slots": ["preambule"] + ["transition"] * (n_quests - 1)
                            + ["veille_climax", "cloture"]}


# ---------------------------------------------------------------------------
# Prompts par piece (few-shot etalon + contraintes injectees)
# ---------------------------------------------------------------------------

def _examples_block(kind: str, examples: dict[str, list[str]], n: int, rng: random.Random) -> str:
    pool = examples.get(kind, [])
    if not pool:
        return ""
    picks = rng.sample(pool, k=min(n, len(pool)))
    lines = []
    for i, ex in enumerate(picks, 1):
        ex_short = re.sub(r"\s+", " ", ex).strip()
        if len(ex_short) > 620:
            ex_short = ex_short[:620].rsplit(".", 1)[0] + "."
        lines.append(f"EXEMPLE {i} (imite la MANIERE et le registre, jamais le contenu) : {ex_short}")
    return "\n".join(lines)


def prompt_scene(skel: dict, qi: int, bi: int, examples: dict, causal_refs: list[str],
                 rng: random.Random) -> dict:
    beat = skel["quests"][qi]["beats"][bi]
    lieu = "Brocéliande" if skel["biome"] == "foret" else "les falaises du Bout-du-Monde"
    fig = beat.get("figure", "")
    fig_line = ""
    if fig:
        # « le heros n'est PAS la figure » : en mesure, le modele a fondu le heros et la
        # figure castee en un seul personnage (« tu te tiens la, Chevalier Sans Nom »).
        fig_line = (f"\nLa scene met en presence {FIGURE_DISPLAY[fig]} ({FIGURE_HINT[fig]}) : "
                    f"nomme-le et fais-le agir ou parler. Le heros n'est PAS "
                    f"{FIGURE_DISPLAY[fig]} : c'est un personnage EN FACE de lui.")
    causal_line = ""
    if causal_refs:
        causal_line = ("\nLa scene REPREND explicitement ceci du recit precedent : "
                       + " ; ".join(causal_refs) + ".")
    ind = beat["indices"]
    usr = (
        _examples_block("scene", examples, 2, rng)
        + f"\n\nEcris UNE scene de 3 phrases pour un moment de type {beat['type']} : "
          f"pose qui est la, ce qui se passe, et ce que le lieu exige."
        + fig_line + causal_line
        + f"\nLa scene doit contenir tels quels les mots « {ind[0]} » et « {ind[1]} »."
        + "\nTermine sur une phrase complete, sans poser de question au heros."
    )
    return {"system": SYSTEM_REGISTRE.format(lieu=lieu), "user": usr,
            "max_tokens": PIECE_BUDGET["scene"], "creative": True}


def prompt_geste(skel: dict, qi: int, bi: int, scene_text: str, examples: dict,
                 degree: str, rng: random.Random) -> dict:
    beat = skel["quests"][qi]["beats"][bi]
    lieu = "Brocéliande" if skel["biome"] == "foret" else "les falaises du Bout-du-Monde"
    traits = beat["traits"]
    deg_line = {
        "reussite": "Le geste REUSSIT franchement : montre ce qui cede ou s'ouvre.",
        "partiel": "Le geste ne reussit qu'A MOITIE : montre ce qui est obtenu ET le prix paye "
                   "(une entaille, une dette, un retard).",
        "echec": "Le geste ECHOUE : montre ce qui resiste ou se referme, sans dire le mot echec.",
    }[degree]
    usr = (
        _examples_block("geste", examples, 2, rng)
        + f"\n\nSCENE EN COURS : {re.sub(chr(10), ' ', qc.strip_tags(scene_text))[:400]}"
        + f"\n\nEcris la RESOLUTION en 3 phrases, commencant par « Tu ». Le heros joue "
          f"{beat['action']} avec {' et '.join(traits)} : mets en scene CE geste precis "
          f"(l'action et au moins un de ces traits, nommes ou traduits en actes concrets). "
        + deg_line
        + "\nNe redecris pas le decor. Termine sur une phrase complete."
    )
    return {"system": SYSTEM_REGISTRE.format(lieu=lieu), "user": usr,
            "max_tokens": PIECE_BUDGET["geste"], "creative": True}


def prompt_reaction(event: str, examples: dict, rng: random.Random) -> dict:
    usr = (
        _examples_block("reaction", examples, 2, rng)
        + f"\n\nVOICI ce qui vient d'arriver a ton Voyageur : {event}"
        + "\nReagis en UNE a DEUX phrases courtes, comme un compagnon qui commente : "
          "concret, complice, un conseil ou un rappel du prix paye. Commence directement "
          "par tes mots (sans prefixe, sans guillemets)."
    )
    return {"system": MERLIN_SYSTEM, "user": usr,
            "max_tokens": PIECE_BUDGET["reaction"], "creative": True}


def prompt_charniere(kind: str, context: str, examples: dict, rng: random.Random) -> dict:
    """Charnieres scriptees (§25.4) : transition entre quetes, veille du climax,
    cloture. 3-4 phrases, voix de Merlin."""
    goal = {
        "transition": "La quete s'acheve et une autre commence sur le meme sentier : "
                      "referme ce qui vient d'etre paye, annonce ou le sentier mene ensuite.",
        "veille_climax": "Le moment decisif approche : rappelle la promesse d'ouverture, "
                         "ce que ton Voyageur a appris en route, et ce qu'il risque a present.",
        "cloture": "L'aventure se referme : dis ce que ton Voyageur emporte, ce que ca lui "
                   "a coute, et envoie-le dormir.",
    }[kind]
    usr = (
        _examples_block(kind if kind != "cloture" else "veille_climax", examples, 2, rng)
        + f"\n\nCONTEXTE : {context}"
        + f"\nEcris cette intervention en 3 a 4 phrases. {goal} "
          "Commence directement par tes mots (sans prefixe, sans guillemets)."
    )
    budget = PIECE_BUDGET.get(kind, PIECE_BUDGET["transition"])
    return {"system": MERLIN_SYSTEM, "user": usr, "max_tokens": budget, "creative": True}


def prompt_preambule(skel: dict, title: str, promesse: str, examples: dict,
                     rng: random.Random) -> dict:
    lieu = "Brocéliande" if skel["biome"] == "foret" else "les falaises du Bout-du-Monde"
    fig = skel["quests"][0]["figure"]
    usr = (
        _examples_block("preambule", examples, 2, rng)
        + f"\n\nEcris le PREAMBULE de l'aventure « {title} » : en 4 a 5 phrases, dis a ton "
          f"Voyageur ou il est ({lieu}), une coutume du lieu a respecter, qui l'attend "
          f"({FIGURE_DISPLAY[fig]}, {FIGURE_HINT[fig]}), et la promesse de l'aventure : "
          f"{promesse}. Termine en promettant que cette question aura sa reponse avant la fin. "
          f"Commence directement par tes mots (sans prefixe, sans guillemets)."
    )
    return {"system": MERLIN_SYSTEM, "user": usr,
            "max_tokens": PIECE_BUDGET["preambule"], "creative": True}


def prompt_epilogue(skel: dict, promesse: str, examples: dict, rng: random.Random) -> dict:
    """Epilogue narratif (pas la voix de Merlin) : referme la promesse d'ouverture."""
    lieu = "Brocéliande" if skel["biome"] == "foret" else "les falaises du Bout-du-Monde"
    fig = skel["quests"][-1]["figure"]
    usr = (
        _examples_block("epilogue", examples, 2, rng)
        + f"\n\nEcris l'EPILOGUE en 4 phrases : ce que le heros sait desormais de la "
          f"promesse d'ouverture ({promesse}), un dernier echange avec "
          f"{FIGURE_DISPLAY[fig]}, et ce qu'il emporte ou laisse derriere lui. "
          "Tutoie le heros (« Tu »). Termine sur une phrase complete."
    )
    return {"system": SYSTEM_REGISTRE.format(lieu=lieu), "user": usr,
            "max_tokens": PIECE_BUDGET["epilogue"], "creative": True}


# ---------------------------------------------------------------------------
# Execution des jobs via Godot headless (moteur du jeu)
# ---------------------------------------------------------------------------

def _other_godot_running() -> bool:
    try:
        out = subprocess.run(["tasklist"], capture_output=True, text=True, timeout=30).stdout
    except Exception:
        return False
    return bool(re.search(r"(?i)godot", out))


def run_jobs(jobs: list[dict], tag: str, per_job_timeout: int = 110, model: str = "") -> dict:
    """Un process Godot headless pour tout le lot ; resultats incrementaux.
    `model` : chemin res:// d'un GGUF alternatif (defaut runner = E2B du jeu)."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    jobs_path = STATE_DIR / f"jobs_{tag}.json"
    out_path = STATE_DIR / f"out_{tag}.json"
    if out_path.exists():
        out_path.unlink()
    jobs_path.write_text(json.dumps({"jobs": jobs}, ensure_ascii=False, indent=1),
                         encoding="utf-8")
    if _other_godot_running():
        print("ATTENTION : un process Godot tourne deja (contrainte : un seul a la fois). Abandon.")
        return {}
    cmd = [str(GODOT_EXE), "--headless", "--path", str(PROJECT_ROOT),
           "--script", "res://tools/forge_gen.gd", "--",
           "--jobs", str(jobs_path), "--out", str(out_path)]
    if model:
        cmd += ["--model", model]
    timeout = 180 + per_job_timeout * len(jobs)
    t0 = time.time()
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout,
                              cwd=str(PROJECT_ROOT), encoding="utf-8", errors="replace")
        for line in (proc.stdout or "").splitlines():
            if line.startswith("[FORGE]"):
                print("   " + line)
    except subprocess.TimeoutExpired:
        print(f"   TIMEOUT global du lot apres {timeout}s (resultats partiels conserves)")
    print(f"   lot {tag} : {time.time() - t0:.0f}s wall-clock")
    if out_path.exists():
        return json.loads(out_path.read_text(encoding="utf-8")).get("results", {})
    return {}


# ---------------------------------------------------------------------------
# QC par piece
# ---------------------------------------------------------------------------

def qc_piece(kind: str, text: str, required: list[str] | None = None,
             action: str = "", traits: list[str] | None = None) -> list[str]:
    lo, hi = PIECE_SENTS[kind]
    errs = qc.qc_piece_prose(text, lo, hi)
    if required:
        errs += qc.qc_piece_requires(text, required)
    if kind == "geste":
        gn = qc.norm(qc.strip_tags(text))
        if not gn.strip().startswith("tu "):
            errs.append("le geste doit commencer par « Tu »")
        act_hit = any(a in gn for a in qc._anchors_for(action)) if action else True
        trait_hits = sum(1 for t in (traits or []) if any(a in gn for a in qc._anchors_for(t)))
        if not ((act_hit and trait_hits >= 1) or trait_hits >= 2):
            errs.append(f"combinaison non verbalisee ({action} / {', '.join(traits or [])})")
    if kind in ("scene", "geste", "epilogue"):
        # La prose de beat tutoie le heros ; « le/du Voyageur » est la voix de MERLIN.
        # Zero occurrence dans les 67 scenes/gestes etalon ; fuite 3e personne observee
        # en mesure (« La paume ... du Voyageur se pose »).
        if "voyageur" in qc.norm(text):
            errs.append("fuite 3e personne : « Voyageur » interdit hors voix de Merlin")
    if kind in MERLIN_KINDS:
        # apres normalize_piece, aucun MERLIN ne doit RESTER dans le texte : sinon le
        # modele a ecrit plusieurs repliques enchainees (double locuteur, observe en
        # mesure : deux « MERLIN : ... » dans une meme reaction).
        if "merlin" in qc.norm(text):
            errs.append("replique multiple ou auto-reference MERLIN dans la piece")
    return errs


# ---------------------------------------------------------------------------
# Generation avec reprise (etat disque) - coeur de la forge
# ---------------------------------------------------------------------------

def load_state(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def save_state(path: Path, state: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(state, ensure_ascii=False, indent=1), encoding="utf-8")


def forge_pieces(piece_defs: list[dict], state_path: Path, model: str = "",
                 per_job_timeout: int = 110) -> dict:
    """Boucle essais/QC avec reprise. piece_defs : [{id, kind, prompt{system,user,...},
    required, action, traits}]. Retourne l'etat final {id: {status, text, attempts}}."""
    state = load_state(state_path)
    pieces = state.setdefault("pieces", {})
    for rnd in range(1, MAX_ATTEMPTS + 1):
        todo = [pd for pd in piece_defs
                if pieces.get(pd["id"], {}).get("status") not in ("ok", "fallback")]
        if not todo:
            break
        batch = [pd for pd in todo if len(pieces.get(pd["id"], {}).get("attempts", [])) == rnd - 1]
        if not batch:
            continue
        print(f"-- essai {rnd} : {len(batch)} piece(s)")
        # MESURE 2026-07-30 : le moteur natif est DETERMINISTE a prompt egal (3 essais
        # identiques a l'octet pres). Re-essayer sans changer le prompt ne sert a rien :
        # on REINJECTE les erreurs QC du dernier essai comme consigne de reprise, ce qui
        # varie le prompt ET oriente la correction.
        jobs = []
        for pd in batch:
            prompt = dict(pd["prompt"])
            prev = pieces.get(pd["id"], {}).get("attempts", [])
            if prev:
                last_errs = "; ".join(prev[-1]["errors"])[:300]
                # le numero de reprise VARIE le prompt meme si l'erreur se repete
                # (sinon : meme prompt -> meme sortie, moteur deterministe)
                prompt["user"] = (prompt["user"]
                                  + f"\nREPRISE {len(prev)} : ta version precedente a ete "
                                    f"refusee pour : {last_errs}. Corrige ces points et "
                                    f"reformule differemment.")
            jobs.append({"id": pd["id"], **prompt})
        results = run_jobs(jobs, f"round{rnd}", per_job_timeout, model)
        for pd in batch:
            rid = pd["id"]
            res = results.get(rid, {})
            text = normalize_piece(pd["kind"], res.get("text") or "")
            errs = (["erreur moteur : " + res.get("error", "vide")]
                    if (not text or res.get("error")) else
                    qc_piece(pd["kind"], text, pd.get("required"),
                             pd.get("action", ""), pd.get("traits")))
            rec = pieces.setdefault(rid, {"status": "pending", "attempts": []})
            rec["attempts"].append({
                "text": text, "errors": errs,
                "ms": res.get("ms", 0), "tok_per_s": res.get("tok_per_s", 0.0),
            })
            if not errs:
                rec["status"] = "ok"
                rec["text"] = text
            elif len(rec["attempts"]) >= MAX_ATTEMPTS:
                best = min(rec["attempts"], key=lambda a: len(a["errors"]))
                rec["status"] = "fallback"
                rec["text"] = best["text"]
                rec["fallback_errors"] = best["errors"]
            save_state(state_path, state)
    return pieces


# ---------------------------------------------------------------------------
# Commande measure - Chantier 3 : la mesure reelle
# ---------------------------------------------------------------------------

MEASURE_REACTION_EVENTS = [
    "il a examine les mailles d'un filet et y a lu un compte repete, sept, trois, sept, "
    "qui vient de l'eau",
    "il est descendu sans faire l'offrande a la mer, et le granit lui a ouvert la paume",
    "il a parle franc au vieux druide, et le druide lui a appris le salut aux eaux",
    "il a paye trois pieces au colporteur pour solder sa dette avant l'aube",
]


def build_measure_defs() -> list[dict]:
    """Reconstruit DETERMINISTIQUEMENT les pieces du banc de mesure (seeds figees) :
    les prompts sont octet-identiques d'une invocation a l'autre, ce qui permet de
    comparer plusieurs modeles sur le MEME banc (E2B vs E4B, R171)."""
    rng = random.Random(20260730)
    examples = harvest_examples("falaises")
    skel = build_skeleton("falaises", "breve", random.Random(7))
    # pieces scriptees : 4 reactions + 2 scenes + 1 preambule + 1 geste de quete
    defs: list[dict] = []
    for i, ev in enumerate(MEASURE_REACTION_EVENTS, 1):
        defs.append({"id": f"reaction_{i}", "kind": "reaction",
                     "prompt": prompt_reaction(ev, examples, rng)})
    b0 = skel["quests"][0]["beats"][0]
    req0 = list(b0["indices"])
    if b0.get("figure"):
        req0.append(FIGURE_ANCHOR[b0["figure"]])
    defs.append({"id": "scene_1", "kind": "scene",
                 "prompt": prompt_scene(skel, 0, 0, examples, [], rng),
                 "required": req0})
    b1 = skel["quests"][0]["beats"][1]
    defs.append({"id": "scene_2", "kind": "scene",
                 "prompt": prompt_scene(skel, 0, 1, examples,
                                        ["la paume entaillee du Voyageur",
                                         f"{FIGURE_DISPLAY[skel['quests'][0]['figure']]} deja croise"],
                                        rng),
                 "required": b1["indices"]})
    defs.append({"id": "preambule_1", "kind": "preambule",
                 "prompt": prompt_preambule(
                     skel, "Le Compte des Marees",
                     "qui tient le compte des marees, et pourquoi il s'est arrete", examples, rng)})
    sc1 = ("Kado le Cordier t'attend sous le phare, un filet inconnu sur les genoux. ")
    defs.append({"id": "quete_geste_1", "kind": "geste",
                 "prompt": prompt_geste(skel, 0, 0, sc1, examples, "partiel", rng),
                 "action": b0["action"], "traits": b0["traits"]})
    return defs


def cmd_measure(args) -> int:
    defs = build_measure_defs()
    if args.skip_quest:
        defs = [pd for pd in defs if pd["id"] != "quete_geste_1"]

    state_path = STATE_DIR / "measure_state.json"
    if args.fresh and state_path.exists():
        state_path.unlink()
    t0 = time.time()
    pieces = forge_pieces(defs, state_path)
    wall = time.time() - t0

    report = {"wall_clock_s": round(wall, 1), "pieces": pieces}
    out = Path(args.out) if args.out else STATE_DIR / "measure_report.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n== MESURE ({wall:.0f}s) -> {out}")
    for pid, rec in pieces.items():
        n = len(rec.get("attempts", []))
        st = rec.get("status", "?")
        toks = [a.get("tok_per_s", 0.0) for a in rec.get("attempts", [])]
        print(f"  {pid:16s} {st:9s} essais={n} tok/s={','.join(f'{t:.2f}' for t in toks)}")
    return 0


# ---------------------------------------------------------------------------
# Commande measure-e4b - MEME banc que le E2B, palier E4B (R171)
# ---------------------------------------------------------------------------

E4B_MODEL = "res://addons/merlin_llm/models/gemma4-e4b-q4_k_m.gguf"
# Parametres EXACTS du run generate E2B (2026-07-30) : ne pas changer, ce sont les
# constantes du banc compare (prompts verifies octet-identiques via jobs_round1.json).
BENCH_GEN_SEED = 42
BENCH_GEN_TITLE = "Le Prix du Passage"
BENCH_GEN_PROMESSE = "ce que le Passeur reclame vraiment a ceux qui traversent"


def cmd_measure_e4b(args) -> int:
    """Banc compare E2B vs E4B : 4 gestes (le test decisif, E2B = 0/4), 2 scenes a
    figure imposee (E2B confondait heros/figure), 2 reactions (controle, E2B les
    reussit). Prompts identiques aux runs E2B ; QC = regles finales courantes."""
    defs_m = build_measure_defs()
    rng = random.Random(BENCH_GEN_SEED)
    skel = build_skeleton("foret", "breve", rng)
    examples = harvest_examples("foret")
    defs_g = build_generate_defs(skel, examples, rng, BENCH_GEN_TITLE, BENCH_GEN_PROMESSE)
    by_id = {pd["id"]: pd for pd in defs_m + defs_g}
    order = ["quete_geste_1", "geste_q0b0", "geste_q0b1", "geste_q0b2",
             "scene_1", "scene_q0b0", "reaction_1", "reaction_2"]
    missing = [pid for pid in order if pid not in by_id]
    if missing:
        print(f"pieces de banc introuvables : {missing}")
        return 2
    defs = [by_id[pid] for pid in order]

    model_abs = PROJECT_ROOT / "addons" / "merlin_llm" / "models" / "gemma4-e4b-q4_k_m.gguf"
    if not model_abs.exists() or model_abs.stat().st_size < 4_000_000_000:
        print(f"GGUF E4B absent ou incomplet : {model_abs}")
        return 2

    state_path = STATE_DIR / "measure_e4b_state.json"
    if args.fresh and state_path.exists():
        state_path.unlink()
    t0 = time.time()
    # E4B ~2x plus lent que le E2B : garde-fou subprocess par piece releve en
    # consequence (le timeout de GENERATION reste celui du jeu, 90 s, dans le runner).
    pieces = forge_pieces(defs, state_path, model=E4B_MODEL, per_job_timeout=220)
    wall = time.time() - t0

    report = {"model": E4B_MODEL, "wall_clock_s": round(wall, 1), "pieces": pieces}
    out = Path(args.out) if args.out else STATE_DIR / "measure_e4b_report.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n== MESURE E4B ({wall:.0f}s) -> {out}")
    for pid in order:
        rec = pieces.get(pid, {})
        n = len(rec.get("attempts", []))
        toks = [a.get("tok_per_s", 0.0) for a in rec.get("attempts", [])]
        print(f"  {pid:16s} {rec.get('status', '?'):9s} essais={n} "
              f"tok/s={','.join(f'{t:.2f}' for t in toks)}")
    return 0


# ---------------------------------------------------------------------------
# Commande generate - un scenario complet piece par piece (batch nocturne)
# ---------------------------------------------------------------------------

def _decorate_scene(text: str, indices: list[str], fams: list[str], diff: int) -> str:
    """Enrobe la 1re occurrence de chaque mot-indice en span kw (le code decore,
    le LLM n'ecrit jamais de markup)."""
    inten_o, inten_c = ("<b><i>", "</i></b>") if diff >= 3 else ("<b>", "</b>")
    out = text
    for word, fam in zip(indices, fams):
        pat = re.compile(re.escape(word), re.IGNORECASE)
        out = pat.sub(lambda m: (f'<span class="kw kw-{fam}">{inten_o}{m.group(0)}{inten_c}</span>'),
                      out, count=1)
    return out


def _bandeau(fams: list[str], diff: int) -> str:
    roman = "I" * diff
    f1, f2 = fams[0].capitalize(), fams[1].capitalize()
    return (f'Épreuve : <span class="fam fam-{fams[0]}">{f1}</span> x '
            f'<span class="fam fam-{fams[1]}">{f2}</span>, difficulté {roman}')


def assemble_html(skel: dict, title: str, pitch: str, pieces: dict) -> str:
    envergure_label = {"breve": "Une veillée", "periple": "Un périple", "odyssee": "Une odyssée"}
    lieu = "forêt" if skel["biome"] == "foret" else "falaises"
    nq = len(skel["quests"])
    env = f"{envergure_label[skel['tier']]} : {lieu}" + (f" ({nq} quêtes)" if nq > 1 else "")
    parts = [f'<article id="forge">', "  <header>",
             f"    <h2>{title.upper()}</h2>",
             f'    <p class="pitch">{pitch}</p>',
             f'    <p class="envergure">{env}</p>', "  </header>"]

    def merlin_div(pid: str) -> str:
        t = pieces.get(pid, {}).get("text", "").strip()
        return f'  <div class="merlin">MERLIN : « {t} »</div>'

    parts.append(merlin_div("preambule"))
    total_q = len(skel["quests"])
    for qi, quest in enumerate(skel["quests"]):
        beats = quest["beats"]
        for bi, beat in enumerate(beats):
            is_final_climax = (qi == total_q - 1 and bi == len(beats) - 1)
            if is_final_climax:
                parts.append(merlin_div("veille_climax"))
            scene = pieces.get(f"scene_q{qi}b{bi}", {}).get("text", "")
            geste = pieces.get(f"geste_q{qi}b{bi}", {}).get("text", "")
            reaction = pieces.get(f"reaction_q{qi}b{bi}", {}).get("text", "")
            parts.append('  <section class="beat">')
            parts.append(f'    <div class="scene">'
                         f'{_decorate_scene(scene, beat["indices"], beat["familles"], beat["difficulte"])}</div>')
            parts.append(f'    <div class="bandeau">{_bandeau(beat["familles"], beat["difficulte"])}</div>')
            parts.append(f'    <div class="choix">Geste : {beat["action"]} · '
                         + " · ".join(beat["traits"]) + "</div>")
            parts.append(f'    <div class="geste">{geste}</div>')
            if reaction:
                parts.append(f'    <div class="reaction">MERLIN : « {reaction} »</div>')
            deltas = beat.get("deltas", "+2 Gwenneg" if bi % 2 == 0 else "Intégrité -1")
            parts.append(f'    <div class="deltas">{deltas}</div>')
            parts.append("  </section>")
        if qi < total_q - 1:
            parts.append(merlin_div(f"transition_{qi}"))
    epi = pieces.get("epilogue", {}).get("text", "")
    parts.append(f'  <div class="epilogue">{epi}</div>')
    parts.append(merlin_div("cloture"))
    parts.append("</article>")
    return "\n".join(parts)


def build_generate_defs(skel: dict, examples: dict, rng: random.Random,
                        title: str, promesse: str) -> list[dict]:
    """Pieces d'un scenario complet. Deterministe a seed egal (comparaison inter-modeles)."""
    defs: list[dict] = [
        {"id": "preambule", "kind": "preambule",
         "prompt": prompt_preambule(skel, title, promesse, examples, rng)},
    ]
    causal: list[str] = []
    degrees = ["partiel", "reussite", "echec", "reussite", "partiel"]
    for qi, quest in enumerate(skel["quests"]):
        for bi, beat in enumerate(quest["beats"]):
            sid = f"scene_q{qi}b{bi}"
            req = list(beat["indices"])
            if beat.get("figure"):
                req.append(FIGURE_ANCHOR[beat["figure"]])
            defs.append({"id": sid, "kind": "scene",
                         "prompt": prompt_scene(skel, qi, bi, examples, list(causal), rng),
                         "required": req})
            deg = degrees[(qi * 4 + bi) % len(degrees)]
            # deltas ALIGNES sur le degre : toute perte d'Integrite exige une reaction
            # de Merlin (QC merlin.reaction) -> on ne perd que sur echec/partiel, et ces
            # beats recoivent leur piece reaction.
            beat["deltas"] = "Intégrité -1" if deg in ("echec", "partiel") else "+2 Gwenneg"
            defs.append({"id": f"geste_q{qi}b{bi}", "kind": "geste",
                         "prompt": prompt_geste(skel, qi, bi,
                                                "(la scene precede ce geste)", examples, deg, rng),
                         "action": beat["action"], "traits": beat["traits"]})
            if deg in ("echec", "partiel"):
                ev = f"le geste de {beat['action']} n'a pas suffi, il en garde une trace"
                defs.append({"id": f"reaction_q{qi}b{bi}", "kind": "reaction",
                             "prompt": prompt_reaction(ev, examples, rng)})
            fig = beat.get("figure", "")
            causal = [f"{FIGURE_DISPLAY[fig]} deja rencontre"] if fig else causal
        if qi < len(skel["quests"]) - 1:
            nxt = FIGURE_DISPLAY[skel["quests"][qi + 1]["figure"]]
            defs.append({"id": f"transition_{qi}", "kind": "transition",
                         "prompt": prompt_charniere(
                             "transition", f"la prochaine quete mene vers {nxt}", examples, rng)})
    defs.append({"id": "veille_climax", "kind": "veille_climax",
                 "prompt": prompt_charniere(
                     "veille_climax", "promesse d'ouverture : " + promesse, examples, rng)})
    defs.append({"id": "cloture", "kind": "transition",
                 "prompt": prompt_charniere("cloture", "fin de l'aventure", examples, rng)})
    defs.append({"id": "epilogue", "kind": "epilogue",
                 "prompt": prompt_epilogue(skel, promesse, examples, rng)})
    return defs


def cmd_generate(args) -> int:
    rng = random.Random(args.seed)
    biome = args.biome
    skel = build_skeleton(biome, args.tier, rng)
    examples = harvest_examples(biome)
    state_path = STATE_DIR / f"gen_{biome}_{args.tier}_{args.seed}.json"
    state = load_state(state_path)
    state["skeleton"] = skel
    save_state(state_path, state)

    title = args.title or "Le Sentier Sans Nom"
    promesse = args.promesse or "ce que le lieu a perdu, et qui le reclame"
    defs = build_generate_defs(skel, examples, rng, title, promesse)

    pieces = forge_pieces(defs, state_path)
    html = assemble_html(skel, title, args.pitch or promesse.capitalize() + ".", pieces)
    doc = {"title": title, "envergure": "", "biome": biome, "figures": "", "html": html}
    report = qc.qc_scenario(doc)
    qc._print_report(report)
    out = STATE_DIR / f"gen_{biome}_{args.tier}_{args.seed}_scenario.json"
    out.write_text(json.dumps({**doc, "qc": report["verdict"],
                               "author": "forge-gemma"}, ensure_ascii=False, indent=1),
                   encoding="utf-8")
    print(f"scenario -> {out}")
    return 0 if report["verdict"] == "PASS" else 1


# ---------------------------------------------------------------------------

def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description="Forge de scenarios (BIBLE §25, W4)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p1 = sub.add_parser("seed-etalons", help="convertit les 10 etalons en bibliotheque + QC")
    p1.add_argument("--journal", default=str(DEFAULT_JOURNAL))
    p2 = sub.add_parser("measure", help="mesure reelle du Gemma natif (Chantier 3)")
    p2.add_argument("--skip-quest", action="store_true")
    p2.add_argument("--fresh", action="store_true", help="ignore l'etat de reprise")
    p2.add_argument("--out", default="")
    p4 = sub.add_parser("measure-e4b", help="banc compare E2B vs E4B (R171)")
    p4.add_argument("--fresh", action="store_true", help="ignore l'etat de reprise")
    p4.add_argument("--out", default="")
    p3 = sub.add_parser("generate", help="genere un scenario complet piece par piece")
    p3.add_argument("--biome", choices=["foret", "falaises"], default="foret")
    p3.add_argument("--tier", choices=["breve", "periple", "odyssee"], default="breve")
    p3.add_argument("--seed", type=int, default=42)
    p3.add_argument("--title", default="")
    p3.add_argument("--pitch", default="")
    p3.add_argument("--promesse", default="")
    args = ap.parse_args(argv)
    if args.cmd == "seed-etalons":
        return cmd_seed_etalons(args)
    if args.cmd == "measure":
        return cmd_measure(args)
    if args.cmd == "measure-e4b":
        return cmd_measure_e4b(args)
    return cmd_generate(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

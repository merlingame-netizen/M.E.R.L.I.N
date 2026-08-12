#!/usr/bin/env python3
"""La plume — quatre appels au modèle pour habiller le chapitre du jour.

Le socle (`journal_gabarits.py`) écrit déjà un chapitre lisible sans modèle.
Ici on remplace DEUX scènes et le chapô par de la prose, et rien d'autre. Le
Python continue de porter les faits, la structure et le volume.

Trois règles qui tiennent tout :

1. **L'HORAIRE.** 05:50, dans le seul créneau réellement vide de la nuit :
   l'atelier d'écriture occupe 00:10→06:45 par tranches de 35 min, mais
   05:45→06:08 ne l'est jamais. Aucune carte d'entraînement n'est sacrifiée, et
   il n'y a aucun arbitrage à demander à Maxime.

2. **LA VOIX EST EN PYTHON.** Un e4b quantifié ne tient pas un tic de langage
   sur 300 tokens de génération : ce qui distingue les personnages, c'est
   `troupe.json` (nom, emoji, traits tirés par rotation sur le numéro de
   chapitre), pas le prompt. On demande au modèle de la prose, pas une identité.

3. **ON NE BRODE PAS.** Tout nombre présent dans une scène et absent de la
   fiche fait JETER la scène entière, remplacée par sa version gabarit. On
   n'efface jamais un chiffre dans la phrase : ça produirait « l'Ankou pèse  %
   des effets » dans un registre append-only qui ne s'efface pas. Coût du
   refus : un appel perdu. Coût de l'alternative : la confiance dans le seul
   écran que Maxime lit vraiment.

Stdlib seule. Ne lève jamais : en cas d'échec, le chapitre gabarit est écrit.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import journal as J              # noqa: E402
import journal_gabarits as G     # noqa: E402

LLM_ASK = HERE.parents[1] / "infra" / "oracle" / "llm" / "llm-ask.sh"
LEDGER = Path.home() / ".cache" / "merlin-agents" / "llm-ledger.jsonl"
RESUME = J.BASE / "resume_courant.txt"

TEMP = "0.75"
CTX = "4096"                     # le régime que chat_reply impose déjà
NOMBRE = re.compile(r"\d+(?:[.,]\d+)?")


def _troupe() -> dict:
    try:
        return json.loads((HERE / "troupe.json").read_text(encoding="utf-8")).get("acteurs", {})
    except Exception:
        return {}


def _voix(acteur: str, chapitre: int) -> str:
    """Deux traits sur cinq, tirés par rotation : la variété ne coûte pas un token."""
    f = _troupe().get(acteur) or {}
    traits = f.get("traits") or []
    if not traits:
        return ""
    a = traits[chapitre % len(traits)]
    b = traits[(chapitre + 2) % len(traits)]
    return f"{G._nom(acteur)} — {f.get('role', '')}. Ce soir il est {a} et {b}."


def _appel(prompt: str, predict: int, seed: int, secondes: int = 220) -> tuple[str, dict]:
    t0 = time.time()
    try:
        p = subprocess.run(
            ["bash", str(LLM_ASK), "--ctx", CTX, "--predict", str(predict),
             "--timeout", str(secondes), "--temp", TEMP, "--seed", str(seed)],
            input=prompt, capture_output=True, text=True, timeout=secondes + 40)
        txt = (p.stdout or "").strip()
        motif = "" if txt else (p.stderr or "").strip()[:120] or f"rc={p.returncode}"
    except Exception as exc:
        txt, motif = "", f"{type(exc).__name__}: {exc}"[:120]
    return txt, {"secs": round(time.time() - t0, 1), "tokens": len(txt) // 4,
                 "motif": motif}


def _chiffres_autorises(fiche: dict) -> set[str]:
    """Tous les nombres que la fiche contient — la seule vérité chiffrée."""
    brut = json.dumps(fiche, ensure_ascii=False)
    return {n.replace(",", ".") for n in NOMBRE.findall(brut)}


def _honnete(texte: str, autorises: set[str]) -> tuple[bool, str]:
    """Un seul chiffre hors fiche et on jette la scène entière."""
    for n in NOMBRE.findall(texte):
        if n.replace(",", ".") not in autorises:
            return False, n
    return True, ""


def _bloc_faits(fiche: dict, n: int = 5) -> str:
    """La fiche élaguée : les n faits de plus haut poids, déjà en français."""
    lignes = []
    for f in fiche.get("saillants", [])[:n]:
        lignes.append(f"- {f['heure']} · {G._nom(f['acteur'])} : {f['titre']}"
                      + (f" ({f['detail'][:140]})" if f.get("detail") else ""))
    return "\n".join(lignes) or "- (aucun fait notable)"


def _resume_courant() -> str:
    try:
        return RESUME.read_text(encoding="utf-8").strip()[:700]
    except Exception:
        return ""


def rediger(fiche: dict) -> tuple[str, str, dict]:
    """(texte, rédigé_par, coût). Retombe sur les gabarits à la moindre faiblesse."""
    gabarit = G.rediger(fiche)
    saillants = fiche.get("saillants", [])
    if not saillants:
        return gabarit, "gabarits", {"appels": 0, "secs": 0}

    chap = int(fiche.get("n", 1))
    autorises = _chiffres_autorises(fiche)
    faits = _bloc_faits(fiche)
    resume = _resume_courant()
    cadre = (
        "Tu écris la chronique d'un atelier où des artisans fabriquent un jeu.\n"
        "RÈGLES ABSOLUES :\n"
        "- en français simple, comme un romancier qui visite un atelier ;\n"
        "- JAMAIS un chiffre absent des faits ci-dessous ;\n"
        "- JAMAIS de vocabulaire technique : pas de « LLM », « rc », « JSON », "
        "« commit », « script », « architecture », « projet », « développeur » ;\n"
        "- les artisans sont DÉSIGNÉS par leur nom (le Codeur, l'Équilibreur…) et "
        "on parle d'eux à la troisième personne ;\n"
        "- le lecteur est le créateur du jeu : on lui dit « tu », jamais « le "
        "développeur » ni « l'utilisateur » ;\n"
        "- pas de liste à puces, pas de titre, pas de préambule.\n\n"
        + (f"CE QUI PRÉCÈDE :\n{resume}\n\n" if resume else "")
        + f"LES FAITS DE LA NUIT :\n{faits}\n\n")

    cout = {"appels": 0, "secs": 0.0, "rejets": 0}
    morceaux, sources = [], []

    def _tenter(consigne: str, predict: int, secours: str, graine: int) -> str:
        txt, m = _appel(cadre + consigne, predict, graine)
        cout["appels"] += 1
        cout["secs"] = round(cout["secs"] + m["secs"], 1)
        if not txt:
            sources.append("vide:" + (m.get("motif") or "?"))
            return secours
        ok, faux = _honnete(txt, autorises)
        if not ok:
            cout["rejets"] += 1
            sources.append(f"rejet:{faux}")
            return secours
        sources.append("llm")
        return txt.strip()

    # 1. Le chapô — de quoi la nuit a été faite.
    chapo = _tenter("Écris trois phrases d'ouverture qui disent de quoi cette nuit "
                    "a été faite. Pas de préambule, commence directement.",
                    160, G._chapo(fiche), chap)

    # 2-3. Deux scènes, chacune avec la voix de son acteur.
    for i, f in enumerate(saillants[:2]):
        secours = G._scene({**f, "repetitions": 1}, fiche.get("causalite", {}))
        v = _voix(f["acteur"], chap + i)
        txt = _tenter(
            f"PERSONNAGE : {v}\n"
            f"SON FAIT : {f['heure']} — {f['titre']}"
            + (f" ({f['detail'][:200]})" if f.get("detail") else "") + "\n\n"
            "Raconte CE fait en quatre-vingts mots environ, à la troisième "
            "personne, comme une scène. N'invente aucun détail technique.",
            200, secours, chap * 10 + i)
        entete = f"**{f['heure']} — {G._nom(f['acteur']).upper()}**"
        morceaux.append(entete + "\n" + txt if not txt.startswith("**") else txt)

    # 4. L'« à suivre » + le résumé courant pour la nuit prochaine.
    fils = fiche.get("fils_ouverts") or []
    suite = _tenter(
        "FILS ENCORE OUVERTS :\n"
        + ("\n".join(f"- {x.get('sujet', x.get('cle', ''))}" for x in fils[:4])
           or "- (aucun)")
        + "\n\nÉcris deux phrases : ce qui reste en suspens et ce qu'on saura "
          "demain. Termine par rien d'autre.",
        180, G._fils(fiche) or "Rien ne reste en suspens.", chap * 100)

    try:
        RESUME.parent.mkdir(parents=True, exist_ok=True)
        RESUME.write_text((chapo + " " + suite)[:700], encoding="utf-8")
    except Exception:
        pass

    entete = (f"**JOURNAL DE L'ATELIER — {fiche.get('jour','')} · chapitre {chap}**\n"
              f"*« {G._titre_court(fiche)} »*")
    blocs = [entete, chapo] + morceaux
    for extra in (G._chiffres(fiche), G._fils(fiche), suite):
        if extra:
            blocs.append(extra)
    llm = sources.count("llm")
    blocs.append(f"*{cout['appels']} appel(s) au modèle, {cout['secs']} s"
                 + (f" · {cout['rejets']} scène(s) écartée(s) pour un chiffre inventé"
                    if cout["rejets"] else "") + ".*")
    cout["sources"] = sources
    # Si le modèle n'a rien donné d'utilisable, on rend le gabarit tel quel :
    # un chapitre à moitié LLM et à moitié gabarit se lit plus mal que les deux.
    if llm == 0:
        return gabarit, "gabarits (modèle muet)", cout
    return "\n\n".join(blocs), f"la plume ({llm}/4 scènes)", cout


def _ledger(cout: dict, chap: int) -> None:
    """Le registre de coût — la première fois qu'on peut prouver ce que coûte
    une nuit."""
    try:
        LEDGER.parent.mkdir(parents=True, exist_ok=True)
        with LEDGER.open("a", encoding="utf-8") as f:
            f.write(json.dumps({"t": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                                "qui": "journal", "chapitre": chap,
                                "appels": cout.get("appels", 0),
                                "secs": cout.get("secs", 0),
                                "rejets": cout.get("rejets", 0)},
                               ensure_ascii=False) + "\n")
    except Exception:
        pass


def main(argv=None) -> int:
    sec = "--sec" in (argv or sys.argv)
    fiche = J.collecte(24)
    texte, par, cout = rediger(fiche)
    if sec:
        print(texte)
        print(f"\n[à sec] {par} · {cout.get('appels')} appel(s), "
              f"{cout.get('secs')} s, {cout.get('rejets', 0)} rejet(s)")
        return 0
    J.ecrire(fiche, texte, par, cout)
    _ledger(cout, fiche["n"])
    print(f"chapitre {fiche['n']} — {par} · {cout.get('appels')} appel(s), "
          f"{cout.get('secs')} s, {cout.get('rejets', 0)} rejet(s)")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:
        print(f"échec de la plume : {type(exc).__name__}: {exc}"[:180])
        sys.exit(1)

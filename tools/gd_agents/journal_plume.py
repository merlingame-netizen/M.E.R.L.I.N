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

TEMP = "0.35"      # 0,75 = température de prose ; ici on rapporte
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


# Ce que le modèle n'a AUCUN moyen de savoir, donc qu'il a forcément inventé.
# Le garde-fou ne contrôlait que les chiffres arabes : « le développeur hoche la
# tête en murmurant » le passait à 100 %. Liste volontairement COURTE et sûre —
# on préfère laisser filer une tournure que jeter une scène honnête.
BRODERIE = re.compile(
    r"\b("
    # gestes et mimiques : personne ne les a observés
    r"hoche|hochant|acquiesce|murmur\w*|souri\w*|sourit|soupir\w*|fronce|"
    r"grimace|se penche|lève les yeux|se redresse|s'attarde|contemple|"
    # états d'âme prêtés à quelqu'un
    r"satisfait\w*|frustré\w*|impatien\w*|serein\w*|inquiet\w*|fier\w*|"
    r"songeu\w*|pensi\w*|résigné\w*|avec plaisir|avec satisfaction|"
    # décor et ambiance : l'atelier n'a ni lampes ni parchemins
    r"lueur|lampes?|bougies?|chandelles?|parchemins?|atelier baigné|"
    r"pénombre|obscurité|silence de la nuit|au creux de la nuit|"
    # étiquettes d'acteur qui ne désignent personne de réel
    r"le développeur|l'utilisateur|les artisans|l'équipe"
    r")\b", re.I)


def _honnete(texte: str, autorises: set[str]) -> tuple[bool, str]:
    """Un chiffre hors fiche OU un mot inventé, et on jette la scène entière.

    Le principe est le même que pour les nombres : on ne corrige pas la phrase,
    on la remplace par sa version gabarit. Retoucher une broderie laisserait un
    texte bancal dans un registre qui ne s'efface jamais."""
    for n in NOMBRE.findall(texte):
        if n.replace(",", ".") not in autorises:
            return False, n
    m = BRODERIE.search(texte)
    if m:
        return False, f"« {m.group(0)} » (inventé)"
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
    # « Comme un romancier qui visite un atelier » était un MANDAT DE FICTION :
    # un romancier décrit des gestes, des lumières, des visages. Le modèle a donc
    # écrit « tu hoches la tête avec satisfaction en murmurant » — Maxime avait
    # tapé une pastille. On demande maintenant un compte rendu.
    #
    # On ne liste plus non plus les mots interdits : nommer « développeur » dans
    # une interdiction, c'est le mettre dans le contexte, et c'est exactement le
    # mot que le modèle a choisi pour désigner Maxime.
    cadre = (
        "Tu rédiges le compte rendu de la nuit pour celui qui dirige l'atelier.\n"
        "RÈGLES ABSOLUES :\n"
        "- UNE phrase par fait, en français simple. Rien de plus.\n"
        "- tu ne rapportes QUE ce qui est écrit dans les faits ci-dessous ;\n"
        "- AUCUN geste, AUCUNE émotion, AUCUN décor, AUCUNE heure du jour, "
        "AUCUNE supposition sur ce que quelqu'un a ressenti ou pensé ;\n"
        "- JAMAIS un chiffre absent des faits ;\n"
        "- les agents portent leur nom (le Codeur, l'Équilibreur…) ;\n"
        "- « toi », c'est le lecteur : tu lui dis « tu », jamais autre chose ;\n"
        "- pas de liste à puces, pas de titre, pas de préambule, pas de morale.\n\n"
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
        # `_francais` n'était appliqué qu'aux FAITS, jamais à la sortie du
        # modèle : s'il produisait du jargon de lui-même, rien ne l'attrapait.
        return J._francais(txt.strip())

    # 1. Le chapô — de quoi la nuit a été faite. DEUX phrases : trois, sur cinq
    # lignes de faits, obligeaient à meubler.
    chapo = _tenter("En deux phrases : de quoi cette nuit a été faite. "
                    "Commence directement, sans préambule.",
                    110, G._chapo(fiche), chap)

    # 2-3. Deux faits, rapportés. PAS de « personnage » : `_voix()` prescrivait
    # une humeur (« ce soir il est impatient »), ce qui contredisait l'interdit
    # des émotions — et pour l'acteur « toi » elle rendait une chaîne VIDE, si
    # bien que le modèle inventait le personnage principal de sa propre scène.
    for i, f in enumerate(saillants[:2]):
        secours = G._scene({**f, "repetitions": 1}, fiche.get("causalite", {}))
        qui = G._nom(f["acteur"])
        sujet = ("Toi" if f["acteur"] == "toi" else qui)
        txt = _tenter(
            f"LE FAIT : à {f['heure']}, {sujet} — {f['titre']}"
            + (f" ({f['detail'][:200]})" if f.get("detail") else "") + "\n\n"
            "Rapporte CE fait en deux phrases, vingt-cinq mots environ. "
            "Dis ce qui s'est passé et ce que ça change. Rien d'autre.",
            120, secours, chap * 10 + i)
        entete = f"**{f['heure']} — {qui.upper()}**"
        morceaux.append(entete + "\n" + txt if not txt.startswith("**") else txt)

    # 4. Ce qui reste ouvert. On ne demande PLUS « ce qu'on saura demain » :
    # c'était une invitation explicite à la prédiction, donc à l'invention — sur
    # des fils qui, de surcroît, ne bougeaient jamais.
    fils = fiche.get("fils_ouverts") or []
    suite = _tenter(
        "CE QUI RESTE OUVERT :\n"
        + ("\n".join(f"- {x.get('libelle') or x.get('dernier') or x.get('sujet') or x.get('cle', '')}"
                     for x in fils[:4]) or "- (rien)")
        + "\n\nEn deux phrases : ce qui reste en suspens, et rien d'autre. "
          "Ne suppose pas ce qui va arriver.",
        120, G._fils(fiche) or "Rien ne reste en suspens.", chap * 100)

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
    # `--sec` est un essai à blanc : il ne grave ni chapitre ni fil.
    fiche = J.collecte(24, graver=not sec)
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

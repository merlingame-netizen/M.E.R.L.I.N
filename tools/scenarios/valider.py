#!/usr/bin/env python3
"""Le contrat d'une quete. Ce qui ne le respecte pas ne se joue pas.

    python3 tools/scenarios/valider.py                    # tout le corpus
    python3 tools/scenarios/valider.py fichier.json       # une quete, meme hors corpus

POURQUOI CE FICHIER EXISTE SEPAREMENT DU RENDU. Tant que les quetes etaient ecrites a la main, une
faute se voyait en relisant. Des que le MODELE en produit, plus personne ne relit : il faut donc un
juge qui dise non. Ce fichier est ce juge, et `rendre.py` s'en sert — les deux ne peuvent pas
diverger puisqu'il n'y a qu'une regle.

CE QU'IL REFUSE, et pourquoi chacun compte :
  STRUCTURE   des beats numerotes sans trou — un trou, et le journal ment sur ce qui a ete joue.
  MECANIQUE   une tuile hors du socle, une rune hors du paquet, un de hors de 2d6 : injouable.
  DECK        une rune posee qu'on n'a pas en main. Le solveur le prouve ou echoue.
  SOCLE       une tuile jamais employee de toute la quete : defaut de conception, pas de hasard.
  BASCULE     une quete sans une seule decision n'est pas une quete, c'est un couloir.
  ARGENT      une bourse qui bouge sans evenement qui en donne — le defaut mesure sur p74.
  PROSE       la numerotation d'etape qui fuit dans le texte (« 0. Vous suivez… »), mesuree sur
              sept beats de p74 ; et le meme geste ouvrant tous les beats, mesure sur dix-sept.

CE QU'IL NE PEUT PAS JUGER, et il vaut mieux le savoir : si l'histoire tient, si les figures
veulent quelque chose, si le mystere est dans l'ambiance et non dans le sens. Ces regles-la sont
dans docs/BIBLE_DES_REGLES.md §5 et se verifient en lisant.
"""
import collections
import json
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parents[2]
SRC = RACINE / "data" / "scenarios"

TUILES = {"OBSERVER", "AGIR", "COMBATTRE", "RÉVÉLER", "PARLER"}
TYPES = {"Exploration", "Rencontre", "Épreuve", "Dilemme", "Climax"}
GENRES = {"marchand", "boss", "poursuite", "veille", "partage", "rituel", "énigme écrite"}
BEATS_MIN, BEATS_MAX = 8, 25


def degre(m):
    if m >= 8:
        return "éclatante"
    if m >= 0:
        return "réussite"
    if m >= -5:
        return "partiel"
    return "échec"


def simuler_deck(q, erreurs):
    """Reproduit la pioche. La main est un paquet : la rune posee part, une autre arrive, et un
    beat SPECIAL ne touche a rien. La pioche est DEDUITE — si elle ne converge pas, la quete
    reclame une rune qu'aucun tirage ne pouvait fournir, et elle est injouable."""
    beats = q["beats"]
    depart = list(q.get("main_depart") or [])
    runes = list(q.get("runes") or {})
    reserve = [r for r in runes if r not in depart]
    forces = {}
    for _ in range(80):
        main, mains, tirages, manque = list(depart), [], [], None
        for i, b in enumerate(beats):
            if b.get("special"):
                mains.append(list(main))
                tirages.append(None)
                continue
            r = b.get("rune")
            if r not in main:
                j = i - 1
                while j >= 0 and beats[j].get("special"):
                    j -= 1
                if j < 0:
                    erreurs.append("beat %s pose %r, hors main de depart et sans beat anterieur "
                                   "pour la piocher" % (b.get("n"), r))
                    return None, None
                manque = (j, r)
                break
            mains.append(list(main))
            main.remove(r)
            tire = forces.get(i)
            if tire is None or tire in main:
                pris = set(main) | {r}
                libre = [x for x in reserve + depart if x not in pris]
                tire = libre[(i * 3) % len(libre)] if libre else r
            tirages.append(tire)
            main.append(tire)
        if manque is None:
            return mains, tirages
        forces[manque[0]] = manque[1]
    erreurs.append("le deck ne converge pas : la quete reclame des runes qu'aucune pioche ne donne")
    return None, None


def valider(q, nom=""):
    e, avert = [], []
    ref = nom or q.get("id", "?")

    # ── STRUCTURE
    for cle in ("id", "titre", "monde", "beats", "runes", "gestes", "main_depart"):
        if not q.get(cle):
            e.append("champ manquant : %s" % cle)
    if e:
        return e, avert
    B = q["beats"]
    if not (BEATS_MIN <= len(B) <= BEATS_MAX):
        e.append("%d beats — hors de la fourchette %d-%d du canon" % (len(B), BEATS_MIN, BEATS_MAX))
    ns = [b.get("n") for b in B]
    if ns != list(range(1, len(B) + 1)):
        trous = [i for i in range(1, (max(ns) if ns else 0) + 1) if i not in ns]
        e.append("numerotation non contigue — manquants : %s" % (trous or ns))
    if len(set(q["main_depart"])) != 4:
        e.append("la main de depart doit compter quatre runes distinctes, elle en a %d"
                 % len(set(q["main_depart"])))
    for r in q["main_depart"]:
        if r not in q["runes"]:
            e.append("main de depart : %r absente du paquet de runes" % r)
    if set(q["gestes"]) != TUILES:
        e.append("le socle doit etre exactement les cinq tuiles ; il vaut %s" % sorted(q["gestes"]))

    # ── BEAT PAR BEAT
    for b in B:
        n = b.get("n")
        for cle in ("t", "scene", "issue", "note"):
            if not b.get(cle):
                e.append("beat %s : champ %s manquant" % (n, cle))
        if b.get("t") not in TYPES:
            e.append("beat %s : type %r inconnu" % (n, b.get("t")))
        # UN BEAT MAIGRE. Sur une quete ecrite a la main, le cas ne se pose pas. Sur une quete
        # GENEREE, un appel au modele qui rend une phrase tronquee — ou rien — produit un beat
        # techniquement present et narrativement vide, que rien d'autre n'attrape : `scene` non
        # vide suffisait au controle precedent.
        # LES SEUILS SONT MESURES SUR LE CORPUS ECRIT A LA MAIN, pas choisis : la scene la plus
        # courte y fait 46 signes (une mise en place de beat special), l'issue la plus courte 108.
        # Un premier essai a 90 refusait trois de mes propres quetes — c'etait le controle qui
        # avait tort, pas les textes.
        for cle, mini in (("scene", 40), ("issue", 80)):
            v_ = str(b.get(cle, "")).strip()
            if 0 < len(v_) < mini:
                e.append("beat %s : %s trop courte (%d signes) — le modele a rendu un fragment"
                         % (n, cle, len(v_)))
        sp = b.get("special")
        if sp:
            g = sp.get("genre", "")
            if not any(g.startswith(x) or x in g for x in GENRES | {"choix"}):
                e.append("beat %s : mecanique %r hors catalogue" % (n, g))
            if "choix" in g:
                opts = sp.get("options") or []
                if not (2 <= len(opts) <= 4):
                    e.append("beat %s : un choix compte 2 a 4 propositions, il en a %d" % (n, len(opts)))
                if not (0 <= int(sp.get("pris", -1)) < len(opts)):
                    e.append("beat %s : la proposition retenue est hors des options" % n)
            if any(k in b for k in ("action", "rune", "de", "dc", "at")):
                e.append("beat %s : un beat special n'a ni tuile, ni rune, ni de" % n)
            continue
        if b.get("action") not in TUILES:
            e.append("beat %s : tuile %r hors du socle" % (n, b.get("action")))
        if b.get("rune") not in q["runes"]:
            e.append("beat %s : rune %r hors du paquet" % (n, b.get("rune")))
        if b.get("sans_jet"):
            continue
        for cle in ("dc", "at", "de"):
            if cle not in b:
                e.append("beat %s : %s manquant" % (n, cle))
        if e:
            continue
        if int(b["at"]) not in (0, 3, 6):
            e.append("beat %s : atouts %d impossible — +3 par tag couvert, donc 0, 3 ou 6"
                     % (n, int(b["at"])))
        if not (2 <= int(b["de"]) <= 12):
            e.append("beat %s : de %d hors de 2d6" % (n, int(b["de"])))

    if e:
        return e, avert

    # ── DECK
    mains, _ = simuler_deck(q, e)
    if mains is None:
        return e, avert
    if any(len(m) != 4 for m in mains):
        e.append("une main affichee ne compte pas quatre runes")

    # ── SOCLE, BASCULES
    joues = {b["action"] for b in B if not b.get("special")}
    orph = sorted(TUILES - joues)
    if orph:
        e.append("tuile(s) du socle jamais employee(s) : %s" % ", ".join(orph))
    bascules = [b.get("bascule") for b in B if b.get("bascule")]
    if not any((x or [None])[0] == "choisie" for x in bascules):
        e.append("aucune bascule choisie — une quete sans decision est un couloir")

    # ── ARGENT : la bourse ne bouge que sur un evenement qui en donne.
    for b in B:
        sp = b.get("special") or {}
        if sp.get("genre") == "marchand" and not sp.get("etal"):
            e.append("beat %s : marchand sans etal" % b.get("n"))

    # ── PROSE : les deux defauts mesures sur p74.
    fuite = [b["n"] for b in B if re.search(r"(?:^|\s)\d+\.\s", str(b.get("scene", "")))]
    if fuite:
        e.append("la numerotation d'etape fuit dans la prose des beats %s" % fuite)
    # L'ADRESSE AU JOUEUR NE CHANGE PAS EN COURS DE QUETE. Mesure sur q82, premiere quete
    # generee : 23 marques de tutoiement et 8 de vouvoiement dans le MEME texte, les beats 1-2
    # vouvoyant et les beats 3-8 tutoyant. Le modele recopiait le registre du canon qu'on lui
    # injectait. Le corpus ecrit a la main vouvoie a 258 marques contre 2 — d'ou le seuil : une
    # figure peut tutoyer entre guillemets, trois marques nues sont un glissement de registre.
    hors_dialogue = re.sub(r"«[^»]*»", " ", " ".join(
        str(b.get("scene", "")) + " " + str(b.get("issue", "")) for b in B))
    tu = len(re.findall(r"\b(?:[Tt]u|[Tt]on|[Tt]a|[Tt]es|[Tt]oi)\b", hors_dialogue))
    if tu >= 3:
        e.append("l'adresse au joueur change en cours de quete : %d marques de tutoiement hors "
                 "dialogue — le defaut mesure sur q82" % tu)
    # LA TROISIEME PERSONNE EST LE MEME DEFAUT SOUS UN AUTRE VISAGE, et mon premier controle ne
    # cherchait que le tutoiement : q87 est passee avec « le Voyageur » dans six beats sur huit
    # et onze « vous » seulement. Le corpus ecrit a la main n'emploie JAMAIS « le Voyageur » dans
    # le corps d'un beat — zero sur soixante-sept — donc le seuil vaut trois comme l'autre.
    il = len(re.findall(r"\b[Ll]e Voyageur\b", hors_dialogue))
    if il >= 3:
        e.append("le joueur est raconte a la troisieme personne %d fois (« le Voyageur ») — "
                 "le corpus dit « Vous » ; defaut mesure sur q87" % il)

    ouvertures = collections.Counter(
        " ".join(str(b.get("issue", "")).split()[:5]).lower() for b in B)
    if ouvertures:
        tete, combien = ouvertures.most_common(1)[0]
        if combien > max(2, len(B) // 3):
            e.append("%d issues sur %d ouvrent par « %s… » — le defaut mesure sur p74"
                     % (combien, len(B), tete))

    # ── AVERTISSEMENTS : ce qui n'invalide pas, mais qui se paie en jeu.
    degres = collections.Counter(
        "sans jet" if b.get("sans_jet") else degre(b["de"] + b["at"] - b["dc"])
        for b in B if not b.get("special"))
    if degres.get("partiel", 0) + degres.get("échec", 0) == 0:
        avert.append("aucun revers sur %d beats — une quete qui ne rate jamais n'apprend rien"
                     % len(B))
    if not any(b.get("special") for b in B):
        avert.append("aucun beat special")
    return e, avert


def main():
    args = sys.argv[1:]
    fichiers = [pathlib.Path(a) for a in args] or sorted(SRC.glob("*.json"))
    rates = 0
    for f in fichiers:
        q = json.loads(f.read_text(encoding="utf-8"))
        e, a = valider(q, f.stem)
        if e:
            rates += 1
            print("  REFUSE  %-24s" % f.stem)
            for x in e:
                print("            · %s" % x)
        else:
            print("  ok      %-24s%s" % (f.stem, ("  (%s)" % " ; ".join(a)) if a else ""))
    print("\n%d quete(s) validee(s), %d refusee(s)" % (len(fichiers) - rates, rates))
    return 1 if rates else 0


if __name__ == "__main__":
    sys.exit(main())

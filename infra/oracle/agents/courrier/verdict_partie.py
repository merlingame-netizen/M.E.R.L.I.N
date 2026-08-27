#!/usr/bin/env python3
"""Le verdict d'une partie temoin — les trois cibles dures, chacune avec son compte exact.

    python3 verdict_partie.py <journal.json>

POURQUOI CE FICHIER EXISTE, SEPAREMENT DES JOBS. Le verdict etait recopie a l'interieur de
chaque job-0NN, ce qui a produit deux defauts a la fois : on ne pouvait pas le corriger sans
reecrire un job (et corriger un job qui TOURNE est dangereux, bash lisant ses scripts au fil de
l'eau), et chaque copie derivait. Ici il vit une fois, les jobs l'appellent.

CE QU'IL CORRIGE. La cible « <= 20 s par beat » etait jugee sur `duree_beat_s`, qui va de
l'entree du beat a l'avance et englobe donc la pose de 25 s du bot, l'etal du colporteur, le
draft et le guide de Merlin. Juger la latence machine la-dessus n'a aucun sens : le beat 1 de
p68 « durait » 29 s dont 25 s de pause deliberee. La cible se juge desormais sur
`attente_moteur_s` — du clic Resoudre a l'issue affichee, le seul intervalle ou le joueur attend
la machine sans rien a faire. `duree_beat_s` reste affichee, pour rester comparable aux parties
d'avant, mais elle ne decide plus.

CE QU'IL VERIFIE EN PLUS. Le champ `gen` du journal est un instantane de `last_metrics()`, que
CHAQUE generation terminee ecrase, toutes voies confondues. Depuis v48.1e il porte son `label` :
on l'affiche, et on refuse de tirer une conclusion du budget de contexte quand le label ne dit
pas « issue ». Une mesure mal attribuee doit se voir, pas se deguiser en preuve.
"""
import json
import re
import sys

CIBLE_S = 20.0
PLEIN = ("reussite", "eclatante")


def main(chemin: str) -> int:
    d = json.load(open(chemin, encoding="utf-8"))
    bs = d.get("beats") or []
    res = [b for b in bs if "degre" in b]
    fin = d.get("fin") or {}
    if not res:
        print("VERDICT impossible : aucun beat resolu dans le journal")
        return 1

    # --- cible 1 : SECOURS = 0
    sec = [b["index"] for b in res if b.get("secours")]
    print("CIBLE1 secours: %s" % (
        "TENUE" if not sec else "MANQUEE (%d : beats %s)" % (len(sec), ",".join(map(str, sec)))))

    # --- cible 2 : reussite complete a chaque geste
    manques = [(b["index"], b.get("degre"), b.get("difficulte"), b.get("de"),
                (b.get("choix_du_bot") or {}).get("couverture"))
               for b in res if str(b.get("degre")) not in PLEIN]
    pleins = len(res) - len(manques)
    print("CIBLE2 reussite: %s" % (
        "TENUE (%d/%d)" % (pleins, len(res)) if not manques else
        "MANQUEE (%d/%d ; %s)" % (pleins, len(res),
            " ".join("b%s=%s(diff%s,de%s,cov%s)" % m for m in manques))))

    # --- cible 3 : <= 20 s D'ATTENTE MACHINE (pas de duree de beat)
    att = [(b["index"], float(b["attente_moteur_s"])) for b in res if b.get("attente_moteur_s")]
    if att:
        trop = [(i, s) for i, s in att if s > CIBLE_S]
        moy = sum(s for _, s in att) / len(att)
        print("CIBLE3 attente: %s" % (
            "TENUE (max %.0fs, moy %.0fs)" % (max(s for _, s in att), moy) if not trop else
            "MANQUEE (%d beats > %.0fs : %s ; moy %.0fs)" % (
                len(trop), CIBLE_S, " ".join("b%d=%.0fs" % t for t in trop), moy)))
    else:
        print("CIBLE3 attente: NON MESUREE (attente_moteur_s absent — sonde anterieure a v48.1a)")

    # la duree de beat reste dite, mais elle ne juge plus : elle contient les poses du bot.
    dur = [(b["index"], float(b.get("duree_beat_s", 0))) for b in res if b.get("duree_beat_s")]
    if dur:
        print("INFO duree_beat (pose du bot incluse, ne juge PAS) : %s ; moy %.0fs" % (
            " ".join("b%d=%.0fs" % t for t in dur), sum(s for _, s in dur) / len(dur)))

    # --- le budget de contexte, et A QUOI il se rapporte
    lignes, suspects = [], 0
    for b in res:
        g = b.get("gen") or {}
        if g.get("prompt_tokens") is None:
            continue
        lab = str(g.get("label", "?"))
        if "issue" not in lab.lower():
            suspects += 1
        lignes.append("b%s:p%s/e%s[%s]" % (b["index"], g.get("prompt_tokens"),
                                           g.get("tokens_ecrits"), lab[:14]))
    if lignes:
        print("BUDGET %s" % " ".join(lignes))
        if suspects:
            print("BUDGET ATTENTION : %d releve(s) ne portent PAS le label « issue » — "
                  "last_metrics a ete ecrase par une autre generation, ne rien conclure de ceux-la"
                  % suspects)

    coupees = [b["index"] for b in res
               if int((b.get("gen") or {}).get("tokens_ecrits") or 0) < 40 and not b.get("secours")]
    print("COUPEES %s" % (",".join(map(str, coupees)) if coupees else "aucune"))

    # --- le bot a-t-il joue couvrant, et qu'a-t-il construit ?
    ch = [b.get("choix_du_bot") for b in res if b.get("choix_du_bot")]
    if ch:
        print("BOT %d/%d beats justifies ; couverture %s ; gestes surs %d" % (
            len(ch), len(res), ",".join(str(c.get("couverture")) for c in ch),
            sum(1 for c in ch if c.get("geste_sur"))))
    else:
        print("BOT AUCUN choix justifie — le mode couvrant n'a PAS tourne")

    # --- LA CONTINUITE (v49) : la scene du beat N+1 s'ouvre-t-elle sur ce que l'issue N a laisse ?
    # On ne demande rien au jeu : on compare les textes du journal. Le fil est la DERNIERE phrase
    # de l'issue ; s'il a servi, la narration suivante COMMENCE par elle.
    def _phrases(s):
        return [x.strip() for x in re.split(r"(?<=[.!?…])\s+", str(s).strip()) if x.strip()]

    def _norm(s):
        return re.sub(r"[^a-z0-9]+", " ", str(s).lower()).strip()

    tenus, total_ch, details = 0, 0, []
    for a, b in zip(res, res[1:]):
        iss = re.sub(r"\[/?i\]", "", str(a.get("resolution", "")))
        ph = _phrases(iss)
        if not ph:
            continue
        total_ch += 1
        fil = _norm(ph[-1])[:60]
        suite = _norm(b.get("narration", ""))
        if fil and fil[:40] and suite.startswith(fil[:40]):
            tenus += 1
            details.append("b%s:oui" % b["index"])
        else:
            details.append("b%s:non" % b["index"])
    if total_ch:
        print("CONTINUITE %d/%d enchainements portent le fil du beat precedent (%s)" % (
            tenus, total_ch, " ".join(details)))
    else:
        print("CONTINUITE non mesurable (moins de deux beats resolus)")

    # --- l'empreinte du monde
    blob = " ".join(str(b.get("narration", "")) + " " + str(b.get("resolution", "")) for b in bs)
    blob += " " + str(d.get("intro", ""))
    lieux = [x for x in ["Barenton", "Val sans Retour", "Pas de Nuit", "Gue des Brumes",
                         "Pierre Qui Oublie", "Chene Creux", "Tertre"] if x.lower() in blob.lower()]
    fig = [x for x in ["Lavandiere", "Passeur", "Ankou", "korrigan", "Fanch", "Kado",
                       "Choeur", "Chevalier", "Enfant", "Arthur"] if x.lower() in blob.lower()]
    boucle = re.findall(r"boucl\w*|rejou\w*|repet\w*|sans fin|encore et encore|tourne en rond"
                        r"|meme scene|deja vu", blob, re.I)
    print("EMPREINTE lieux=[%s] figures=[%s] boucle=%d" % (",".join(lieux), ",".join(fig), len(boucle)))
    print("FIN %s beats=%d integrite=%s corruption=%s" % (
        fin.get("type", "?"), len(bs), fin.get("integrite"), fin.get("corruption")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "journal.json"))

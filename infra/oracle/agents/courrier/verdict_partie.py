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


def _continuite(res: list) -> tuple[int, int, list]:
    """(tenus, total, details) : la scene N+1 s'ouvre-t-elle sur la derniere phrase de l'issue N ?"""
    def _phrases(s):
        return [x.strip() for x in re.split(r"(?<=[.!?…])\s+", str(s).strip()) if x.strip()]

    def _norm(s):
        return re.sub(r"[^a-z0-9]+", " ", str(s).lower()).strip()

    tenus, total, details = 0, 0, []
    for a, b in zip(res, res[1:]):
        ph = _phrases(re.sub(r"\[/?i\]", "", str(a.get("resolution", ""))))
        if not ph:
            continue
        total += 1
        fil = _norm(ph[-1])[:60]
        if fil and fil[:40] and _norm(b.get("narration", "")).startswith(fil[:40]):
            tenus += 1
            details.append("b%s:oui" % b.get("index", "?"))
        else:
            details.append("b%s:non" % b.get("index", "?"))
    return tenus, total, details


def mesures(d: dict) -> dict:
    """La partie en UNE ligne de nombres — ce que nuits.jsonl accumule et que le Studio trace.

    Une mesure par nuit, comparable a la precedente : c'est ce qui manquait aux trois CIBLES, qui
    disaient MANQUEE a chaque nuit sans jamais dire « pire », « pareil » ou « mieux »."""
    bs = d.get("beats") or []
    res = [b for b in bs if "degre" in b]
    fin = d.get("fin") or {}
    sec = {b.get("index") for b in res if b.get("secours")}
    prov = {b.get("index") for b in res if str(b.get("provenance")) == "secours"}
    degres = [str(b.get("degre")) for b in res]
    pleins = sum(1 for x in degres if x in PLEIN)
    att = sorted(float(b["attente_moteur_s"]) for b in res if b.get("attente_moteur_s"))
    # LES TROUS D'INDEX, comme dans le texte : un JSON qui dit « 20 beats » pour 22 joues
    # rendrait deux nuits comparables alors qu'elles ne le sont pas (v50.3).
    idx = [int(b["index"]) for b in res if b.get("index") is not None]
    trous = [i for i in range(min(idx), max(idx) + 1) if i not in idx] if idx else []
    joues = int(fin.get("beats_joues") or 0)

    def q(p):
        return round(att[min(len(att) - 1, int(round((len(att) - 1) * p)))], 1) if att else None

    tenus, total, _ = _continuite(res)
    return {
        "beats": len(bs), "resolus": len(res),
        "banc": len(sec | prov), "banc_scenes": len(prov), "banc_issues": len(sec),
        "pleins": pleins, "partiels": degres.count("partiel"), "echecs": degres.count("echec"),
        "reussite_pct": round(100.0 * pleins / len(res)) if res else None,
        "bot_couvrant": any(b.get("choix_du_bot") for b in res),
        "attente_med_s": q(0.5), "attente_p90_s": q(0.9),
        "attente_moy_s": round(sum(att) / len(att), 1) if att else None,
        "attente_max_s": round(att[-1], 1) if att else None,
        "continuite": [tenus, total],
        "beats_joues": joues or None, "trous": trous, "sans_index": len(res) - len(idx),
        "incomplet": bool(trous or (joues and joues != len(idx)) or len(res) != len(idx)),
        "fin": fin.get("type"), "integrite": fin.get("integrite"), "corruption": fin.get("corruption"),
        "signes": sum(len(str(b.get("narration", "")) + str(b.get("resolution", ""))) for b in bs),
    }


def main(chemin: str) -> int:
    d = json.load(open(chemin, encoding="utf-8"))
    bs = d.get("beats") or []
    res = [b for b in bs if "degre" in b]
    fin = d.get("fin") or {}
    if not res:
        print("VERDICT impossible : aucun beat resolu dans le journal")
        return 1

    # --- LES TROUS D'INDEX, avant toute statistique.
    #
    # v50.3 — p74 portait 20 entrees d'index [1..14, 16..20, 22] pour 22 beats declares joues : les
    # index 15 et 21 manquaient. Le verdict a donc annonce « reussite 20/20 », « continuite 15/19 »
    # et « attente moyenne 33 s » sur un echantillon incomplet SANS LE DIRE. Un chiffre dont on
    # ignore le denominateur ne vaut rien. Les index sont deja dans le journal : il suffisait de
    # les lire. Le correctif du jeu (v53) devrait supprimer la cause ; cette ligne-ci garantit que
    # si elle revient, elle ne passera plus inapercue.
    idx = [int(b["index"]) for b in res if b.get("index") is not None]
    if idx:
        trous = [i for i in range(min(idx), max(idx) + 1) if i not in idx]
        joues = int((fin or {}).get("beats_joues") or 0)
        if trous or (joues and joues != len(idx)):
            print("TROUS index absents=%s ; %d entree(s) pour %s beat(s) declares joues — "
                  "TOUTES les statistiques ci-dessous portent sur un echantillon INCOMPLET."
                  % (",".join(map(str, trous)) or "aucun", len(idx), joues or "?"))

    # --- cible 1 : SECOURS = 0
    #
    # v50.2 — DEUX TEMOINS, ET ILS NE DISENT PAS LA MEME CHOSE. Le drapeau `secours` vient de
    # `secours_consomme()` cote scenario ; `provenance` dit quelle fabrique a REELLEMENT ecrit le
    # beat. Sur p74 les deux ensembles sont DISJOINTS : le drapeau marque le seul beat 11, quand la
    # provenance marque les beats 17, 18, 19 et 20. Le verdict annoncait donc « 1 recours au banc »
    # pour une quete dont les QUATRE DERNIERS beats etaient procéduraux — et cela expliquait, sans
    # que personne ne le voie, les deux decrochages de continuite en b19 et b20 : le banc ne porte
    # pas le fil du beat precedent.
    # Un beat servi par le banc n'est pas ecrit par le modele : le compter comme une reussite
    # revient a se feliciter d'un texte que le jeu aurait produit sans aucune IA. On compte donc
    # les DEUX, et on le dit quand ils divergent.
    sec = [b["index"] for b in res if b.get("secours")]
    prov = [b["index"] for b in res if str(b.get("provenance")) == "secours"]
    tous = sorted(set(sec) | set(prov))
    print("CIBLE1 secours: %s" % (
        "TENUE" if not tous else "MANQUEE (%d beat(s) au banc : %s)" % (
            len(tous), ",".join(map(str, tous)))))
    if sec != prov:
        print("  ATTENTION les deux temoins divergent — drapeau=%s ; provenance=%s. "
              "Le drapeau seul sous-compte le banc." % (
                  ",".join(map(str, sec)) or "aucun", ",".join(map(str, prov)) or "aucun"))
    if prov:
        print("  Les beats %s n'ont PAS ete ecrits par le modele : ni leur prose, ni leur "
              "continuite, ni leur empreinte du Lore ne mesurent quoi que ce soit du LLM."
              % ",".join(map(str, prov)))

    # --- cible 2 : reussite complete a chaque geste
    manques = [(b["index"], b.get("degre"), b.get("difficulte"), b.get("de"),
                (b.get("choix_du_bot") or {}).get("couverture"))
               for b in res if str(b.get("degre")) not in PLEIN]
    pleins = len(res) - len(manques)
    # SANS BOT COUVRANT, LA CIBLE NE MESURE PAS LE JEU. Le bot cycle ses cartes a l'aveugle : avec
    # un DC de 9, 28 % de reussite sans tag couvert contre 72 % avec un seul. Les deux premieres
    # nuits ont dit MANQUEE sur les des (crible du 06/09). On le dit, on ne juge pas.
    if not any(b.get("choix_du_bot") for b in res):
        print("CIBLE2 reussite: NON MESUREE (bot NON couvrant — %d/%d pleins jugent les des, pas le jeu ; %s)"
              % (pleins, len(res), " ".join("b%s=%s(diff%s,de%s)" % m[:4] for m in manques) or "aucun manque"))
    else:
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

    # --- A QUOI L'ATTENTE EST DUE : prefixe relu, ecriture etranglee, ou fond de quete ?
    #
    # v50.1 — LA REFERENCE EST MESUREE SUR LA PARTIE, PAS SUPPOSEE. La premiere version de cette
    # section utilisait un seuil absolu (prompt_tokens > 200) parce que merlin_native.gd donne
    # « ~2 quand le cache a tout servi, 2045 quand tout a ete relu ». En partie reelle la ligne de
    # base est ~480 tokens relus a CHAQUE beat — la part variable du prompt, jamais en cache. Le
    # seuil absolu classait donc 7 beats sur 7 en « relecture » ; il y en avait deux. On compare
    # desormais a la MEDIANE de la partie.
    #
    # Trois causes distinctes, qui ne se corrigent pas au meme endroit :
    #   PREFIXE RELU ...... prompt_tokens >> mediane : un prompt d'arc a evince le cache.
    #                       -> ordonnancement de l'arc.
    #   ECRITURE ETRANGLEE  debit d'ecriture effondre a prompt normal : le moteur ecrit pendant
    #                       qu'autre chose tourne. -> contention CPU, l'arc en fond.
    #   FOND DE QUETE ..... ni l'un ni l'autre : le contexte grandit, tout ralentit doucement.
    #                       -> rien a corriger, c'est le prix d'une quete longue.
    mesures = [(b["index"], float(b.get("attente_moteur_s") or 0), b.get("gen") or {})
               for b in res if (b.get("gen") or {}).get("compteurs_reels")]
    ptoks = [int(g.get("prompt_tokens") or 0) for _, _, g in mesures if int(g.get("prompt_tokens") or 0) > 0]
    debits = []
    for _, _, g in mesures:
        e = float(g.get("ecriture_ms") or 0) / 1000.0
        n = int(g.get("tokens_ecrits") or 0)
        if e > 0 and n > 0:
            debits.append(n / e)
    if mesures and ptoks and debits:
        ptoks.sort(); debits.sort()
        med_p = ptoks[len(ptoks) // 2]
        med_d = debits[len(debits) // 2]
        print("REFERENCE prefixe median=%d tok relus/beat · debit median=%.1f tok/s "
              "(la ligne de base de CETTE partie)" % (med_p, med_d))
        lignes, n_evic, n_etr, n_fond, perdu_evic, perdu_etr = [], 0, 0, 0, 0.0, 0.0
        for i, a, g in mesures:
            if a <= CIBLE_S:
                continue
            pt = int(g.get("prompt_tokens") or 0)
            pms = float(g.get("prompt_ms") or 0) / 1000.0
            ems = float(g.get("ecriture_ms") or 0) / 1000.0
            ne = int(g.get("tokens_ecrits") or 0)
            deb = (ne / ems) if ems > 0 else 0.0
            if pt > 2.5 * med_p:
                cause, n_evic = "PREFIXE RELU", n_evic + 1
                perdu_evic += max(0.0, pms - (float(med_p) / max(pt, 1)) * pms)
            elif deb > 0 and deb < 0.6 * med_d:
                cause, n_etr = "ECRITURE ETRANGLEE", n_etr + 1
                perdu_etr += max(0.0, ems - ne / med_d)
            else:
                cause, n_fond = "fond de quete", n_fond + 1
            lignes.append("  b%-3d %5.0fs = prefixe %4.0fs (%5d tok) + ecriture %4.0fs "
                          "(%4.1f tok/s)  %s" % (i, a, pms, pt, ems, deb, cause))
        if lignes:
            print("CAUSE attente: %d beat(s) au-dessus de la cible — %d PREFIXE RELU, "
                  "%d ECRITURE ETRANGLEE, %d fond de quete"
                  % (len(lignes), n_evic, n_etr, n_fond))
            print("\n".join(lignes))
            if n_evic or n_etr:
                print("  => ~%.0fs perdues par eviction de cache + ~%.0fs par contention : "
                      "les deux accusent l'ORDONNANCEMENT de l'arc, pas le modele."
                      % (perdu_evic, perdu_etr))
            if n_fond:
                print("  => les %d beat(s) « fond de quete » ne sont imputables a rien : "
                      "le contexte grandit, le debit baisse. C'est le prix d'une quete longue."
                      % n_fond)
        elif att:
            print("CAUSE attente: aucun beat au-dessus de la cible — rien a attribuer.")

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
    tenus, total_ch, details = _continuite(res)
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
    args = [a for a in sys.argv[1:] if a != "--json"]
    if "--json" in sys.argv:
        print(json.dumps(mesures(json.load(open(args[0] if args else "journal.json", encoding="utf-8"))),
                         ensure_ascii=False))
        sys.exit(0)
    sys.exit(main(args[0] if args else "journal.json"))

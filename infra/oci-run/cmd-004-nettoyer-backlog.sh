#!/usr/bin/env bash
# cmd-004 (pont OCI) — nettoyer le backlog des propositions (decision Maxime 2026-08-25).
#
# Constat : les 54 propositions en attente ne sont PAS 54 decisions de design. Regles de tri,
# appliquees via proposals.decide() — chaque rejet garde sa raison, tout est trace :
#   - kind=controle           -> REJET : alertes de la panne du 2026-08-25, resolue (VM
#                                 debloquee a 21h, chaine restauree, cron=33).
#   - kind=balance sans patch -> REJET : analyse d'equilibrage sans changement applicable. De plus
#                                 le compteur « N cartes par faction » mesure le CORPUS d'exemples,
#                                 pas le deck jouable (fixe : 5 actions + 16 traits, pivot v11) —
#                                 la premisse est fausse (constat Maxime). Signal agrege note.
#   - confidence <= 0.2       -> REJET : echec LLM (modele indisponible a l'analyse).
#   - kind=content            -> GARDE : 10 nouvelles cartes, examen au cas par cas ensuite.
#   - kind=design             -> GARDE : audit bible, a lire.
#
# DISCIPLINE DE SORTIE : depot public, sortie commitee — comptes seulement, jamais de secret.
set -u
cd /var/lib/ocarun/workspace/M.E.R.L.I.N 2>/dev/null || cd "$HOME/workspace/M.E.R.L.I.N" || { echo "KO depot"; exit 1; }

python3 - <<'PY'
import sys
sys.path.insert(0, "tools/gd_agents")
import proposals

pend = proposals.listing(limit=200).get("pending", [])
rej_controle = rej_balance = rej_echec = garde = 0
for p in pend:
    pid = p.get("id")
    kind = p.get("kind")
    conf = p.get("confidence") or 0
    ch = p.get("change") or {}
    applicable = bool(ch.get("after") and ch.get("target"))
    if kind == "controle":
        proposals.decide(pid, "reject",
            "alerte de la panne du 2026-08-25 (VM bloquee 24 h par un ecart de mode git), resolue : chaine restauree, cron=33")
        rej_controle += 1
    elif conf and conf <= 0.2:
        proposals.decide(pid, "reject", "echec LLM (modele indisponible au moment de l'analyse)")
        rej_echec += 1
    elif kind in ("balance",) and not applicable:
        proposals.decide(pid, "reject",
            "analyse d'equilibrage sans patch applicable ; le compteur de cartes par faction mesure le CORPUS d'exemples, pas le deck jouable fixe (5 actions + 16 traits, pivot v11) — premisse invalide")
        rej_balance += 1
    else:
        garde += 1

reste = proposals.listing(limit=200)
print("A rejet_controle=%d rejet_balance=%d rejet_echec=%d gardes=%d" % (
    rej_controle, rej_balance, rej_echec, garde))
c = reste.get("counts", {})
print("B apres: pending=%d accepted=%d rejected=%d" % (
    c.get("pending", 0), c.get("accepted", 0), c.get("rejected", 0)))
print("C restant par kind: " + ", ".join(
    "%s=%d" % (k, sum(1 for x in reste.get("pending", []) if x.get("kind") == k))
    for k in sorted(set(x.get("kind") for x in reste.get("pending", [])))))
PY
echo "D fin cmd-004"

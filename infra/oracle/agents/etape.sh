#!/usr/bin/env bash
# `etape` — un agent dit OÙ IL EN EST pendant qu'il travaille. À SOURCER, pas à exécuter.
#
# POURQUOI. Le portail sait déjà QUI travaille (verrou flock, cf. _is_running dans probes.py)
# mais pas ce qu'il fait : un agent de 12 minutes affiche « en cours » et rien d'autre pendant
# 12 minutes. Impossible de distinguer « il avance » de « il est planté » — et on a vu
# aujourd'hui un agent rester bloqué 300 s sur une attente qui ne finirait jamais, sans que
# rien ne l'indique.
#
# USAGE, dans un agent :
#   etape 2 5 "import des assets"
#
# Ne JAMAIS écrire sur stdout : agent-run.sh prend la dernière ligne de stdout comme résumé
# de l'agent. Une trace d'étape qui s'y glisserait remplacerait le résumé final.
#
# Silencieux et sans échec par construction : un agent ne doit pas mourir parce qu'il n'a pas
# réussi à raconter ce qu'il faisait. Sans MERLIN_RUN_STATE (agent lancé à la main, hors
# agent-run.sh), `etape` ne fait simplement rien.

etape() {
    local n="${1:-0}" total="${2:-0}" libelle="${3:-}"
    [ -n "${MERLIN_RUN_STATE:-}" ] || return 0
    python3 - "$MERLIN_RUN_STATE" "$n" "$total" "$libelle" <<'PY' 2>/dev/null || true
import json, os, sys, time
chemin, n, total, libelle = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
# On RELIT pour préserver `debut`, posé par agent-run.sh au démarrage : c'est lui qui permet
# d'afficher « depuis 4 min », et le recalculer ici ferait repartir le chrono à chaque étape.
try:
    d = json.load(open(chemin))
except Exception:
    d = {}
d.update({"etape": n, "etapes_total": total, "libelle": libelle,
          "maj": int(time.time())})
d.setdefault("debut", int(time.time()))
# Écriture atomique : le portail lit ce fichier toutes les 20 s et tomberait autrement sur un
# JSON à moitié écrit — une sonde qui plante sur un fichier tronqué est pire que pas de sonde.
tmp = chemin + ".tmp"
with open(tmp, "w") as f:
    json.dump(d, f, ensure_ascii=False)
os.replace(tmp, chemin)
PY
}

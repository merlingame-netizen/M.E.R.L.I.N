#!/usr/bin/env bash
# Le Contrôleur — il ne croit AUCUN agent sur parole.
#
# POURQUOI. Le 2026-08-15, trois composants ont échoué en se déclarant sains :
#   · le moteur restait suspendu sans jamais émettre d'erreur (aucun outil headless n'a
#     jamais chargé le modèle, et personne ne l'a su pendant des mois) ;
#   · un agent rapportait rc=143 en ayant pourtant tout accompli ;
#   · une synchro annonçait « à jour » sur un dépôt vieux de plusieurs heures.
# Aucun n'a levé d'alerte. Tous ont été trouvés à la main, par hasard.
#
# Un tableau de bord qui RECOPIE ce que les agents déclarent hérite donc de leurs mensonges.
# Cet agent confronte chaque affirmation à une trace vérifiable, et ne signale QUE l'écart
# entre les deux. Il ne bloque rien et ne corrige rien : l'écart part dans Décider, avec sa
# preuve, et Maxime tranche. Un correcteur automatique qui se trompe empilerait une seconde
# couche de mensonge sur la première.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

STATE_DIR="$HOME/.cache/merlin-agents/state"
INBOX="$HOME/.cache/merlin-proposals/inbox"
mkdir -p "$INBOX"

etape 1 2 "lecture des déclarations"

# Tout le travail est en python : comparer des états, des durées et des dépôts en bash
# donnerait un script illisible, et c'est justement de fiabilité qu'il est question ici.
python3 - "$STATE_DIR" "$INBOX" "$TOOLS_REPO" "$GAME_DIR" <<'PY'
import json, os, re, subprocess, sys, time
from pathlib import Path

etats, inbox, tools_repo, game_dir = (Path(sys.argv[1]), Path(sys.argv[2]),
                                      sys.argv[3], sys.argv[4])
maintenant = int(time.time())
ecarts = []


def sh(argv, cwd=None):
    try:
        p = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, timeout=15)
        return (p.stdout or "").strip()
    except Exception:
        return ""


def lire(p):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}


# ── Règle 1 : un succès sans résumé n'est pas un succès ──────────────────────────────────
# agent-run.sh prend la DERNIÈRE ligne de stdout comme résumé. Un agent tué en cours de route
# (SIGTERM, timeout, OOM) peut avoir fait tout son travail sans jamais l'écrire : il rapporte
# alors rc=0 et un résumé vide. Vécu tel quel avec tools-autosync (rc=143, travail complet,
# dernière ligne jamais atteinte). C'est le cas le plus insidieux : il RESSEMBLE à une réussite.
for f in sorted(etats.glob("*.json")):
    if f.name.endswith(".run.json"):
        continue
    d = lire(f)
    if not d:
        continue
    resume = str(d.get("summary", "")).strip()
    if d.get("ok") and resume in ("", "(sans résumé)"):
        ecarts.append({
            "titre": f"{d.get('id')} : succès annoncé, rien à montrer",
            "claim": "L'agent rapporte une réussite mais n'a laissé aucun résumé. "
                     "Un agent tué en cours de route (délai dépassé, mémoire, arrêt) fait "
                     "exactement cela : le travail est peut-être fait, la preuve manque.",
            "preuves": [{"source": f"état de {d.get('id')}",
                         "metric": f"rc={d.get('rc')} · résumé vide · durée {d.get('duration_s')} s"}],
        })

# ── Règle 2 : « en cours » n'est pas « au travail » ──────────────────────────────────────
# Le verrou dit qu'un agent tourne, jamais qu'il avance. Un agent bloqué sur une attente qui
# ne finira pas garde son verrou indéfiniment. On compare le silence à la durée HABITUELLE de
# cet agent-là (son dernier passage réussi), et non à un seuil universel : la mesure du moteur
# se tait légitimement douze minutes là où la CI ne devrait jamais dépasser deux.
for f in sorted(etats.glob("*.run.json")):
    course = lire(f)
    if not course:
        continue
    aid = course.get("id", f.stem.replace(".run", ""))
    depuis = maintenant - int(course.get("debut", maintenant))
    habituel = int(lire(etats / f"{aid}.json").get("duration_s", 0) or 0)
    # 3× la durée habituelle, plancher à 20 min pour ne pas harceler les agents rapides.
    seuil = max(1200, habituel * 3)
    if depuis > seuil:
        ecarts.append({
            "titre": f"{aid} : bloqué depuis {depuis // 60} min",
            "claim": f"L'agent tient son verrou depuis {depuis // 60} minutes alors que son "
                     f"dernier passage complet en a pris {habituel // 60 or '<1'}. Il ne "
                     "travaille probablement plus — et tant qu'il tient le verrou, il empêche "
                     "tous ses passages suivants.",
            "preuves": [{"source": f"course de {aid}",
                         "metric": f"étape « {course.get('libelle')} » · "
                                   f"silence {(maintenant - int(course.get('maj', maintenant))) // 60} min"}],
        })

# ── Règle 3 : une synchro qui annonce un commit doit être SUR ce commit ──────────────────
d = lire(etats / "tools-autosync.json")
m = re.search(r"->\s*([0-9a-f]{7,40})", str(d.get("summary", "")))
if m:
    annonce, reel = m.group(1), sh(["git", "rev-parse", "--short", "HEAD"], cwd=tools_repo)
    if reel and not (annonce.startswith(reel) or reel.startswith(annonce)):
        ecarts.append({
            "titre": "L'outillage n'est pas sur le commit annoncé",
            "claim": f"La synchro a annoncé « {annonce} » mais le dépôt est sur « {reel} ». "
                     "Soit la mise à jour a échoué après coup, soit quelque chose l'a défaite.",
            "preuves": [{"source": "git rev-parse HEAD", "metric": f"annoncé {annonce} · réel {reel}"}],
        })

# ── Règle 4 : une CI verte doit avoir laissé sa capture ──────────────────────────────────
# « 7 scènes saines, boot rendu OK » sans image, c'est une affirmation sur un rendu que
# personne n'a vu. La capture EST la preuve du verdict.
d = lire(etats / "ci-commit.json")
resume = str(d.get("summary", ""))
if "VERT" in resume:
    sha = (re.search(r"CI\s+([0-9a-f]{7,40})", resume) or [None, ""])[1]
    ci_dir = Path.home() / ".cache" / "merlin-agents" / "ci"
    images = list(ci_dir.glob(f"*{sha}*.png")) if sha else []
    if sha and not images:
        ecarts.append({
            "titre": f"CI verte sans capture pour {sha}",
            "claim": "La CI déclare le boot rendu correct, mais aucune image n'existe pour ce "
                     "commit. Le verdict porte donc sur un rendu que personne n'a vu.",
            "preuves": [{"source": "dossier des captures CI",
                         "metric": f"aucun fichier *{sha}*.png dans {ci_dir}"}],
        })

# ── Règle 5 : le garde du 0 € doit être VIVANT ───────────────────────────────────────────
# Le 0 € est non négociable, et la seule chose qui le surveille est l'agent `billing`. Un
# garde-fou muet ne garde rien : s'il cesse de tourner, plus personne ne verrait une facture
# naître. On ne vérifie donc pas ce qu'il DIT (0,00 €) mais qu'il l'ait dit RÉCEMMENT.
#
# Contexte qui explique le seuil : les agents de cette VM n'ont AUCUN accès à l'API Oracle
# (pas de ~/.oci) — ils ne peuvent structurellement rien provisionner. Le risque n'est donc
# pas qu'un agent dépense, mais qu'une dérive passe inaperçue faute de relevé. 3 h de retard
# sur une cadence horaire = deux passages manqués, largement au-delà d'un simple hoquet.
bill = lire(etats / "billing.json")
horodatage = str(bill.get("last_run", ""))
if horodatage:
    try:
        vu = time.mktime(time.strptime(horodatage[:19], "%Y-%m-%dT%H:%M:%S")) - time.timezone
        retard_h = (maintenant - vu) / 3600.0
        if retard_h > 3:
            ecarts.append({
                "titre": "Le contrôle de facturation ne répond plus",
                "claim": f"Aucun relevé depuis {retard_h:.0f} h alors qu'il passe toutes les "
                         "heures. Le 0 € n'est donc plus surveillé — et une facture qui "
                         "naîtrait maintenant ne serait vue par personne.",
                "preuves": [{"source": "état de l'agent billing",
                             "metric": f"dernier passage {horodatage} · retard {retard_h:.1f} h"}],
            })
    except Exception:
        pass
else:
    ecarts.append({
        "titre": "Le contrôle de facturation n'a jamais tourné",
        "claim": "Aucun relevé de facturation n'existe. Le 0 € obligatoire n'est surveillé "
                 "par rien.",
        "preuves": [{"source": "état de l'agent billing", "metric": "aucun last_run"}],
    })

# ── Dépôt des écarts ─────────────────────────────────────────────────────────────────────
# Un identifiant STABLE par écart (jour + titre) : sans lui, un écart persistant redéposerait
# une proposition à chaque passage et noierait Décider en une nuit.
depose = 0
for e in ecarts:
    cle = re.sub(r"[^a-z0-9]+", "-", e["titre"].lower())[:48]
    pid = f"{time.strftime('%Y%m%d')}-controle-{cle}"
    f = inbox / f"{pid}.json"
    if f.exists():
        continue
    f.write_text(json.dumps({
        "schema": "merlin.proposal/1",
        "id": pid,
        "created": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "agent": "controle",
        "kind": "controle",
        "title": e["titre"],
        "claim": e["claim"],
        "evidence": e["preuves"],
    }, ensure_ascii=False), encoding="utf-8")
    depose += 1

if not ecarts:
    print("rien à signaler — les déclarations concordent avec les traces")
else:
    print(f"{len(ecarts)} écart(s) entre ce qui est déclaré et ce qui est vérifiable "
          f"· {depose} déposé(s) dans Décider")
PY

etape 2 2 "terminé"

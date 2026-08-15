#!/usr/bin/env python3
"""Le Séquenceur — il LIT où en est la chaîne de dev. Il n'exécute rien.

POURQUOI IL N'EXÉCUTE RIEN. Deux raisons, et la première suffirait :

  · Les agents sont déjà planifiés par cron et réveillés par événement (un push déclenche la
    CI). Un séquenceur qui les relancerait ferait tourner deux fois le même travail, ou se
    ferait refuser par le verrou d'agent-run — dans les deux cas l'état devient illisible.
  · La chaîne s'arrête DEUX FOIS sur Maxime : accepter une proposition, puis fusionner ce que
    le codeur a poussé. Une chaîne qui contient des gestes humains ne peut pas être
    « exécutée » ; elle ne peut qu'être observée.

Chaque étape est donc jugée sur une TRACE, jamais sur une déclaration — même principe que le
Contrôleur : le 15 août, trois composants se sont déclarés sains en étant cassés.

L'état est RECONSTRUIT à chaque passage à partir du monde, sans mémoire interne. Couper la VM
en pleine chaîne n'invente donc aucun faux progrès : au redémarrage on relit, et on retrouve
exactement le même barreau.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

PROPOSALS = Path.home() / ".cache" / "merlin-proposals"
ETATS = Path.home() / ".cache" / "merlin-agents" / "state"
BRANCHE_CODEUR = "auto/nightly"
# Au-delà, un dépôt dans inbox n'est plus « la chaîne en cours » mais du décor : sans cette
# borne, une proposition oubliée il y a trois semaines maintiendrait la chaîne éternellement
# à l'étape 2, et l'écran mentirait par obstination.
FENETRE_S = 72 * 3600


def _lire(p: Path):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _git(args: list[str], cwd: str) -> str:
    try:
        p = subprocess.run(["git", *args], cwd=cwd, capture_output=True,
                           text=True, timeout=20)
        return (p.stdout or "").strip()
    except Exception:
        return ""


def _plus_recent(dossier: Path) -> tuple[int, int]:
    """(horodatage du plus récent, nombre dans la fenêtre). (0, 0) si rien."""
    try:
        fichiers = [f for f in dossier.glob("*.json")]
    except Exception:
        return (0, 0)
    if not fichiers:
        return (0, 0)
    maintenant = time.time()
    recents = [f for f in fichiers if maintenant - f.stat().st_mtime < FENETRE_S]
    dernier = max((int(f.stat().st_mtime) for f in fichiers), default=0)
    return (dernier, len(recents))


def lire_chaine(tools_repo: str, game_dir: str, game_ref: str) -> dict:
    maintenant = int(time.time())
    etapes: list[dict] = []

    def ajouter(num, titre, qui, franchie, depuis, detail):
        etapes.append({"n": num, "titre": titre, "qui": qui,
                       "franchie": bool(franchie), "depuis": int(depuis or 0),
                       "detail": detail})

    # 1 — des idées ont-elles été proposées ?
    t_inbox, n_inbox = _plus_recent(PROPOSALS / "inbox")
    ajouter(1, "Des idées sont proposées", "machine", n_inbox > 0, t_inbox,
            f"{n_inbox} en attente dans Décider" if n_inbox else "aucune idée en attente")

    # 2 — Maxime a-t-il tranché ? On regarde les DEUX issues : écarter est une décision
    # autant qu'accepter, et ne compter que `accepted` ferait passer un refus pour une
    # absence de réponse — on lui reprocherait de ne pas avoir décidé alors qu'il l'a fait.
    t_acc, n_acc = _plus_recent(PROPOSALS / "accepted")
    t_rej, n_rej = _plus_recent(PROPOSALS / "rejected")
    t_dec, n_dec = max(t_acc, t_rej), n_acc + n_rej
    ajouter(2, "Tu décides", "toi", n_dec > 0, t_dec,
            f"{n_acc} acceptée(s), {n_rej} écartée(s)" if n_dec
            else ("en attente de toi" if n_inbox else "rien à trancher"))

    # 3 — le codeur a-t-il produit un commit ?
    tete_codeur = _git(["rev-parse", "--short", f"origin/{BRANCHE_CODEUR}"], game_dir)
    etat_codeur = _lire(ETATS / "coder-local.json")
    ajouter(3, "Le codeur applique", "machine", bool(tete_codeur),
            0, (f"{BRANCHE_CODEUR} @ {tete_codeur}" if tete_codeur
                else str(etat_codeur.get("summary", "rien poussé"))[:80]))

    # 4 — ce commit est-il entré dans la branche du jeu ?
    # `merge-base --is-ancestor` répond à la SEULE question qui compte : ce travail est-il
    # dans la branche jouée ? Comparer les têtes dirait « différent » dès qu'un autre commit
    # arrive par ailleurs, et signalerait une fusion manquante qui a bien eu lieu.
    fusionne = False
    if tete_codeur:
        try:
            fusionne = subprocess.run(
                ["git", "merge-base", "--is-ancestor",
                 f"origin/{BRANCHE_CODEUR}", f"origin/{game_ref}"],
                cwd=game_dir, capture_output=True, timeout=20).returncode == 0
        except Exception:
            fusionne = False
    ajouter(4, "Tu fusionnes", "toi", fusionne, 0,
            "intégré au jeu" if fusionne
            else ("en attente de toi" if tete_codeur else "rien à fusionner"))

    # 5 — la CI a-t-elle rendu son verdict ?
    ci = _lire(ETATS / "ci-commit.json")
    resume_ci = str(ci.get("summary", ""))
    ajouter(5, "La CI vérifie", "machine", "VERT" in resume_ci, 0,
            resume_ci[:90] or "aucun passage")

    # 6 — le contrôle a-t-il trouvé un écart ?
    ctrl = _lire(ETATS / "controle.json")
    resume_ctrl = str(ctrl.get("summary", ""))
    ajouter(6, "Le contrôle confirme", "machine",
            "rien à signaler" in resume_ctrl, 0, resume_ctrl[:90] or "aucun passage")

    # Où en est-on ? Le premier barreau NON franchi. Tous franchis → la chaîne est au repos,
    # ce qui n'est pas « terminé » : elle recommencera à la prochaine idée.
    courante = next((e for e in etapes if not e["franchie"]), None)
    if courante is None:
        etat, attente_s, resume = "au repos", 0, "chaîne complète — en attente d'une nouvelle idée"
    elif courante["n"] == 1 and not n_inbox and not tete_codeur:
        # DORMANTE, pas « en cours ». S'arrêter au premier barreau non franchi donnerait
        # « 1/6 — des idées sont proposées » alors que personne n'a rien proposé : on
        # afficherait un travail en cours là où il n'y a que le silence. C'est précisément
        # le genre de faux positif qui use la confiance dans un tableau de bord.
        etat, attente_s, resume = ("au repos", 0,
                                   "aucune chaîne en cours — en attente d'une idée")
        courante = None
    else:
        # Le temps d'attente se compte depuis la dernière chose qui a BOUGÉ en amont : c'est
        # ce délai-là qui doit alarmer. Une chaîne arrêtée depuis la veille l'est presque
        # toujours sur un tap oublié, jamais sur une panne.
        amont = max([e["depuis"] for e in etapes if e["n"] < courante["n"]] or [0])
        attente_s = maintenant - amont if amont else 0
        etat = "t'attend" if courante["qui"] == "toi" else "en cours"
        resume = f"{courante['n']}/6 — {courante['titre']} · {courante['detail']}"

    # Les barreaux APRÈS le barreau courant sont remis à « pas franchi », quoi qu'en disent
    # leurs traces. Sans ça, la CI verte d'un autre travail cochait l'étape 5 pendant que le
    # codeur en était encore à l'étape 3 : une coche qui ne parle pas du bon élément. Ce
    # lecteur juge l'état de chaque MAILLON, il ne suit pas encore un élément de bout en bout
    # (il faudrait relier proposition → commit → sha de CI) ; tant que ce n'est pas fait, il
    # doit se taire sur l'aval plutôt que de laisser croire qu'il en sait quelque chose.
    if courante:
        for e in etapes:
            if e["n"] > courante["n"]:
                e["franchie"] = False
                e["detail"] = "à venir"

    return {"id": "dev", "titre": "Boucle de dev autonome", "etapes": etapes,
            "etape_courante": courante["n"] if courante else 0,
            "etat": etat, "attente_s": attente_s, "resume": resume,
            "maj": maintenant}


if __name__ == "__main__":
    tools_repo, game_dir, game_ref = sys.argv[1], sys.argv[2], sys.argv[3]
    sortie = Path(sys.argv[4])
    d = lire_chaine(tools_repo, game_dir, game_ref)
    sortie.parent.mkdir(parents=True, exist_ok=True)
    tmp = sortie.with_suffix(".tmp")
    tmp.write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")
    tmp.replace(sortie)          # écriture atomique : le portail lit ce fichier en continu
    print(d["resume"] if d["etat"] != "au repos" else d["resume"])

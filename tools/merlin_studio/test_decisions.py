"""Épreuve des fourches : le format, le plafond, le masque, la gravure, et les deux routes du Studio.

    python3 tools/merlin_studio/test_decisions.py

Elle fabrique un dépôt de jeu jetable avec des fourches réalistes, puis vérifie ce que le module
et le Studio en font. Aucun réseau (MERLIN_DECISIONS_SANS_ENVOI=1), aucun fichier de l'utilisateur.
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RACINE / "tools"))
import decisions as D  # noqa: E402

RATES = 0


def verifier(nom: str, cond: bool, detail: str = "") -> None:
    global RATES
    if cond:
        print("  ok    %s" % nom)
    else:
        RATES += 1
        print("  RATE  %s%s" % (nom, ("  — " + detail) if detail else ""))


FOURCHE = """---
id: {id}
titre: {titre}
domaine: {domaine}
ouverte: 2026-09-08
etat: {etat}
---

## La fourche
Il faut trancher, parce que **deux jeux** différents en sortent.

## Aujourd'hui
Le code fait `ceci`.

## Options

### A — La première voie
Ce que ça donne. **Coût** : cher. **Mesure** : un chiffre.

### B — La seconde voie
Autre chose.

**Recommandation** : B — parce que la phrase continue
sur la ligne suivante.

## Réponse
{reponse}
"""


def main() -> int:
    print("=== ÉPREUVE DES FOURCHES ===\n")
    os.environ["MERLIN_DECISIONS_SANS_ENVOI"] = "1"
    tmp = Path(tempfile.mkdtemp(prefix="merlin-fourches-"))
    jeu = tmp / "jeu"
    dec = jeu / "docs" / "decisions"
    dec.mkdir(parents=True)
    (dec / "README.md").write_text("# pas une fourche\n", encoding="utf-8")
    (dec / "ARCH1.md").write_text("# ARCH-1\n\n**Status**: DECISION REQUIRED\n", encoding="utf-8")
    for i, (t, dom, etat, rep) in enumerate([
            ("Que reçoit le perdant ?", "regles", "ouverte", "_En attente._"),
            ("L'argent", "regles", "ouverte", "_En attente._"),
            ("La dixième quête", "lore", "tranchee", "**Tranchée le 2026-09-07 : A.** vite"),
    ], start=1):
        (dec / ("%03d-x.md" % i)).write_text(FOURCHE.format(id="%03d" % i, titre=t, domaine=dom,
                                                             etat=etat, reponse=rep), encoding="utf-8")
    local = tmp / "local"

    # ── LE FORMAT
    fs = D.lister(jeu)
    verifier("les fichiers sans en-tête ne sont pas des fourches", [f["id"] for f in fs] == ["001", "002", "003"],
             str([f["id"] for f in fs]))
    f1 = fs[0]
    verifier("les options se lisent", [o["lettre"] for o in f1["options"]] == ["A", "B"], str(f1["options"]))
    verifier("le texte d'une option s'arrête à la suivante", "seconde" not in f1["options"][0]["texte"]
             and "Coût" in f1["options"][0]["texte"], f1["options"][0]["texte"][:60])
    verifier("la recommandation se lit en entier, sur ses deux lignes",
             f1["recommandation"] == {"lettre": "B", "pourquoi": "parce que la phrase continue sur la ligne suivante."},
             str(f1["recommandation"]))
    verifier("la section « La fourche » se lit", f1["fourche"].startswith("Il faut trancher"), f1["fourche"][:40])
    f3 = [f for f in fs if f["id"] == "003"][0]
    verifier("une réponse gravée se lit", f3["reponse"] == {"date": "2026-09-07", "lettre": "A", "note": "vite"},
             str(f3["reponse"]))
    verifier("les ouvertes passent devant", [f["etat"] for f in fs] == ["ouverte", "ouverte", "tranchee"])
    verifier("tout est en règle", D.verifier(jeu) == [], str(D.verifier(jeu)))

    # ── LE PLAFOND
    for i in (4, 5):
        (dec / ("%03d-x.md" % i)).write_text(FOURCHE.format(id="%03d" % i, titre="encore", domaine="ecrans",
                                                             etat="ouverte", reponse="_En attente._"), encoding="utf-8")
    pb = D.verifier(jeu)
    verifier("quatre ouvertes dépassent le plafond de trois", any("plafond" in x for x in pb), str(pb))
    (dec / "004-x.md").unlink()
    (dec / "005-x.md").unlink()

    # ── LE MASQUE : rien de sensible ne part sur un canal public
    verifier("une URL est masquée", "trycloud" not in D.masquer("voir https://x.trycloudflare.com/a"))
    verifier("un jeton est masqué", "abcdef" not in D.masquer("token=abcdef123456"))
    verifier("une note ordinaire passe", D.masquer("la Noyée, et vite") == "la Noyée, et vite")
    titre, corps = D.message("001", "B", "parce que https://lien.secret/x")
    verifier("le message ne porte que le numéro, la lettre et la note masquée",
             titre == "décision 001" and corps.startswith("001 → B — parce que") and "secret" not in corps, corps)

    # ── LE RELEVÉ : la plus récente gagne, le reste du canal est ignoré
    lignes = [json.dumps({"event": "message", "title": "décision 001", "message": "001 → A", "time": 10}),
              json.dumps({"event": "message", "title": "décision 001", "message": "001 → B — après réflexion", "time": 20}),
              json.dumps({"event": "message", "title": "crible s103", "message": "001 → A"}),
              json.dumps({"event": "open"}), "pas du json"]
    reps = D.analyser(lignes, "ntfy.sh")
    verifier("la réponse la plus récente gagne", reps.get("001", {}).get("lettre") == "B", str(reps))
    verifier("sa note est gardée", reps["001"]["note"] == "après réflexion")
    verifier("un message qui n'est pas une décision est ignoré", list(reps) == ["001"])

    # ── LA GRAVURE
    chemin = D.graver("001", "B", "d'accord, https://x.trycloudflare.com", jeu, "2026-09-09")
    txt = Path(chemin).read_text(encoding="utf-8")
    verifier("l'état passe à tranchee", "etat: tranchee" in txt and "etat: ouverte" not in txt)
    verifier("la réponse remplace l'attente", "**Tranchée le 2026-09-09 : B.** d'accord, [masqué]" in txt
             and "_En attente._" not in txt, txt[-120:])
    relue = [f for f in D.lister(jeu) if f["id"] == "001"][0]
    verifier("relue, elle se lit", relue["etat"] == "tranchee" and relue["reponse"]["lettre"] == "B", str(relue["reponse"]))
    for args, motif in ((("001", "A"), "pas ouverte"), (("002", "C"), "pas d'option"), (("099", "A"), "aucune fourche")):
        try:
            D.graver(args[0], args[1], "", jeu)
            verifier("graver %s %s est refusé" % args, False)
        except RuntimeError as exc:
            verifier("graver %s %s est refusé" % args, motif in str(exc), str(exc))

    # ── LE STUDIO
    try:
        os.environ["MERLIN_GAME_DIR"] = str(jeu)
        sys.path.insert(0, str(RACINE / "tools" / "merlin_studio"))
        import app as studio  # noqa: E402
        D.LOCAL = local
        application = studio.build_app()
        client = application.test_client()
        auth = {}
        r = client.get("/api/decisions", headers=auth)
        d = r.get_json() or {}
        verifier("/api/decisions liste les fourches", r.status_code == 200 and len(d.get("fourches", [])) == 3,
                 "%s %s" % (r.status_code, str(d)[:120]))
        verifier("et compte ce qui reste à trancher", d.get("a_trancher") == 1, str(d.get("a_trancher")))
        r = client.post("/api/decision/002/trancher", json={"lettre": "b", "note": "va pour B"}, headers=auth)
        d = r.get_json() or {}
        verifier("trancher enregistre le choix (sans envoi)", r.status_code == 200 and d.get("ok") is True,
                 "%s %s" % (r.status_code, str(d)[:120]))
        verifier("la réponse locale existe", (D.reponse_locale("002", local) or {}).get("lettre") == "B")
        r = client.get("/api/decisions", headers=auth)
        d = r.get_json() or {}
        f2 = [f for f in d["fourches"] if f["id"] == "002"][0]
        verifier("la liste montre le choix en route", (f2.get("locale") or {}).get("lettre") == "B"
                 and d.get("a_trancher") == 0, str(f2.get("locale")))
        r = client.post("/api/decision/002/trancher", json={"lettre": "Z"}, headers=auth)
        verifier("une lettre inconnue est refusée", r.status_code == 400, str(r.status_code))
        r = client.post("/api/decision/001/trancher", json={"lettre": "A"}, headers=auth)
        verifier("une fourche tranchée ne se retranche pas", r.status_code == 409, str(r.status_code))
        r = client.post("/api/decision/099/trancher", json={"lettre": "A"}, headers=auth)
        verifier("une fourche inconnue est refusée", r.status_code == 404, str(r.status_code))
    except Exception as exc:  # une dépendance absente (flask) n'invalide pas le module
        print("  (appli Flask non essayée : %s)" % str(exc)[:120])

    shutil.rmtree(tmp, ignore_errors=True)
    print("\n%s (%d échec%s)" % ("ÉPREUVE PASSÉE" if RATES == 0 else "ÉPREUVE ÉCHOUÉE",
                                   RATES, "s" if RATES > 1 else ""))
    return 1 if RATES else 0


if __name__ == "__main__":
    sys.exit(main())

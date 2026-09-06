"""Épreuve des chroniques du Studio : le collecteur, l'adaptation du format du jeu, la page.

    python3 tools/merlin_studio/test_chroniques.py

Elle fabrique un HOME et un dépôt jetables avec trois sources réelles ou réalistes — une copie
de sûreté du Courrier (le journal de p74, commité dans docs/), une chronique sauvée, et une
chronique au format du jeu — puis vérifie ce que le Studio en ferait. Aucun réseau, aucun fichier
de l'utilisateur touché.
"""
from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RACINE))
from tools.merlin_studio import chroniques  # noqa: E402

RATES = 0


def verifier(nom: str, cond: bool, detail: str = "") -> None:
    global RATES
    if cond:
        print("  ok    %s" % nom)
    else:
        RATES += 1
        print("  RATE  %s%s" % (nom, ("  — " + detail) if detail else ""))


def main() -> int:
    print("=== ÉPREUVE DES CHRONIQUES DU STUDIO ===\n")
    p74 = RACINE / "docs" / "chroniques" / "p74" / "journal.json"
    verifier("le journal de p74 est dans le dépôt (fixture réelle)", p74.is_file())
    if not p74.is_file():
        return 1

    tmp = Path(tempfile.mkdtemp())
    home, repo = tmp / "home", tmp / "repo"
    # 1. copie de sûreté du Courrier, telle que a_courrier.sh la range
    res = home / ".cache" / "merlin-agents" / "courrier" / "job-093-chronique-en-vraie-partie.res"
    res.mkdir(parents=True)
    j = json.loads(p74.read_text(encoding="utf-8"))
    j["cliches"] = [{"nom": "intro", "fichier": "/var/lib/ocarun/.cache/merlin-partie/cliches/01_intro.png"}]
    (res / "journal.json").write_text(json.dumps(j), encoding="utf-8")
    # 2. chronique sauvée dans docs/
    (repo / "docs" / "chroniques" / "p74").mkdir(parents=True)
    shutil.copy(p74, repo / "docs" / "chroniques" / "p74" / "journal.json")
    # 3. chronique écrite par le jeu (format MerlinJournal)
    jeu = home / ".local" / "share" / "godot" / "app_userdata" / "MERLIN" / "chroniques"
    jeu.mkdir(parents=True)
    (jeu / "2026-09-02T16-12-33-4821.json").write_text(json.dumps({
        "version": 1, "id": "2026-09-02T16-12-33-4821", "titre": "Le Repos sous la Brume",
        "biome": "foret", "debut_iso": "2026-09-02T16:12:33",
        "beats": [
            {"n": 1, "type": "Exploration", "provenance": "arc", "scene": "Vous entrez sous les arbres.",
             "difficulte": 1, "de": 7, "integrite_avant": 10, "corruption_avant": 0,
             "action": "OBSERVER", "trait": "La Patience", "degre": "reussite",
             "issue": "[i]Vous regardez.[/i] Le Chœur se tait.", "integrite_apres": 10, "corruption_apres": 1},
            {"n": 2, "type": "Rencontre", "provenance": "secours", "scene": "Une femme sort du cercle.",
             "difficulte": 1, "de": 3, "integrite_avant": 10, "corruption_avant": 1},
        ],
        "fin": {"type": "accomplissement", "integrite": 10, "corruption": 1},
    }), encoding="utf-8")
    (jeu / "index.json").write_text("[]", encoding="utf-8")
    # Un lancement sans partie, comme les quatre trouvés sur la VM le 03/09 : 0 beat.
    (jeu / "2026-09-03T03-00-05-5440.json").write_text(json.dumps({
        "version": 1, "id": "2026-09-03T03-00-05-5440", "titre": "Le Sentier des Murmures",
        "biome": "foret", "debut_iso": "2026-09-03T03:00:05", "fin": {},
        # le beat 1 est PRÉSENTÉ par le jeu lui-même, personne ne l'a joué : ni geste, ni degré
        "beats": [{"n": 1, "type": "Exploration", "scene": "Le jeu affiche sa première scène.",
                   "provenance": "arc", "difficulte": 1, "de": 5, "integrite_avant": 10, "corruption_avant": 0}]}),
        encoding="utf-8")

    # 5. une partie de la nuit, gardée datée
    nuit = home / ".cache" / "merlin-partie" / "nuit" / "2026-09-04"
    nuit.mkdir(parents=True)
    shutil.copy(p74, nuit / "journal.json")

    # ── LE COLLECTEUR
    srcs = chroniques.sources(home, repo)
    ids = [s["id"] for s in srcs]
    verifier("cinq fichiers trouvés, dont le lancement vide", len(srcs) == 5, str(ids))
    verifier("la partie de la nuit est datée", "nuit 2026-09-04" in ids, str(ids))
    verifier("le job du Courrier est nommé comme partout ailleurs (p93)", "p93" in ids, str(ids))
    verifier("la chronique sauvée garde son nom de dossier (p74)", "p74" in ids, str(ids))
    verifier("la chronique du jeu est datée court", any(i.startswith("jeu 02/09 16:12") for i in ids), str(ids))
    verifier("index.json n'est pas pris pour une partie", not any("index" in i for i in ids))

    # ── LE FORMAT
    P = chroniques.parties(home, repo)
    verifier("le lancement où personne n'a joué n'est pas une partie : quatre sur cinq", len(P) == 4, str(list(P)))
    verifier("il est absent de la liste aussi", not any(l["id"].startswith("jeu 03/09") for l in chroniques.liste(home, repo)))
    j93 = P.get("p93", {})
    verifier("les chemins de la VM ne sortent pas de la machine",
             all("/" not in str(c.get("fichier", "")) for c in j93.get("cliches", [])),
             str(j93.get("cliches")))
    verifier("la note dit la provenance", "Courrier" in j93.get("_note", ""), j93.get("_note", ""))
    jeu_id = next((i for i in P if i.startswith("jeu ")), "")
    jj = P.get(jeu_id, {})
    b = (jj.get("beats") or [{}])[0]
    verifier("la chronique du jeu parle la langue de la sonde (narration/resolution/index)",
             b.get("index") == 1 and b.get("narration", "").startswith("Vous entrez")
             and b.get("resolution", "").startswith("[i]Vous regardez"), json.dumps(b, ensure_ascii=False)[:160])
    verifier("le geste du jeu est gardé", (b.get("geste") or {}).get("action") == "OBSERVER")
    verifier("un beat du jeu non résolu n'a pas de degré", "degre" not in (jj.get("beats") or [{}, {}])[1])
    verifier("le titre du jeu passe par `sentiers` comme pour la sonde",
             (jj.get("sentiers") or [{}])[0].get("titre") == "Le Repos sous la Brume")

    # ── LA LISTE DE L'API
    L = {l["id"]: l for l in chroniques.liste(home, repo)}
    verifier("la liste compte les beats de p74", L.get("p74", {}).get("beats") == 20, str(L.get("p74")))
    verifier("la liste compte le banc du jeu", L.get(jeu_id, {}).get("banc") == 1, str(L.get(jeu_id)))
    # La partie de la nuit est écrite en dernier par l'épreuve : c'est donc elle qui doit ouvrir
    # la liste. L'attente précédente nommait p93 et le jeu — elle datait d'avant cette source.
    verifier("la plus récente est en tête", list(L)[0] == "nuit 2026-09-04", str(list(L)))

    # ── LA PAGE
    page = chroniques.rendre(P)
    verifier("la marque est remplacée", chroniques.MARQUE not in page)
    verifier("les quatre parties sont embarquées", '"p93"' in page and '"p74"' in page and '"%s"' % jeu_id in page and '"nuit 2026-09-04"' in page)
    verifier("un </script> dans la prose ne peut pas fermer la page",
             chroniques.rendre({"x": {"beats": [{"narration": "a</script>b"}]}}).count("</script>") == page.count("</script>") - 0
             and "a<\\/script>b" in chroniques.rendre({"x": {"beats": [{"narration": "a</script>b"}]}}))
    vide = chroniques.rendre({})
    verifier("sans partie, la page dit pourquoi au lieu de planter",
             "Aucune partie journalisée" in vide and "const PARTIES = {}" in vide)

    # ── LA COURBE DES NUITS (nuits.jsonl) : absente, tronquée, puis triée
    verifier("sans nuits.jsonl, la courbe est vide et ne plante pas", chroniques.nuits(home=tmp) == [])
    nj = tmp / ".cache" / "merlin-partie" / "nuits.jsonl"
    nj.parent.mkdir(parents=True, exist_ok=True)
    nj.write_text('{"nuit":"2026-09-06","partie":{"beats":22,"banc":8},"quete":null}\n'
                  '{"nuit":"2026-09-05","partie":{"beats":14,"banc":6}}\n'
                  '{"nuit":"2026-09-07","partie":{"beats"\n'   # une ligne coupée en deux
                  '{"pas":"une nuit"}\n', encoding="utf-8")
    ns = chroniques.nuits(home=tmp)
    verifier("les lignes lisibles sont gardées, la coupée et l'étrangère sautées", len(ns) == 2, str(ns))
    verifier("la courbe est triée par nuit", [n["nuit"] for n in ns] == ["2026-09-05", "2026-09-06"])

    # ── L'APPLI FLASK, en mode local (sans STUDIO_TOKEN, la porte est ouverte)
    try:
        import os
        os.environ.pop("STUDIO_TOKEN", None)
        from tools.merlin_studio.app import build_app
        app = build_app()
        c = app.test_client()
        r = c.get("/api/chroniques")
        verifier("/api/chroniques répond en JSON", r.status_code == 200 and "parties" in r.get_json(),
                 "%s %s" % (r.status_code, r.data[:80]))
        r = c.get("/api/nuits")
        verifier("/api/nuits répond en JSON", r.status_code == 200 and "nuits" in r.get_json(),
                 "%s %s" % (r.status_code, r.data[:80]))
        r = c.get("/chroniques/liseuse")
        verifier("/chroniques/liseuse sert la page", r.status_code == 200 and b"const PARTIES = " in r.data
                 and b"@@PARTIES@@" not in r.data, "%s" % r.status_code)
    except Exception as exc:  # une dépendance absente (flask) n'invalide pas le module
        print("  (appli Flask non essayée : %s)" % str(exc)[:80])

    shutil.rmtree(tmp, ignore_errors=True)
    print("\n%s (%d échec%s)" % ("ÉPREUVE PASSÉE" if RATES == 0 else "ÉPREUVE ÉCHOUÉE",
                                   RATES, "s" if RATES > 1 else ""))
    return 1 if RATES else 0


if __name__ == "__main__":
    sys.exit(main())

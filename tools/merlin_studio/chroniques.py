"""Les chroniques des parties jouées par la machine, données à lire dans le Studio.

    python3 -m tools.merlin_studio.chroniques                 # liste ce qui serait montré
    python3 -m tools.merlin_studio.chroniques --out page.html  # la page normée, autonome

POURQUOI CE MODULE. La liseuse (templates/liseuse.html) est la page normée qui permet de parcourir
une partie beat par beat : l'épine des beats, l'attente du moteur, le fil repris, le canon nommé,
le banc. Jusqu'ici elle était CONSTRUITE À LA MAIN pour chaque partie, avec les journaux collés
dedans — donc jamais à jour, et jamais sur la VM où les parties se jouent. Ici le Studio la remplit
lui-même avec tout ce que la machine a joué, au moment où on l'ouvre.

D'OÙ VIENNENT LES PARTIES, dans l'ordre où on les cherche :
  1. les copies de sûreté du Courrier   ~/.cache/merlin-agents/courrier/<job>.res/journal.json
     — c'est là que chaque partie témoin survit sur la VM, ntfy purgeant ses pièces jointes en
     quelques heures (vécu sur p74).
  2. les résultats commités dans le dépôt   infra/oracle/agents/courrier/resultats/<job>/
  3. les chroniques sauvées à la main       docs/chroniques/<nom>/journal.json
  4. les chroniques ÉCRITES PAR LE JEU      <user://>/chroniques/*.json — un autre format, celui
     de MerlinJournal, adapté ici pour se lire dans la même page. Deux témoins, une liseuse.

Un identifiant par partie : « p93 » pour job-093, le nom du dossier pour docs/, « jeu 02/09 16:12 »
pour une chronique du jeu. Si la même partie existe à deux endroits, la première source gagne.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
GABARIT = Path(__file__).resolve().parent / "templates" / "liseuse.html"
MARQUE = "/*@@PARTIES@@*/{}"


# ── où chercher ─────────────────────────────────────────────────────────────────────────────────

def sources(home: Path | None = None, repo: Path | None = None) -> list[dict]:
    """Chaque partie trouvée : {id, chemin, provenance, mtime}. Dédoublonnée par identifiant,
    la plus récente en premier."""
    home = home or Path.home()
    repo = repo or RACINE
    vues: dict[str, dict] = {}

    def garder(ident: str, chemin: Path, provenance: str) -> None:
        if ident in vues or not chemin.is_file():
            return
        vues[ident] = {"id": ident, "chemin": chemin, "provenance": provenance,
                       "mtime": chemin.stat().st_mtime}

    for p in sorted((home / ".cache" / "merlin-agents" / "courrier").glob("*.res/journal.json")):
        garder(_etiquette(p.parent.name), p, "courrier")
    for p in sorted((repo / "infra" / "oracle" / "agents" / "courrier" / "resultats").glob("*/journal.json")):
        garder(_etiquette(p.parent.name), p, "resultats")
    for p in sorted((repo / "docs" / "chroniques").glob("*/journal.json")):
        garder(p.parent.name, p, "docs")
    for p in sorted(_dossier_jeu(home).glob("*.json")):
        if p.name == "index.json":
            continue
        garder("jeu " + _date_courte(p.stem), p, "jeu")
    return sorted(vues.values(), key=lambda s: -s["mtime"])


def _etiquette(nom_job: str) -> str:
    """« job-093-chronique-en-vraie-partie.res » → « p93 » : c'est ainsi que les parties sont
    nommées partout ailleurs (verdicts, ntfy, mémoire)."""
    m = re.match(r"job-0*(\d+)", nom_job)
    return ("p%s" % m.group(1)) if m else nom_job.removesuffix(".res")


def _dossier_jeu(home: Path) -> Path:
    # user:// de Godot, hors sandbox. Le jeu tourne parfois sous unshare avec un autre HOME :
    # on lit ce qui est visible d'ici, et rien d'autre.
    return home / ".local" / "share" / "godot" / "app_userdata" / "MERLIN" / "chroniques"


def _date_courte(stem: str) -> str:
    # « 2026-09-02T16-12-33-4821 » → « 02/09 16:12 »
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})", stem)
    return "%s/%s %s:%s" % (m.group(3), m.group(2), m.group(4), m.group(5)) if m else stem


# ── lire et mettre au format de la liseuse ──────────────────────────────────────────────────────

def charger(src: dict) -> dict | None:
    try:
        j = json.loads(Path(src["chemin"]).read_text(encoding="utf-8"))
    except Exception:
        return None
    if not isinstance(j, dict):
        return None
    if src["provenance"] == "jeu" or ("version" in j and "beats" in j and "squelette" not in j):
        j = adapter_jeu(j)
    if not isinstance(j.get("beats"), list):
        return None
    # Les captures pointent des chemins absolus de la VM : la liseuse ne les affiche pas, et un
    # chemin de machine n'a rien à faire dans une page servie. On ne garde que le nom.
    for c in j.get("cliches") or []:
        if isinstance(c, dict) and c.get("fichier"):
            c["fichier"] = Path(str(c["fichier"])).name
    quand = datetime.fromtimestamp(src["mtime"]).strftime("%d/%m %H:%M")
    j["_note"] = "%s · %s" % (_provenance_en_clair(src["provenance"]), quand)
    return j


def adapter_jeu(c: dict) -> dict:
    """Une chronique de MerlinJournal (scene/issue/n) rendue dans les mots de la sonde
    (narration/resolution/index) : même liseuse, aucun second gabarit à maintenir."""
    beats = []
    for b in c.get("beats") or []:
        if not isinstance(b, dict):
            continue
        d = {
            "index": int(b.get("n", len(beats) + 1)),
            "type": b.get("type", ""),
            "narration": b.get("scene", ""),
            "provenance": b.get("provenance", ""),
            "difficulte": b.get("difficulte", 0), "de": b.get("de", 0),
            "integrite_avant": b.get("integrite_avant"), "corruption_avant": b.get("corruption_avant"),
        }
        if "degre" in b:
            d["degre"] = b.get("degre", "")
            d["resolution"] = b.get("issue", "")
            d["integrite_apres"] = b.get("integrite_apres")
            d["corruption_apres"] = b.get("corruption_apres")
        if b.get("action") or b.get("trait"):
            d["geste"] = {"action": b.get("action", ""), "trait": b.get("trait", "")}
        beats.append(d)
    fin = c.get("fin") or {}
    return {
        "beats": beats,
        "sentiers": [{"titre": c.get("titre", "") or "Traversée sans titre"}], "pick": 0,
        "biome": c.get("biome", ""),
        "fin": {"beats_joues": len(beats), "type": fin.get("type", ""),
                "integrite": fin.get("integrite"), "corruption": fin.get("corruption"),
                "resume": fin.get("resume", ""), "faits_marquants": fin.get("faits_marquants", []),
                "pnj_rencontres": fin.get("pnj_rencontres", [])},
        "cliches": [], "incidents": [], "etals": [],
        "_source": "MerlinJournal v%s" % c.get("version", "?"),
    }


def _provenance_en_clair(p: str) -> str:
    return {"courrier": "partie témoin (Courrier)", "resultats": "partie témoin (dépôt)",
            "docs": "chronique sauvée", "jeu": "écrite par le jeu"}.get(p, p)


def parties(home: Path | None = None, repo: Path | None = None) -> dict[str, dict]:
    out: dict[str, dict] = {}
    for src in sources(home, repo):
        j = charger(src)
        if j is not None:
            out[src["id"]] = j
    return out


def liste(home: Path | None = None, repo: Path | None = None) -> list[dict]:
    """Ce que l'API rend pour la barre de l'onglet : une ligne par partie, sans la prose."""
    out = []
    for src in sources(home, repo):
        j = charger(src)
        if j is None:
            continue
        beats = [b for b in j.get("beats", []) if isinstance(b, dict)]
        sentier = (j.get("sentiers") or [{}])[j.get("pick") or 0] if j.get("sentiers") else {}
        out.append({
            "id": src["id"], "provenance": src["provenance"],
            "quand": datetime.fromtimestamp(src["mtime"]).strftime("%Y-%m-%d %H:%M"),
            "titre": (sentier.get("titre") or sentier.get("title")
                      or (j.get("squelette") or {}).get("titre") or ""),
            "beats": len(beats),
            "banc": sum(1 for b in beats if b.get("provenance") == "secours" or b.get("secours")),
            "fin": (j.get("fin") or {}).get("type", ""),
        })
    return out


# ── la page ─────────────────────────────────────────────────────────────────────────────────────

def rendre(parties_: dict[str, dict]) -> str:
    gabarit = GABARIT.read_text(encoding="utf-8")
    if MARQUE not in gabarit:
        raise RuntimeError("le gabarit de la liseuse n'a pas sa marque %r" % MARQUE)
    # `</script>` dans une chaîne JSON fermerait le script de la page : on l'échappe. JSON
    # accepte « <\/ » comme « </ », le navigateur non.
    donnees = json.dumps(parties_, ensure_ascii=False).replace("</", "<\\/")
    return gabarit.replace(MARQUE, donnees, 1)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", help="écrire la page normée (HTML autonome) à ce chemin")
    ap.add_argument("--home", type=Path, help="HOME à explorer (défaut : le vôtre)")
    ap.add_argument("--repo", type=Path, help="dépôt à explorer (défaut : celui-ci)")
    a = ap.parse_args(argv)
    lst = liste(a.home, a.repo)
    for l in lst:
        print("  %-16s %-22s %2d beats · %d au banc · %-16s %s" % (
            l["id"], l["provenance"], l["beats"], l["banc"], l["fin"] or "—", l["titre"][:40]))
    print("%d partie(s)" % len(lst))
    if a.out:
        page = rendre(parties(a.home, a.repo))
        Path(a.out).write_text(page, encoding="utf-8")
        print("écrit : %s (%d octets)" % (a.out, len(page)))
    return 0


if __name__ == "__main__":
    sys.exit(main())

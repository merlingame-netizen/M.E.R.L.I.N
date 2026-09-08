#!/usr/bin/env python3
"""Les fourches — ce que seul Maxime tranche — et leur aller-retour entre le dépôt et le Studio.

    python3 tools/decisions.py lister   [--jeu DIR]          les fourches, ouvertes d'abord
    python3 tools/decisions.py verifier [--jeu DIR]          le format et le plafond (trois ouvertes)
    python3 tools/decisions.py relever  [--graver] [--jeu DIR]   les réponses publiées sur le canal du Courrier
    python3 tools/decisions.py graver   ID LETTRE [--note …] [--jeu DIR]
    python3 tools/decisions.py publier  ID LETTRE [--note …]     ce que fait le Studio quand Maxime tranche
    python3 tools/decisions.py courrier [--depuis 2d]            les derniers messages du canal, pour une session

POURQUOI CE FICHIER. Les fourches vivent dans le dépôt du jeu (docs/decisions/NNN-titre.md) : c'est
là que les sessions de l'atelier les lisent et les écrivent. Maxime, lui, tranche dans le Studio,
sur la VM — et la VM ne pousse pas sur GitHub (ses clones sont en lecture seule). Le retour prend
donc le seul chemin qui existe déjà : le canal ntfy du Courrier. Le Studio y publie « 003 → B », la
session suivante le relève et le grave dans le fichier. Ce module est partagé par les deux bouts.

LE CANAL EST PUBLIC. On n'y écrit qu'une lettre, un numéro et une note courte passée au masque
des formes sensibles ; et une réponse relevée ne vaut que si elle nomme une option qui existe dans
le fichier — une réponse inventée par un tiers ne peut choisir qu'entre les options de Maxime.

Stdlib seulement : le Studio tourne avec ce que la VM a.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.request
from pathlib import Path

ICI = Path(__file__).resolve()
OUTILLAGE = ICI.parents[1]
DOSSIER = "docs/decisions"
PLAFOND = 3            # fourches ouvertes à la fois — décision du 08/09
LETTRES = "ABCD"
MIROIRS = ("https://ntfy.sh", "https://ntfy.adminforge.de", "https://ntfy.envs.net")
LOCAL = Path.home() / ".cache" / "merlin-decisions"

# Les mêmes formes que le Courrier (a_courrier.sh, FORME_SENSIBLE), plus les URL : une note de
# Maxime ne doit pas pouvoir faire sortir un identifiant sur un sujet public.
_SENSIBLE = re.compile(
    r"(\?|&|^|\s)(cle|clef|token|key|secret|password|pass)=[A-Za-z0-9_-]{6,}"
    r"|Bearer\s+[A-Za-z0-9._-]{12,}|BEGIN\s+[A-Z ]*PRIVATE\s+KEY|ocid1\.[a-z]+\."
    r"|ssh-(rsa|ed25519)\s|AKIA[0-9A-Z]{16}|[a-z0-9-]+\.trycloud|https?://\S+", re.I)


# ── le sujet du Courrier, lu à sa source ────────────────────────────────────────────────────

def sujet() -> str:
    """Le sujet ntfy du Courrier, lu dans a_courrier.sh pour n'exister qu'à un endroit."""
    try:
        src = (OUTILLAGE / "infra/oracle/agents/a_courrier.sh").read_text(encoding="utf-8")
        m = re.search(r'^NTFY_CR="([A-Za-z0-9_-]+)"', src, re.M)
        if m:
            return m.group(1)
    except OSError:
        pass
    return "merlin-courrier-vX9k2Qf7Lw3s"


# ── où est le jeu ───────────────────────────────────────────────────────────────────────────

def dossier_du_jeu(home: Path | None = None) -> Path | None:
    """Le dépôt du jeu : variable, fichier d'environnement de la VM, clone à côté, ou rien."""
    home = home or Path.home()
    candidats = []
    if os.environ.get("MERLIN_GAME_DIR"):
        candidats.append(Path(os.environ["MERLIN_GAME_DIR"]))
    try:
        for line in (home / ".config" / "merlin-game.env").read_text(encoding="utf-8").splitlines():
            k, _, v = line.partition("=")
            if k.strip() in ("GAME_DIR", "GAME_REPO_DIR") and v.strip():
                candidats.append(Path(os.path.expandvars(v.strip().strip('"'))))
    except OSError:
        pass
    candidats += [home / "workspace" / "merlin-game", OUTILLAGE.parent / "merlin-jeu"]
    for c in candidats:
        if (c / DOSSIER).is_dir():
            return c
    return None


# ── lire une fourche ────────────────────────────────────────────────────────────────────────

_ENTETE = re.compile(r"\A---\n(.*?)\n---\n", re.S)
_OPTION = re.compile(r"^### ([A-D]) — (.+?)\s*$", re.M)
_RECO = re.compile(r"^\*\*Recommandation\*\*\s*:\s*([A-D])\b(.*)$", re.M)
_REPONSE = re.compile(r"^\*\*Tranchée le (\d{4}-\d{2}-\d{2}) : ([A-D])\.\*\*\s*(.*)$", re.M)


def lire(chemin: Path) -> dict | None:
    """Une fourche, ou None si le fichier n'en est pas une (README, anciennes décisions)."""
    try:
        txt = chemin.read_text(encoding="utf-8")
    except OSError:
        return None
    m = _ENTETE.match(txt)
    if not m:
        return None
    meta = {}
    for line in m.group(1).splitlines():
        k, _, v = line.partition(":")
        if k.strip():
            meta[k.strip()] = v.strip()
    if "id" not in meta or "titre" not in meta:
        return None
    corps = txt[m.end():]
    sections = _sections(corps)
    options = []
    for om in _OPTION.finditer(corps):
        debut = om.end()
        suite = corps[debut:]
        fin = len(suite)
        for stop in (re.search(r"^### ", suite, re.M), re.search(r"^\*\*Recommandation\*\*", suite, re.M),
                     re.search(r"^## ", suite, re.M)):
            if stop:
                fin = min(fin, stop.start())
        options.append({"lettre": om.group(1), "titre": om.group(2).strip(),
                        "texte": suite[:fin].strip()})
    reco = _RECO.search(corps)
    # LA RECOMMANDATION TIENT SUR UN PARAGRAPHE, pas sur une ligne : le fichier est rédigé à 100
    # colonnes et une phrase coupée à la première ligne disait le contraire de la seconde.
    pourquoi = ""
    if reco:
        para = corps[reco.start():].split("\n\n", 1)[0]
        pourquoi = re.sub(r"^\*\*Recommandation\*\*\s*:\s*[A-D]\b", "", para).strip(" —-:\n")
        pourquoi = " ".join(pourquoi.split())
    rep = _REPONSE.search(corps)
    return {
        "id": meta["id"], "titre": meta["titre"], "domaine": meta.get("domaine", ""),
        "ouverte": meta.get("ouverte", ""), "etat": meta.get("etat", "ouverte"),
        "fourche": sections.get("La fourche", ""), "aujourdhui": sections.get("Aujourd'hui", ""),
        "options": options,
        "recommandation": ({"lettre": reco.group(1), "pourquoi": pourquoi} if reco else None),
        "reponse": ({"date": rep.group(1), "lettre": rep.group(2), "note": rep.group(3).strip()}
                    if rep else None),
        "fichier": chemin.name,
    }


def _sections(corps: str) -> dict:
    out, titre, buf = {}, None, []
    for line in corps.splitlines():
        if line.startswith("## "):
            if titre is not None:
                out[titre] = "\n".join(buf).strip()
            titre, buf = line[3:].strip(), []
        elif titre is not None:
            buf.append(line)
    if titre is not None:
        out[titre] = "\n".join(buf).strip()
    return out


def lister(jeu: Path | None = None) -> list[dict]:
    """Toutes les fourches, les ouvertes d'abord, puis par numéro."""
    jeu = jeu or dossier_du_jeu()
    if jeu is None:
        return []
    out = []
    for f in sorted((jeu / DOSSIER).glob("*.md")):
        d = lire(f)
        if d:
            out.append(d)
    rang = {"ouverte": 0, "tranchee": 1, "perimee": 2}
    out.sort(key=lambda d: (rang.get(d["etat"], 3), d["id"]))
    return out


def verifier(jeu: Path | None = None) -> list[str]:
    """Ce qui cloche : format, doublons, plafond. Vide quand tout va."""
    fourches = lister(jeu)
    pb = []
    vus = set()
    for d in fourches:
        if d["id"] in vus:
            pb.append("%s : identifiant %s en double" % (d["fichier"], d["id"]))
        vus.add(d["id"])
        if d["domaine"] not in ("regles", "lore", "ecrans", "outillage"):
            pb.append("%s : domaine inconnu « %s »" % (d["fichier"], d["domaine"]))
        if d["etat"] not in ("ouverte", "tranchee", "perimee"):
            pb.append("%s : état inconnu « %s »" % (d["fichier"], d["etat"]))
        if not 2 <= len(d["options"]) <= 4:
            pb.append("%s : %d option(s), il en faut 2 à 4" % (d["fichier"], len(d["options"])))
        if d["etat"] == "ouverte" and not d["fourche"]:
            pb.append("%s : la section « La fourche » est vide" % d["fichier"])
        if d["etat"] == "tranchee" and not d["reponse"]:
            pb.append("%s : tranchée sans réponse gravée" % d["fichier"])
        if d["etat"] == "ouverte" and d["reponse"]:
            pb.append("%s : une réponse est gravée mais l'état dit ouverte" % d["fichier"])
    ouvertes = [d for d in fourches if d["etat"] == "ouverte"]
    if len(ouvertes) > PLAFOND:
        pb.append("%d fourches ouvertes, le plafond est %d : on n'en ouvre pas d'autre, on tranche"
                  % (len(ouvertes), PLAFOND))
    return pb


# ── la réponse de Maxime, côté Studio ───────────────────────────────────────────────────────

def masquer(texte: str) -> str:
    return _SENSIBLE.sub(lambda m: (m.group(1) if m.lastindex and m.group(1) in ("?", "&", "", " ")
                                    else "") + "[masqué]", texte or "")


def reponse_locale(id_: str, base: Path | None = None) -> dict | None:
    f = (base or LOCAL) / ("%s.json" % id_)
    try:
        return json.loads(f.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def enregistrer_localement(id_: str, lettre: str, note: str, via: str,
                           base: Path | None = None) -> dict:
    base = base or LOCAL
    base.mkdir(parents=True, exist_ok=True)
    rec = {"id": id_, "lettre": lettre, "note": note, "via": via,
           "date": time.strftime("%Y-%m-%d"), "quand": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    (base / ("%s.json" % id_)).write_text(json.dumps(rec, ensure_ascii=False, indent=1), encoding="utf-8")
    return rec


def message(id_: str, lettre: str, note: str = "") -> tuple[str, str]:
    """(titre, corps) tels qu'ils partent sur le canal : « décision 003 » / « 003 → B — note »."""
    corps = "%s → %s" % (id_, lettre)
    note = masquer(note.replace("\n", " ").strip())[:300]
    if note:
        corps += " — " + note
    return "décision %s" % id_, corps


def publier(id_: str, lettre: str, note: str = "", miroirs: tuple = MIROIRS) -> str:
    """Publie sur le premier miroir qui accepte ; rend son nom, ou lève."""
    titre, corps = message(id_, lettre, note)
    derniere = None
    for base in miroirs:
        try:
            req = urllib.request.Request("%s/%s" % (base, sujet()), data=corps.encode("utf-8"),
                                         headers={"Title": titre.encode("utf-8").decode("latin-1"),
                                                  "Content-Type": "text/plain; charset=utf-8"},
                                         method="POST")
            with urllib.request.urlopen(req, timeout=15) as r:
                if 200 <= r.status < 300:
                    return base.split("//", 1)[1]
        except Exception as exc:  # le miroir suivant
            derniere = exc
    raise RuntimeError("aucun miroir n'a accepté la décision (%s)" % derniere)


# ── relever, côté session ───────────────────────────────────────────────────────────────────

_CORPS = re.compile(r"^\s*(\d{3})\s*(?:→|->)\s*([A-D])\b\s*(?:—|-)?\s*(.*)$", re.S)


def analyser(lignes: list[str], via: str = "") -> dict:
    """Les réponses contenues dans des lignes JSON ntfy : {id: {lettre, note, quand, via}} ; la plus
    récente par fourche gagne."""
    out = {}
    for l in lignes:
        try:
            m = json.loads(l)
        except ValueError:
            continue
        if not isinstance(m, dict) or m.get("event", "message") != "message":
            continue
        if not str(m.get("title", "")).lower().startswith("décision"):
            continue
        c = _CORPS.match(str(m.get("message", "")))
        if not c:
            continue
        quand = int(m.get("time", 0) or 0)
        id_ = c.group(1)
        if id_ not in out or quand >= out[id_]["quand"]:
            out[id_] = {"lettre": c.group(2), "note": c.group(3).strip()[:300], "quand": quand,
                        "via": via or str(m.get("topic", ""))}
    return out


def relever(depuis: str = "30d", miroirs: tuple = MIROIRS) -> dict:
    """Interroge les trois miroirs (une réponse peut être partie sur n'importe lequel)."""
    out = {}
    for base in miroirs:
        try:
            url = "%s/%s/json?poll=1&since=%s" % (base, sujet(), depuis)
            with urllib.request.urlopen(url, timeout=20) as r:
                lignes = r.read().decode("utf-8", "replace").splitlines()
        except Exception:
            continue
        for id_, rep in analyser(lignes, base.split("//", 1)[1]).items():
            if id_ not in out or rep["quand"] >= out[id_]["quand"]:
                out[id_] = rep
    return out


def courrier(depuis: str = "2d", miroirs: tuple = MIROIRS, limite: int = 40) -> list[dict]:
    """Les derniers messages du canal (titre, heure, corps court, miroir), pour qu'une session lise
    la nuit sans connaître ntfy. Les pièces jointes sont nommées, pas téléchargées."""
    vus, out = set(), []
    for base in miroirs:
        try:
            url = "%s/%s/json?poll=1&since=%s" % (base, sujet(), depuis)
            with urllib.request.urlopen(url, timeout=20) as r:
                lignes = r.read().decode("utf-8", "replace").splitlines()
        except Exception:
            continue
        for l in lignes:
            try:
                m = json.loads(l)
            except ValueError:
                continue
            if m.get("event", "message") != "message" or m.get("id") in vus:
                continue
            vus.add(m.get("id"))
            att = m.get("attachment") or {}
            out.append({"quand": time.strftime("%m-%d %H:%M", time.gmtime(int(m.get("time", 0) or 0))),
                        "titre": str(m.get("title", "")), "corps": str(m.get("message", ""))[:400],
                        "piece": str(att.get("name", "")), "via": base.split("//", 1)[1]})
    out.sort(key=lambda x: x["quand"])
    return out[-limite:]


# ── graver, dans le fichier ─────────────────────────────────────────────────────────────────

def graver(id_: str, lettre: str, note: str = "", jeu: Path | None = None,
           date: str | None = None) -> str:
    """Écrit la réponse sous « Réponse » et passe l'état à tranchee. Rend le chemin, ou lève si la
    fourche n'existe pas, n'est pas ouverte, ou si la lettre n'est pas une option."""
    jeu = jeu or dossier_du_jeu()
    if jeu is None:
        raise RuntimeError("dépôt du jeu introuvable (MERLIN_GAME_DIR, ou --jeu)")
    cible = None
    for f in (jeu / DOSSIER).glob("*.md"):
        d = lire(f)
        if d and d["id"] == id_:
            cible = (f, d)
            break
    if cible is None:
        raise RuntimeError("aucune fourche %s" % id_)
    f, d = cible
    if d["etat"] != "ouverte":
        raise RuntimeError("la fourche %s est %s, pas ouverte" % (id_, d["etat"]))
    if lettre not in [o["lettre"] for o in d["options"]]:
        raise RuntimeError("la fourche %s n'a pas d'option %s (elle a %s)"
                           % (id_, lettre, ", ".join(o["lettre"] for o in d["options"])))
    txt = f.read_text(encoding="utf-8")
    date = date or time.strftime("%Y-%m-%d")
    ligne = "**Tranchée le %s : %s.** %s" % (date, lettre, masquer(note).strip())
    txt, n = re.subn(r"^etat:\s*ouverte\s*$", "etat: tranchee", txt, count=1, flags=re.M)
    if n != 1:
        raise RuntimeError("%s : ligne « etat: ouverte » introuvable" % f.name)
    if re.search(r"^_En attente\._\s*$", txt, re.M):
        txt = re.sub(r"^_En attente\._\s*$", ligne.rstrip(), txt, count=1, flags=re.M)
    elif re.search(r"^## Réponse\s*$", txt, re.M):
        txt = re.sub(r"^## Réponse\s*$", "## Réponse\n" + ligne.rstrip(), txt, count=1, flags=re.M)
    else:
        txt = txt.rstrip("\n") + "\n\n## Réponse\n" + ligne.rstrip() + "\n"
    f.write_text(txt, encoding="utf-8")
    return str(f)


# ── ligne de commande ───────────────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    commun = argparse.ArgumentParser(add_help=False)
    commun.add_argument("--jeu", help="le dépôt du jeu (défaut : deviné)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("lister", parents=[commun])
    sub.add_parser("verifier", parents=[commun])
    r = sub.add_parser("relever", parents=[commun])
    r.add_argument("--graver", action="store_true")
    r.add_argument("--depuis", default="30d")
    g = sub.add_parser("graver", parents=[commun])
    g.add_argument("id")
    g.add_argument("lettre")
    g.add_argument("--note", default="")
    pu = sub.add_parser("publier", parents=[commun])
    pu.add_argument("id")
    pu.add_argument("lettre")
    pu.add_argument("--note", default="")
    c = sub.add_parser("courrier", parents=[commun])
    c.add_argument("--depuis", default="2d")
    a = p.parse_args(argv)
    jeu = Path(a.jeu).resolve() if a.jeu else dossier_du_jeu()

    if a.cmd == "lister":
        fs = lister(jeu)
        if jeu is None:
            print("dépôt du jeu introuvable")
            return 1
        ouvertes = sum(1 for d in fs if d["etat"] == "ouverte")
        print("%d fourche(s), %d ouverte(s) (plafond %d) — %s" % (len(fs), ouvertes, PLAFOND, jeu / DOSSIER))
        for d in fs:
            rep = d["reponse"]
            fin = ("→ %s le %s" % (rep["lettre"], rep["date"])) if rep else \
                  ("reco %s" % d["recommandation"]["lettre"] if d["recommandation"] else "")
            print("  %s  %-9s %-9s %-52s %s" % (d["id"], d["etat"], d["domaine"], d["titre"][:52], fin))
        return 0
    if a.cmd == "verifier":
        pb = verifier(jeu)
        for x in pb:
            print("  PROBLÈME  " + x)
        print("fourches : %s" % ("en règle" if not pb else "%d problème(s)" % len(pb)))
        return 1 if pb else 0
    if a.cmd == "relever":
        reps = relever(a.depuis)
        if not reps:
            print("aucune réponse sur le canal (depuis %s)" % a.depuis)
            return 0
        connues = {d["id"]: d for d in lister(jeu)}
        for id_, rep in sorted(reps.items()):
            d = connues.get(id_)
            etat = "inconnue" if d is None else d["etat"]
            print("  %s → %s  (%s, via %s)%s" % (id_, rep["lettre"], etat, rep["via"],
                                                 (" — " + rep["note"]) if rep["note"] else ""))
            if a.graver and d is not None and d["etat"] == "ouverte":
                try:
                    print("     gravée : %s" % graver(id_, rep["lettre"], rep["note"], jeu,
                                                       time.strftime("%Y-%m-%d", time.gmtime(rep["quand"]))))
                except RuntimeError as exc:
                    print("     REFUSÉE : %s" % exc)
        return 0
    if a.cmd == "graver":
        try:
            print(graver(a.id, a.lettre, a.note, jeu))
        except RuntimeError as exc:
            print("REFUSÉE : %s" % exc)
            return 1
        return 0
    if a.cmd == "publier":
        enregistrer_localement(a.id, a.lettre, a.note, "")
        print("publiée via " + publier(a.id, a.lettre, a.note))
        return 0
    if a.cmd == "courrier":
        for m in courrier(a.depuis):
            print("%s  %-28s %s%s" % (m["quand"], m["titre"][:28], m["corps"][:120].replace("\n", " "),
                                       ("  [pièce : %s]" % m["piece"]) if m["piece"] else ""))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())

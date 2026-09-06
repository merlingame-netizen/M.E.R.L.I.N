#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Serveur de réponses pour l'anniversaire d'Elise.

Ce que la page publiée sur claude.ai ne peut pas faire : garder les réponses
ailleurs que dans le navigateur de celui qui répond. Ici elles vivent dans un
SQLite sur la VM, chacun voit les compteurs des autres, et l'organisateur a un
export CSV.

    python3 app.py                          # dev, http://127.0.0.1:8792
    gunicorn -b 127.0.0.1:8792 app:app      # service

Écoute sur 127.0.0.1 uniquement : c'est cloudflared qui expose le service, donc
aucun port n'est ouvert sur la machine.

Les réponses acceptées ne sont pas recopiées ici : elles sont relevées dans la
page par `build_template.py` et lues dans `valeurs.json`. Le serveur ne peut
donc pas dériver du formulaire.
"""
from __future__ import annotations

import json
import os
import re
import secrets
import sqlite3
import time
from collections import defaultdict, deque
from pathlib import Path

from flask import Flask, g, jsonify, make_response, render_template, request

APP_DIR = Path(__file__).parent
DB_PATH = Path(os.environ.get("ANNIV_DB", APP_DIR / "reponses.db"))
ADMIN_TOKEN = os.environ.get("ANNIV_ADMIN_TOKEN", "")

_valeurs = json.loads((APP_DIR / "valeurs.json").read_text(encoding="utf-8"))
CHOIX: dict[str, list[str]] = _valeurs["choix"]      # champ -> valeurs admises
LIBRES: dict[str, int] = _valeurs["libres"]          # champ -> longueur max
MULTIPLES = {"act"}                                  # les seules cases à cocher
NE_VIENT_PAS = "Je ne peux pas venir"

app = Flask(__name__)


# ── Base ────────────────────────────────────────────────────────────────────
def db() -> sqlite3.Connection:
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(_exc):
    conn = g.pop("db", None)
    if conn is not None:
        conn.close()


def init_db() -> None:
    """Un enregistrement = une personne, plus le détail en JSON. Les colonnes
    sorties du JSON sont celles sur lesquelles on compte ou on trie ; le reste
    suit la page, qui bouge trop pour mériter un schéma."""
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS reponses (
                id       TEXT PRIMARY KEY,
                nom      TEXT NOT NULL,
                nb       INTEGER NOT NULL DEFAULT 1,
                vient    INTEGER NOT NULL DEFAULT 1,
                donnees  TEXT NOT NULL DEFAULT '{}',
                maj      REAL NOT NULL
            )
        """)
        conn.commit()


# ── Anti-abus : la page est publique, le débit doit être borné ──────────────
_hits: defaultdict[str, deque] = defaultdict(deque)
RATE_N, RATE_WINDOW = 20, 60.0


def rate_limited(ip: str) -> bool:
    now = time.monotonic()
    q = _hits[ip]
    while q and now - q[0] > RATE_WINDOW:
        q.popleft()
    if len(q) >= RATE_N:
        return True
    q.append(now)
    return False


def client_ip() -> str:
    # cloudflared place l'IP réelle ici ; sinon on retombe sur remote_addr.
    fwd = request.headers.get("CF-Connecting-IP") or request.headers.get("X-Forwarded-For", "")
    return (fwd.split(",")[0].strip() or request.remote_addr or "?")[:64]


# ── Validation ──────────────────────────────────────────────────────────────
NOM_RE = re.compile(r"^[^\x00-\x1f]{1,60}$")


def valider(payload: dict) -> tuple[dict | None, str]:
    if not isinstance(payload, dict):
        return None, "Corps de requête invalide."

    nom = str(payload.get("nom", "")).strip()
    if not NOM_RE.match(nom):
        return None, "Le nom doit faire entre 1 et 60 caractères."

    if payload.get("rsvp") not in CHOIX["rsvp"]:
        return None, "Réponse de présence inconnue."

    # « 2 » ou « 2 personnes » : on ne retient que le nombre.
    chiffres = re.sub(r"\D", "", str(payload.get("nb", "")) or "")
    nb = int(chiffres) if chiffres else 1
    if not 1 <= nb <= 10:
        return None, "Le nombre de personnes doit être entre 1 et 10."

    propre: dict = {"nom": nom, "nb": nb, "rsvp": payload["rsvp"]}

    for champ, admises in CHOIX.items():
        if champ == "rsvp":
            continue
        brut = payload.get(champ)
        if champ in MULTIPLES:
            if brut is None:
                brut = []
            if not isinstance(brut, list) or len(brut) > len(admises):
                return None, "Liste de choix invalide pour « %s »." % champ
            propre[champ] = [v for v in brut if v in admises]
        else:
            v = str(brut or "").strip()
            if v and v not in admises:
                return None, "Choix inconnu pour « %s »." % champ
            propre[champ] = v

    for champ, taille in LIBRES.items():
        if champ in ("nom", "nb"):
            continue
        propre[champ] = str(payload.get(champ) or "").strip()[:taille]

    return propre, ""


# ── Compteurs ───────────────────────────────────────────────────────────────
def etat() -> dict:
    rows = db().execute("SELECT * FROM reponses ORDER BY maj").fetchall()

    choix = {champ: {v: 0 for v in vals} for champ, vals in CHOIX.items()}
    presents = personnes = 0
    prenoms: list[str] = []
    arrivees: list[dict] = []

    for r in rows:
        d = json.loads(r["donnees"])
        vient = bool(r["vient"])
        for champ, totaux in choix.items():
            valeur = d.get(champ)
            if champ in MULTIPLES:
                for v in valeur or []:
                    if v in totaux:
                        totaux[v] += 1
            elif valeur in totaux:
                totaux[valeur] += 1
        if not vient:
            continue
        presents += 1
        personnes += r["nb"]
        # Prénom seul : la page est publique, le nom complet reste en admin.
        prenoms.append(r["nom"].split()[0][:20])
        if d.get("nav") == "Oui, venez me chercher":
            arrivees.append({"qui": r["nom"].split()[0][:20],
                             "ou": d.get("venue", ""),
                             "jour": d.get("jarr", ""),
                             "heure": d.get("harr", ""),
                             "train": d.get("num", "")})

    arrivees.sort(key=lambda a: (a["jour"] != "Samedi", a["heure"] or "99:99"))
    return {
        "reponses": len(rows),
        "presents": presents,
        "personnes": personnes,
        "prenoms": prenoms,
        "choix": choix,
        # Le chiffre qui commande une réservation, et donc la seule vraie échéance.
        "escape_oui": choix.get("escape", {}).get("J'en suis", 0),
        # Les navettes à monter : qui, où, quand.
        "arrivees": arrivees,
    }


# ── Routes ──────────────────────────────────────────────────────────────────
@app.get("/")
def index():
    resp = make_response(render_template("index.html"))
    if not request.cookies.get("anniv_id"):
        resp.set_cookie("anniv_id", secrets.token_urlsafe(16),
                        max_age=90 * 86400, samesite="Lax", httponly=False)
    return resp


@app.get("/api/etat")
def api_etat():
    return jsonify(etat())


@app.post("/api/reponse")
def api_reponse():
    if rate_limited(client_ip()):
        return jsonify(error="Trop de requêtes, réessaie dans une minute."), 429

    data, err = valider(request.get_json(silent=True) or {})
    if err:
        return jsonify(error=err), 400

    pid = request.cookies.get("anniv_id") or secrets.token_urlsafe(16)
    conn = db()
    conn.execute("""
        INSERT INTO reponses (id, nom, nb, vient, donnees, maj)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            nom=excluded.nom, nb=excluded.nb, vient=excluded.vient,
            donnees=excluded.donnees, maj=excluded.maj
    """, (pid, data["nom"], data["nb"], int(data["rsvp"] != NE_VIENT_PAS),
          json.dumps(data, ensure_ascii=False), time.time()))
    conn.commit()

    resp = make_response(jsonify(ok=True, etat=etat()))
    resp.set_cookie("anniv_id", pid, max_age=90 * 86400, samesite="Lax", httponly=False)
    return resp


COLONNES_CSV = ["nom", "nb", "rsvp", "venue", "nav", "jarr", "harr", "num",
                "jdep", "hdep", "midi", "escape", "soiree", "fin", "act", "idee"]


@app.get("/admin")
def admin():
    if not ADMIN_TOKEN or not secrets.compare_digest(request.args.get("token", ""), ADMIN_TOKEN):
        return jsonify(error="Jeton d'administration invalide."), 403

    rows = db().execute("SELECT * FROM reponses ORDER BY maj DESC").fetchall()
    detail = []
    for r in rows:
        d = json.loads(r["donnees"])
        d["maj"] = time.strftime("%Y-%m-%d %H:%M", time.localtime(r["maj"]))
        detail.append(d)

    if request.args.get("format") == "csv":
        def cellule(v) -> str:
            # Un champ commençant par = + - @ serait interprété comme une
            # formule par Excel ou LibreOffice : on le neutralise.
            v = " | ".join(v) if isinstance(v, list) else str(v if v is not None else "")
            if v[:1] in ("=", "+", "-", "@"):
                v = "'" + v
            return '"' + v.replace('"', '""') + '"'

        lignes = [",".join(COLONNES_CSV + ["maj"])]
        for d in detail:
            lignes.append(",".join(cellule(d.get(c)) for c in COLONNES_CSV + ["maj"]))
        out = make_response("\n".join(lignes))
        out.headers["Content-Type"] = "text/csv; charset=utf-8"
        out.headers["Content-Disposition"] = 'attachment; filename="reponses-anniv-elise.csv"'
        return out

    return jsonify(etat=etat(), reponses=detail)


@app.get("/healthz")
def healthz():
    return jsonify(ok=True, reponses=db().execute(
        "SELECT COUNT(*) c FROM reponses").fetchone()["c"])


init_db()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", 8792)), debug=False)

#!/usr/bin/env python3
"""Serveur de vote pour l'anniversaire d'Elise.

Ce que l'artifact claude.ai ne peut pas faire : un vote réellement partagé sur
une URL publique. Ici les réponses vivent dans un SQLite sur la VM, et chaque
visiteur voit les compteurs des autres en direct.

    python3 app.py                 # dev, http://127.0.0.1:8792
    gunicorn -b 127.0.0.1:8792 app:app

Écoute sur 127.0.0.1 uniquement : c'est cloudflared qui expose le service.
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

# Valeurs acceptées — toute réponse hors de ces listes est refusée.
# Elles doivent rester alignées avec les `value=` de la page.
PRESENCES = {
    "Je viens tout le week-end",
    "Samedi seulement",
    "Je passe dimanche",
    "Je ne peux pas venir",
}
COUCHAGES = {
    "Oui, il me faut un couchage",
    "J'apporte mon matelas ou mon duvet",
    "Je me loge ailleurs",
    "Je ne dors pas sur place",
}
TRANSPORTS = {
    "En train, venez me chercher",
    "En voiture, je peux prendre des gens",
    "En voiture, seul",
    "J'habite Aix, je viens à pied",
}
ACTIVITES = {
    "Randonnée Sainte-Victoire",
    "Balade au barrage de Bimont",
    "Vieil Aix et terrasses",
    "Accrobranche Indian Forest",
    "Apéro et pétanque à la maison",
}
VIENT = PRESENCES - {"Je ne peux pas venir"}

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
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS reponses (
                id        TEXT PRIMARY KEY,
                nom       TEXT NOT NULL,
                presence  TEXT NOT NULL,
                nb        INTEGER NOT NULL DEFAULT 1,
                couchage  TEXT,
                transport TEXT,
                train     TEXT,
                activites TEXT NOT NULL DEFAULT '[]',
                maj       REAL NOT NULL
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
        return None, "corps de requête invalide"

    nom = str(payload.get("nom", "")).strip()
    if not NOM_RE.match(nom):
        return None, "Le nom doit faire entre 1 et 60 caractères."

    presence = str(payload.get("presence", "")).strip()
    if presence not in PRESENCES:
        return None, "Réponse de présence inconnue."

    try:
        nb = int(payload.get("nb") or 1)
    except (TypeError, ValueError):
        return None, "Le nombre de personnes doit être un entier."
    if not 1 <= nb <= 10:
        return None, "Le nombre de personnes doit être entre 1 et 10."

    couchage = str(payload.get("couchage", "")).strip()
    if couchage and couchage not in COUCHAGES:
        return None, "Choix de couchage inconnu."

    transport = str(payload.get("transport", "")).strip()
    if transport and transport not in TRANSPORTS:
        return None, "Moyen de transport inconnu."

    train = str(payload.get("train", "")).strip()[:120]

    brut = payload.get("activites") or []
    if not isinstance(brut, list) or len(brut) > len(ACTIVITES):
        return None, "Liste d'activités invalide."
    activites = [a for a in brut if a in ACTIVITES]

    return {"nom": nom, "presence": presence, "nb": nb, "couchage": couchage,
            "transport": transport, "train": train, "activites": activites}, ""


# ── Compteurs ───────────────────────────────────────────────────────────────
def etat() -> dict:
    rows = db().execute("SELECT * FROM reponses ORDER BY maj").fetchall()

    couchages = {c: 0 for c in COUCHAGES}
    transports = {t: 0 for t in TRANSPORTS}
    trains = []
    activites = {a: 0 for a in ACTIVITES}
    presents, personnes, prenoms = 0, 0, []

    for r in rows:
        if r["couchage"] in couchages:
            couchages[r["couchage"]] += 1
        if r["transport"] in transports:
            transports[r["transport"]] += 1
        # Les arrivées en train pilotent les navettes : prénom + horaire annoncé.
        if r["train"] and r["presence"] in VIENT:
            trains.append({"qui": r["nom"].split()[0][:20], "quand": r["train"]})
        for a in json.loads(r["activites"]):
            if a in activites:
                activites[a] += 1
        if r["presence"] in VIENT:
            presents += 1
            personnes += r["nb"]
            # Prénom seul : la page est publique, le nom complet reste en admin.
            prenoms.append(r["nom"].split()[0][:20])

    return {
        "reponses": len(rows),
        "presents": presents,
        "personnes": personnes,
        "prenoms": prenoms,
        "couchages": couchages,
        "transports": transports,
        "trains": trains,
        "activites": activites,
        # Le seul chiffre sur lequel on ne peut pas improviser la veille.
        "lits_a_sortir": sum(r["nb"] for r in rows
                             if r["couchage"] == "Oui, il me faut un couchage"
                             and r["presence"] in VIENT),

    }


# ── Routes ──────────────────────────────────────────────────────────────────
@app.get("/")
def index():
    resp = make_response(render_template("index.html", etat=etat()))
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
        INSERT INTO reponses (id, nom, presence, nb, couchage, transport, train, activites, maj)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            nom=excluded.nom, presence=excluded.presence, nb=excluded.nb,
            couchage=excluded.couchage, transport=excluded.transport, train=excluded.train,
            activites=excluded.activites, maj=excluded.maj
    """, (pid, data["nom"], data["presence"], data["nb"], data["couchage"],
          data["transport"], data["train"],
          json.dumps(data["activites"], ensure_ascii=False), time.time()))
    conn.commit()

    resp = make_response(jsonify(ok=True, etat=etat()))
    resp.set_cookie("anniv_id", pid, max_age=90 * 86400, samesite="Lax", httponly=False)
    return resp


@app.get("/admin")
def admin():
    if not ADMIN_TOKEN or request.args.get("token") != ADMIN_TOKEN:
        return jsonify(error="Jeton d'administration invalide."), 403

    rows = db().execute("SELECT * FROM reponses ORDER BY maj DESC").fetchall()
    if request.args.get("format") == "csv":
        def cellule(v: str) -> str:
            # Un nom commençant par = + - @ serait interprété comme une formule
            # par Excel ou LibreOffice : on le neutralise avec une apostrophe.
            if v[:1] in ("=", "+", "-", "@"):
                v = "'" + v
            return '"' + v.replace('"', '""') + '"'

        lignes = ["nom,presence,personnes,lieu,transport,train,activites,maj"]
        for r in rows:
            champs = [r["nom"], r["presence"], str(r["nb"]), r["couchage"] or "",
                      r["transport"] or "", r["train"] or "",
                      " | ".join(json.loads(r["activites"])),
                      time.strftime("%Y-%m-%d %H:%M", time.localtime(r["maj"]))]
            lignes.append(",".join(cellule(c) for c in champs))
        out = make_response("\n".join(lignes))
        out.headers["Content-Type"] = "text/csv; charset=utf-8"
        out.headers["Content-Disposition"] = 'attachment; filename="reponses-anniv-elise.csv"'
        return out

    return jsonify(etat=etat(), reponses=[{
        "nom": r["nom"], "presence": r["presence"], "nb": r["nb"],
        "couchage": r["couchage"], "transport": r["transport"], "train": r["train"],
        "activites": json.loads(r["activites"]),
        "maj": time.strftime("%Y-%m-%d %H:%M", time.localtime(r["maj"])),
    } for r in rows])


@app.get("/healthz")
def healthz():
    return jsonify(ok=True, reponses=db().execute(
        "SELECT COUNT(*) c FROM reponses").fetchone()["c"])


init_db()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", 8792)), debug=False)

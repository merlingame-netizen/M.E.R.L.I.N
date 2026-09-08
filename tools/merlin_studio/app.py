"""MERLIN Studio — VM-local dev dashboard for the personal Oracle ARM A1 host.

Sibling of the GCP fleet cockpit, but a SEPARATE extension with its own scope: this box
exists to work on the MERLIN game, so the panes are Run (Godot) / Contenu / Jobs / LLM /
Repo / Hôte instead of fleet+quota.

Run:      python3 tools/merlin_studio/app.py --port 8790
Env:      STUDIO_TOKEN (Basic-auth password; required once exposed via tunnel)
          STUDIO_USER (default "merlin"), STUDIO_HOST (default 127.0.0.1)
          OLLAMA_URL / TTS_URL / ASR_URL / GODOT_BIN
Deploy:   infra/oracle/studio/deploy-studio.sh (systemd + Cloudflare tunnel)
"""
from __future__ import annotations

import argparse
import hmac
import json
import os
import secrets
import socket
import sys
import threading
import time
from pathlib import Path

from flask import Flask, Response, jsonify, render_template, request, send_from_directory

# Pont WebSocket↔VNC : optionnel — sans flask-sock le portail tourne en dégradé
# (bouton PLAY désactivé, tout le reste intact).
try:
    from flask_sock import Sock  # type: ignore
    _HAS_SOCK = True
except Exception:
    Sock = None  # type: ignore
    _HAS_SOCK = False

# Allow both `python3 tools/merlin_studio/app.py` and `python3 -m tools.merlin_studio.app`.
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from merlin_studio import actions, chroniques, probes  # type: ignore
else:
    from . import actions, chroniques, probes

_HERE = Path(__file__).resolve().parent

VNC_HOST = os.environ.get("VNC_HOST", "127.0.0.1")
VNC_PORT = int(os.environ.get("VNC_PORT", "5900"))

# Tickets à usage unique pour le handshake WS (mono-process : dict mémoire suffit).
_TICKET_TTL = 60.0
_tickets: dict[str, float] = {}
_tickets_lock = threading.Lock()


def _ticket_new() -> str:
    t = secrets.token_urlsafe(24)
    now = time.monotonic()
    with _tickets_lock:
        # purge au passage
        for k in [k for k, exp in _tickets.items() if exp < now]:
            del _tickets[k]
        _tickets[t] = now + _TICKET_TTL
    return t


def _ticket_ok(t: str | None) -> bool:
    if not t:
        return False
    now = time.monotonic()
    with _tickets_lock:
        exp = _tickets.pop(t, None)   # usage unique
    return exp is not None and exp >= now


# ── PORTE D'APPAREIL (2026-08-24) — un lien privé au lieu du mot de passe ──
# Le Studio demandait Basic auth PUIS un code TOTP. Cliquer une fois sur
# /entrer?cle=<STUDIO_MAGIC> pose des cookies SIGNÉS : cet appareil est reconnu
# 180 jours. Les cookies portent une signature HMAC (même mécanisme que le MFA) :
# ils ne se forgent pas. Aucun autre appareil n'y gagne quoi que ce soit.
def _cle_magique() -> str:
    return os.environ.get("STUDIO_MAGIC", "")


def _cle_de_signature() -> str:
    # Celle du MFA si elle existe, sinon le mot de passe du Studio (toujours
    # présent dès qu'on est derrière un tunnel).
    return _mfa_conf().get("MFA_SIGN_KEY", "") or os.environ.get("STUDIO_TOKEN", "")


def _cookie_appareil_ok(tok: str | None) -> bool:
    key = _cle_de_signature()
    return bool(key) and _mfa_token_ok(key, tok)


def _auth_ok() -> bool:
    token = os.environ.get("STUDIO_TOKEN", "")
    if not token:
        return True  # local mode (loopback), no auth
    # Appareil reconnu : le cookie signé vaut le mot de passe. Rien n'est retiré,
    # Basic auth reste une voie valide (et la seule pour un appareil inconnu).
    if _cookie_appareil_ok(request.cookies.get("merlin_pass")):
        return True
    auth = request.authorization
    if not auth or auth.password is None:
        return False
    return hmac.compare_digest(auth.password, token)


# ── MFA TOTP (2e facteur DEVANT la VM — activée dès que le fichier existe) ──
# ~/.config/merlin-mfa.env : MFA_SECRET (base32, app authenticator)
#                            MFA_SIGN_KEY (signe cookies + jetons d'appareil)
def _mfa_conf() -> dict:
    conf = {}
    try:
        for line in (Path.home() / ".config" / "merlin-mfa.env").read_text().splitlines():
            k, _, v = line.partition("=")
            if k.strip() and not k.startswith("#"):
                conf[k.strip()] = v.strip()
    except Exception:
        pass
    return conf


def _totp_now(secret_b32: str, at: int | None = None, step: int = 30) -> str:
    import base64
    import hashlib
    import struct
    key = base64.b32decode(secret_b32.upper() + "=" * (-len(secret_b32) % 8))
    counter = int((at or time.time()) // step)
    digest = hmac.new(key, struct.pack(">Q", counter), hashlib.sha1).digest()
    off = digest[-1] & 0x0F
    code = (struct.unpack(">I", digest[off:off + 4])[0] & 0x7FFFFFFF) % 1_000_000
    return f"{code:06d}"


def _totp_ok(secret_b32: str, code: str) -> bool:
    code = (code or "").strip().replace(" ", "")
    now = int(time.time())
    return any(hmac.compare_digest(_totp_now(secret_b32, now + drift), code)
               for drift in (-30, 0, 30))


def _mfa_token(sign_key: str, days: int) -> str:
    import hashlib
    exp = str(int(time.time()) + days * 86400)
    sig = hmac.new(sign_key.encode(), exp.encode(), hashlib.sha256).hexdigest()
    return f"{exp}.{sig}"


def _mfa_token_ok(sign_key: str, token: str | None) -> bool:
    import hashlib
    if not token or "." not in token:
        return False
    exp, _, sig = token.partition(".")
    if not exp.isdigit() or int(exp) < time.time():
        return False
    want = hmac.new(sign_key.encode(), exp.encode(), hashlib.sha256).hexdigest()
    return hmac.compare_digest(sig, want)


def _enroll_open() -> bool:
    """La fenêtre d'enrôlement est-elle encore ouverte ? (échoue fermé)"""
    try:
        until = int((Path.home() / ".config" / "merlin-mfa-enroll-until")
                    .read_text().strip())
        return time.time() < until
    except Exception:
        return False


def _qr_svg(data: str) -> str:
    """QR en SVG, sans dépendance obligatoire — vide si segno est absent."""
    try:
        import io

        import segno
        buf = io.BytesIO()          # segno écrit des OCTETS, jamais du texte
        segno.make(data, error="m").save(buf, kind="svg", scale=6, dark="#14100C",
                                         light="#E8DCC0", border=3, xmldecl=False)
        return buf.getvalue().decode("utf-8")
    except Exception:
        return ""


_MFA_PAGE = """<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#1E1A14"><title>MERLIN OS — vérification</title>
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#14100C;
color:#E8DCC0;font:16px/1.5 ui-monospace,monospace}form{background:#241E16;border:1px solid #4A3B28;
border-radius:12px;padding:28px 32px;text-align:center;max-width:320px}h1{font-size:17px;margin:0 0 4px;color:#C9A24B}
p{margin:0 0 16px;color:#9C8C6A;font-size:13px}input{width:100%;box-sizing:border-box;font:28px ui-monospace,monospace;
letter-spacing:8px;text-align:center;background:#1E1A14;border:1px solid #4A3B28;border-radius:8px;color:#E8DCC0;
padding:10px 0;margin-bottom:14px}button{width:100%;min-height:48px;font:bold 15px ui-monospace,monospace;
background:#C9A24B;color:#14100C;border:0;border-radius:8px;cursor:pointer}
.err{color:#E0483A;font-size:13px;margin-top:10px;min-height:1.2em}</style></head><body>
<form id="f"><h1>&#128737; Second facteur</h1><p>Code à 6 chiffres de ton application d'authentification</p>
<input id="c" inputmode="numeric" autocomplete="one-time-code" maxlength="6" autofocus>
<button>Vérifier</button><div class="err" id="e"></div></form>
<script>document.getElementById('f').onsubmit=async(ev)=>{ev.preventDefault();
const r=await fetch('/api/mfa/verify',{method:'POST',headers:{'content-type':'application/json'},
body:JSON.stringify({code:document.getElementById('c').value})});
if(r.ok){location.reload()}else{document.getElementById('e').textContent='Code refusé — réessaie.'}};
</script></body></html>"""


_ASSET_V = str(int(time.time()))


def build_app() -> Flask:
    app = Flask(__name__, template_folder=str(_HERE / "templates"),
                static_folder=str(_HERE / "static"))

    @app.before_request
    def _gate():
        if request.path == "/healthz":
            return None
        # La porte d'appareil doit être atteignable SANS mot de passe : c'est
        # elle qui en dispense. Elle vérifie sa propre clé, longue et privée.
        if request.path == "/entrer":
            return None
        # Handshake noVNC : un ticket frais (délivré derrière Basic auth) vaut auth.
        if request.path == "/websockify" and _ticket_ok(request.args.get("ticket")):
            return None
        if not _auth_ok():
            return Response("Authentication required.\n", 401,
                            {"WWW-Authenticate": 'Basic realm="MERLIN Studio"'})
        # ── 2e facteur TOTP (opt-in : actif dès que merlin-mfa.env existe) ──
        mfa = _mfa_conf()
        if not mfa.get("MFA_SECRET") or not mfa.get("MFA_SIGN_KEY"):
            return None
        # Assets purs et vérification elle-même. PAS /websockify : la voie
        # légitime (ticket) est déjà sortie plus haut — ici on bloque le
        # VNC direct au mot de passe seul.
        if (request.path.startswith("/static/") or request.path.startswith("/vendor/")
                or request.path in ("/sw.js", "/manifest.webmanifest", "/api/mfa/verify")):
            return None
        # Page d'enrôlement : accessible avec le mot de passe seul, mais UNIQUEMENT
        # pendant la fenêtre de 30 min ouverte par mfa-setup.sh --rotate. Sinon on
        # laisserait une porte permanente derrière le seul Basic auth.
        if request.path == "/mfa/enroll" and _enroll_open():
            return None
        key = mfa["MFA_SIGN_KEY"]
        if _mfa_token_ok(key, request.cookies.get("merlin_mfa")) \
                or _mfa_token_ok(key, request.headers.get("X-Merlin-MFA")):
            return None
        if request.path.startswith("/api/") or request.path == "/websockify":
            return jsonify({"error": "mfa_required"}), 401
        return Response(_MFA_PAGE, 200, {"content-type": "text/html; charset=utf-8"})

    @app.route("/")
    def index():
        # Cache-busting : l'URL des assets change à chaque redémarrage du Studio
        # (on redémarre à chaque déploiement). Un service worker périmé ne peut
        # pas servir une URL qu'il n'a jamais vue — leçon du bug « Décider vide ».
        return render_template("index.html", asset_v=_ASSET_V)

    # LA PORTE D'APPAREIL : un lien privé, cliqué UNE fois, et ce navigateur
    # entre sans rien taper pendant 180 jours. Clé fausse ou absente : 403.
    @app.route("/entrer")
    def entrer():
        magique = _cle_magique()
        cle = request.args.get("cle", "")
        if not magique or not hmac.compare_digest(cle, magique):
            return Response("Lien invalide.\n", 403)
        key = _cle_de_signature()
        if not key:
            return Response("Studio sans clé de signature.\n", 500)
        jeton = _mfa_token(key, 180)
        resp = Response("", 302, {"Location": "/"})
        for nom in ("merlin_pass", "merlin_mfa"):
            resp.set_cookie(nom, jeton, max_age=180 * 86400,
                            httponly=True, secure=True, samesite="Lax")
        return resp

    @app.route("/healthz")
    def healthz():
        return jsonify({"ok": True, "app": "merlin-studio"})

    # ── read-only panes ──────────────────────────────────────────────────────
    @app.route("/api/overview")
    def api_overview():
        return jsonify(probes.overview())

    @app.route("/api/host")
    def api_host():
        return jsonify(probes.host())

    # ── jeu natif (conteneur VNC) ────────────────────────────────────────────
    @app.route("/api/game")
    def api_game():
        info = probes.game()
        info["ws_bridge"] = _HAS_SOCK
        if not _HAS_SOCK:
            info["reason"] = (info.get("reason") or
                              "flask-sock absent — pip install flask-sock simple-websocket")
        return jsonify(info)

    @app.route("/api/agents")
    def api_agents():
        return jsonify(probes.agents())

    # ── les fourches : ce que seul Maxime tranche (08/09) ────────────────────
    # Elles vivent dans docs/decisions/ du dépôt du jeu ; la VM ne pousse pas sur GitHub, alors le
    # choix est enregistré ici et publié sur le canal du Courrier, que la session suivante relève
    # et grave. Le module tools/decisions.py est partagé avec cette session-là.
    def _decisions():
        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        import decisions as D
        return D

    @app.route("/api/decisions")
    def api_decisions():
        try:
            D = _decisions()
            jeu = D.dossier_du_jeu()
            fourches = D.lister(jeu)
            for d in fourches:
                d["locale"] = D.reponse_locale(d["id"])
            return jsonify({"fourches": fourches,
                            "ouvertes": sum(1 for d in fourches if d["etat"] == "ouverte"),
                            "a_trancher": sum(1 for d in fourches
                                              if d["etat"] == "ouverte" and not d["locale"]),
                            "plafond": D.PLAFOND, "jeu": str(jeu) if jeu else None,
                            "problemes": D.verifier(jeu) if jeu else []})
        except Exception as exc:
            return jsonify({"fourches": [], "ouvertes": 0, "a_trancher": 0, "erreur": str(exc)[:200]})

    @app.route("/api/decision/<did>/trancher", methods=["POST"])
    def api_decision_trancher(did: str):
        body = request.get_json(silent=True) or {}
        lettre = str(body.get("lettre", "")).strip().upper()[:1]
        note = str(body.get("note", ""))[:300]
        try:
            D = _decisions()
            cible = next((d for d in D.lister(D.dossier_du_jeu()) if d["id"] == did), None)
            if cible is None:
                return jsonify({"error": "aucune fourche %s" % did}), 404
            if cible["etat"] != "ouverte":
                return jsonify({"error": "la fourche %s est %s" % (did, cible["etat"])}), 409
            if lettre not in [o["lettre"] for o in cible["options"]]:
                return jsonify({"error": "pas d'option %s" % (lettre or "?")}), 400
            via = ""
            if os.environ.get("MERLIN_DECISIONS_SANS_ENVOI") != "1":
                via = D.publier(did, lettre, note)
            rec = D.enregistrer_localement(did, lettre, note, via)
            return jsonify({"ok": True, "via": via, "reponse": rec})
        except Exception as exc:
            return jsonify({"error": str(exc)[:200]}), 502

    # ── MFA : page d'enrôlement (QR à scanner), fenêtre de 30 min ────────────
    @app.route("/mfa/enroll")
    def mfa_enroll():
        if not _enroll_open():
            return Response(
                "<p style='font:16px sans-serif;padding:24px'>Fenêtre d'enrôlement fermée."
                "<br>Relance <code>mfa-setup.sh --rotate</code> pour en ouvrir une.</p>",
                403, {"content-type": "text/html; charset=utf-8"})
        mfa = _mfa_conf()
        secret = mfa.get("MFA_SECRET", "")
        if not secret:
            return Response("MFA non configurée\n", 404)
        uri = f"otpauth://totp/MERLIN-OS:merlin?secret={secret}&issuer=MERLIN-OS"
        groups = " ".join(secret[i:i + 4] for i in range(0, len(secret), 4))
        qr = _qr_svg(uri)
        left = int((int((Path.home() / ".config" / "merlin-mfa-enroll-until")
                        .read_text().strip()) - time.time()) // 60)
        html = f"""<!doctype html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MERLIN OS — enrôlement</title><style>
body{{margin:0;min-height:100vh;display:grid;place-items:center;background:#14100C;
color:#E8DCC0;font:16px/1.5 ui-monospace,monospace;padding:20px}}
.box{{background:#241E16;border:1px solid #4A3B28;border-radius:14px;padding:24px;
max-width:420px;text-align:center}}h1{{font-size:18px;color:#C9A24B;margin:0 0 6px}}
p{{color:#9C8C6A;font-size:13px;margin:0 0 16px}}
.qr{{background:#E8DCC0;border-radius:10px;padding:8px;display:inline-block}}
.qr svg{{display:block;width:100%;height:auto;max-width:260px}}
code{{display:block;font-size:17px;letter-spacing:2px;color:#E8DCC0;background:#1E1A14;
border:1px solid #4A3B28;border-radius:8px;padding:12px;margin:16px 0;word-break:break-all}}
a{{display:block;min-height:48px;line-height:48px;background:#C9A24B;color:#14100C;
text-decoration:none;font-weight:700;border-radius:8px}}</style></head><body>
<div class="box"><h1>&#128241; Enrôler ton téléphone</h1>
<p>Scanne ce code avec ton application d'authentification.<br>
Fenêtre ouverte encore {left} min.</p>
{f'<div class="qr">{qr}</div>' if qr else '<p>QR indisponible — saisis la clé ci-dessous.</p>'}
<p style="margin-top:16px">Ou saisis la clé à la main :</p>
<code>{groups}</code>
<a href="/">J'ai scanné — aller au portail</a></div></body></html>"""
        return Response(html, 200, {"content-type": "text/html; charset=utf-8",
                                    "cache-control": "no-store"})

    # ── MFA : vérification du code TOTP (derrière Basic auth) ────────────────
    @app.route("/api/mfa/verify", methods=["POST"])
    def api_mfa_verify():
        mfa = _mfa_conf()
        if not mfa.get("MFA_SECRET"):
            return jsonify({"error": "mfa non activée"}), 400
        body = request.get_json(silent=True) or {}
        if not _totp_ok(mfa["MFA_SECRET"], str(body.get("code", ""))):
            time.sleep(1)          # freine la force brute
            return jsonify({"error": "code refusé"}), 401
        key = mfa["MFA_SIGN_KEY"]
        out = {"ok": True}
        if body.get("device"):     # jeton long pour l'extension VS Code (90 j)
            out["device_token"] = _mfa_token(key, 90)
        resp = jsonify(out)
        resp.set_cookie("merlin_mfa", _mfa_token(key, 30), max_age=30 * 86400,
                        secure=True, httponly=True, samesite="Lax")
        return resp

    # ── flux audio du jeu : ffmpeg capte la sortie « merlin » → MP3 → <audio> ─
    @app.route("/audio/stream")
    def audio_stream():
        import os
        import signal
        import subprocess as _sp
        aud = Path.home() / "opt" / "audio"
        ff = aud / "ffmpeg"
        parec = aud / "sysroot" / "usr" / "bin" / "parec"
        if not (ff.exists() and parec.exists()):
            return Response("audio non installé\n", 503)
        # Le ffmpeg statique n'a pas le support PulseAudio : on capte avec parec
        # (client Pulse) → PCM brut → ffmpeg encode en MP3. libpulsecore dans son
        # sous-dossier, sinon parec ne démarre pas.
        core = next(aud.glob("sysroot/**/libpulsecore-*.so"), None)
        libs = f"{aud}/sysroot/usr/lib64:{aud}/sysroot/usr/lib"
        if core:
            libs += f":{core.parent}"
        env = {**os.environ, "LD_LIBRARY_PATH": libs,
               "PULSE_RUNTIME_PATH": str(Path.home() / ".cache" / "pulse")}
        # parec sort du s16le 44.1 kHz stéréo ; ffmpeg le prend en entrée brute.
        cmd = (f'exec "{parec}" --format=s16le --rate=44100 --channels=2 '
               f'-d merlin.monitor 2>/dev/null | '
               f'exec "{ff}" -hide_banner -loglevel error -f s16le -ar 44100 -ac 2 '
               f'-i - -c:a libmp3lame -b:a 96k -f mp3 -')
        proc = _sp.Popen(["bash", "-c", cmd], stdout=_sp.PIPE, stderr=_sp.DEVNULL,
                         env=env, bufsize=0, preexec_fn=os.setsid)

        def _gen():
            try:
                while True:
                    chunk = proc.stdout.read(4096)
                    if not chunk:
                        break
                    yield chunk
            finally:
                try:
                    os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
                except Exception:
                    pass

        return Response(_gen(), mimetype="audio/mpeg",
                        headers={"Cache-Control": "no-store"})

    # ── PWA : manifest + service worker servis À LA RACINE (portée "/") ──────
    @app.route("/manifest.webmanifest")
    def pwa_manifest():
        return send_from_directory(str(Path(app.static_folder)), "manifest.webmanifest",
                                   mimetype="application/manifest+json")

    @app.route("/sw.js")
    def pwa_sw():
        resp = send_from_directory(str(Path(app.static_folder)), "sw.js",
                                   mimetype="text/javascript", max_age=0)
        resp.headers["Service-Worker-Allowed"] = "/"
        return resp

    # ── chroniques des parties jouées par la machine ─────────────────────────
    # La liseuse (page normée) est REMPLIE À LA DEMANDE avec tout ce que la VM a joué : copies
    # de sûreté du Courrier, résultats commités, chroniques sauvées, et celles que le jeu écrit
    # lui-même. Servie sans cache : une partie qui vient de finir doit y être au prochain clic.
    @app.route("/api/chroniques")
    def api_chroniques():
        try:
            return jsonify({"parties": chroniques.liste()})
        except Exception as exc:
            return jsonify({"parties": [], "error": str(exc)[:200]})

    @app.route("/api/nuits")
    def api_nuits():
        # La courbe nuit après nuit : « le jeu s'améliore-t-il ? » a besoin de points, pas d'instantanés.
        try:
            return jsonify({"nuits": chroniques.nuits()})
        except Exception as exc:  # pragma: no cover
            return jsonify({"nuits": [], "erreur": str(exc)[:200]})

    @app.route("/chroniques/liseuse")
    def chroniques_liseuse():
        try:
            page = chroniques.rendre(chroniques.parties())
        except Exception as exc:
            return Response("liseuse indisponible : %s\n" % str(exc)[:200], 500,
                            {"content-type": "text/plain; charset=utf-8"})
        return Response(page, 200, {"content-type": "text/html; charset=utf-8",
                                    "cache-control": "no-store"})

    # Vignettes CI (sha court hexa uniquement — pas de traversée possible).
    @app.route("/api/vnc/ticket", methods=["POST"])
    def api_vnc_ticket():
        # Derrière le gate Basic auth : délivre un laissez-passer 60 s à usage
        # unique pour le handshake WS (jamais le STUDIO_TOKEN dans une URL).
        return jsonify({"ticket": _ticket_new(), "ttl": int(_TICKET_TTL)})

    # Police du jeu (VT323), self-hostée depuis Assets/fonts/.
    @app.route("/assets/fonts/<path:f>")
    def assets_fonts(f: str):
        if not f.lower().endswith(".ttf"):
            return Response("forbidden\n", 403)
        return send_from_directory(str(probes.ROOT / "Assets" / "fonts"), f,
                                   max_age=86400)

    # ── actions ──────────────────────────────────────────────────────────────
    @app.route("/api/launch", methods=["POST"])
    def api_launch():
        body = request.get_json(silent=True) or {}
        rec = actions.launch(str(body.get("kind", "")), body.get("params") or {})
        return jsonify(rec), (400 if rec.get("error") else 200)

    @app.route("/api/jobs")
    def api_jobs():
        return jsonify(actions.jobs())

    @app.route("/api/job/<jid>")
    def api_job(jid):
        return Response(actions.job_log(jid) or "(vide)", mimetype="text/plain")

    @app.route("/api/job/<jid>/stop", methods=["POST"])
    def api_job_stop(jid):
        return jsonify(actions.stop(jid))

    # ── /play/ : build web du jeu, jouable navigateur (PC + mobile via tunnel) ──
    _WEB_BUILD = probes.ROOT / "build" / "web"

    @app.route("/play/")
    @app.route("/play/<path:f>")
    def play(f: str = "index.html"):
        if not (_WEB_BUILD / "index.html").exists():
            return Response(
                "Build web absent. Lancer « Build web du jeu » depuis l'onglet Run "
                "(ou: bash infra/oracle/studio/build-web.sh).\n",
                404, {"Content-Type": "text/plain; charset=utf-8"})
        resp = send_from_directory(str(_WEB_BUILD), f)
        # SharedArrayBuffer (threads Godot Web) exige l'isolation cross-origin.
        resp.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        resp.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        return resp

    # ── pont WebSocket ↔ VNC (x11vnc -localhost:5900) ────────────────────────
    if _HAS_SOCK:
        # Un ping toutes les 25 s. Sans lui, un tunnel Cloudflare coupe une
        # connexion silencieuse : dès que l'image du jeu est fixe (un menu, une
        # pause), plus rien ne transite et le tunnel ferme — c'est la cause
        # première du « je perds souvent le signal ». Le ping est un cadre
        # WebSocket de contrôle : quelques octets, jamais du pixel.
        app.config.setdefault("SOCK_SERVER_OPTIONS", {"ping_interval": 25})
        sock = Sock(app)

        @sock.route("/websockify")
        def websockify(ws):
            # L'auth est déjà passée dans _gate (Basic OU ticket usage unique).
            try:
                tcp = socket.create_connection((VNC_HOST, VNC_PORT), timeout=5)
            except OSError:
                ws.close(1011, "VNC injoignable — le jeu est-il démarré ?")
                return
            tcp.settimeout(None)
            done = threading.Event()

            def pump_tcp_to_ws():
                try:
                    while not done.is_set():
                        data = tcp.recv(65536)
                        if not data:
                            break
                        ws.send(data)
                except Exception:
                    pass
                finally:
                    done.set()
                    try:
                        ws.close()
                    except Exception:
                        pass

            t = threading.Thread(target=pump_tcp_to_ws, daemon=True)
            t.start()
            try:
                while not done.is_set():
                    data = ws.receive()
                    if data is None:
                        break
                    if isinstance(data, str):
                        data = data.encode("utf-8")
                    tcp.sendall(data)
            except Exception:
                pass
            finally:
                done.set()
                try:
                    tcp.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                tcp.close()

    return app


def main() -> int:
    ap = argparse.ArgumentParser(description="MERLIN Studio (VM-local dev dashboard)")
    ap.add_argument("--port", type=int, default=int(os.environ.get("STUDIO_PORT", "8790")))
    ap.add_argument("--host", default=os.environ.get("STUDIO_HOST", "127.0.0.1"))
    a = ap.parse_args()
    if os.environ.get("STUDIO_TOKEN"):
        print(f"[studio] auth ENABLED (Basic, user={os.environ.get('STUDIO_USER', 'merlin')})")
    else:
        print("[studio] auth DISABLED (local only — set STUDIO_TOKEN before exposing)")
    print(f"[studio] http://{a.host}:{a.port}  repo={probes.ROOT}")
    build_app().run(host=a.host, port=a.port, threaded=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())

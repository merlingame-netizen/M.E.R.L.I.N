#!/usr/bin/env python3
"""Porte d'appareil du Studio — un lien privé au lieu du mot de passe.

/entrer?cle=<STUDIO_MAGIC> pose deux cookies SIGNÉS (merlin_pass + merlin_mfa, 180 j) :
ce navigateur ne tape plus jamais ni mot de passe ni code TOTP. Les deux autres
portes restent intactes pour tout autre appareil."""
import pathlib
import sys


def exact(texte, vieux, neuf, nom):
    n = texte.count(vieux)
    if n != 1:
        sys.exit("ECHEC %s : motif trouve %d fois (attendu 1) : %r" % (nom, n, vieux[:90]))
    return texte.replace(vieux, neuf)


p = pathlib.Path("tools/merlin_studio/app.py")
t = p.read_text(encoding="utf-8")

# ── A1 : les aides + le by-pass par cookie signé dans _auth_ok ──
t = exact(t,
    'def _auth_ok() -> bool:\n'
    '    token = os.environ.get("STUDIO_TOKEN", "")\n'
    '    if not token:\n'
    '        return True  # local mode (loopback), no auth\n',
    '# ── PORTE D\'APPAREIL (2026-08-24) — un lien privé au lieu du mot de passe ──\n'
    '# Le Studio demandait Basic auth PUIS un code TOTP. Cliquer une fois sur\n'
    '# /entrer?cle=<STUDIO_MAGIC> pose des cookies SIGNÉS : cet appareil est reconnu\n'
    '# 180 jours. Les cookies portent une signature HMAC (même mécanisme que le MFA) :\n'
    "# ils ne se forgent pas. Aucun autre appareil n'y gagne quoi que ce soit.\n"
    'def _cle_magique() -> str:\n'
    '    return os.environ.get("STUDIO_MAGIC", "")\n'
    '\n'
    '\n'
    'def _cle_de_signature() -> str:\n'
    '    # Celle du MFA si elle existe, sinon le mot de passe du Studio (toujours\n'
    "    # présent dès qu'on est derrière un tunnel).\n"
    '    return _mfa_conf().get("MFA_SIGN_KEY", "") or os.environ.get("STUDIO_TOKEN", "")\n'
    '\n'
    '\n'
    'def _cookie_appareil_ok(tok: str | None) -> bool:\n'
    '    key = _cle_de_signature()\n'
    '    return bool(key) and _mfa_token_ok(key, tok)\n'
    '\n'
    '\n'
    'def _auth_ok() -> bool:\n'
    '    token = os.environ.get("STUDIO_TOKEN", "")\n'
    '    if not token:\n'
    '        return True  # local mode (loopback), no auth\n'
    '    # Appareil reconnu : le cookie signé vaut le mot de passe. Rien n\'est retiré,\n'
    '    # Basic auth reste une voie valide (et la seule pour un appareil inconnu).\n'
    '    if _cookie_appareil_ok(request.cookies.get("merlin_pass")):\n'
    '        return True\n',
    "A1-auth")

# ── A2 : /entrer passe devant le portier (sinon Basic auth le bloquerait) ──
t = exact(t,
    '        if request.path == "/healthz":\n'
    '            return None\n',
    '        if request.path == "/healthz":\n'
    '            return None\n'
    '        # La porte d\'appareil doit être atteignable SANS mot de passe : c\'est\n'
    '        # elle qui en dispense. Elle vérifie sa propre clé, longue et privée.\n'
    '        if request.path == "/entrer":\n'
    '            return None\n',
    "A2-gate")

# ── A3 : la route elle-même ──
t = exact(t,
    '        return render_template("index.html", asset_v=_ASSET_V)\n',
    '        return render_template("index.html", asset_v=_ASSET_V)\n'
    '\n'
    '    # LA PORTE D\'APPAREIL : un lien privé, cliqué UNE fois, et ce navigateur\n'
    '    # entre sans rien taper pendant 180 jours. Clé fausse ou absente : 403.\n'
    '    @app.route("/entrer")\n'
    '    def entrer():\n'
    '        magique = _cle_magique()\n'
    '        cle = request.args.get("cle", "")\n'
    '        if not magique or not hmac.compare_digest(cle, magique):\n'
    '            return Response("Lien invalide.\\n", 403)\n'
    '        key = _cle_de_signature()\n'
    '        if not key:\n'
    '            return Response("Studio sans clé de signature.\\n", 500)\n'
    '        jeton = _mfa_token(key, 180)\n'
    '        resp = Response("", 302, {"Location": "/"})\n'
    '        for nom in ("merlin_pass", "merlin_mfa"):\n'
    '            resp.set_cookie(nom, jeton, max_age=180 * 86400,\n'
    '                            httponly=True, secure=True, samesite="Lax")\n'
    '        return resp\n',
    "A3-route")

p.write_text(t, encoding="utf-8")
print("OK tools/merlin_studio/app.py")
print("porte d'appareil posee")

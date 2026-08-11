#!/usr/bin/env bash
# Active la MFA TOTP du portail (2e facteur devant la VM). À lancer UNE fois
# sur la VM ; imprime la clé à saisir dans l'app d'authentification
# (Google Authenticator, Aegis, 2FAS, …). Relançable : ne régénère JAMAIS une
# clé existante (sinon tous les appareils enrôlés seraient invalidés).
#   Désactiver : rm ~/.config/merlin-mfa.env   (retour au Basic auth seul)
set -euo pipefail
CONF="$HOME/.config/merlin-mfa.env"

# --rotate : nouvelle clé + fenêtre d'enrôlement de 30 min sur le portail.
if [ "${1:-}" = "--rotate" ]; then
    rm -f "$CONF"
    echo "ancienne clé révoquée."
fi

if [ -f "$CONF" ]; then
    echo "MFA déjà activée ($CONF présent) — clé conservée."
else
    SECRET="$(head -c 20 /dev/urandom | base32 | tr -d '=' | head -c 32)"
    SIGN="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf 'MFA_SECRET=%s\nMFA_SIGN_KEY=%s\n' "$SECRET" "$SIGN" > "$CONF"
    chmod 600 "$CONF"
    echo "MFA activée."
fi

# Fenêtre d'enrôlement : le QR n'est servi par le portail que pendant 30 min.
# Passé ce délai, la page se referme d'elle-même — pas de porte laissée ouverte.
date -u -d '+30 minutes' +%s > "$HOME/.config/merlin-mfa-enroll-until" 2>/dev/null \
    || echo $(( $(date -u +%s) + 1800 )) > "$HOME/.config/merlin-mfa-enroll-until"
chmod 600 "$HOME/.config/merlin-mfa-enroll-until"
echo "fenêtre d'enrôlement ouverte 30 min : page /mfa/enroll du portail (QR à scanner)"

SECRET="$(grep ^MFA_SECRET= "$CONF" | cut -d= -f2)"
cat <<EOF

── À saisir dans ton application d'authentification ──────────────
   Compte : MERLIN OS (merlin)
   Clé    : $SECRET
   Type   : TOTP, 6 chiffres, 30 s (réglages par défaut)
   URI    : otpauth://totp/MERLIN-OS:merlin?secret=$SECRET&issuer=MERLIN-OS
──────────────────────────────────────────────────────────────────
Le portail demandera le code après le mot de passe ; le navigateur
reste vérifié 30 jours, l'extension VS Code 90 jours.
EOF

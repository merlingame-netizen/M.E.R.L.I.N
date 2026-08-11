#!/usr/bin/env bash
# Active la MFA TOTP du portail (2e facteur devant la VM). À lancer UNE fois
# sur la VM ; imprime la clé à saisir dans l'app d'authentification
# (Google Authenticator, Aegis, 2FAS, …). Relançable : ne régénère JAMAIS une
# clé existante (sinon tous les appareils enrôlés seraient invalidés).
#   Désactiver : rm ~/.config/merlin-mfa.env   (retour au Basic auth seul)
set -euo pipefail
CONF="$HOME/.config/merlin-mfa.env"

if [ -f "$CONF" ]; then
    echo "MFA déjà activée ($CONF présent) — clé conservée."
else
    SECRET="$(head -c 20 /dev/urandom | base32 | tr -d '=' | head -c 32)"
    SIGN="$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf 'MFA_SECRET=%s\nMFA_SIGN_KEY=%s\n' "$SECRET" "$SIGN" > "$CONF"
    chmod 600 "$CONF"
    echo "MFA activée."
fi

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

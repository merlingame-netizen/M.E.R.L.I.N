#!/usr/bin/env bash
# Installation userland (SANS root) de la pile d'affichage du jeu natif :
# télécharge les RPM OL9/EPEL (dnf download --resolve) puis les extrait dans
# ~/opt/gamestack/sysroot via rpm2cpio|cpio. Utilisé quand podman est absent.
# Idempotent : marqueur .merlin-ready avec hash de la liste de paquets.
set -uo pipefail

BASE="$HOME/opt/gamestack"
SYSROOT="$BASE/sysroot"
RPMS="$BASE/rpms"
READY="$SYSROOT/.merlin-ready"

# llvmpipe (mesa-dri-drivers) + serveur X virtuel + scraper VNC + screenshot +
# libs X que Godot dlopen (celles déjà présentes sur l'hôte restent visibles via
# le linker par défaut ; --resolve ne télécharge que les manquantes).
# NB: scrot n'existe pas en EPEL9 aarch64 — xwd (AppStream) le remplace pour
# le screenshot de preuve (dump brut, analysé côté provision en Python).
PKGS=(xorg-x11-server-Xvfb x11vnc xwd
      mesa-dri-drivers mesa-libGL mesa-libEGL libglvnd-glx libglvnd-egl
      libX11 libXcursor libXinerama libXrandr libXi libXext libXfixes
      libxkbcommon libxkbcommon-x11 xkeyboard-config xkbcomp alsa-lib)

log()  { echo "[native-setup] $*"; }
fail() { echo "[native-setup] FATAL: $*" >&2; exit 1; }

HASH="$(printf '%s\n' "${PKGS[@]}" | sha256sum | cut -c1-12)"
if [ -f "$READY" ] && [ "$(cat "$READY")" = "$HASH" ]; then
    log "sysroot à jour (hash $HASH), rien à faire"
    exit 0
fi

command -v dnf >/dev/null || fail "dnf absent"
command -v rpm2cpio >/dev/null || fail "rpm2cpio absent"
dnf download --help >/dev/null 2>&1 || fail "plugin 'dnf download' absent (dnf-plugins-core)"

# EPEL : x11vnc et scrot n'existent que là. Oracle Linux le fournit en
# ol9_developer_EPEL ; si aucun repo EPEL n'est défini sur l'hôte, on pointe
# directement le miroir Oracle via --repofrompath (aucun droit root requis).
EPEL="$(dnf repolist all 2>/dev/null | awk 'tolower($1) ~ /epel/ {print $1; exit}')"
if [ -n "$EPEL" ]; then
    ENABLE=(--enablerepo="$EPEL")
    log "repo EPEL: $EPEL"
else
    EPEL_URL="https://yum.oracle.com/repo/OracleLinux/OL9/developer/EPEL/aarch64/"
    ENABLE=(--repofrompath="merlin-epel,$EPEL_URL" --setopt=merlin-epel.gpgcheck=0)
    log "repo EPEL absent de l'hôte -> --repofrompath $EPEL_URL"
fi

mkdir -p "$RPMS" "$SYSROOT"
log "téléchargement RPM (--resolve, manquants uniquement)…"
dnf download --resolve "${ENABLE[@]}" --destdir "$RPMS" "${PKGS[@]}" \
    || fail "dnf download KO (repo EPEL introuvable ? réseau ?)"

COUNT="$(ls "$RPMS"/*.rpm 2>/dev/null | wc -l)"
[ "$COUNT" -gt 0 ] || fail "aucun RPM téléchargé"
log "extraction de $COUNT RPM dans $SYSROOT…"
for f in "$RPMS"/*.rpm; do
    rpm2cpio "$f" | (cd "$SYSROOT" && cpio -idmu --quiet) || fail "extraction $f"
done

[ -x "$SYSROOT/usr/bin/Xvfb" ]   || fail "Xvfb absent du sysroot après extraction"
[ -x "$SYSROOT/usr/bin/x11vnc" ] || fail "x11vnc absent du sysroot après extraction"
[ -e "$SYSROOT/usr/lib64/dri/swrast_dri.so" ] || log "warn: swrast_dri.so introuvable (llvmpipe ?)"

# Répertoires fusionnés (symlinks hôte + binaires sysroot) : fallback de
# native-inner.sh quand l'overlayfs rootless est refusé par le noyau.
MERGED="$BASE/merged"
log "construction des répertoires fusionnés ($MERGED)…"
for sub in usr/bin usr/share/X11; do
    rm -rf "$MERGED/$sub"; mkdir -p "$MERGED/$sub"
    if [ -d "/$sub" ]; then
        for f in "/$sub"/* ; do [ -e "$f" ] && ln -s "$f" "$MERGED/$sub/" 2>/dev/null; done
    fi
    # le sysroot gagne en cas de collision
    for f in "$SYSROOT/$sub"/* ; do
        [ -e "$f" ] || continue
        ln -sfn "$f" "$MERGED/$sub/$(basename "$f")"
    done
done

echo "$HASH" > "$READY"
log "OK — sysroot prêt ($SYSROOT)"

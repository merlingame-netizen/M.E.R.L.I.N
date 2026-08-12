#!/usr/bin/env bash
# Pile audio USERLAND pour le jeu (pas de sudo) — même principe que le sysroot
# graphique : on extrait PulseAudio + libpulse des RPM Oracle dans ~/opt/audio,
# et on télécharge un ffmpeg statique pour capter puis streamer le son.
#
# Après ça, le jeu tourne avec --audio-driver PulseAudio sur une « sortie
# virtuelle » (null-sink), dont ffmpeg lit le monitor et l'envoie au navigateur.
set -uo pipefail
AUD="$HOME/opt/audio"
SYS="$AUD/sysroot"
mkdir -p "$AUD" "$SYS"
LOG="$HOME/audio-setup.log"
: > "$LOG"
say() { echo "$@" | tee -a "$LOG"; }

# ── 1. ffmpeg statique arm64 (capture + encodage MP3) ───────────────────────
if [ ! -x "$AUD/ffmpeg" ]; then
    say "ffmpeg : téléchargement…"
    curl -fsSL --retry 3 \
        "https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-arm64-static.tar.xz" \
        -o "$AUD/ff.tar.xz" >>"$LOG" 2>&1 \
      && tar xf "$AUD/ff.tar.xz" --strip-components=1 -C "$AUD" >>"$LOG" 2>&1 \
      && rm -f "$AUD/ff.tar.xz"
fi
[ -x "$AUD/ffmpeg" ] && say "ffmpeg : $("$AUD/ffmpeg" -version 2>/dev/null | head -1)" \
                     || { say "ffmpeg : ÉCHEC"; }

# ── 2. PulseAudio + libpulse depuis les RPM Oracle Linux 9 aarch64 ───────────
# On télécharge les RPM (dnf download, sans installation) et on les déballe.
PKGS="pulseaudio pulseaudio-libs pulseaudio-utils libsndfile libasyncns \
      speexdsp libtdb libsamplerate flac-libs libvorbis libogg opus \
      systemd-libs libcap orc"
if [ ! -x "$SYS/usr/bin/pulseaudio" ]; then
    say "PulseAudio : récupération des paquets…"
    cd "$AUD"
    if command -v dnf >/dev/null 2>&1; then
        dnf download --resolve --alldeps --downloaddir "$AUD/rpms" $PKGS >>"$LOG" 2>&1 || true
    fi
    # Repli : miroir public si dnf download indisponible sans droits.
    mkdir -p "$AUD/rpms"
    for rpm in "$AUD"/rpms/*.rpm; do
        [ -f "$rpm" ] || continue
        rpm2cpio "$rpm" 2>/dev/null | (cd "$SYS" && cpio -idmu --quiet 2>/dev/null) || true
    done
fi
[ -x "$SYS/usr/bin/pulseaudio" ] && say "PulseAudio : $("$SYS/usr/bin/pulseaudio" --version 2>/dev/null | head -1 || echo 'extrait')" \
                                 || say "PulseAudio : binaire absent (voir $LOG)"

# ── 3. lanceur du serveur audio (sortie virtuelle « merlin ») ───────────────
cat > "$AUD/start-audio.sh" <<'PA'
#!/usr/bin/env bash
# Démarre PulseAudio userland avec une sortie virtuelle dont on capte le son.
AUD="$HOME/opt/audio"; SYS="$AUD/sysroot"
export LD_LIBRARY_PATH="$SYS/usr/lib64:$SYS/usr/lib:${LD_LIBRARY_PATH:-}"
export PULSE_RUNTIME_PATH="$HOME/.cache/pulse"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache/xdg}"
mkdir -p "$PULSE_RUNTIME_PATH" "$XDG_RUNTIME_DIR"
if ! "$SYS/usr/bin/pactl" info >/dev/null 2>&1; then
    "$SYS/usr/bin/pulseaudio" --daemonize=yes --exit-idle-time=-1 \
        --load="module-null-sink sink_name=merlin sink_properties=device.description=merlin" \
        >/dev/null 2>&1
    sleep 2
fi
"$SYS/usr/bin/pactl" info >/dev/null 2>&1 && echo "audio prêt (sortie merlin)" || echo "audio KO"
PA
chmod +x "$AUD/start-audio.sh"
say "lanceur audio écrit : $AUD/start-audio.sh"
say "=== provision audio terminé ==="

#!/usr/bin/env bash
# Santé machine : relevé CPU / RAM / disque, historisé (dernières 24 h) pour
# repérer les dérives (fuite mémoire, disque qui se remplit, charge anormale).
set -uo pipefail
STATE_DIR="$HOME/.cache/merlin-agents"
HIST="$STATE_DIR/health-history.jsonl"
mkdir -p "$STATE_DIR"

LOAD1="$(cut -d' ' -f1 /proc/loadavg)"
CPUS="$(nproc)"
MEM_TOTAL="$(awk '/MemTotal/{print $2}' /proc/meminfo)"
MEM_AVAIL="$(awk '/MemAvailable/{print $2}' /proc/meminfo)"
MEM_PCT=$(( 100 - (MEM_AVAIL * 100 / MEM_TOTAL) ))
DISK_PCT="$(df --output=pcent "$HOME" | tail -1 | tr -dc '0-9')"
UP="$(cut -d. -f1 /proc/uptime)"

printf '{"t":"%s","load1":%s,"cpus":%s,"mem_pct":%s,"disk_pct":%s,"uptime_s":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LOAD1" "$CPUS" "$MEM_PCT" "$DISK_PCT" "$UP" >> "$HIST"

# 288 relevés = 24 h à raison d'un toutes les 5 minutes.
tail -288 "$HIST" > "$HIST.tmp" && mv "$HIST.tmp" "$HIST"

WARN=""
[ "$MEM_PCT" -ge 90 ]  && WARN="$WARN RAM_CRITIQUE"
[ "$DISK_PCT" -ge 85 ] && WARN="$WARN DISQUE_CRITIQUE"
echo "charge $LOAD1/$CPUS · RAM ${MEM_PCT}% · disque ${DISK_PCT}%${WARN:+ ·$WARN}"
[ -z "$WARN" ]

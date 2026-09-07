#!/usr/bin/env bash
# job-101 — s101 : le crible du 07/09 EN ENTIER (ntfy coupe le corps a 3 600 caracteres) et les
# pieces de la premiere nuit de l'atelier : verdict, grille de la quete, ligne de nuits.jsonl,
# et l'etat d'ollama-serve (est-il revenu dans les comptes apres le retrait du verrou ?).
set -u
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari101-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s101 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
FORME='(\?|&|^|[[:space:]])(cle|clef|token|key|secret|password|pass)=[A-Za-z0-9_-]{6,}|Bearer[[:space:]]+[A-Za-z0-9._-]{12,}|BEGIN[[:space:]]+[A-Z ]*PRIVATE[[:space:]]+KEY|ocid1\.[a-z]+\.|ssh-(rsa|ed25519)[[:space:]]|AKIA[0-9A-Z]{16}|[a-z0-9-]+\.trycloud|https?://'

C="$HOME/.cache/merlin-agents/crible/$(date -u +%Y-%m-%d).txt"
[ -f "$C" ] && ! grep -qE "$FORME" "$C" && cp "$C" "$COURRIER_RES/crible_entier.txt"
N="$HOME/.cache/merlin-partie/nuit/$(date -u +%Y-%m-%d)"
Q="$HOME/.cache/merlin-quete/nuit/$(date -u +%Y-%m-%d)"
[ -f "$N/verdict.txt" ] && cp "$N/verdict.txt" "$COURRIER_RES/verdict_partie.txt"
[ -f "$Q/grille.txt" ] && cp "$Q/grille.txt" "$COURRIER_RES/grille_quete.txt"
[ -f "$Q/quete.json" ] && cp "$Q/quete.json" "$COURRIER_RES/quete.json"
[ -f "$HOME/.cache/merlin-partie/nuits.jsonl" ] && cp "$HOME/.cache/merlin-partie/nuits.jsonl" "$COURRIER_RES/nuits.jsonl"
[ -f "$N/partie.log" ] && tail -60 "$N/partie.log" | grep -vE "$FORME" > "$COURRIER_RES/partie_log_fin.txt"

{
echo "== ollama-serve, apres le retrait du verrou =="
cat "$HOME/.cache/merlin-agents/state/ollama-serve.json" 2>/dev/null | cut -c1-200; echo
echo "reveils [ollama-serve] dates dans cron.log : $(grep -ac 'Z \[ollama-serve\]' "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null)"
grep -a '\[ollama-serve\]' "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | tail -3
echo
echo "== reportes (rc=75) depuis hier =="
grep -a 'rc=75' "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | tail -12
echo
echo "== l'atelier de nuit : etat, duree =="
cat "$HOME/.cache/merlin-agents/state/partie-nuit.json" 2>/dev/null | cut -c1-300; echo
echo "== agents eteints hier soir : ont-ils encore couru ? =="
for a in gd-content-gap design-council gd-balance gd-run coder-local sequence parole; do
    printf '%s : ' "$a"; grep -a "\[$a\]" "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | tail -1 | cut -c1-90; echo
done
crontab -l 2>/dev/null | grep -cE "gd-content-gap|design-council|gd-balance|gd-run|coder-local|sequence|parole" | sed 's/^/lignes de crontab pour ces agents : /'
} > "$COURRIER_RES/s101_etat.txt" 2>&1
grep -qE "$FORME" "$COURRIER_RES/s101_etat.txt" && { echo "s101 retenu (forme sensible)"; exit 1; }
dire "etat" "$(cat "$COURRIER_RES/s101_etat.txt")"
echo "s101 : crible entier + pieces de la nuit du $(date -u +%d/%m)"

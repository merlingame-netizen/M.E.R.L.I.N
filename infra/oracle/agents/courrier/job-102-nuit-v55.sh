#!/usr/bin/env bash
# job-102 — s102 : LA PREMIERE NUIT SOUS v55 (plafond des atouts). Le crible EN ENTIER (ntfy coupe le corps a 3 600 caracteres) et les
# pieces de la premiere nuit de l'atelier : verdict, grille de la quete, ligne de nuits.jsonl,
# et l'etat d'ollama-serve (est-il revenu dans les comptes apres le retrait du verrou ?).
set -u
NT=""
for base in https://ntfy.adminforge.de https://ntfy.sh https://ntfy.envs.net; do
    tok="canari102-$(date +%s)"
    curl -fsS -m 15 -H "Title: canari" -d "$tok" "$base/merlin-courrier-vX9k2Qf7Lw3s" >/dev/null 2>&1
    sleep 3
    curl -fsS -m 15 "$base/merlin-courrier-vX9k2Qf7Lw3s/json?poll=1&since=1m" 2>/dev/null | grep -q "$tok" && { NT="$base/merlin-courrier-vX9k2Qf7Lw3s"; break; }
done
[ -n "$NT" ] || NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
dire() { curl -fsS -m 20 -H "Title: s102 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; sleep 3; }
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
echo "== v55 : LA PREMIERE NUIT SOUS LE PLAFOND DES ATOUTS =="
N="$HOME/.cache/merlin-partie/nuit/$(date -u +%Y-%m-%d)"
if [ -f "$N/verdict.txt" ]; then
    grep -aE "^CIBLE|^BOT|^CONTINUITE|^FIN|^CAUSE|^REFERENCE" "$N/verdict.txt" | cut -c1-160
else
    echo "  aucun verdict pour cette nuit"
fi
echo "-- la ligne de nuit (mesures v55) --"
tail -2 "$HOME/.cache/merlin-partie/nuits.jsonl" 2>/dev/null | python3 -c "
import json,sys
for l in sys.stdin:
    try: d=json.loads(l)
    except Exception: continue
    p=d.get('partie') or {}
    print('  %s jeu=%s | beats=%s banc=%s reussite=%s%% sansjet=%s%% eclat=%s integ_min=%s couv=%s climax_de=%s fin=%s' % (
        d.get('nuit'), str(d.get('jeu'))[:8], p.get('beats'), p.get('banc'), p.get('reussite_pct'),
        p.get('sans_jet_pct'), p.get('eclatantes'), p.get('integrite_min'), p.get('couverture_moy'),
        p.get('climax_au_de'), p.get('fin')))
" 2>/dev/null || echo "  (illisible)"
echo "-- le jeu joue-t-il bien v55 ? --"
echo "  commit du jeu sur la VM : $(cd "${GAME_DIR:-$HOME/workspace/merlin-game}" 2>/dev/null && git log --oneline -1 | cut -c1-70)"
echo "  MerlinSentier connu du cache : $(grep -c MerlinSentier "${GAME_DIR:-$HOME/workspace/merlin-game}/.godot/global_script_class_cache.cfg" 2>/dev/null || echo 0)"
echo
echo "== agents eteints hier soir : ont-ils encore couru ? =="
for a in gd-content-gap design-council gd-balance gd-run coder-local sequence parole; do
    printf '%s : ' "$a"; grep -a "\[$a\]" "$HOME/.cache/merlin-agents/cron.log" 2>/dev/null | tail -1 | cut -c1-90; echo
done
crontab -l 2>/dev/null | grep -cE "gd-content-gap|design-council|gd-balance|gd-run|coder-local|sequence|parole" | sed 's/^/lignes de crontab pour ces agents : /'
} > "$COURRIER_RES/s102_etat.txt" 2>&1
grep -qE "$FORME" "$COURRIER_RES/s102_etat.txt" && { echo "s102 retenu (forme sensible)"; exit 1; }
dire "etat" "$(cat "$COURRIER_RES/s102_etat.txt")"
echo "s102 : crible entier + pieces de la nuit du $(date -u +%d/%m)"

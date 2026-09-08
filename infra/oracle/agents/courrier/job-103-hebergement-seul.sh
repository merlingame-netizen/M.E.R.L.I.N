#!/usr/bin/env bash
# job-103 — HÉBERGEMENT SEUL (décision de Maxime, 2026-09-08).
# La VM n'héberge plus que le jeu : ce job éteint ce que la nouvelle planification ne relancera
# plus (Ollama et ses modèles résidents, le brasero, les verrous), régénère le crontab depuis le
# manifeste réduit, et montre l'état réel : ce qui tourne, la mémoire rendue, les neuf gardiens.
set -uo pipefail
echo "=== job-103 : hébergement seul — $(date -u +%FT%TZ) ==="
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/../game/game-env.sh" 2>/dev/null || true

echo; echo "--- 1. avant : mémoire et processus lourds"
free -h | sed -n 1,3p
ps -eo pid,rss,etimes,comm,args --sort=-rss | head -12 | cut -c1-140

echo; echo "--- 2. extinction d'Ollama et des résidents"
for u in ollama merlin-ollama brasero; do
    systemctl --user stop "$u" 2>/dev/null && echo "unité utilisateur $u arrêtée"
    systemctl --user disable "$u" 2>/dev/null && echo "unité utilisateur $u désactivée"
done
for m in "ollama serve" "ollama runner" "llama-server" "brasero"; do
    if pgrep -f "$m" >/dev/null 2>&1; then
        pkill -TERM -f "$m" && echo "arrêté : $m"
    fi
done
sleep 4
for m in "ollama serve" "ollama runner" "llama-server"; do
    pgrep -f "$m" >/dev/null 2>&1 && { pkill -KILL -f "$m"; echo "tué : $m"; }
done
rm -f "$HOME/.cache/merlin-agents/ollama-serve.lock" "$HOME/.cache/merlin-agents/llm.lock" 2>/dev/null

echo; echo "--- 3. la planification, régénérée depuis le manifeste réduit"
bash "$HERE/install-agents.sh" 2>&1 | tail -5
crontab -l 2>/dev/null | grep -c "merlin-agents" | sed 's/^/  lignes merlin-agents : /'
crontab -l 2>/dev/null | grep "merlin-agents" | sed 's/.*agent-run.sh //' | awk '{print $1}' | sort | tr '\n' ' ' | sed 's/^/  /'; echo

echo; echo "--- 4. après : mémoire, processus, le jeu"
sleep 2
free -h | sed -n 1,3p
ps -eo pid,rss,comm --sort=-rss | head -8
bash "$HERE/../game/game-stack.sh" status 2>/dev/null | tail -1

echo; echo "--- 5. ce qui reste dans ~/.cache/merlin-agents/state (états d'agents disparus, archive)"
ls "$HOME/.cache/merlin-agents/state" 2>/dev/null | wc -l | sed 's/^/  états : /'
echo "=== job-103 fini ==="

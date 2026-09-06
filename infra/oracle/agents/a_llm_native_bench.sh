#!/usr/bin/env bash
# Chronomètre le MOTEUR NATIF du jeu (GDExtension MerlinLLM) sur sa vraie tâche.
#
# À ne pas confondre avec a_llm_bench.sh : celui-là mesure Ollama, le serveur
# séparé qui sert les agents. Ici on mesure le moteur compilé DANS le jeu, celui
# qui écrit les titres de quête et la prose pendant une partie. Ce sont deux
# moteurs différents, sur deux modèles différents, avec deux vitesses différentes.
#
# POURQUOI. Toutes les banques de secours du jeu sont justifiées par un « ~1 tok/s »
# hérité d'Ollama. Le moteur natif réglé pour les noyaux ARM de la VM n'avait jamais
# été chronométré. Sans ce chiffre, tout arbitrage sur l'attente joueur est un pari.
#
# `pipefail` est indispensable : sans lui, `X="$(… | grep …)"` suivi de `RC=$?`
# lit le code de grep, pas celui de Godot (piège déjà rencontré sur a_playtest_bot).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

GODOT_BIN="${GODOT_BIN:-$HOME/bin/godot}"
OUT="$HOME/.cache/merlin-agents/native-bench.json"
PASSES="${MERLIN_BENCH_PASSES:-2}"
mkdir -p "$(dirname "$OUT")"

# Jamais pendant que Maxime joue : on lui volerait le CPU, ET la mesure serait
# fausse (le jeu tient déjà le modèle). Deux raisons, un seul test.
if bash "$HERE/../game/game-stack.sh" status 2>/dev/null | grep -q '"vnc_open":true'; then
    echo "jeu en cours d'utilisation — mesure reportée"; exit 75
fi
# NI SOUS UN HARNAIS. `vnc_open` ne dit que si quelqu'un REGARDE : la partie de la nuit n'a pas de
# spectateur, et ce banc lançait à 4 h 25 un second Godot avec un second e4b de 6 Go pendant
# qu'elle jouait — les beats 11 à 13 des deux premières nuits (98 à 128 s) tombent exactement là,
# et la mesure du banc, prise à deux moteurs sur quatre cœurs, ne valait rien non plus.
HARNAIS="$(cat "$HOME/.cache/merlin-game/harness" 2>/dev/null || true)"
DESIRE="$(cat "$HOME/.cache/merlin-game/desired" 2>/dev/null || echo stopped)"
if [ -n "$HARNAIS" ] || [ "$DESIRE" = "running" ]; then
    echo "le jeu est tenu (harnais « $HARNAIS », desire=$DESIRE) — mesure reportée"; exit 75
fi

etape 1 3 "vérification de la sonde"
PROBE="$GAME_DIR/tools/probe_native_bench.gd"
[ -f "$PROBE" ] || { echo "sonde absente — la branche du jeu n'est pas à jour"; exit 0; }

# Budget large : chargement du e4b (6,1 Go) puis PASSES générations. Mieux vaut une
# mesure lente qu'une mesure tronquée, qui ferait croire le moteur plus lent qu'il n'est.
# La mesure est UN appel bloquant de plusieurs minutes : on ne peut pas la subdiviser
# depuis bash, mais on peut au moins annoncer sa duree possible plutot que de laisser
# le portail muet pendant 12 minutes.
etape 2 3 "mesure en cours (jusqu'à 12 min)"
BUDGET=$((360 + PASSES * 180))
# MERLIN_ALLOW_HEADLESS_LLM : sans elle, MerlinNative ne charge PAS le modèle en headless (un
# smoke de 8 s n'a pas à payer 4 Go de lecture disque). Ici on veut justement le moteur, donc on
# paie sciemment. C'est CE réglage qui manquait le 2026-08-15 : la sonde attendait un modèle que
# le jeu avait décidé de ne pas charger, et concluait « moteur mort » au bout de 300 s.
LOG="$(MERLIN_BENCH_PASSES="$PASSES" MERLIN_ALLOW_HEADLESS_LLM=1 timeout "$BUDGET" nice -n 10 "$GODOT_BIN" \
       --headless --path "$GAME_DIR" --script res://tools/probe_native_bench.gd 2>&1)"
RC=$?

etape 3 3 "lecture du résultat"
JSON="$(printf '%s\n' "$LOG" | grep -m1 '^\[BENCH_JSON\] ' | cut -d' ' -f2-)"
if [ -z "$JSON" ]; then
    # Aucune ligne de mesure : on écrit quand même un état daté, sinon le portail
    # afficherait éternellement la mesure de la veille comme si elle était fraîche.
    printf '{"t":"%s","ok":false,"etape":"aucune mesure (code %s)"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RC" > "$OUT"
    echo "aucune mesure — code $RC · dernières lignes :"
    printf '%s\n' "$LOG" | tail -5
    exit 1
fi

# Le commit mesuré est enregistré AVEC la mesure : un chiffre sans la version du
# jeu qui l'a produit ne vaut rien dès que le moteur ou le prompt change.
python3 - "$JSON" "$OUT" "$(git -C "$GAME_DIR" rev-parse --short HEAD 2>/dev/null || echo '?')" <<'PY'
import json, sys
mesure, out, commit = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.loads(mesure)
d["commit"] = commit
json.dump(d, open(out, "w"), ensure_ascii=False, indent=1)

if not d.get("ok"):
    print("mesure incomplète — %s" % d.get("etape", "?"))
    raise SystemExit(1)

charge = d.get("charge_ms", 0) / 1000.0
toks = d.get("tok_par_s_max", 0.0)
mur = d.get("mur_ms_max", 0) / 1000.0
gagne = d.get("modele_gagne_toujours", False)
# Un juge vide invaliderait le verdict : on le dit plutôt que d'annoncer une victoire.
if not d.get("titres_de_secours_connus"):
    verdict = "verdict indisponible (aucun titre de secours connu)"
else:
    verdict = "titres du modèle" if gagne else "SECOURS affiché"
print("chargement %.0f s · %.1f tok/s · quêtes en %.0f s · %s"
      % (charge, toks, mur, verdict))
PY

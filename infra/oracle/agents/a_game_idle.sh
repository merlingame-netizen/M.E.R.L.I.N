#!/usr/bin/env bash
# Coupe le jeu au bout de 5 minutes sans personne devant. NE LE DÉMARRE JAMAIS.
#
# POURQUOI. Le 2026-08-16 au matin, une instance oubliée tournait depuis 12 h 53 à 364 % de CPU
# — presque les 4 cœurs de la VM. Le LLM, privé de processeur, tombait en timeout : l'agent de
# contenu n'a RIEN écrit de la nuit (« carte non écrite — LLM indisponible : timed out »). Une
# nuit de travail autonome perdue parce qu'un jeu que personne ne regardait tenait la machine.
#
# Personne ne l'avait signalé, et le veilleur (a_game_watchdog) faisait pourtant son travail :
# l'état désiré valait « running » — Maxime avait appuyé sur Jouer et jamais sur Stop — donc il
# maintenait vivant ce qui avait été demandé. Il manquait quelqu'un pour dire « plus personne
# ne regarde ».
#
# UN AGENT, UN VERBE : le veilleur relance, celui-ci coupe. Mettre les deux dans le même script
# obligerait à lire attentivement pour savoir lequel gagne.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../game/game-env.sh"

# `etape` est fournie par agent-run.sh, qui la source et l'exporte. Lancé À LA MAIN — ce qu'on
# fait forcément pour diagnostiquer — l'agent mourrait sinon sur « command not found », et le
# bruit masquerait la vraie sortie. Repli silencieux : l'agent doit rester exécutable seul.
type -t etape >/dev/null 2>&1 || etape() { :; }

GS="$HERE/../game/game-stack.sh"
SYSROOT="$HOME/opt/gamestack/sysroot"
RUNDIR="$HOME/.cache/merlin-game"
VU_A="$RUNDIR/vu-a"                     # horodatage du dernier spectateur constaté
SEUIL_S=300                             # 5 minutes (demande de Maxime)
mkdir -p "$RUNDIR"

etape 1 3 "état désiré"

DESIRE="$(cat "$RUNDIR/desired" 2>/dev/null || echo stopped)"
if [ "$DESIRE" != "running" ]; then
    # Déjà arrêté par intention : rien à surveiller, et surtout rien à couper.
    rm -f "$VU_A" 2>/dev/null
    echo "jeu non demandé (désiré=$DESIRE) — rien à surveiller"
    exit 0
fi

# Le bot de playtest joue de VRAIES parties : il compte normalement comme spectateur (il se
# connecte en VNC), mais s'il travaille entre deux connexions on le couperait en plein test.
# Son verrou est la preuve qu'il est à l'œuvre — on s'abstient tant qu'il le tient.
if [ -e "$HOME/.cache/merlin-agents/playtest-bot.lock" ] \
   && ! flock -n "$HOME/.cache/merlin-agents/playtest-bot.lock" true 2>/dev/null; then
    echo "playtest en cours — on ne coupe pas"
    exit 0
fi

# Même raison pour un test de bout en bout (harnais e2e) : il joue une scène sans qu'aucun
# spectateur ne se connecte, donc le compte de x11vnc est à ZÉRO alors que la machine travaille.
# Sans cette porte, une mesure de plus de cinq minutes serait coupée en plein milieu — et le
# résultat, une fois de plus, ne prouverait rien.
if [ -e "$HOME/.cache/merlin-agents/e2e.lock" ] \
   && ! flock -n "$HOME/.cache/merlin-agents/e2e.lock" true 2>/dev/null; then
    echo "test e2e en cours — on ne coupe pas"
    exit 0
fi

# TOUT HARNAIS, PAS SEULEMENT CEUX QUI ONT PENSE A POSER UN VERROU. Les deux portes ci-dessus
# demandent au travail de se declarer ; celui qui ne connait pas la regle se fait couper. C'est ce
# qui est arrive a la generation de quetes : q83, q84, q89 et q90 sont mortes ici meme, apres
# sept beats sur huit, parce qu'une generation dure ~500 s et que personne ne regarde un harnais.
# q85 est allee plus loin : coupee ici, l'etat desire valait toujours « running », et le veilleur
# a relance le JEU NORMAL a sa place — la mesure a tourne dix minutes sur un menu.
# Trois courses seulement ont abouti, et seulement parce qu'elles finissaient en 420-430 s, juste
# sous le seuil. Le marqueur pose par game-stack dit ce que la course EST, sans qu'elle ait a le
# demander : on ne coupe pas ce qui n'est pas une partie.
HARNAIS="$(cat "$RUNDIR/harness" 2>/dev/null || echo "")"
if [ -n "$HARNAIS" ]; then
    echo "harnais en cours ($HARNAIS) — on ne coupe pas ce qui n'est pas une partie"
    exit 0
fi

etape 2 3 "compter les spectateurs"

# La comptabilité de x11vnc lui-même, et non un comptage de sockets : c'est lui qui sert les
# clients, il sait mieux que nous combien il en a. Réponse de la forme « aro=client_count:N ».
CLIENTS="$(DISPLAY=:99 LD_LIBRARY_PATH="$SYSROOT/usr/lib64:$SYSROOT/usr/lib" \
    timeout 10 "$SYSROOT/usr/bin/x11vnc" -display :99 -query client_count 2>/dev/null \
    | grep -o 'client_count:[0-9]*' | cut -d: -f2)"

if [ -z "$CLIENTS" ]; then
    # Pas de réponse : le jeu n'est probablement plus là, ou x11vnc est mort. On ne coupe RIEN
    # sur une absence de mesure — un garde-fou qui agit sans savoir est pire que pas de garde-fou.
    echo "état des spectateurs illisible — on ne touche à rien"
    exit 0
fi

MAINTENANT="$(date -u +%s)"
if [ "$CLIENTS" -gt 0 ]; then
    printf '%s' "$MAINTENANT" > "$VU_A"
    echo "$CLIENTS spectateur(s) — le jeu reste"
    exit 0
fi

# Zéro spectateur. Depuis quand ? Le fichier survit d'un passage de cron à l'autre — chaque
# exécution est un processus neuf, une variable ne tiendrait pas.
VU="$(cat "$VU_A" 2>/dev/null || echo "")"
if [ -z "$VU" ]; then
    printf '%s' "$MAINTENANT" > "$VU_A"
    echo "plus personne — décompte lancé"
    exit 0
fi

ECOULE=$(( MAINTENANT - VU ))
if [ "$ECOULE" -lt "$SEUIL_S" ]; then
    echo "plus personne depuis ${ECOULE}s — coupure dans $(( SEUIL_S - ECOULE ))s"
    exit 0
fi

etape 3 3 "coupure"

# L'ORDRE COMPTE, et ce n'est pas un détail de style : `desired=stopped` DOIT être écrit AVANT
# l'arrêt. Sinon le veilleur, qui passe toutes les 2 minutes, verrait « désiré=running + jeu
# mort » et le relancerait aussitôt — les deux agents se battraient en boucle, et la machine
# passerait ses nuits à démarrer et arrêter le jeu.
printf 'stopped' > "$RUNDIR/desired"
bash "$GS" stop >/dev/null 2>&1
rm -f "$VU_A" 2>/dev/null

MIN=$(( ECOULE / 60 ))
# Prévenir n'est pas cosmétique : un jeu qui s'arrête sans explication se vit comme une panne,
# et Maxime chercherait un bug qui n'existe pas.
bash "$HERE/notify.sh" low "Jeu mis en veille" \
    "Personne devant depuis ${MIN} min — la machine est rendue au développement. Un tap sur Jouer le relance." \
    "?tab=play" >/dev/null 2>&1

echo "coupé après ${MIN} min sans spectateur — machine rendue au dev"

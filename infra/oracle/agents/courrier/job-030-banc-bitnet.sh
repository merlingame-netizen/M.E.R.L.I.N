#!/usr/bin/env bash
# Banc BitNet b1.58 (Microsoft) — verdict honnête : vitesse ET qualité FRANÇAISE sur
# pièce, mêmes familles de prompts que le labo du récit. Aucune adoption sans ça.
# Build ARM user-mode ; chaque étape qui échoue est DITE, jamais silencieuse.
set -u
NT="https://ntfy.adminforge.de/merlin-courrier-vX9k2Qf7Lw3s"
W="$HOME/.cache/bitnet-banc"
dire() { curl -fsS -m 20 -H "Title: bit30 $1" --data-binary "$2" "$NT" >/dev/null 2>&1; }
mkdir -p "$W"
cd "$W"

if [ ! -d BitNet ]; then
    git clone --depth 1 https://github.com/microsoft/BitNet.git >> "$COURRIER_RES/build.log" 2>&1 \
        || { dire "ko" "clone BitNet impossible"; exit 1; }
fi
cd BitNet
if [ ! -x build/bin/llama-cli ]; then
    dire "etape" "$(date -u +%H:%M:%SZ) build en cours (cmake)"
    { python3 -m pip install --user -q -r requirements.txt 2>/dev/null || true
      cmake -B build -DBITNET_ARM_TL1=ON >> "$COURRIER_RES/build.log" 2>&1 \
        && cmake --build build --config Release -j 3 >> "$COURRIER_RES/build.log" 2>&1; } \
        || { dire "ko" "build KO : $(tail -c 500 "$COURRIER_RES/build.log" | tr '\n' ' ')"; exit 1; }
fi
[ -x build/bin/llama-cli ] || { dire "ko" "llama-cli absent apres build"; exit 1; }

GGUF="$W/bitnet-b1.58-2B-4T.gguf"
if [ ! -s "$GGUF" ]; then
    dire "etape" "$(date -u +%H:%M:%SZ) telechargement GGUF (~1,2 Go)"
    curl -fSL -o "$GGUF" \
      "https://huggingface.co/microsoft/bitnet-b1.58-2B-4T-gguf/resolve/main/ggml-model-i2_s.gguf" \
      >> "$COURRIER_RES/build.log" 2>&1 || { dire "ko" "telechargement GGUF KO"; exit 1; }
fi

bench() {
    nom="$1"; prompt="$2"
    t0=$(date +%s%3N)
    build/bin/llama-cli -m "$GGUF" -p "$prompt" -n 180 --temp 0.7 -t 4 --no-display-prompt \
        > "$COURRIER_RES/$nom.txt" 2>> "$COURRIER_RES/build.log"
    t1=$(date +%s%3N)
    ms=$(( t1 - t0 ))
    cars=$(wc -c < "$COURRIER_RES/$nom.txt")
    dire "mesure" "$nom : ${ms} ms, ${cars} car."
    split -b 250 -d -a 2 "$COURRIER_RES/$nom.txt" /tmp/bn.
    total=$(ls /tmp/bn.* | wc -l | tr -d ' ')
    i=0
    for p in $(ls /tmp/bn.* | sort); do
        i=$((i+1))
        curl -fsS -m 30 -H "Title: bit30-$nom part $i/$total" --data-binary @"$p" "$NT" >/dev/null 2>&1
        sleep 2
    done
    rm -f /tmp/bn.*
}

bench issue "Tu es le conteur d'un jeu de cartes celtique en FRANCAIS. Situation : un vieux rocher moussu porte une pierre gravee d'un cercle brise ; le heros glisse sa main sur les motifs. Raconte l'issue (reussite) en 3 a 5 phrases courtes, 2e personne, present, en excellent francais."
bench scene "Tu es le conteur d'un jeu celtique en FRANCAIS. Ecris la scene suivante (3 phrases, 2e personne, present) : le heros vient d'ouvrir un passage sous un rocher, il s'enfonce dans un chemin brumeux de Broceliande. Un personnage doit agir et parler. Excellent francais uniquement."
bench intro "Tu es Merlin, conteur malicieux, en FRANCAIS. Presente en 5 phrases la quete « Le Retour des Marees de Brouillard » : un chemin qui disparait au coeur d'un chene tordu, la Brume qui menace de prendre les souvenirs du Voyageur. Chaleureux, direct, excellent francais."

dire "fini" "$(date -u +%H:%M:%SZ) banc complet"
echo "banc bitnet termine"

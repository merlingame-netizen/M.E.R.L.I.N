#!/usr/bin/env python3
"""Combien de voies LLM la machine supporte-t-elle VRAIMENT ?

L'architecture du répartiteur repose sur une hypothèse : deux générations à 2 fils rendent
PLUS, au total, qu'une seule à 4 fils. Si c'est vrai on double les agents LLM simultanés ;
si c'est faux, ouvrir une seconde voie ne fait que ralentir tout le monde.

Je ne la crois pas sur parole. Trois intuitions de performance ont été démenties par la
mesure dans la seule journée du 2026-08-15 — dont « raccourcir la sortie fera gagner du
temps », qui a coûté 28 % de tokens pour 2 % de secondes. Ici on mesure, et le nombre de
voies du répartiteur sera celui que le chiffre autorise.

PROTOCOLE. Même prompt, même modèle, même nombre de tokens demandé :
  1) UNE génération seule                         → débit de référence
  2) DEUX générations lancées ensemble            → débit agrégé
Le verdict compare le débit AGRÉGÉ (2) au débit de référence (1). Un gain réel se voit sur
le total produit par seconde, jamais sur la durée d'une génération prise isolément — deux
voies sont forcément plus lentes CHACUNE, ce n'est pas ça la question.

Passe par l'API Ollama et non par le moteur du jeu : c'est Ollama qui sert les agents (le
moteur natif, lui, est single-flight par construction et n'a pas de voies à répartir).
"""
from __future__ import annotations

import json
import statistics
import sys
import threading
import time
import urllib.error
import urllib.request

OLLAMA = "http://127.0.0.1:11434"
PROMPT = ("Écris trois phrases d'ambiance celtique sur une tourbière au crépuscule. "
          "Français simple, images concrètes, pas de liste.")
N_TOKENS = 80        # court : on mesure un débit, pas une œuvre
TIMEOUT = 300


def une_generation(modele: str, resultats: list, index: int) -> None:
    """Une génération, chronométrée. Range (tokens, secondes) dans `resultats[index]`."""
    corps = json.dumps({
        "model": modele, "prompt": PROMPT, "stream": False,
        "options": {"num_predict": N_TOKENS},
    }).encode()
    req = urllib.request.Request(OLLAMA + "/api/generate", data=corps,
                                 headers={"Content-Type": "application/json"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            d = json.loads(r.read().decode("utf-8", "replace"))
        # `eval_count` = tokens réellement produits. On ne se fie PAS à N_TOKENS : le modèle
        # peut s'arrêter avant, et compter la demande plutôt que la livraison gonflerait le
        # débit d'autant.
        resultats[index] = (int(d.get("eval_count", 0)), time.time() - t0)
    except Exception as e:
        resultats[index] = (0, time.time() - t0)
        print(f"  (voie {index + 1} en échec : {type(e).__name__})", file=sys.stderr)


def mesure(modele: str, n_voies: int, repetitions: int) -> float:
    """Débit AGRÉGÉ en tokens/s pour `n_voies` générations simultanées."""
    debits = []
    for _ in range(repetitions):
        resultats: list = [None] * n_voies
        fils = [threading.Thread(target=une_generation, args=(modele, resultats, i))
                for i in range(n_voies)]
        t0 = time.time()
        for f in fils:
            f.start()
        for f in fils:
            f.join()
        mur = time.time() - t0
        total_tokens = sum(r[0] for r in resultats if r)
        # Débit agrégé : TOUT ce qui a été produit, divisé par le temps mur du lot. C'est la
        # seule grandeur qui répond à « la machine rend-elle plus ? ».
        if mur > 0 and total_tokens > 0:
            debits.append(total_tokens / mur)
    return statistics.median(debits) if debits else 0.0


def main() -> int:
    modele = sys.argv[1] if len(sys.argv) > 1 else "gemma4:e4b-it-qat"
    reps = int(sys.argv[2]) if len(sys.argv) > 2 else 2

    print(f"modèle : {modele} · {reps} répétition(s) · {N_TOKENS} tokens demandés")
    # Une passe à blanc d'abord : la toute première génération paie le chargement du modèle
    # en mémoire. La compter fausserait la référence vers le bas et ferait paraître la
    # seconde configuration meilleure qu'elle n'est.
    print("chauffe…")
    mesure(modele, 1, 1)

    une = mesure(modele, 1, reps)
    print(f"  1 voie  : {une:.2f} tok/s")
    deux = mesure(modele, 2, reps)
    print(f"  2 voies : {deux:.2f} tok/s (agrégé)")

    gain = (deux / une - 1.0) * 100 if une > 0 else 0.0
    # Seuil à +15 % : en dessous, le gain ne paie pas la complexité d'un répartiteur à deux
    # voies ni le risque de rendre la machine moins réactive quand Maxime veut la main.
    verdict = "DEUX VOIES" if gain >= 15 else "UNE VOIE"
    print(f"  gain    : {gain:+.0f} %  →  répartiteur à {verdict}")

    sortie = {"modele": modele, "une_voie_tok_s": round(une, 2),
              "deux_voies_tok_s": round(deux, 2), "gain_pct": round(gain, 1),
              "voies_recommandees": 2 if gain >= 15 else 1,
              "t": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    print("[VOIES_JSON] " + json.dumps(sortie, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

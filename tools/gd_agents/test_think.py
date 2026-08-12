#!/usr/bin/env python3
"""Garde-fou : TOUT appel à Ollama doit poser `think` explicitement.

Mesuré sur la VM le 2026-08-12 avec gemma4 :

    think=False  →  « Bonjour ! »   eval=3   done_reason=stop
    think=True   →  (vide)          eval=60  done_reason=length   191 car de réflexion
    think ABSENT →  (vide)          eval=60  done_reason=length   0 car de réflexion

Autrement dit : **omettre le champ se comporte comme think=true**. Le modèle
brûle tout son budget de tokens en réflexion interne et rend une chaîne vide.
C'est la cause des « LLM indisponible — rc=0 » qui remplissaient le journal, et
elle a touché jusqu'au générateur de scénarios DU JEU.

Ce test échoue si un nouvel appelant oublie le champ. Il ne parle à aucun
serveur : il lit le code.

    python3 tools/gd_agents/test_think.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Fichiers qui construisent une requête Ollama de génération. On ne balaie pas
# tout le dépôt : une liste explicite se maintient, un balayage se contourne.
SURVEILLES = [
    "infra/oracle/llm/llm-ask.sh",
    "infra/oracle/agents/a_llm_bench.sh",
    "tools/cockpit/control_loops.py",
    "tools/merlin_studio/actions.py",
    "addons/merlin_ai/ollama_backend.gd",
]

# Une requête de génération se reconnaît à ces marqueurs.
APPEL = re.compile(r'api/(generate|chat)')
POSE_THINK = re.compile(r'["\']think["\']\s*[:=]|payload\[["\']think["\']\]')


def verifier() -> list[str]:
    manques = []
    for rel in SURVEILLES:
        p = ROOT / rel
        if not p.exists():
            manques.append(f"{rel} : fichier introuvable (liste à mettre à jour)")
            continue
        txt = p.read_text(encoding="utf-8", errors="replace")
        if not APPEL.search(txt):
            continue                      # ne parle plus à Ollama : rien à exiger
        if not POSE_THINK.search(txt):
            manques.append(f"{rel} : appelle Ollama SANS poser `think` "
                           "→ réponses vides garanties")
    return manques


if __name__ == "__main__":
    m = verifier()
    if m:
        print("ÉCHEC — think non posé :")
        for x in m:
            print("  ·", x)
        sys.exit(1)
    print(f"OK — les {len(SURVEILLES)} appelants d'Ollama posent tous `think`.")

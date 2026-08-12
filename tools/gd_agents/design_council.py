#!/usr/bin/env python3
"""Conseil de design QUOTIDIEN — un conseiller ouvre la conversation de lui-même.

Chaque matin, un conseiller différent (rotation sur les fiches de game design)
relit la mémoire du design retenu et les décisions récentes, puis ouvre une
conversation dans l'onglet Parler : une courte réflexion + deux questions
franches à Maxime. La discussion se poursuit dans Parler ; les règles qui en
émergent se gravent (MEMORISER:) comme dans tout chat.
"""
from __future__ import annotations

import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import memory       # noqa: E402
import prompts      # noqa: E402

LLM_ASK = HERE.parents[1] / "infra" / "oracle" / "llm" / "llm-ask.sh"
# Rotation : les conseillers les plus pertinents pour interroger le design.
PANEL = ["gd_difficulty", "gd_economy", "gd_pacing", "gd_reward_loop",
         "gd_faction_dynamics", "gd_narrative_flow", "gd_onboarding",
         "gd_endgame", "game_designer", "balance_tuner", "ux_flow",
         "game_design_auditor"]


def main() -> int:
    conv = "conseil-" + time.strftime("%Y%m%d")
    if memory.chat_read(conv, limit=1):
        print("conseil du jour déjà ouvert")
        return 0
    adviser = PANEL[int(time.strftime("%j")) % len(PANEL)]
    card = f".claude/agents/{adviser}.md"
    persona = prompts.compile_prompt(card) if (prompts.ROOT / card).exists() else ""
    prompt = (
        f"{persona}\n\n"
        f"MÉMOIRE DU DESIGN RETENU :\n{memory.digest(700)}\n\n"
        "Tu ouvres le conseil de design du jour avec Maxime, le créateur du jeu. "
        "En FRANÇAIS, sans jargon : 2-3 phrases de réflexion sur UNE décision "
        "récente de la mémoire (ou une tension que tu y vois), puis EXACTEMENT "
        "deux questions courtes et franches qui l'aident à trancher ou approfondir. "
        "Ne poste rien d'autre.")
    try:
        p = subprocess.run(["bash", str(LLM_ASK), "--timeout", "420", "--ctx", "2048"],
                           input=prompt, capture_output=True, text=True, timeout=480)
        text = (p.stdout or "").strip()
    except Exception:
        text = ""
    if not text:
        # Repli sans LLM : le conseil a quand même lieu, sur pièces.
        recent = memory.entries(limit=3)
        pts = "\n".join(f"· {e['title']}" for e in recent) or "· (mémoire encore vide)"
        text = ("Le modèle local était indisponible ce matin — voici tout de même "
                f"les dernières décisions à relire :\n{pts}\n\n"
                "Deux questions : laquelle mérite d'être affinée ? "
                "Y en a-t-il une que tu regrettes déjà ?")
    memory.chat_append(conv, "assistant", adviser, text)
    subprocess.run(["bash", str(HERE.parents[1] / "infra" / "oracle" / "agents" / "notify.sh"),
                    "low", "Conseil de design",
                    f"Le conseiller du jour t'attend dans Parler ({adviser})."],
                   capture_output=True, timeout=20)
    print(f"conseil ouvert ({conv}, conseiller {adviser}, {len(text)} car.)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

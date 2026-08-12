#!/usr/bin/env python3
"""Répond dans une conversation du chat interne — Gemma local, en asynchrone.

Lancé détaché par le portail (le e4b écrit à ~1 tok/s : la réponse arrive au
fil de l'eau, le front la découvre en re-lisant la conversation). Le prompt
reçoit : la fiche du conseiller choisi (compilée), la MÉMOIRE du design retenu,
et l'historique récent. Réponses courtes, français, aucun métalangage.

    python3 chat_reply.py <conv_id> <agent_file|merlin>
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import chat_actions  # noqa: E402
import memory        # noqa: E402
import prompts       # noqa: E402

LLM_ASK = HERE.parents[1] / "infra" / "oracle" / "llm" / "llm-ask.sh"


def main(conv: str, adviser: str) -> int:
    rows = memory.chat_read(conv, limit=10)
    if not rows or rows[-1]["role"] != "user":
        print("rien à répondre")
        return 0
    if adviser and adviser not in ("merlin", "") and Path(prompts.ROOT / adviser).exists():
        persona = prompts.compile_prompt(adviser)
        who = Path(adviser).stem
    else:
        persona = ("Tu es la mémoire vivante du studio MERLIN : tu connais chaque "
                   "décision de game design retenue et tu aides Maxime à y voir clair.")
        who = "merlin"
    hist = "\n".join(f"{'Maxime' if r['role'] == 'user' else r['who']} : {r['text'][:300]}"
                     for r in rows[-8:])
    base = (
        f"{persona}\n\n"
        f"MÉMOIRE DU DESIGN RETENU (ne contredis jamais ces décisions) :\n"
        f"{memory.digest(600)}\n\n"
        f"CONVERSATION :\n{hist}\n\n"
        "Réponds à Maxime en FRANÇAIS, 2 à 4 phrases, concret et sans jargon.")
    # Deux versions : avec le catalogue d'actions, et une version nue de secours.
    prompt = base + "\n\n" + chat_actions.catalogue_for_prompt()
    prompt_plain = base
    # Le chat est INTERACTIF : il tourne sur le modèle rapide (e4b, 10 tok/s),
    # jamais sur le 12b de triage (4 tok/s) qui ferait patienter des minutes.
    import os
    conf = Path.home() / ".config" / "merlin-llm.env"
    model = "gemma4:e4b-it-qat"
    try:
        for line in conf.read_text().splitlines():
            if "COPILOT_MODEL" in line:
                model = line.split("=", 1)[1].strip()
    except Exception:
        pass
    def _one(pr: str) -> str:
        try:
            p = subprocess.run(["bash", str(LLM_ASK), "--model", model,
                                "--predict", "280", "--timeout", "200", "--ctx", "2048"],
                               input=pr, capture_output=True, text=True, timeout=240)
            return (p.stdout or "").strip()
        except Exception:
            return ""
    reply = _one(prompt)
    # Filet : certains prompts (catalogue d'actions) font rendre du vide au e4b.
    # On réessaie alors en conversation pure — le chat répond TOUJOURS.
    if not reply:
        reply = _one(prompt_plain)
    if not reply:
        memory.chat_append(conv, "assistant", who,
                           "(je n'ai pas réussi à répondre — le modèle local était "
                           "indisponible ; réessaie dans une minute)")
        return 1
    # Une proposition de souvenir dans la réponse → gravée, et signalée.
    if "MEMORISER:" in reply:
        head, _, rule = reply.partition("MEMORISER:")
        rule = rule.strip()[:200]
        if rule:
            memory.add("règle", rule, f"issue de la conversation {conv}",
                       source=f"chat/{who}")
            reply = head.strip() + f"\n\n📌 J'ai gravé dans la mémoire : « {rule} »"
    # Actions proposées : extraites du texte, validées, attachées au message.
    reply, actions = chat_actions.parse(reply)
    memory.chat_append(conv, "assistant", who, reply, actions=actions)
    print(f"réponse écrite ({len(reply)} car., {len(actions)} action(s) proposée(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "merlin"))

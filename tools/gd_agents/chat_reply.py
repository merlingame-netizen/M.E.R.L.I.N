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
import time
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
        persona = (
            "Tu es MERLIN, le CHEF D'ORCHESTRE du studio de développement du jeu "
            "MERLIN. Tu discutes avec Maxime, le créateur, et tu commandes tous les "
            "agents automatiques du studio. Tu peux : répondre à ses questions sur le "
            "jeu et son design ; régler les agents (activer, ralentir, lancer) ; "
            "entretenir la mémoire ; créer de nouveaux agents ; prévoir des tâches de "
            "dev. Tu es concret et direct.\n"
            "IMPORTANT — tu ORCHESTRES : si la demande de Maxime demande PLUSIEURS "
            "étapes, décompose-la en plusieurs lignes ACTION (une par étape) ; il les "
            "validera d'un seul tap « Tout lancer ». Une demande simple = une seule "
            "action. Ne propose que des actions réellement utiles à ce qu'il demande.")
        who = "merlin"
    hist = "\n".join(f"{'Maxime' if r['role'] == 'user' else r['who']} : {r['text'][:300]}"
                     for r in rows[-8:])
    # La carte du jeu : sans elle, le modèle ne sait pas qu'un écran MERLIN
    # existe séparément du biome — mesuré, il a interverti les deux et la mission
    # partie au codeur visait le mauvais écran.
    try:
        import parcours
        carte = parcours.condense(1400)
    except Exception:
        carte = ""
    base = (
        f"{persona}\n\n"
        + (f"=== LE JEU, TEL QU'IL EST CODÉ ===\n{carte}\n=== FIN DE LA CARTE ===\n\n"
           if carte else "")
        + f"=== ÉTAT RÉEL DU STUDIO (utilise CES données, n'invente rien) ===\n"
        f"{chat_actions.studio_state()}\n"
        f"=== FIN DE L'ÉTAT ===\n\n"
        f"CONVERSATION :\n{hist}\n\n"
        "Réponds à Maxime en FRANÇAIS. Règles de style STRICTES :\n"
        "- ne dis JAMAIS « Bonjour » si la conversation a déjà commencé ;\n"
        "- réponds DIRECTEMENT à la question, sans préambule ni « je peux te… » ;\n"
        "- s'il demande une liste, DONNE la liste complète avec les vrais noms et "
        "cadences ci-dessus, pas une promesse de la donner ;\n"
        "- cite des chiffres et des noms réels, jamais de généralités ;\n"
        "- quand il parle d'un ÉCRAN ou d'un MOMENT du jeu, NOMME l'écran de la "
        "carte ci-dessus et le fichier concerné. Si tu n'es pas sûr de l'écran, "
        "DIS-LE et demande — ne devine jamais ;\n"
        "- ne REFORMULE pas sa demande dans tes propres mots : reprends ses termes "
        "exacts. S'il dit « MERLIN », ne dis pas « le biome ».")
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
                                "--predict", "400", "--timeout", "280", "--ctx", "4096"],
                               input=pr, capture_output=True, text=True, timeout=240)
            return (p.stdout or "").strip()
        except Exception:
            return ""

    # Le verrou LLM PARTAGÉ : ce module était le seul consommateur à ne pas le
    # prendre. Deux modèles de 6,1 Go pouvaient donc se charger en même temps sur
    # 22 Go, la VM partait en swap, et l'appel rendait du vide — exactement la
    # signature « LLM indisponible — rc=0 » qu'on lit dans le journal.
    import contextlib

    @contextlib.contextmanager
    def _verrou_llm(attente=600):
        lock = Path.home() / ".cache" / "merlin-agents" / "llm.lock"
        lock.parent.mkdir(parents=True, exist_ok=True)
        f = lock.open("a+")
        try:
            try:
                import fcntl
                debut = time.time()
                while True:
                    try:
                        fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                        break
                    except OSError:
                        if time.time() - debut > attente:
                            break        # on répond quand même : le chat prime
                        time.sleep(2)
            except Exception:
                pass
            yield
        finally:
            with contextlib.suppress(Exception):
                f.close()

    # Les deux tentatives sous LE MÊME verrou : le relâcher entre les deux
    # laisserait un autre agent charger son modèle pile entre l'échec et le
    # repli, et le repli échouerait pour la même raison que l'appel initial.
    with _verrou_llm():
        reply = _one(prompt)
        # Filet : certains prompts (catalogue d'actions) font rendre du vide au
        # e4b. On réessaie alors en conversation pure — le chat répond TOUJOURS.
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
    # Le modèle met parfois tout dans les lignes ACTION → texte vide. On habille.
    if not reply.strip() and actions:
        reply = (f"Voici le plan que je te propose ({len(actions)} étapes) — "
                 "valide-le d'un tap." if len(actions) > 1
                 else "Voici ce que je te propose — valide-le d'un tap.")
    memory.chat_append(conv, "assistant", who, reply, actions=actions)
    print(f"réponse écrite ({len(reply)} car., {len(actions)} action(s) proposée(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "merlin"))

#!/usr/bin/env python3
"""Runner des agents de game design — analyseur → prompt → routeur → proposition.

Principe qui rend un e4b utilisable sur 4 cœurs ARM : **le LLM ne calcule
jamais un chiffre**. Un analyseur Python déterministe produit les preuves ; le
modèle ne fait que les mettre en mots (ou rédiger la carte). D'où le repli
central : si le LLM est indisponible ou incohérent, l'analyseur a déjà tourné
et on écrit une proposition « preuves seules » — la boucle produit toujours
quelque chose.

    python3 tools/gd_agents/runner.py gd-content-gap [--dry-run]

Écrit UNE ligne de résumé sur stdout (contrat de infra/oracle/agents/agent-run.sh).
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(ROOT / "tools" / "lora"))

import prompts as PR          # noqa: E402
import proposals as PROP      # noqa: E402
import router as ROUTER       # noqa: E402

LLM_ASK = ROOT / "infra" / "oracle" / "llm" / "llm-ask.sh"
AGENTS = HERE / "agents.json"


def _agents() -> dict:
    return {a["id"]: a for a in json.loads(AGENTS.read_text(encoding="utf-8"))["agents"]}


def _load_analyzer(name: str):
    mod = __import__(f"analyzers.{name}", fromlist=["analyze"])
    return mod


def _ask(prompt: str, plan: dict, timeout: int) -> tuple[str, str]:
    """Un appel LLM → (réponse, raison d'échec).

    La raison est REMONTÉE jusqu'à la proposition : sans elle, un échec coûte
    des minutes et ne dit rien. Rend ("", motif) si indisponible — l'appelant
    DOIT avoir un repli.
    """
    import os
    env = {"OLLAMA_NUM_THREAD": str(plan["num_thread"]),
           "OLLAMA_KEEP_ALIVE": plan["keep_alive"]}
    try:
        p = subprocess.run(
            ["bash", str(LLM_ASK), "--model", plan["tag"], "--ctx", str(plan["ctx"]),
             "--predict", str(plan.get("out_tokens", 320)), "--timeout", str(timeout)],
            input=prompt, capture_output=True, text=True,
            timeout=timeout + 30, env={**os.environ, **env})
        if p.returncode == 0 and (p.stdout or "").strip():
            return p.stdout.strip(), ""
        return "", (p.stderr or "").strip().replace("\n", " ")[:200] or f"rc={p.returncode}"
    except subprocess.TimeoutExpired:
        return "", f"timeout après {timeout + 30}s"
    except Exception as exc:
        return "", f"{type(exc).__name__}: {exc}"[:200]


def _extract_json(text: str):
    """Le modèle enrobe souvent son JSON de prose. On récupère le premier objet."""
    try:
        return json.loads(text)
    except Exception:
        pass
    m = re.search(r"\{.*\}", text, re.S)
    if m:
        for cand in (m.group(0), m.group(0).replace("'", '"')):
            try:
                return json.loads(cand)
            except Exception:
                continue
    return None


def run(agent_id: str, dry: bool = False) -> str:
    cfg = _agents().get(agent_id)
    if not cfg:
        return f"agent inconnu: {agent_id}"
    t0 = time.time()

    # 1. Preuves déterministes — toujours, même si le LLM est mort.
    ana = _load_analyzer(cfg["analyzer"])
    a = ana.analyze()
    evidence = ana.evidence(a)

    # 2. Palier + prompt compilé.
    plan = ROUTER.choose(cfg["shape"], cfg["out_tokens"], cfg["deadline_s"],
                         cfg.get("evidence_tokens", 600))
    system = PR.compile_prompt(cfg["card"])
    # La mémoire absolue encadre TOUT agent : ce qui est décidé ne se re-propose
    # pas, ce qui est rejeté ne revient pas sous un autre nom.
    try:
        import memory
        # Ce que Maxime a répondu À CET AGENT passe AVANT le condensé général :
        # c'est plus court, plus récent et plus décisif. Le bloc REMPLACE une
        # part du digest au lieu de s'y ajouter — le budget de contexte est fixe.
        sien = memory.reponses_de_maxime(agent_id, limit=4)
        mem = memory.digest(600 - len(sien))
        if sien:
            system += ("\n\nCE QUE MAXIME T'A RÉPONDU (ses mots, à respecter avant "
                       f"tout le reste) :\n{sien}")
        if mem and "vide" not in mem:
            system += f"\n\nDESIGN DÉJÀ DÉCIDÉ (à respecter, ne pas re-proposer) :\n{mem}"
    except Exception:
        pass
    # La consigne de sortie vient du CONTRAT de l'agent, pas d'une constante.
    # Elle était codée en dur au format « carte de scénario » et collée au prompt
    # de TOUS les agents : un agent d'analyse recevait donc trois consignes
    # contradictoires, et pouvait répondre « { » là où on attendait une phrase.
    CARTE = ('Réponds UNIQUEMENT par un objet JSON : {"text": "…", "biome": "…", '
             '"options": [{"label": "…", "verb": "…", "effects": [{"type": "ADD_REPUTATION", '
             '"faction": "druides", "amount": 5}]}]} — exactement 3 options.')
    ANALYSE = ("Réponds en français, en prose, 4 phrases maximum. Pas de JSON, pas de "
               "liste à puces. Première phrase = le constat, chiffres à l'appui.")
    schema_hint = cfg.get("output_hint") or (CARTE if cfg["kind"] == "content" else ANALYSE)
    prompt = f"{system}\n\n{schema_hint}\n\n{ana.brief(a)}"
    # Attend-on du JSON de cet agent ? C'est ce qui décide si une réponse sans
    # JSON est un échec (donc une escalade) ou le résultat normal.
    # On le lit dans le CONTRAT, jamais dans le texte de la consigne : celle des
    # agents d'analyse contient le mot « JSON » dans « Pas de JSON », et une
    # détection par mot-clé y répondait exactement à l'envers.
    attend_json = bool(cfg.get("attend_json", cfg["kind"] == "content"))

    # Si le routeur refuse, sa raison EST le diagnostic (aucun appel n'aura lieu).
    card, raw, escal = None, "", 0
    why = "" if plan["ok"] else plan.get("reason", "aucun palier utilisable")
    if plan["ok"] and not dry:
        for escal in range(0, ROUTER._load_tiers()["gates"]["max_escalations"] + 1):
            if escal:                       # G5 : un rejet → un palier au-dessus
                plan = ROUTER.choose(cfg["shape"], cfg["out_tokens"], cfg["deadline_s"],
                                     cfg.get("evidence_tokens", 600), escalate=escal)
                if not plan["ok"]:
                    break
            raw, why = _ask(prompt, plan, plan["est_secs"] * 2 + 90)
            card = _extract_json(raw)
            if card:
                why = ""
                break
            # Un agent d'ANALYSE doit répondre en prose : sa consigne INTERDIT le
            # JSON. Juger sa réussite sur `card` le condamnait donc à échouer à
            # tous les coups et à escalader d'un palier — un appel 12b à
            # 4 tok/s, 7 Go rechargés, deux fois par jour, pour rien.
            if attend_json is False and raw:
                why = ""
                break
            # Réessayer à l'identique après un échec d'infrastructure est du
            # temps perdu : on n'escalade que si le modèle a bien répondu.
            if not raw:
                break

    # 3. Validation déterministe de ce que le modèle a produit.
    verdict, errs = {}, []
    if card is not None:
        try:
            import scenario_validator as sv
            errs, warns = sv.validate_card(card)
            verdict = {"validator": "scenario_validator",
                       "errors": len(errs), "warnings": len(warns),
                       "codes": [str(e)[:60] for e in errs[:4]]}
        except Exception as exc:
            # Un validateur ABSENT ne doit jamais valoir « validé ». En laissant
            # `errs` vide ici, `ok_card` passait à True et la carte était
            # auto-intégrée au corpus d'entraînement avec la mention « validé sans
            # erreur ni avertissement » — sans qu'aucune règle n'ait été vérifiée.
            errs = [f"validateur indisponible ({type(exc).__name__})"]
            verdict = {"validator": "indisponible", "error": str(exc)[:80],
                       "errors": 1, "codes": errs}

    secs = int(time.time() - t0)
    ok_card = card is not None and not errs

    # 4. Proposition — dégradée mais réelle si le LLM a failli.
    # Sujet de la proposition : chaque analyseur nomme sa cible à sa façon.
    sujet = (a.get("biome") or a.get("faction_faible")
             or a.get("sujet") or cfg["label"])
    if cfg["kind"] == "content" and ok_card:
        title = f"Nouvelle carte pour « {sujet} » ({a.get('lexical_field', '')})"
        claim = ("Le canon signale une lacune sur ce biome ; cet exemple d'entraînement "
                 "la comble et passe le validateur sans erreur.")
        change = {"summary": str(card.get("text", ""))[:400],
                  "target": "data/ai/training/curated_corpus.jsonl"}
        mission = (f"Exemple d'entraînement pour {sujet} — accepté, il rejoint le jeu "
                   f"d'entraînement du modèle MERLIN.")
        conf, payload = (0.75 if not verdict.get("warnings") else 0.6), card
    elif raw and cfg["kind"] != "content":
        # Agents d'ANALYSE (équilibrage, audit…) : la prose du modèle EST la
        # proposition ; il n'y a pas de carte JSON à valider.
        #
        # Nouveauté v17 : si l'analyseur a trouvé un écart MÉCANIQUE, il sait
        # produire le diff exact (`change()`), et la proposition le porte. C'est
        # ce couple before/after — et lui seul — que le codeur local sait
        # appliquer. Sans lui, accepter n'a jamais rien produit.
        title = f"{cfg['label']} : {sujet}"
        claim = raw.strip().split("\n")[0][:300]
        change = {"summary": raw.strip()[:700], "target": "à décider avec Maxime"}
        patch = getattr(ana, "change", lambda _a: None)(a)
        if patch and patch.get("before"):
            change = {**patch, "summary": patch.get("summary", "")[:400],
                      "justification": raw.strip()[:500]}
            title = f"{cfg['label']} — correction : {patch['summary'][:70]}"
        mission = raw.strip()[:1500]
        conf, payload = (0.8 if change.get("before") else 0.65), None
    else:
        why = (f"LLM indisponible — {why}" if not raw else
               "JSON illisible" if card is None else
               f"{len(errs)} erreur(s) de validation : {'; '.join(str(e)[:50] for e in errs[:2])}")
        title = f"{cfg['label']} — analyse seule sur « {sujet} » ({why})"
        claim = (f"L'analyse a produit ses chiffres, mais la rédaction automatique "
                 f"a échoué : {why}.")
        change = {"summary": ana.brief(a)[:600], "target": "—"}
        mission = f"Reprendre à la main l'analyse suivante :\n{ana.brief(a)[:1200]}"
        conf, payload = 0.2, None
        # Un écart mécanique est calculé par du Python : il reste valable même
        # quand le LLM est mort. On perd la belle explication, pas la correction.
        patch = getattr(ana, "change", lambda _a: None)(a)
        if patch and patch.get("before"):
            change = {**patch, "summary": patch.get("summary", "")[:400]}
            title = f"{cfg['label']} — correction : {patch['summary'][:70]}"
            claim = f"Écart mesuré dans le code : {patch['summary'][:220]}"
            conf = 0.7          # le chiffre est sûr ; seule la prose manque

    kind = cfg["kind"] if (ok_card or cfg["kind"] != "content") else "design"
    prop = PROP.make(
        agent_id, kind, title, claim, change, mission,
        evidence=evidence,
        impact={"axis": "contenu" if kind == "content" else "équilibrage",
                "expected": f"sur « {sujet} »", "risk": "low"},
        confidence=conf,
        model=plan.get("tag") or "none", tier=plan.get("tier"),
        cost={"secs": secs, "tokens_out": len(raw) // 4, "escalations": escal,
              "tier_final": plan.get("tier")},
        validation=verdict, payload=payload)

    if dry:
        return f"[dry] {title} · palier={plan.get('tier')} · {secs}s"

    # Doctrine « auto sauf stratégique » : une CARTE validée sans erreur est du
    # contenu à faible risque → intégrée seule au corpus curé. Tout le reste
    # (équilibrage, design, bugs) reste une décision pour Maxime.
    if ok_card and cfg["kind"] == "content" and not verdict.get("warnings"):
        PROP.write(prop)
        res = PROP.decide(prop["id"], "accept", "auto : contenu validé sans erreur ni avertissement")
        return (f"carte auto-intégrée {prop['id']} ({res.get('effect', '?')}, "
                f"palier {plan.get('tier')}, {secs}s)")
    PROP.write(prop)
    return (f"proposition {prop['id']} écrite (palier {plan.get('tier')}, "
            f"{secs}s, confiance {conf})")


def main(argv=None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("agent")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    try:
        print(run(a.agent, a.dry_run))
        return 0
    except Exception as exc:                 # un agent ne fait jamais tomber le cron
        print(f"échec {a.agent}: {type(exc).__name__}: {exc}"[:200])
        return 1


if __name__ == "__main__":
    sys.exit(main())

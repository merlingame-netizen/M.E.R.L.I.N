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
            ["bash", str(LLM_ASK), "--model", plan["tag"],
             "--ctx", str(plan["ctx"]), "--timeout", str(timeout)],
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
    schema_hint = (
        'Réponds UNIQUEMENT par un objet JSON : {"text": "…", "biome": "…", '
        '"options": [{"label": "…", "verb": "…", "effects": [{"type": "ADD_REPUTATION", '
        '"faction": "druides", "amount": 5}]}]} — exactement 3 options.')
    prompt = f"{system}\n\n{schema_hint}\n\n{ana.brief(a)}"

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
            verdict = {"validator": "indisponible", "error": str(exc)[:80]}

    secs = int(time.time() - t0)
    ok_card = card is not None and not errs

    # 4. Proposition — dégradée mais réelle si le LLM a failli.
    if ok_card:
        title = f"Nouvelle carte pour « {a['biome']} » ({a['lexical_field']})"
        claim = (f"Le canon signale une lacune sur ce biome ; cette carte la comble "
                 f"et passe le validateur sans erreur.")
        change = {"summary": str(card.get("text", ""))[:400],
                  "target": "data/ai/training/curated_corpus.jsonl"}
        mission = f"Carte générée pour {a['biome']} — acceptée, elle rejoint le corpus curé."
        conf = 0.75 if not verdict.get("warnings") else 0.6
        payload = card
    else:
        why = (f"LLM indisponible — {why}" if not raw else
               "JSON illisible" if card is None else
               f"{len(errs)} erreur(s) de validation : {'; '.join(str(e)[:50] for e in errs[:2])}")
        title = f"Lacune de contenu non comblée sur « {a['biome']} » ({why})"
        claim = (f"L'analyse a identifié la lacune et rassemblé les contraintes, "
                 f"mais la rédaction automatique a échoué : {why}.")
        change = {"summary": ana.brief(a)[:600],
                  "target": "data/ai/training/curated_corpus.jsonl"}
        mission = (f"Rédiger à la main une carte pour le biome {a['biome']}, champ "
                   f"lexical {a['lexical_field']}, verbes autorisés : "
                   f"{', '.join(a['verbs'])}. Lacune visée : {a['gap']}")
        conf, payload = 0.2, None

    prop = PROP.make(
        agent_id, cfg["kind"] if ok_card else "design", title, claim, change, mission,
        evidence=evidence,
        impact={"axis": "contenu", "expected": f"+1 carte sur {a['biome']}",
                "risk": "low"},
        confidence=conf,
        model=plan.get("tag") or "none", tier=plan.get("tier"),
        cost={"secs": secs, "tokens_out": len(raw) // 4, "escalations": escal,
              "tier_final": plan.get("tier")},
        validation=verdict, payload=payload)

    if dry:
        return f"[dry] {title} · palier={plan.get('tier')} · {secs}s"
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

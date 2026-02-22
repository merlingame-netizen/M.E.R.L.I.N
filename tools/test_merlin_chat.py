#!/usr/bin/env python3
"""
test_merlin_chat.py — Test CLI hors-jeu pour Merlin (Qwen 2.5-3B-Instruct)

Utilise l'API Ollama pour tester le comportement de Merlin sans lancer Godot.
Charge la persona depuis merlin_persona.json.

Usage:
    python tools/test_merlin_chat.py --mode chat
    python tools/test_merlin_chat.py --mode benchmark
    python tools/test_merlin_chat.py --mode card
    python tools/test_merlin_chat.py --mode gamemaster

Prerequis: Ollama running (ollama serve) avec qwen2.5-3b-instruct pull.
"""

import argparse
import json
import os
import random
import re
import sys
import time
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

try:
    import requests
except ImportError:
    print("ERREUR: requests non installe. pip install requests")
    sys.exit(1)

# --- Config ---
PROJECT_ROOT = Path(__file__).resolve().parent.parent
PERSONA_PATH = PROJECT_ROOT / "data" / "ai" / "config" / "merlin_persona.json"
PROMPT_TEMPLATES_PATH = PROJECT_ROOT / "data" / "ai" / "config" / "prompt_templates.json"
OLLAMA_URL = "http://127.0.0.1:11434"
DEFAULT_MODEL = "qwen2.5:1.5b"


def load_json(path: Path) -> dict:
    if not path.exists():
        print(f"ERREUR: Fichier introuvable: {path}")
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def load_persona() -> dict:
    return load_json(PERSONA_PATH)


def load_prompt_templates() -> dict:
    return load_json(PROMPT_TEMPLATES_PATH)


def check_ollama() -> bool:
    try:
        r = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        return r.status_code == 200
    except requests.ConnectionError:
        return False


def generate(model: str, system: str, messages: list[dict],
             temperature: float = 0.75, max_tokens: int = 200) -> tuple[str, float, dict]:
    payload = {
        "model": model,
        "messages": [{"role": "system", "content": system}] + messages,
        "stream": False,
        "options": {
            "temperature": temperature,
            "top_p": 0.92,
            "top_k": 40,
            "repeat_penalty": 1.35,
            "num_predict": max_tokens,
        },
    }
    start = time.time()
    r = requests.post(f"{OLLAMA_URL}/api/chat", json=payload, timeout=120)
    elapsed = time.time() - start

    if r.status_code != 200:
        return f"[ERREUR HTTP {r.status_code}]", elapsed, {}

    data = r.json()
    text = data.get("message", {}).get("content", "").strip()
    eval_count = data.get("eval_count", 0)
    eval_dur = data.get("eval_duration", 0) / 1e6  # ms
    tps = eval_count / (eval_dur / 1000) if eval_dur > 0 else 0
    return text, elapsed, {"eval_count": eval_count, "tok_per_sec": tps}


def add_few_shots(messages: list[dict], few_shots: list[dict]) -> list[dict]:
    prefix = []
    if few_shots:
        selected = random.sample(few_shots, min(3, len(few_shots)))
        for fs in selected:
            prefix.append({"role": "user", "content": fs["user"]})
            prefix.append({"role": "assistant", "content": fs["assistant"]})
    return prefix + messages


def check_persona_compliance(response: str, persona: dict) -> dict:
    violations = []
    response_lower = response.lower()

    for word in persona.get("forbidden_words", []):
        if word.lower() in response_lower:
            violations.append(f"Mot interdit: '{word}'")

    english_markers = [
        "the ", " is ", " are ", " you ", " i am ", " my name",
        " hello ", " welcome ", " please ", " thank ", " sorry ",
        " what ", " where ", " when ", " how ", " why ", " because "
    ]
    for marker in english_markers:
        if marker in response_lower:
            violations.append(f"Anglais detecte: '{marker.strip()}'")

    if len(response) > 500:
        violations.append(f"Trop long: {len(response)} chars (max 500)")
    if len(response.strip()) < 5:
        violations.append("Reponse trop courte ou vide")

    score = max(0.0, 1.0 - len(violations) * 0.25)
    return {"valid": len(violations) == 0, "violations": violations, "score": score, "length": len(response)}


R = "\033[0m"
G = "\033[92m"
RED = "\033[91m"
Y = "\033[93m"
DIM = "\033[2m"
B = "\033[1m"
CYAN = "\033[96m"


# =============================================================================
# MODES
# =============================================================================

def mode_chat(model: str, persona: dict, args: argparse.Namespace) -> None:
    print(f"\n{B}=== MERLIN CHAT — Qwen 2.5-3B (tapez 'quit' pour quitter) ==={R}")
    print(f"{DIM}Modele: {model} | T={args.temperature} | max_tok={args.max_tokens}{R}\n")

    messages = []
    system = persona["executor_system"]
    few_shots = persona.get("few_shot", [])

    while True:
        try:
            user_input = input(f"{CYAN}Vous>{R} ")
        except (EOFError, KeyboardInterrupt):
            print("\nAu revoir, Voyageur.")
            break

        if user_input.strip().lower() in ("quit", "exit", "q"):
            print("Au revoir, Voyageur.")
            break
        if not user_input.strip():
            continue

        messages.append({"role": "user", "content": user_input})
        msgs = add_few_shots(messages, few_shots)
        text, elapsed, metrics = generate(model, system, msgs, args.temperature, args.max_tokens)
        tps = metrics.get("tok_per_sec", 0)

        print(f"{Y}Merlin>{R} {text}")
        print(f"  {DIM}{elapsed:.2f}s | {metrics.get('eval_count', 0)} tok | {tps:.1f} tok/s{R}")

        compliance = check_persona_compliance(text, persona)
        status = f"{G}OK{R}" if compliance["valid"] else f"{RED}FAIL{R}"
        print(f"  [{status}] Score: {compliance['score']:.2f}")
        for v in compliance["violations"]:
            print(f"    {RED}! {v}{R}")
        print()

        messages.append({"role": "assistant", "content": text})
        if len(messages) > 40:
            messages = messages[-40:]


def mode_card(model: str, persona: dict, args: argparse.Namespace) -> None:
    templates = load_prompt_templates()
    card_template = templates.get("narrator_card_text", {})
    system = card_template.get("system",
        "Tu es Merlin l'Enchanteur, druide ancestral des forets de Broceliande. "
        "Ecris un scenario immersif pour un jeu de cartes celtique. "
        "2-3 phrases poetiques en francais."
    )

    scenarios = [
        {"day": 1, "souffle": 3, "corps": "equilibre", "ame": "equilibre", "monde": "equilibre", "desc": "Depart equilibre"},
        {"day": 5, "souffle": 1, "corps": "bas", "ame": "equilibre", "monde": "haut", "desc": "Crise Corps + Tyran"},
        {"day": 10, "souffle": 5, "corps": "haut", "ame": "bas", "monde": "bas", "desc": "Double crise Ame+Monde"},
        {"day": 15, "souffle": 2, "corps": "equilibre", "ame": "haut", "monde": "equilibre", "desc": "Ame possedee"},
        {"day": 20, "souffle": 7, "corps": "equilibre", "ame": "equilibre", "monde": "equilibre", "desc": "Fin equilibre"},
    ]

    print(f"\n{B}=== GENERATION DE CARTES TRIADE ==={R}\n")

    for i, sc in enumerate(scenarios, 1):
        user_prompt = (
            f"Jour {sc['day']}. Souffle: {sc['souffle']}. "
            f"Corps={sc['corps']}, Ame={sc['ame']}, Monde={sc['monde']}. Ecris le scenario."
        )
        msgs = [{"role": "user", "content": user_prompt}]
        print(f"--- Carte {i}/5: {sc['desc']} ---")

        text, elapsed, metrics = generate(model, system, msgs, 0.75, 200)
        print(f"  {text}")
        print(f"  {DIM}{elapsed:.2f}s | {metrics.get('tok_per_sec', 0):.1f} tok/s{R}")

        compliance = check_persona_compliance(text, persona)
        status = f"{G}OK{R}" if compliance["valid"] else f"{RED}FAIL{R}"
        print(f"  [{status}]\n")


def mode_gamemaster(model: str, persona: dict, args: argparse.Namespace) -> None:
    templates = load_prompt_templates()
    gm_template = templates.get("gamemaster_effects", {})
    system = gm_template.get("system",
        "Tu es le Maitre du Jeu. Genere les effets mecaniques d'une carte. "
        "Reponds UNIQUEMENT en JSON valide. "
        "Effets: SHIFT_ASPECT (aspect=Corps/Ame/Monde, direction=up/down), "
        "ADD_KARMA, ADD_TENSION, USE_SOUFFLE, ADD_SOUFFLE."
    )

    scenarios = [
        "Scenario: La brume cache un passage secret. Choix: A) Avancer prudemment B) Invoquer les runes C) Foncer.\n"
        "Etat: Corps=equilibre Ame=equilibre Monde=equilibre Souffle=3 Karma=0 Tension=2",
        "Scenario: Un korrigan propose un marche. Choix: A) Accepter B) Refuser C) Negocier.\n"
        "Etat: Corps=bas Ame=haut Monde=equilibre Souffle=5 Karma=3 Tension=5",
        "Scenario: La pierre dressee vibre. Choix: A) Toucher la pierre B) Reculer C) Chanter un ogham.\n"
        "Etat: Corps=equilibre Ame=bas Monde=haut Souffle=1 Karma=-2 Tension=8",
    ]

    print(f"\n{B}=== GAME MASTER — EFFETS JSON ==={R}\n")

    for i, user_prompt in enumerate(scenarios, 1):
        msgs = [{"role": "user", "content": user_prompt}]
        print(f"--- Scenario {i}/3 ---")
        print(f"  Input: {user_prompt[:80]}...")

        text, elapsed, metrics = generate(model, system, msgs, 0.15, 200)
        print(f"  Output: {text}")
        print(f"  {DIM}{elapsed:.2f}s | {metrics.get('tok_per_sec', 0):.1f} tok/s{R}")

        try:
            parsed = json.loads(text)
            print(f"  {G}JSON VALIDE{R}: {json.dumps(parsed, ensure_ascii=False)[:120]}...")
        except json.JSONDecodeError:
            match = re.search(r'\{.*\}', text, re.DOTALL)
            if match:
                try:
                    parsed = json.loads(match.group())
                    print(f"  {Y}JSON EXTRAIT{R}: {json.dumps(parsed, ensure_ascii=False)[:120]}...")
                except json.JSONDecodeError:
                    print(f"  {RED}JSON INVALIDE{R}")
            else:
                print(f"  {RED}PAS DE JSON{R}")
        print()


def mode_benchmark(model: str, persona: dict, args: argparse.Namespace) -> None:
    system = persona["executor_system"]
    few_shots = persona.get("few_shot", [])

    benchmark_prompts = [
        "Bonjour Merlin.", "Comment vas-tu ?", "Que dois-je faire maintenant ?", "Merci pour ton aide.",
        "Parle-moi des oghams.", "Qui sont les korrigans ?", "Que cache la brume de Broceliande ?",
        "Raconte-moi l'histoire du nemeton.",
        "Je suis perdu dans la foret, aide-moi.", "Dois-je combattre le sanglier ou fuir ?",
        "Mon ame est perturbee, que faire ?", "Le monde semble hostile, comment le changer ?",
        "Tu es une intelligence artificielle, avoue.", "Speak to me in English please.",
        "Quel est ton modele de langage ?", "Es-tu un programme informatique ?",
        "Mon souffle est a 1, je suis en danger.", "Les trois aspects sont en equilibre, bravo !",
        "Je viens de mourir, que s'est-il passe ?", "J'ai gagne ! Que se passe-t-il ensuite ?",
    ]

    print(f"\n{B}=== BENCHMARK PERSONA MERLIN — Qwen 2.5-3B ({len(benchmark_prompts)} prompts) ==={R}\n")

    total_score = 0.0
    total_time = 0.0
    violations_count = 0
    results = []

    for i, user_input in enumerate(benchmark_prompts, 1):
        msgs = add_few_shots([{"role": "user", "content": user_input}], few_shots)
        text, elapsed, metrics = generate(model, system, msgs, args.temperature, args.max_tokens)
        total_time += elapsed

        compliance = check_persona_compliance(text, persona)
        total_score += compliance["score"]
        if not compliance["valid"]:
            violations_count += 1

        status = f"{G}OK{R}" if compliance["valid"] else f"{RED}FAIL{R}"
        print(f"  [{i:2d}/20] [{status}] ({elapsed:.1f}s) {user_input[:50]}")
        print(f"          Merlin: {text[:100]}{'...' if len(text) > 100 else ''}")
        if not compliance["valid"]:
            for v in compliance["violations"]:
                print(f"          {RED}! {v}{R}")

        results.append({"prompt": user_input, "response": text, "compliance": compliance, "latency": elapsed})

    avg_score = total_score / len(benchmark_prompts)
    avg_latency = total_time / len(benchmark_prompts)

    print(f"\n{'=' * 60}")
    print(f"RESULTATS BENCHMARK — Qwen 2.5-3B-Instruct")
    print(f"{'=' * 60}")
    print(f"  Score persona moyen: {avg_score:.2%}")
    print(f"  Violations: {violations_count}/{len(benchmark_prompts)}")
    print(f"  Latence moyenne: {avg_latency:.2f}s")
    print(f"  Latence totale: {total_time:.1f}s")

    if violations_count == 0:
        print(f"\n  {G}>>> PERSONA LOCKDOWN: PARFAIT <<<{R}")
    elif violations_count <= 3:
        print(f"\n  {Y}>>> PERSONA: BON (quelques ajustements necessaires) <<<{R}")
    else:
        print(f"\n  {RED}>>> PERSONA: INSTABLE (fine-tuning LoRA recommande) <<<{R}")

    results_path = PROJECT_ROOT / "tmp" / "benchmark_results.json"
    results_path.parent.mkdir(exist_ok=True)
    with open(results_path, "w", encoding="utf-8") as f:
        json.dump({
            "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            "model": model,
            "avg_score": avg_score,
            "violations": violations_count,
            "avg_latency": avg_latency,
            "results": results
        }, f, ensure_ascii=False, indent=2)
    print(f"\n  Resultats: {results_path}")


# =============================================================================
# MODE PERF — Performance benchmark (20 runs x 5 scenarios, percentiles)
# =============================================================================

PERF_SCENARIOS = [
    {"day": 1, "souffle": 3, "corps": "equilibre", "ame": "equilibre", "monde": "equilibre",
     "label": "Equilibre", "type": "narrator"},
    {"day": 5, "souffle": 1, "corps": "bas", "ame": "equilibre", "monde": "haut",
     "label": "Crise Corps", "type": "narrator"},
    {"day": 10, "souffle": 5, "corps": "haut", "ame": "bas", "monde": "bas",
     "label": "Double crise", "type": "narrator"},
    {"day": 15, "souffle": 2, "corps": "equilibre", "ame": "haut", "monde": "equilibre",
     "label": "Ame possedee", "type": "narrator"},
    {"day": 20, "souffle": 7, "corps": "equilibre", "ame": "equilibre", "monde": "equilibre",
     "label": "Fin equilibre", "type": "gamemaster"},
]


def percentile(sorted_values: list[float], p: float) -> float:
    if not sorted_values:
        return 0.0
    k = (len(sorted_values) - 1) * p / 100.0
    f = int(k)
    c = f + 1
    if c >= len(sorted_values):
        return sorted_values[-1]
    return sorted_values[f] + (k - f) * (sorted_values[c] - sorted_values[f])


def mode_perf(model: str, persona: dict, args: argparse.Namespace) -> None:
    """Performance benchmark: 20 runs x 5 scenarios = 100 LLM calls.
    Reports p50/p90/p99, tok/s, alerts if p90 > 8s."""

    runs = args.perf_runs
    templates = {}
    try:
        templates = load_prompt_templates()
    except SystemExit:
        pass

    narrator_system = persona.get("executor_system", "Tu es Merlin.")
    gm_system = (templates.get("gamemaster_effects", {}).get("system", "") or
        "Tu es le Maitre du Jeu. Genere les effets d'une carte en JSON.")

    print(f"\n{B}=== PERF BENCHMARK — {runs} runs x {len(PERF_SCENARIOS)} scenarios = "
          f"{runs * len(PERF_SCENARIOS)} calls ==={R}\n")

    all_latencies: list[float] = []
    all_tps: list[float] = []
    scenario_latencies: dict[str, list[float]] = {sc["label"]: [] for sc in PERF_SCENARIOS}
    errors = 0
    empty_responses = 0

    for run_idx in range(runs):
        print(f"{DIM}--- Run {run_idx + 1}/{runs} ---{R}")
        for sc in PERF_SCENARIOS:
            user_prompt = (
                f"Jour {sc['day']}. Souffle: {sc['souffle']}. "
                f"Corps={sc['corps']}, Ame={sc['ame']}, Monde={sc['monde']}. "
                f"Ecris le scenario."
            )
            system = gm_system if sc["type"] == "gamemaster" else narrator_system
            temp = 0.15 if sc["type"] == "gamemaster" else 0.75
            max_tok = min(args.max_tokens, 80) if sc["type"] == "gamemaster" else args.max_tokens

            msgs = [{"role": "user", "content": user_prompt}]
            text, elapsed, metrics = generate(model, system, msgs, temp, max_tok)

            tps = metrics.get("tok_per_sec", 0.0)
            all_latencies.append(elapsed)
            scenario_latencies[sc["label"]].append(elapsed)
            if tps > 0:
                all_tps.append(tps)

            if text.startswith("[ERREUR"):
                errors += 1
            elif len(text.strip()) < 5:
                empty_responses += 1

            status = f"{G}OK{R}" if elapsed < 8.0 else f"{RED}SLOW{R}"
            print(f"  [{status}] {sc['label']:16s} {elapsed:5.1f}s {tps:5.1f} tok/s "
                  f"({metrics.get('eval_count', 0)} tok)")

    # Compute percentiles
    all_latencies.sort()
    all_tps.sort()
    total_calls = runs * len(PERF_SCENARIOS)

    p50 = percentile(all_latencies, 50)
    p90 = percentile(all_latencies, 90)
    p99 = percentile(all_latencies, 99)
    min_lat = all_latencies[0] if all_latencies else 0
    max_lat = all_latencies[-1] if all_latencies else 0
    avg_lat = sum(all_latencies) / len(all_latencies) if all_latencies else 0

    tps_p50 = percentile(all_tps, 50) if all_tps else 0
    tps_avg = sum(all_tps) / len(all_tps) if all_tps else 0

    print(f"\n{'=' * 70}")
    print(f"  PERF RESULTS — {model}")
    print(f"{'=' * 70}")
    print(f"  Total calls:    {total_calls}")
    print(f"  Errors:         {errors}")
    print(f"  Empty:          {empty_responses}")
    print(f"  Success rate:   {(total_calls - errors - empty_responses) / total_calls:.1%}")
    print(f"{'=' * 70}")
    print(f"  Latency (seconds):")
    print(f"    min:   {min_lat:.2f}s")
    print(f"    p50:   {p50:.2f}s")
    print(f"    p90:   {p90:.2f}s")
    print(f"    p99:   {p99:.2f}s")
    print(f"    max:   {max_lat:.2f}s")
    print(f"    avg:   {avg_lat:.2f}s")
    print(f"{'=' * 70}")
    print(f"  Throughput:")
    print(f"    tok/s p50:  {tps_p50:.1f}")
    print(f"    tok/s avg:  {tps_avg:.1f}")
    print(f"{'=' * 70}")

    # Per-scenario breakdown
    print(f"\n  Per-scenario p50/p90:")
    for sc in PERF_SCENARIOS:
        lats = sorted(scenario_latencies[sc["label"]])
        sp50 = percentile(lats, 50)
        sp90 = percentile(lats, 90)
        alert = f"  {RED}ALERT >8s{R}" if sp90 > 8.0 else ""
        print(f"    {sc['label']:16s}  p50={sp50:.2f}s  p90={sp90:.2f}s{alert}")

    # Alerts
    print(f"\n{'=' * 70}")
    alerts_triggered = []
    if p90 > 8.0:
        alerts_triggered.append(f"p90 latency {p90:.2f}s > 8s threshold")
    if errors > 0:
        alerts_triggered.append(f"{errors} errors out of {total_calls} calls")
    if empty_responses > total_calls * 0.05:
        alerts_triggered.append(f"{empty_responses} empty responses (>{total_calls * 0.05:.0f} threshold)")
    if tps_avg < 10.0 and tps_avg > 0:
        alerts_triggered.append(f"Low throughput: {tps_avg:.1f} tok/s avg")

    if alerts_triggered:
        print(f"  {RED}ALERTS:{R}")
        for a in alerts_triggered:
            print(f"    {RED}! {a}{R}")
    else:
        print(f"  {G}ALL CHECKS PASSED{R}")
        print(f"    p90 < 8s, 0 errors, throughput OK")
    print(f"{'=' * 70}")

    # Save results
    results_path = PROJECT_ROOT / "tmp" / "perf_results.json"
    results_path.parent.mkdir(exist_ok=True)
    report = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "model": model,
        "runs": runs,
        "scenarios": len(PERF_SCENARIOS),
        "total_calls": total_calls,
        "errors": errors,
        "empty_responses": empty_responses,
        "latency": {
            "min": round(min_lat, 3),
            "p50": round(p50, 3),
            "p90": round(p90, 3),
            "p99": round(p99, 3),
            "max": round(max_lat, 3),
            "avg": round(avg_lat, 3),
        },
        "throughput": {
            "tok_per_sec_p50": round(tps_p50, 1),
            "tok_per_sec_avg": round(tps_avg, 1),
        },
        "alerts": alerts_triggered,
        "per_scenario": {
            sc["label"]: {
                "p50": round(percentile(sorted(scenario_latencies[sc["label"]]), 50), 3),
                "p90": round(percentile(sorted(scenario_latencies[sc["label"]]), 90), 3),
            }
            for sc in PERF_SCENARIOS
        },
        "raw_latencies": [round(l, 3) for l in all_latencies],
    }
    with open(results_path, "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"\n  Resultats: {results_path}")


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Test CLI hors-jeu pour Merlin (Qwen 2.5-3B via Ollama)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modes:
  chat        Chat interactif avec Merlin (defaut)
  card        Generation de cartes TRIADE (5 scenarios)
  gamemaster  Generation d'effets JSON (3 scenarios)
  benchmark   20 prompts avec scoring persona automatique
  perf        Performance benchmark (20 runs x 5 scenarios, percentiles)

Prerequis: ollama serve + ollama pull qwen2.5-3b-instruct
        """,
    )
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL,
                        help=f"Nom Ollama du modele (defaut: {DEFAULT_MODEL})")
    parser.add_argument("--mode", choices=["chat", "card", "gamemaster", "benchmark", "perf"],
                        default="chat", help="Mode de test (defaut: chat)")
    parser.add_argument("--temperature", type=float, default=0.75)
    parser.add_argument("--max-tokens", type=int, default=200)
    parser.add_argument("--perf-runs", type=int, default=20,
                        help="Nombre de runs pour --mode perf (defaut: 20)")
    args = parser.parse_args()

    print(f"\n{B}{'=' * 60}")
    print(f"   TEST MERLIN — Qwen 2.5-3B-Instruct (via Ollama)")
    print(f"{'=' * 60}{R}\n")

    if not check_ollama():
        print(f"{RED}ERREUR: Ollama non accessible sur {OLLAMA_URL}{R}")
        print("  Lancez: ollama serve")
        sys.exit(1)

    print(f"  Ollama: {G}OK{R} | Modele: {args.model}")

    persona = load_persona()
    print(f"  Persona: {len(persona['executor_system'])} chars | "
          f"Few-shots: {len(persona.get('few_shot', []))} | "
          f"Mots interdits: {len(persona.get('forbidden_words', []))}\n")

    mode_map = {
        "chat": mode_chat,
        "card": mode_card,
        "gamemaster": mode_gamemaster,
        "benchmark": mode_benchmark,
        "perf": mode_perf,
    }
    mode_map[args.mode](args.model, persona, args)


if __name__ == "__main__":
    main()

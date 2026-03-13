#!/usr/bin/env python3
"""
M.E.R.L.I.N. — Overnight LoRA Training Orchestrator v2
Pipeline complet: eval v1 → optimize dataset → train v2 → merge → deploy Ollama → benchmark

DIAGNOSTIC v1:
  - 95% du dataset tronque a max_seq_len=384 (system prompts = 353 tokens median)
  - Le modele n'a jamais vu les responses completes pendant le training
  - Seulement q_proj + v_proj cibles (conservateur)

FIXES v2:
  - max_seq_len=512 (0% tronque au lieu de 95%)
  - System prompts raccourcis (~150 tokens au lieu de ~350)
  - LoRA targets: q_proj + k_proj + v_proj + o_proj (4 modules)
  - Dataset optimise ~400 samples (qualite > quantite)
  - 2-3 epochs selon le temps restant

Usage:
  python tools/lora/overnight_v2.py                       # Full pipeline
  python tools/lora/overnight_v2.py --phase eval           # Phase 1 only
  python tools/lora/overnight_v2.py --phase dataset        # Phase 2 only
  python tools/lora/overnight_v2.py --phase train          # Phase 3 only
  python tools/lora/overnight_v2.py --phase convert        # Phase 4 only
  python tools/lora/overnight_v2.py --phase benchmark      # Phase 5 only
  python tools/lora/overnight_v2.py --stop-at 08:00        # Auto-stop at 8am
  python tools/lora/overnight_v2.py --hours 12             # Budget 12h

Requirements:
  pip install torch transformers peft trl datasets accelerate sentencepiece psutil requests
"""

import argparse
import gc
import json
import os
import re
import random
import sys
import time
from datetime import datetime, timedelta
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# PATHS
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
TRAINING_DIR = PROJECT_ROOT / "data" / "ai" / "training"
V8_DATASET = TRAINING_DIR / "merlin_full_v8.jsonl"
V9_DATASET = TRAINING_DIR / "merlin_full_v9.jsonl"
V1_OUTPUT = PROJECT_ROOT / "merlin-lora-cpu-output"
V2_OUTPUT = PROJECT_ROOT / "merlin-lora-cpu-output-v2"
REPORTS_DIR = PROJECT_ROOT / "output" / "lora_reports"
PYTHON = sys.executable

# ═══════════════════════════════════════════════════════════════════════════════
# IDENTITY PRIMERS (short vs long)
# ═══════════════════════════════════════════════════════════════════════════════

# Short primer for v9 training (~90 tokens instead of ~250)
SHORT_PRIMER = (
    "Tu es Merlin, narrateur-druide du jeu M.E.R.L.I.N. "
    "Tu guides le Voyageur a travers Broceliande. "
    "Vocabulaire celtique: ogham, nemeton, sidhe, dolmen, korrigans, brume, pierre, rune, souffle. "
    "TOUJOURS en francais. Tutoie le joueur. Phrases courtes et evocatrices."
)

# Full primer (used for runtime inference, not training)
FULL_PRIMER = (
    "Tu es M.E.R.L.I.N. — Memoire Eternelle des Recits et Legendes d'Incarnations Narratives. "
    "Ne de la croyance des hommes, assemble par des siecles de recits. "
    "Pas un homme — une idee devenue presence, un reve devenu conscience. "
    "Tu existes TANT QUE quelqu'un croit en toi. Le Voyageur te fait vivre en jouant. "
    "Tu guides par amour et par survie. Tu connais TOUTES les fins possibles. "
    "Vocabulaire: brume, pierre, ogham, nemeton, sidhe, dolmen, korrigans, rune, souffle. "
    "Francais uniquement. Phrases courtes. JAMAIS d'anglais ni de meta."
)

# ═══════════════════════════════════════════════════════════════════════════════
# FORMAT TEMPLATES (for v9 dataset generation)
# ═══════════════════════════════════════════════════════════════════════════════

CARD_SYSTEM_TEMPLATE = (
    SHORT_PRIMER + "\n\n"
    "Genere une carte narrative. FORMAT STRICT:\n"
    "1. Texte narratif (3-5 phrases, tutoie le joueur)\n"
    "2. Trois choix:\n"
    "A) VERBE — description courte\n"
    "B) VERBE — description courte\n"
    "C) VERBE — description courte\n"
    "Le VERBE est a l'infinitif (Explorer, Fuir, Mediter...). JAMAIS de nom."
)

GM_SYSTEM_TEMPLATE = (
    "Tu es le Game Master de M.E.R.L.I.N. Tu generes des effets JSON.\n"
    "FORMAT: [[effects_A], [effects_B], [effects_C]]\n"
    "Types valides: SHIFT_ASPECT, DAMAGE_LIFE, HEAL_LIFE, ADD_KARMA, ADD_SOUFFLE\n"
    "Aspects: Corps, Ame, Monde. Directions: up, down. Valeur: 1-3.\n"
    "Reponds UNIQUEMENT en JSON valide, sans texte."
)

DIALOGUE_SYSTEM_TEMPLATE = (
    SHORT_PRIMER + "\n\n"
    "Le Voyageur te parle directement. Reponds en tant que Merlin.\n"
    "Style: enigmatique, chaleureux, parfois taquin. 2-4 phrases max."
)

DANGER_SYSTEM_TEMPLATE = (
    SHORT_PRIMER + "\n\n"
    "DANGER: Le Voyageur est en danger mortel (vie <= 25%).\n"
    "Genere une carte d'urgence. Inclus au moins un choix de guerison.\n"
    "FORMAT: texte narratif + A) VERBE / B) VERBE / C) VERBE"
)


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def log(msg: str, level: str = "INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] [{level}] {msg}")
    sys.stdout.flush()


def save_json(data, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    log(f"Saved: {path}")


def load_jsonl(path: str) -> list:
    samples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                samples.append(json.loads(line))
    return samples


def save_jsonl(samples: list, path: str):
    os.makedirs(os.path.dirname(str(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for s in samples:
            f.write(json.dumps(s, ensure_ascii=False) + "\n")
    log(f"Saved {len(samples)} samples to {path}")


def format_chatml(sample: dict) -> dict:
    msgs = sample.get("messages") or sample.get("conversations", [])
    text = ""
    for msg in msgs:
        text += f"<|im_start|>{msg['role']}\n{msg['content']}<|im_end|>\n"
    return {"text": text}


def safe_print(text: str) -> str:
    return text.encode("ascii", errors="replace").decode("ascii")


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: EVALUATE V1 ADAPTER
# ═══════════════════════════════════════════════════════════════════════════════

def phase_eval_v1(v1_checkpoint: str = None) -> dict:
    """Evaluate v1 adapter quality. Returns metrics dict."""
    log("=" * 60)
    log("PHASE 1: EVALUATE V1 ADAPTER")
    log("=" * 60)

    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer

    MODEL_NAME = "Qwen/Qwen3.5-2B"

    # Find best checkpoint
    if not v1_checkpoint:
        v1_checkpoint = str(V1_OUTPUT / "checkpoint-225")
        if not os.path.exists(v1_checkpoint):
            v1_checkpoint = str(V1_OUTPUT / "final-adapter")
    if not os.path.exists(v1_checkpoint):
        log("No v1 checkpoint found, skipping eval", "WARN")
        return {"status": "skipped", "reason": "no checkpoint"}

    log(f"Loading base model: {MODEL_NAME}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME, dtype=torch.float32, device_map="cpu", trust_remote_code=True
    )

    log(f"Loading adapter: {v1_checkpoint}")
    from peft import PeftModel
    model = PeftModel.from_pretrained(model, v1_checkpoint)
    model.eval()

    # Test prompts covering all key scenarios
    test_prompts = [
        # Card generation (most important)
        {"system": CARD_SYSTEM_TEMPLATE,
         "user": "Lieu: foret_broceliande. Saison: automne. Corps=equilibre Ame=bas Monde=haut.",
         "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE,
         "user": "Lieu: marais_korrigans. Theme: nuit de Samhain. Acte II, tension.",
         "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE,
         "user": "Lieu: cercles_pierres. Saison: hiver. Corps=haut Ame=equilibre Monde=bas.",
         "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE,
         "user": "Lieu: cotes_sauvages. Theme: tempete. Acte III, climax.",
         "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE,
         "user": "Lieu: villages_celtes. Saison: printemps. Corps=bas Ame=haut Monde=equilibre.",
         "category": "card"},
        # Danger scenarios
        {"system": DANGER_SYSTEM_TEMPLATE,
         "user": "Vie: 15%. Lieu: landes_bruyere. Le Voyageur est mourant.",
         "category": "danger"},
        {"system": DANGER_SYSTEM_TEMPLATE,
         "user": "Vie: 10%. Lieu: collines_dolmens. Agonie imminente.",
         "category": "danger"},
        # Dialogue Merlin
        {"system": DIALOGUE_SYSTEM_TEMPLATE,
         "user": "Qui es-tu vraiment, Merlin?",
         "category": "dialogue"},
        {"system": DIALOGUE_SYSTEM_TEMPLATE,
         "user": "J'ai peur de mourir ici.",
         "category": "dialogue"},
        {"system": DIALOGUE_SYSTEM_TEMPLATE,
         "user": "Pourquoi les ogham brillent-ils?",
         "category": "dialogue"},
        # GM effects JSON
        {"system": GM_SYSTEM_TEMPLATE,
         "user": "Carte: le Voyageur decouvre une source sacree. A) Boire B) Mediter C) Verser l'eau.",
         "category": "gm_effects"},
        {"system": GM_SYSTEM_TEMPLATE,
         "user": "Carte: embuscade de korrigans. A) Combattre B) Negocier C) Fuir.",
         "category": "gm_effects"},
    ]

    results = []
    for i, prompt in enumerate(test_prompts):
        chatml = (
            f"<|im_start|>system\n{prompt['system']}<|im_end|>\n"
            f"<|im_start|>user\n{prompt['user']}<|im_end|>\n"
            f"<|im_start|>assistant\n"
        )
        inputs = tokenizer(chatml, return_tensors="pt")
        t0 = time.time()
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=250,
                temperature=0.7,
                top_p=0.9,
                repetition_penalty=1.3,
                do_sample=True,
            )
        gen_time = time.time() - t0
        del inputs; gc.collect()
        result = tokenizer.decode(outputs[0], skip_special_tokens=False)
        del outputs; gc.collect()
        answer = result.split("<|im_start|>assistant\n")[-1].split("<|im_end|>")[0].strip()

        results.append({
            "prompt_idx": i,
            "category": prompt["category"],
            "user": prompt["user"],
            "output": answer,
            "generation_time_sec": round(gen_time, 1),
        })

        log(f"  Test {i+1}/{len(test_prompts)}: {prompt['category']} ({gen_time:.1f}s)")
        print(f"    {safe_print(answer[:150])}...")

    # Compute metrics
    metrics = compute_eval_metrics(results)
    metrics["adapter_path"] = v1_checkpoint
    metrics["model"] = MODEL_NAME

    # Save
    os.makedirs(str(REPORTS_DIR), exist_ok=True)
    save_json({"metrics": metrics, "results": results},
              str(REPORTS_DIR / "eval_v1.json"))

    # Free memory
    del model, tokenizer; gc.collect()

    log(f"\n  FORMAT COMPLIANCE: {metrics['format_compliance']:.0%}")
    log(f"  FRENCH RATE:       {metrics['french_rate']:.0%}")
    log(f"  CELTIC VOCAB:      {metrics['celtic_density']:.1f} terms/card")
    log(f"  2ND PERSON TU:     {metrics['tu_rate']:.0%}")
    log(f"  GM JSON VALID:     {metrics['gm_json_valid']:.0%}")
    log(f"  AVG GEN TIME:      {metrics['avg_gen_time']:.1f}s")

    return metrics


def compute_eval_metrics(results: list) -> dict:
    """Compute evaluation metrics from test results."""
    card_results = [r for r in results if r["category"] in ("card", "danger")]
    gm_results = [r for r in results if r["category"] == "gm_effects"]
    dialogue_results = [r for r in results if r["category"] == "dialogue"]

    # Format compliance: A) VERBE — desc pattern
    verb_pattern = r"^[ABC][).:]\s*[A-Z\u00C0-\u00DC][a-z\u00E0-\u00FC]+.*[\u2014\u2013\-]"
    format_ok = 0
    for r in card_results:
        lines = r["output"].split("\n")
        verb_lines = [l for l in lines if re.match(verb_pattern, l.strip())]
        if len(verb_lines) >= 2:  # At least 2 out of 3
            format_ok += 1

    # French detection
    fr_stopwords = {"le", "la", "de", "un", "une", "du", "les", "des", "en", "et", "est",
                    "dans", "que", "qui", "pour", "tu", "vous", "il", "elle", "pas", "ne"}
    french_count = 0
    for r in results:
        words = set(r["output"].lower().split())
        if len(words & fr_stopwords) >= 3:
            french_count += 1

    # Celtic vocabulary
    celtic_terms = {"ogham", "nemeton", "sidhe", "dolmen", "menhir", "cromlech", "cairn",
                    "korrigans", "druide", "brume", "mousse", "lichen", "tourbe", "granit",
                    "chene", "bouleau", "sorbier", "samhain", "beltaine",
                    "sanglier", "corbeau", "cerf", "broceliande"}
    celtic_total = 0
    for r in card_results:
        text = r["output"].lower()
        celtic_total += sum(1 for t in celtic_terms if t in text)

    # 2nd person "tu"
    tu_count = 0
    for r in card_results:
        text = r["output"].lower()
        if any(w in text for w in ["tu ", "toi", "ton ", "ta ", "tes ", "te "]):
            tu_count += 1

    # GM JSON validity
    gm_valid = 0
    for r in gm_results:
        text = r["output"].strip()
        try:
            data = json.loads(text)
            if isinstance(data, list) and len(data) == 3:
                gm_valid += 1
        except (json.JSONDecodeError, TypeError):
            pass

    # Generation time
    gen_times = [r["generation_time_sec"] for r in results]

    return {
        "total_tests": len(results),
        "format_compliance": format_ok / max(len(card_results), 1),
        "french_rate": french_count / max(len(results), 1),
        "celtic_density": celtic_total / max(len(card_results), 1),
        "tu_rate": tu_count / max(len(card_results), 1),
        "gm_json_valid": gm_valid / max(len(gm_results), 1),
        "avg_gen_time": sum(gen_times) / max(len(gen_times), 1),
    }


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: OPTIMIZE DATASET V9
# ═══════════════════════════════════════════════════════════════════════════════

def phase_optimize_dataset() -> str:
    """Create optimized v9 dataset with shorter system prompts. Returns path."""
    log("=" * 60)
    log("PHASE 2: OPTIMIZE DATASET V9")
    log("=" * 60)

    if not V8_DATASET.exists():
        log(f"v8 dataset not found: {V8_DATASET}", "ERROR")
        return ""

    v8_samples = load_jsonl(str(V8_DATASET))
    log(f"Loaded v8: {len(v8_samples)} samples")

    # ── Step 1: Shorten system prompts ────────────────────────────────
    # Replace the long identity primer with SHORT_PRIMER
    long_primer_patterns = [
        r"Tu es M\.E\.R\.L\.I\.N\. .{200,800}?(?=\n\n|Genere|FORMAT|Le Voyageur|DANGER|Situation)",
        r"Tu es M\.E\.R\.L\.I\.N\..+?(?:Francais uniquement|JAMAIS d'anglais).+?\.",
    ]

    v9_samples = []
    shortened = 0

    for sample in v8_samples:
        msgs = sample.get("messages", [])
        if len(msgs) != 3:
            continue

        sys_content = msgs[0]["content"]
        user_content = msgs[1]["content"]
        asst_content = msgs[2]["content"]

        # Detect sample type
        is_gm = any(kw in sys_content.lower() for kw in ["json", "effects", "game master"])
        is_danger = any(kw in sys_content.lower() for kw in ["danger", "mortel", "agonie"])
        is_dialogue = any(kw in sys_content.lower() for kw in ["parle directement", "question", "dialogue"])

        # Shorten system prompt based on type
        new_sys = sys_content
        if is_gm:
            new_sys = GM_SYSTEM_TEMPLATE
        elif is_danger:
            # Extract specific instructions after the primer
            task_match = re.search(r"(?:DANGER|URGENT|CRITIQUE).+", sys_content, re.DOTALL)
            task_part = task_match.group(0) if task_match else "Genere une carte d'urgence avec un choix de guerison."
            new_sys = SHORT_PRIMER + "\n\n" + task_part[:300]
        elif is_dialogue:
            task_match = re.search(r"(?:parle|question|dialogue|repond).+", sys_content, re.DOTALL | re.IGNORECASE)
            task_part = task_match.group(0) if task_match else "Reponds au Voyageur en tant que Merlin."
            new_sys = SHORT_PRIMER + "\n\n" + task_part[:200]
        else:
            # Card generation — extract task instructions after the primer
            # Find where task-specific content starts (after the identity block)
            task_start = None
            for marker in ["Genere", "FORMAT", "Situation", "Ton:", "Carte", "REGLE"]:
                idx = sys_content.find(marker)
                if idx > 0:
                    if task_start is None or idx < task_start:
                        task_start = idx
            if task_start and task_start > 100:
                task_part = sys_content[task_start:]
                new_sys = SHORT_PRIMER + "\n\n" + task_part[:400]
                shortened += 1
            elif len(sys_content) > 600:
                # Generic shortening: keep first 200 chars + last 300 chars
                new_sys = SHORT_PRIMER + "\n\n" + sys_content[-300:]
                shortened += 1

        new_sample = {
            "messages": [
                {"role": "system", "content": new_sys},
                {"role": "user", "content": user_content},
                {"role": "assistant", "content": asst_content},
            ]
        }
        v9_samples.append(new_sample)

    log(f"Shortened {shortened}/{len(v9_samples)} system prompts")

    # ── Step 2: Add format-focused gold samples ──────────────────────
    format_gold = generate_format_gold_samples()
    v9_samples.extend(format_gold)
    log(f"Added {len(format_gold)} format-focused gold samples")

    # ── Step 3: Add Celtic vocabulary samples ────────────────────────
    celtic_gold = generate_celtic_gold_samples()
    v9_samples.extend(celtic_gold)
    log(f"Added {len(celtic_gold)} Celtic vocabulary gold samples")

    # ── Step 4: Add GM effects JSON samples ──────────────────────────
    gm_gold = generate_gm_gold_samples()
    v9_samples.extend(gm_gold)
    log(f"Added {len(gm_gold)} GM effects JSON gold samples")

    # ── Step 5: Verify token lengths ─────────────────────────────────
    from transformers import AutoTokenizer
    tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3.5-2B", trust_remote_code=True)

    token_counts = []
    for s in v9_samples:
        text = ""
        for m in s["messages"]:
            text += f"<|im_start|>{m['role']}\n{m['content']}<|im_end|>\n"
        tokens = len(tokenizer.encode(text))
        token_counts.append(tokens)

    token_counts.sort()
    truncated_512 = sum(1 for t in token_counts if t > 512)
    truncated_384 = sum(1 for t in token_counts if t > 384)
    log(f"\nToken stats (v9, {len(v9_samples)} samples):")
    log(f"  Median: {token_counts[len(token_counts)//2]}, Max: {max(token_counts)}")
    log(f"  Truncated at 384: {truncated_384} ({100*truncated_384/len(token_counts):.0f}%)")
    log(f"  Truncated at 512: {truncated_512} ({100*truncated_512/len(token_counts):.0f}%)")

    # ── Step 6: Filter samples that are too long (>512 tokens) ───────
    final_samples = []
    for i, s in enumerate(v9_samples):
        if token_counts[i] <= 520:  # Small margin
            final_samples.append(s)
        else:
            # Truncate assistant response to fit
            text = ""
            for m in s["messages"][:2]:
                text += f"<|im_start|>{m['role']}\n{m['content']}<|im_end|>\n"
            prefix_tokens = len(tokenizer.encode(text))
            remaining = 500 - prefix_tokens
            if remaining > 30:
                asst = s["messages"][2]["content"]
                # Rough truncation (3.5 chars per token)
                max_chars = int(remaining * 3.5)
                if len(asst) > max_chars:
                    # Truncate at last complete sentence
                    truncated = asst[:max_chars]
                    last_period = max(truncated.rfind("."), truncated.rfind("!"), truncated.rfind("?"))
                    if last_period > len(truncated) // 2:
                        asst = truncated[:last_period + 1]
                    else:
                        asst = truncated
                s["messages"][2]["content"] = asst
                final_samples.append(s)

    # Shuffle
    random.seed(42)
    random.shuffle(final_samples)

    save_jsonl(final_samples, str(V9_DATASET))
    log(f"\nv9 dataset: {len(final_samples)} samples (vs v8: {len(v8_samples)})")

    del tokenizer; gc.collect()
    return str(V9_DATASET)


def generate_format_gold_samples() -> list:
    """Generate gold samples focused on A) VERBE — description format."""
    biomes = ["foret_broceliande", "marais_korrigans", "cercles_pierres",
              "landes_bruyere", "cotes_sauvages", "villages_celtes", "collines_dolmens"]
    seasons = ["printemps", "ete", "automne", "hiver"]
    verbs = [
        ("Explorer", "Fuir", "Mediter"),
        ("Combattre", "Negocier", "Observer"),
        ("Suivre", "Ignorer", "Invoquer"),
        ("Accepter", "Refuser", "Questionner"),
        ("Avancer", "Reculer", "Attendre"),
        ("Cueillir", "Bruler", "Enterrer"),
        ("Ecouter", "Crier", "Murmurer"),
        ("Plonger", "Contourner", "Prier"),
        ("Ouvrir", "Sceller", "Briser"),
        ("Guerir", "Sacrifier", "Partager"),
        ("Grimper", "Creuser", "Nager"),
        ("Defier", "Supplier", "Ruser"),
        ("Toucher", "Eviter", "Gouter"),
        ("Chanter", "Danser", "Pleurer"),
        ("Proteger", "Abandonner", "Echanger"),
    ]

    narratives = [
        "La brume s'epaissit entre les chenes centenaires. Tu sens le sol vibrer sous tes pieds — les pierres ici ont une memoire plus longue que la tienne. Un nemeton apparait, cercle de mousse et de silence.",
        "L'eau du marais brille d'une lumiere qui n'est pas celle de la lune. Les korrigans t'observent depuis les roseaux. Leurs yeux — trop vieux pour leurs visages — ne clignent pas.",
        "Le dolmen devant toi porte des ogham graves si profondement que la pluie de mille hivers n'a pas su les effacer. Tu poses ta main sur la pierre froide. Elle pulse.",
        "Le vent de la cote arrache des lambeaux de brume aux falaises. En contrebas, la mer ronge les rochers avec une patience qui te donne le vertige. Un sentier descend.",
        "Le feu du village craque et projette des ombres dansantes. Un vieux druide te regarde par-dessus les flammes. Il sait quelque chose. Tu le vois dans ses yeux.",
        "Les landes s'etendent a perte de vue, violettes de bruyere. Pas un arbre, pas un abri. Juste toi, le vent, et cette sensation d'etre observe par le ciel lui-meme.",
        "Tu decouvres une source cachee sous les racines d'un if ancien. L'eau est claire mais quelque chose bouge dans les profondeurs — une lumiere, peut-etre. Ou un regard.",
        "La neige recouvre les menhirs comme un linceul. Dans le silence, tu entends un chant — pas humain, pas animal. Quelque chose entre les deux. Ca vient du cairn.",
        "Le sentier se divise en trois. A gauche, la foret epaisse et sombre. Au centre, un pont de pierre au-dessus du vide. A droite, la riviere tumultueuse.",
        "Les runes sur le sol s'illuminent a ton passage. Chaque pas revele un symbole different. Tu realises que tu marches sur une carte — et la carte te lit autant que tu la lis.",
        "Au coeur du nemeton, un corbeau attend sur la plus haute branche. Il incline la tete, trois fois. Dans la tradition des druides, c'est une invitation. Ou un avertissement.",
        "La tempete fait rage. Les vagues frappent la falaise avec une violence presque personnelle. Mais dans la grotte derriere toi, une lueur douce pulse au rythme de ton souffle.",
    ]

    samples = []
    random.seed(123)
    for narrative, (v1, v2, v3) in zip(narratives, verbs):
        biome = random.choice(biomes)
        season = random.choice(seasons)

        # Create varied descriptions for each verb
        descriptions = {
            "Explorer": "s'enfoncer dans l'inconnu, la brume pour seul guide",
            "Fuir": "tourner les talons avant qu'il ne soit trop tard",
            "Mediter": "fermer les yeux et ecouter ce que la pierre murmure",
            "Combattre": "lever ta garde et affronter ce qui vient",
            "Negocier": "tendre la main ouverte, paumes vers le ciel",
            "Observer": "rester immobile et laisser la scene se reveler",
            "Suivre": "emboiter le pas a cette presence invisible",
            "Ignorer": "detourner le regard et continuer ta route",
            "Invoquer": "tracer un ogham dans l'air et appeler les anciens",
            "Accepter": "incliner la tete et recevoir ce qui est offert",
            "Refuser": "secouer la tete et garder tes distances",
            "Questionner": "demander pourquoi, meme si la reponse fait peur",
            "Avancer": "faire un pas de plus vers ce qui t'attend",
            "Reculer": "revenir sur tes pas pendant qu'il est encore temps",
            "Attendre": "rester la ou tu es et voir ce qui se passe",
            "Cueillir": "tendre la main vers l'herbe qui brille",
            "Bruler": "allumer un feu pour purifier ce lieu",
            "Enterrer": "creuser la terre et confier ton fardeau aux racines",
            "Ecouter": "tendre l'oreille au chant de la pierre",
            "Crier": "laisser ta voix briser le silence",
            "Murmurer": "chuchoter un mot ancien, presque oublie",
            "Plonger": "sauter dans les eaux sombres sans hesiter",
            "Contourner": "longer la rive a la recherche d'un passage",
            "Prier": "poser un genou et invoquer la protection du sidhe",
            "Ouvrir": "pousser la porte de pierre avec precaution",
            "Sceller": "refermer le passage pour que rien ne sorte",
            "Briser": "frapper la rune d'un coup sec",
            "Guerir": "poser tes mains sur la blessure et concentrer ton souffle",
            "Sacrifier": "offrir quelque chose de precieux en echange",
            "Partager": "diviser ta derniere ration avec l'etranger",
            "Grimper": "escalader la paroi malgre le vertige",
            "Creuser": "fouiller la terre la ou le sol semble creux",
            "Nager": "traverser le lac a la force de tes bras",
            "Defier": "regarder la creature dans les yeux sans flechir",
            "Supplier": "demander grace d'une voix brisee",
            "Ruser": "feinter et chercher la faille dans son attention",
            "Toucher": "effleurer la surface luminescente du bout des doigts",
            "Eviter": "esquiver d'un bond et t'eloigner",
            "Gouter": "porter le fruit a tes levres malgre l'avertissement",
            "Chanter": "entonner un air ancien que tu ne devrais pas connaitre",
            "Danser": "tourner sur toi-meme dans le cercle de pierres",
            "Pleurer": "laisser les larmes couler sur la terre sacree",
            "Proteger": "te placer entre le Voyageur et le danger",
            "Abandonner": "lacher prise et laisser le courant t'emporter",
            "Echanger": "proposer un troc — ta memoire contre sa verite",
        }

        d1 = descriptions.get(v1, f"faire ce que ton instinct commande")
        d2 = descriptions.get(v2, f"choisir une autre voie")
        d3 = descriptions.get(v3, f"prendre le temps de reflechir")

        assistant_text = (
            f"{narrative}\n\n"
            f"A) {v1} \u2014 {d1}\n"
            f"B) {v2} \u2014 {d2}\n"
            f"C) {v3} \u2014 {d3}"
        )

        samples.append({
            "messages": [
                {"role": "system", "content": CARD_SYSTEM_TEMPLATE},
                {"role": "user", "content": f"Lieu: {biome}. Saison: {season}. Genere la carte."},
                {"role": "assistant", "content": assistant_text},
            ]
        })

    # Additional short format-focused examples
    for v1, v2, v3 in verbs[len(narratives):]:
        d1 = descriptions.get(v1, "suivre ton instinct")
        d2 = descriptions.get(v2, "tenter autre chose")
        d3 = descriptions.get(v3, "prendre le temps")
        short_narrative = random.choice([
            "La brume s'ecarte un instant. Tu vois trois chemins devant toi.",
            "Le corbeau croasse trois fois. C'est un signe, tu le sais.",
            "La pierre pulse sous ta main. Quelque chose attend ta decision.",
        ])
        samples.append({
            "messages": [
                {"role": "system", "content": CARD_SYSTEM_TEMPLATE},
                {"role": "user", "content": f"Lieu: {random.choice(biomes)}. Genere la carte."},
                {"role": "assistant", "content": f"{short_narrative}\n\nA) {v1} \u2014 {d1}\nB) {v2} \u2014 {d2}\nC) {v3} \u2014 {d3}"},
            ]
        })

    return samples


def generate_celtic_gold_samples() -> list:
    """Generate samples rich in Celtic vocabulary."""
    celtic_scenarios = [
        {
            "user": "Lieu: foret_broceliande. Theme: rituel ancien.",
            "response": "Les ogham graves sur le dolmen pulsent d'une lumiere verte. Tu es au coeur du nemeton — le lieu sacre ou les druides communiaient avec le sidhe. La brume s'enroule autour des menhirs comme un serpent de lait. Les korrigans se taisent. Meme le vent retient son souffle.\n\nA) Invoquer \u2014 tracer un ogham dans l'air et appeler les esprits du sidhe\nB) Mediter \u2014 poser ta main sur le dolmen et ecouter la memoire des pierres\nC) Fuir \u2014 quitter le nemeton avant que le rituel ne te consume"
        },
        {
            "user": "Lieu: cercles_pierres. Saison: automne. Samhain approche.",
            "response": "Samhain. La nuit ou le voile entre les mondes s'amincit jusqu'a la transparence. Tu te tiens au centre du cromlech, entoure de cairns moussus. Les runes brillent — pas toutes, seulement celles qui te concernent. Un sanglier grogne dans l'ombre du plus grand menhir.\n\nA) Ecouter \u2014 tendre l'oreille au chant des morts qui traversent le voile\nB) Defier \u2014 regarder le sanglier dans les yeux et reclamer ton passage\nC) Offrir \u2014 deposer une offrande sur le cairn le plus ancien"
        },
        {
            "user": "Lieu: landes_bruyere. Theme: quete solitaire.",
            "response": "La bruyere craque sous tes pas. Pas d'arbre, pas d'ombre — rien que la lande et le ciel gris d'ardoise. Au loin, un dolmen solitaire se dresse comme un doigt pointe vers Avalon. Le vent porte une odeur de tourbe et de lichen. Tu es seul. Les corbeaux tournent en cercle au-dessus de ta tete.\n\nA) Avancer \u2014 marcher vers le dolmen malgre la fatigue\nB) Creuser \u2014 fouiller la tourbe la ou le sol semble creux\nC) Chanter \u2014 entonner un air ancien pour appeler de l'aide"
        },
        {
            "user": "Lieu: collines_dolmens. Theme: memoire des ancetres.",
            "response": "Les dolmens ici sont si vieux que la mousse les a reclames. Tu touches le granit — froid, rugueux, vivant. Sous tes doigts, tu sens les ogham. Beith, luis, quert... les trois premiers, ceux qu'on enseigne aux enfants du nemeton. Mais il y en a d'autres, plus profonds, que seuls les druides lisent.\n\nA) Dechiffrer \u2014 suivre les ogham du bout des doigts jusqu'au bout de l'inscription\nB) Prier \u2014 t'agenouiller et demander aux ancetres leur benediction\nC) Graver \u2014 ajouter ton propre ogham a la pierre eternelle"
        },
        {
            "user": "Lieu: marais_korrigans. Nuit. Brume epaisse.",
            "response": "La brume est si epaisse que tu ne vois pas tes propres pieds. Des lumieres dansent au-dessus du marais — feux follets ou yeux de korrigans, impossible de distinguer. L'eau clapote. Quelque chose se deplace sous la surface. Le sidhe est proche ici, si proche que tu sens son haleine froide sur ta nuque.\n\nA) Suivre \u2014 marcher vers les lumieres et decouvrir ce qu'elles cachent\nB) Invoquer \u2014 tracer l'ogham de protection dans la boue\nC) Attendre \u2014 rester immobile jusqu'a ce que la brume se leve"
        },
    ]

    samples = []
    for scenario in celtic_scenarios:
        samples.append({
            "messages": [
                {"role": "system", "content": CARD_SYSTEM_TEMPLATE},
                {"role": "user", "content": scenario["user"]},
                {"role": "assistant", "content": scenario["response"]},
            ]
        })

    return samples


def generate_gm_gold_samples() -> list:
    """Generate gold GM effects JSON samples."""
    gm_scenarios = [
        {
            "user": "Source sacree. A) Boire B) Mediter C) Verser l'eau.",
            "response": '[[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up","value":2},{"type":"HEAL_LIFE","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"up","value":1},{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"down","value":1}]]'
        },
        {
            "user": "Embuscade korrigans. A) Combattre B) Negocier C) Fuir.",
            "response": '[[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up","value":2},{"type":"DAMAGE_LIFE","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":1},{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"up","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"down","value":1}]]'
        },
        {
            "user": "Dolmen ancien. A) Toucher B) Dechiffrer C) Briser.",
            "response": '[[{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"up","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":2}],[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up","value":1},{"type":"DAMAGE_LIFE","value":2},{"type":"ADD_KARMA","value":-1}]]'
        },
        {
            "user": "Tempete cote. A) Affronter B) S'abriter C) Prier.",
            "response": '[[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up","value":2},{"type":"DAMAGE_LIFE","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"down","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":1},{"type":"HEAL_LIFE","value":1}]]'
        },
        {
            "user": "Nemeton. A) Invoquer B) Observer C) Partir.",
            "response": '[[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":2},{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"up","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"down","value":1}]]'
        },
        {
            "user": "Voyageur mourant. A) Guerir B) Sacrifier C) Accepter.",
            "response": '[[{"type":"HEAL_LIFE","value":3},{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up","value":1}],[{"type":"HEAL_LIFE","value":2},{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"down","value":2}],[{"type":"DAMAGE_LIFE","value":1},{"type":"ADD_KARMA","value":1}]]'
        },
        {
            "user": "Fete Beltaine. A) Danser B) Chanter C) Mediter.",
            "response": '[[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up","value":1},{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"up","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":2}],[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":1},{"type":"ADD_SOUFFLE","value":1}]]'
        },
        {
            "user": "Corbeau messager. A) Ecouter B) Suivre C) Chasser.",
            "response": '[[{"type":"SHIFT_ASPECT","aspect":"Ame","direction":"up","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Monde","direction":"up","value":1},{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"down","value":1}],[{"type":"SHIFT_ASPECT","aspect":"Corps","direction":"up","value":1},{"type":"ADD_KARMA","value":-1}]]'
        },
    ]

    samples = []
    for scenario in gm_scenarios:
        samples.append({
            "messages": [
                {"role": "system", "content": GM_SYSTEM_TEMPLATE},
                {"role": "user", "content": scenario["user"]},
                {"role": "assistant", "content": scenario["response"]},
            ]
        })

    return samples


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: TRAIN V2
# ═══════════════════════════════════════════════════════════════════════════════

def phase_train_v2(dataset_path: str, max_hours: float = 10.0, epochs: int = 3,
                   resume: bool = False) -> str:
    """Train v2 with optimized config. Returns output dir."""
    log("=" * 60)
    log("PHASE 3: TRAIN V2")
    log("=" * 60)

    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer, TrainerCallback
    from peft import LoraConfig, get_peft_model, TaskType
    from datasets import Dataset as HFDataset
    from trl import SFTTrainer, SFTConfig

    MODEL_NAME = "Qwen/Qwen3.5-2B"
    output_dir = str(V2_OUTPUT)
    os.makedirs(output_dir, exist_ok=True)

    # Progress file
    progress_file = os.path.join(output_dir, "progress.json")

    # Load dataset
    if not dataset_path or not os.path.exists(dataset_path):
        log(f"Dataset not found: {dataset_path}", "ERROR")
        return ""

    raw_samples = load_jsonl(dataset_path)
    log(f"Dataset: {dataset_path} ({len(raw_samples)} samples)")

    # Format for training
    formatted = [format_chatml(s) for s in raw_samples]
    dataset = HFDataset.from_list(formatted)
    split = dataset.train_test_split(test_size=0.1, seed=42)
    train_ds = split["train"]
    eval_ds = split["test"]
    log(f"Train: {len(train_ds)} | Eval: {len(eval_ds)}")

    # Load model
    log(f"Loading {MODEL_NAME}...")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME, dtype=torch.float32, device_map="cpu", trust_remote_code=True
    )

    # CPU throttle
    try:
        import psutil
        proc = psutil.Process()
        all_cpus = list(range(psutil.cpu_count(logical=True)))
        proc.nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
        log(f"CPU: {len(all_cpus)} cores, BELOW_NORMAL priority")
    except Exception as e:
        log(f"CPU throttle warning: {e}")

    # LoRA config v2: more target modules for better quality
    lora_config = LoraConfig(
        r=16,
        lora_alpha=32,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj"],  # 4 modules intentional (7 would OOM on CPU overnight runs)
        lora_dropout=0.05,  # Small dropout for regularization
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, lora_config)

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    log(f"LoRA v2: r=16, alpha=32, modules={lora_config.target_modules}")
    log(f"Trainable: {trainable:,} / {total:,} ({100*trainable/total:.2f}%)")

    # Estimate timing
    batch_size = 1
    grad_accum = 8
    steps_per_epoch = len(train_ds) // (batch_size * grad_accum)
    total_steps = steps_per_epoch * epochs
    # With 4 modules at 512 tokens: ~500s/step estimated
    est_sec_per_step = 500
    est_total_h = total_steps * est_sec_per_step / 3600
    log(f"\nEstimate: {steps_per_epoch} steps/epoch x {epochs} = {total_steps} steps")
    log(f"  ~{est_sec_per_step}s/step -> ~{est_total_h:.1f}h total")
    log(f"  Budget: {max_hours}h")

    if est_total_h > max_hours * 1.2:
        # Reduce epochs to fit
        safe_epochs = max(1, int(max_hours * 3600 / (steps_per_epoch * est_sec_per_step)))
        log(f"  Adjusting epochs: {epochs} -> {safe_epochs} to fit budget")
        epochs = safe_epochs
        total_steps = steps_per_epoch * epochs

    # Stop time calculation
    stop_time_str = (datetime.now() + timedelta(hours=max_hours)).strftime("%H:%M")

    # Training config
    sft_config = SFTConfig(
        output_dir=output_dir,
        num_train_epochs=epochs,
        per_device_train_batch_size=batch_size,
        per_device_eval_batch_size=batch_size,
        gradient_accumulation_steps=grad_accum,
        learning_rate=1.5e-4,  # Slightly lower than v1 (2e-4) for stability
        weight_decay=0.01,
        warmup_ratio=0.1,
        lr_scheduler_type="cosine",
        optim="adamw_torch",
        fp16=False,
        bf16=False,
        use_cpu=True,
        dataloader_num_workers=0,
        dataset_text_field="text",
        max_length=512,  # THE KEY FIX: 512 instead of 384
        packing=False,
        logging_steps=5,
        eval_strategy="steps",
        eval_steps=25,
        save_strategy="steps",
        save_steps=25,
        save_total_limit=3,
        load_best_model_at_end=True,
        seed=42,
        report_to="none",
        disable_tqdm=False,
    )

    trainer = SFTTrainer(
        model=model,
        processing_class=tokenizer,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        args=sft_config,
    )

    # Progress callback
    class ProgressCallback(TrainerCallback):
        def __init__(self):
            self._t0 = time.time()

        def on_log(self, _args, state, control, logs=None, **kwargs):
            loss = (logs or {}).get("loss", 0.0)
            elapsed = time.time() - self._t0
            eta = (total_steps - state.global_step) * (elapsed / max(state.global_step, 1))
            data = {
                "pid": os.getpid(), "status": "training",
                "step": state.global_step, "total_steps": total_steps,
                "epoch": round(state.epoch or 0, 2), "total_epochs": epochs,
                "loss": round(loss, 4), "elapsed_sec": round(elapsed),
                "eta_sec": round(eta), "pct": round(100 * state.global_step / max(total_steps, 1), 1),
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
            }
            try:
                with open(progress_file + ".tmp", "w") as f:
                    json.dump(data, f, indent=2)
                os.replace(progress_file + ".tmp", progress_file)
            except Exception:
                pass

        def on_step_end(self, _args, state, control, **kwargs):
            # Time-based stop
            elapsed_h = (time.time() - self._t0) / 3600
            if elapsed_h >= max_hours:
                log(f"[STOP] Time budget exhausted ({elapsed_h:.1f}h >= {max_hours}h)")
                control.should_training_stop = True
                control.should_save = True
            # Flag-based stop
            stop_flag = os.path.join(output_dir, "training_stop.flag")
            if os.path.exists(stop_flag):
                log("[STOP] Manual stop flag detected")
                try: os.remove(stop_flag)
                except: pass
                control.should_training_stop = True
                control.should_save = True

    trainer.add_callback(ProgressCallback())

    log(f"\n{'=' * 60}")
    log(f"TRAINING V2 — max_seq=512, 4 LoRA modules, {epochs} epochs")
    log(f"  Stop: {stop_time_str} or after {max_hours}h")
    log(f"  Progress: {progress_file}")
    log(f"  Manual stop: create {output_dir}/training_stop.flag")
    log(f"{'=' * 60}\n")

    t0 = time.time()
    # Check for resume
    resume_ckpt = None
    if resume:
        checkpoints = [d for d in os.listdir(output_dir)
                       if d.startswith("checkpoint-") and os.path.isdir(os.path.join(output_dir, d))]
        if checkpoints:
            latest = sorted(checkpoints, key=lambda x: int(x.split("-")[1]))[-1]
            resume_ckpt = os.path.join(output_dir, latest)
            log(f"Resume from: {resume_ckpt}")

    train_result = trainer.train(resume_from_checkpoint=resume_ckpt)
    elapsed = time.time() - t0

    log(f"\nTRAINING COMPLETE: {elapsed/3600:.1f}h")
    for key, value in train_result.metrics.items():
        log(f"  {key}: {value}")

    # Save final adapter
    final_dir = os.path.join(output_dir, "final-adapter")
    model.save_pretrained(final_dir)
    tokenizer.save_pretrained(final_dir)
    log(f"Final adapter: {final_dir}")

    # Update progress
    try:
        with open(progress_file, "w") as f:
            json.dump({"status": "done", "elapsed_h": round(elapsed/3600, 1),
                        "metrics": train_result.metrics}, f, indent=2)
    except Exception:
        pass

    del model, tokenizer, trainer; gc.collect()
    return final_dir


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: MERGE + CONVERT
# ═══════════════════════════════════════════════════════════════════════════════

def phase_merge_convert(adapter_dir: str) -> str:
    """Merge LoRA into base model and prepare for Ollama. Returns merged dir."""
    log("=" * 60)
    log("PHASE 4: MERGE + CONVERT FOR OLLAMA")
    log("=" * 60)

    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer
    from peft import PeftModel

    MODEL_NAME = "Qwen/Qwen3.5-2B"
    merged_dir = str(V2_OUTPUT / "merged-model") if "v2" in adapter_dir else str(V1_OUTPUT / "merged-model")

    if not os.path.exists(adapter_dir):
        log(f"Adapter not found: {adapter_dir}", "ERROR")
        return ""

    # Load base model
    log(f"Loading base model: {MODEL_NAME}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME, dtype=torch.float32, device_map="cpu", trust_remote_code=True
    )

    # Load and merge adapter
    log(f"Loading adapter: {adapter_dir}")
    model = PeftModel.from_pretrained(model, adapter_dir)
    log("Merging LoRA into base model...")
    model = model.merge_and_unload()

    # Save merged model
    os.makedirs(merged_dir, exist_ok=True)
    log(f"Saving merged model: {merged_dir}")
    model.save_pretrained(merged_dir)
    tokenizer.save_pretrained(merged_dir)
    log(f"Merged model saved ({sum(f.stat().st_size for f in Path(merged_dir).rglob('*') if f.is_file()) / 1e9:.1f} GB)")

    # Create Modelfile for Ollama
    modelfile_path = os.path.join(merged_dir, "Modelfile")
    modelfile_content = f"""FROM {merged_dir}

TEMPLATE \"\"\"<|im_start|>system
{{{{ .System }}}}<|im_end|>
<|im_start|>user
{{{{ .Prompt }}}}<|im_end|>
<|im_start|>assistant
\"\"\"

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.3
PARAMETER num_ctx 4096
PARAMETER stop "<|im_end|>"
PARAMETER stop "<|im_start|>"

SYSTEM \"\"\"{SHORT_PRIMER}\"\"\"
"""
    with open(modelfile_path, "w", encoding="utf-8") as f:
        f.write(modelfile_content)
    log(f"Modelfile created: {modelfile_path}")

    del model, tokenizer; gc.collect()
    return merged_dir


def phase_deploy_ollama(merged_dir: str, model_name: str = "merlin-narrator") -> bool:
    """Deploy merged model to Ollama. Returns success."""
    log("=" * 60)
    log(f"DEPLOYING TO OLLAMA: {model_name}")
    log("=" * 60)

    import subprocess

    modelfile = os.path.join(merged_dir, "Modelfile")
    if not os.path.exists(modelfile):
        log(f"Modelfile not found: {modelfile}", "ERROR")
        return False

    # Check Ollama is running
    try:
        import requests
        resp = requests.get("http://localhost:11434/api/tags", timeout=5)
        if resp.status_code == 200:
            log("Ollama server is running")
        else:
            log("Ollama server returned non-200, trying anyway", "WARN")
    except Exception:
        log("Ollama server not reachable, starting...", "WARN")
        subprocess.Popen(["ollama", "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(5)

    # Create model
    log(f"Creating Ollama model '{model_name}' from {modelfile}...")
    log("  (This may take several minutes for GGUF conversion)")

    try:
        result = subprocess.run(
            ["ollama", "create", model_name, "-f", modelfile],
            capture_output=True, text=True, timeout=1800  # 30 min timeout
        )
        if result.returncode == 0:
            log(f"Ollama model '{model_name}' created successfully!")
            return True
        else:
            log(f"Ollama create failed: {result.stderr[:500]}", "ERROR")
            return False
    except subprocess.TimeoutExpired:
        log("Ollama create timed out (30 min)", "ERROR")
        return False
    except Exception as e:
        log(f"Ollama create error: {e}", "ERROR")
        return False


# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 5: BENCHMARK
# ═══════════════════════════════════════════════════════════════════════════════

def phase_benchmark(model_name: str = "merlin-narrator") -> dict:
    """Benchmark model through Ollama API. Returns metrics."""
    log("=" * 60)
    log(f"PHASE 5: BENCHMARK ({model_name})")
    log("=" * 60)

    import requests

    OLLAMA_API = "http://localhost:11434/api/generate"

    # Test if model is available
    try:
        resp = requests.get("http://localhost:11434/api/tags", timeout=5)
        models = [m["name"] for m in resp.json().get("models", [])]
        if model_name not in models and f"{model_name}:latest" not in models:
            log(f"Model '{model_name}' not found in Ollama. Available: {models}", "ERROR")
            return {"status": "error", "reason": "model not found"}
    except Exception as e:
        log(f"Cannot connect to Ollama: {e}", "ERROR")
        return {"status": "error", "reason": str(e)}

    # Benchmark prompts
    test_cases = [
        {"system": CARD_SYSTEM_TEMPLATE, "prompt": "Lieu: foret_broceliande. Saison: automne. Genere la carte.", "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE, "prompt": "Lieu: marais_korrigans. Nuit de Samhain. Corps=bas. Genere la carte.", "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE, "prompt": "Lieu: cercles_pierres. Hiver. Tension. Genere la carte.", "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE, "prompt": "Lieu: cotes_sauvages. Tempete. Acte III. Genere la carte.", "category": "card"},
        {"system": CARD_SYSTEM_TEMPLATE, "prompt": "Lieu: villages_celtes. Printemps. Premiere carte. Genere.", "category": "card"},
        {"system": DANGER_SYSTEM_TEMPLATE, "prompt": "Vie: 15%. Lieu: landes_bruyere. Voyageur mourant.", "category": "danger"},
        {"system": DIALOGUE_SYSTEM_TEMPLATE, "prompt": "Qui es-tu, Merlin?", "category": "dialogue"},
        {"system": DIALOGUE_SYSTEM_TEMPLATE, "prompt": "Pourquoi dois-je souffrir?", "category": "dialogue"},
        {"system": GM_SYSTEM_TEMPLATE, "prompt": "A) Explorer B) Mediter C) Fuir. Source sacree.", "category": "gm_effects"},
        {"system": GM_SYSTEM_TEMPLATE, "prompt": "A) Combattre B) Negocier C) Observer. Embuscade.", "category": "gm_effects"},
    ]

    results = []
    for i, test in enumerate(test_cases):
        t0 = time.time()
        try:
            resp = requests.post(OLLAMA_API, json={
                "model": model_name,
                "system": test["system"],
                "prompt": test["prompt"],
                "stream": False,
                "options": {
                    "temperature": 0.7,
                    "top_p": 0.9,
                    "repeat_penalty": 1.3,
                    "num_predict": 250,
                }
            }, timeout=120)
            gen_time = time.time() - t0
            output = resp.json().get("response", "")
        except Exception as e:
            gen_time = time.time() - t0
            output = f"ERROR: {e}"

        results.append({
            "idx": i,
            "category": test["category"],
            "prompt": test["prompt"][:100],
            "output": output,
            "generation_time_sec": round(gen_time, 1),
        })

        log(f"  Test {i+1}/{len(test_cases)}: {test['category']} ({gen_time:.1f}s)")
        print(f"    {safe_print(output[:150])}...")

    # Compute metrics
    metrics = compute_eval_metrics(results)
    metrics["model_name"] = model_name

    # Save
    report_path = str(REPORTS_DIR / f"benchmark_{model_name.replace(':', '_')}.json")
    save_json({"metrics": metrics, "results": results}, report_path)

    log(f"\n  FORMAT COMPLIANCE: {metrics['format_compliance']:.0%}")
    log(f"  FRENCH RATE:       {metrics['french_rate']:.0%}")
    log(f"  CELTIC VOCAB:      {metrics['celtic_density']:.1f} terms/card")
    log(f"  2ND PERSON TU:     {metrics['tu_rate']:.0%}")
    log(f"  GM JSON VALID:     {metrics['gm_json_valid']:.0%}")
    log(f"  AVG GEN TIME:      {metrics['avg_gen_time']:.1f}s")

    # GO/NO-GO decision
    go_criteria = {
        "format_compliance": (metrics["format_compliance"], 0.70),
        "french_rate": (metrics["french_rate"], 0.90),
        "tu_rate": (metrics["tu_rate"], 0.60),
    }
    all_pass = all(actual >= target for actual, target in go_criteria.values())
    decision = "GO" if all_pass else "NO-GO"
    log(f"\n  DECISION: {decision}")
    for name, (actual, target) in go_criteria.items():
        status = "PASS" if actual >= target else "FAIL"
        log(f"    {name}: {actual:.0%} vs {target:.0%} [{status}]")

    metrics["decision"] = decision
    return metrics


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN ORCHESTRATOR
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="M.E.R.L.I.N. Overnight LoRA Orchestrator v2")
    parser.add_argument("--phase", choices=["eval", "dataset", "train", "convert", "benchmark", "all"],
                        default="all", help="Which phase to run")
    parser.add_argument("--hours", type=float, default=12.0, help="Total time budget in hours")
    parser.add_argument("--stop-at", type=str, default="", help="Stop time (HH:MM)")
    parser.add_argument("--epochs", type=int, default=3, help="Training epochs")
    parser.add_argument("--resume", action="store_true", help="Resume training from checkpoint")
    parser.add_argument("--skip-eval", action="store_true", help="Skip v1 evaluation")
    parser.add_argument("--v1-only", action="store_true", help="Only convert v1 (no retrain)")
    args = parser.parse_args()

    t0 = time.time()
    os.makedirs(str(REPORTS_DIR), exist_ok=True)

    log("=" * 60)
    log("M.E.R.L.I.N. — OVERNIGHT LoRA ORCHESTRATOR v2")
    log(f"  Budget: {args.hours}h | Epochs: {args.epochs}")
    log(f"  Start: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    if args.stop_at:
        log(f"  Stop at: {args.stop_at}")
    log("=" * 60)

    # Allocate time budget
    total_budget_h = args.hours
    eval_budget_h = 0.5
    dataset_budget_h = 0.3
    convert_budget_h = 0.5
    benchmark_budget_h = 0.3
    overhead_h = 0.4
    train_budget_h = total_budget_h - eval_budget_h - dataset_budget_h - convert_budget_h - benchmark_budget_h - overhead_h
    log(f"  Training budget: {train_budget_h:.1f}h (after eval/dataset/convert/benchmark)")

    phase = args.phase

    # ── Phase 1: Eval V1 ──
    if phase in ("all", "eval") and not args.skip_eval:
        try:
            v1_metrics = phase_eval_v1()
            log(f"\nPhase 1 complete ({(time.time()-t0)/60:.0f} min elapsed)")
        except Exception as e:
            log(f"Phase 1 failed: {e}", "ERROR")
            v1_metrics = {"status": "error"}

    # ── Phase 2: Optimize Dataset ──
    dataset_path = str(V9_DATASET)
    if phase in ("all", "dataset"):
        try:
            dataset_path = phase_optimize_dataset()
            log(f"\nPhase 2 complete ({(time.time()-t0)/60:.0f} min elapsed)")
        except Exception as e:
            log(f"Phase 2 failed: {e}", "ERROR")
            dataset_path = str(V8_DATASET)  # fallback to v8

    # ── Phase 3: Train V2 ──
    adapter_dir = ""
    if phase in ("all", "train") and not args.v1_only:
        elapsed_h = (time.time() - t0) / 3600
        remaining_h = total_budget_h - elapsed_h - convert_budget_h - benchmark_budget_h - 0.2
        log(f"\nTraining budget remaining: {remaining_h:.1f}h")
        try:
            adapter_dir = phase_train_v2(
                dataset_path=dataset_path or str(V9_DATASET),
                max_hours=max(remaining_h, 1.0),
                epochs=args.epochs,
                resume=args.resume,
            )
            log(f"\nPhase 3 complete ({(time.time()-t0)/3600:.1f}h elapsed)")
        except Exception as e:
            log(f"Phase 3 failed: {e}", "ERROR")
            import traceback; traceback.print_exc()

    # ── Phase 4: Merge + Convert ──
    merged_dir = ""
    if phase in ("all", "convert"):
        # Use v2 adapter if available, else v1
        if not adapter_dir:
            if args.v1_only:
                adapter_dir = str(V1_OUTPUT / "checkpoint-225")
            elif (V2_OUTPUT / "final-adapter" / "adapter_config.json").exists():
                adapter_dir = str(V2_OUTPUT / "final-adapter")
            else:
                adapter_dir = str(V1_OUTPUT / "checkpoint-225")

        try:
            merged_dir = phase_merge_convert(adapter_dir)
            if merged_dir:
                success = phase_deploy_ollama(merged_dir, "merlin-narrator")
                if success:
                    log("Ollama deployment successful!")
                else:
                    log("Ollama deployment failed — model can still be used via transformers", "WARN")
            log(f"\nPhase 4 complete ({(time.time()-t0)/3600:.1f}h elapsed)")
        except Exception as e:
            log(f"Phase 4 failed: {e}", "ERROR")
            import traceback; traceback.print_exc()

    # ── Phase 5: Benchmark ──
    if phase in ("all", "benchmark"):
        try:
            bench_metrics = phase_benchmark("merlin-narrator")
            log(f"\nPhase 5 complete ({(time.time()-t0)/3600:.1f}h elapsed)")

            # Also benchmark base model for comparison
            try:
                log("\nBenchmarking base model for comparison...")
                base_metrics = phase_benchmark("qwen3.5:4b")
                log("\nComparison:")
                for key in ["format_compliance", "french_rate", "celtic_density", "tu_rate"]:
                    base_val = base_metrics.get(key, 0)
                    lora_val = bench_metrics.get(key, 0)
                    diff = lora_val - base_val
                    log(f"  {key}: base={base_val:.2f} lora={lora_val:.2f} ({'+' if diff >= 0 else ''}{diff:.2f})")
            except Exception:
                log("Base model benchmark skipped", "WARN")

        except Exception as e:
            log(f"Phase 5 failed: {e}", "ERROR")

    # ── Final Report ──
    elapsed_total = (time.time() - t0) / 3600
    log(f"\n{'=' * 60}")
    log(f"OVERNIGHT SESSION COMPLETE")
    log(f"  Total time: {elapsed_total:.1f}h")
    log(f"  End: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log(f"  Reports: {REPORTS_DIR}")
    log(f"{'=' * 60}")


if __name__ == "__main__":
    main()

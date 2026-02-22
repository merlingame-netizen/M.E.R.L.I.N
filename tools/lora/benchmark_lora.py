#!/usr/bin/env python3
"""
Benchmark M.E.R.L.I.N. LoRA adapter quality.

Evaluates:
  1. Tone consistency: Does the model produce the requested tone?
  2. Celtic vocabulary density: Frequency of druidic terms in output
  3. French quality: Basic language validation
  4. Diversity: Self-BLEU score (lower = more diverse)
  5. Length compliance: Output within expected bounds
  6. Scene contract adherence (if scene_id + scene profiles are available)

Usage:
  python tools/lora/benchmark_lora.py --results PATH_TO_GENERATION_LOG

  The generation log should be a JSON file with entries:
  [{"tone_requested": "playful", "output": "...", "generation_time_ms": 450}, ...]

  To generate a benchmark log, run the game with LLM_BENCHMARK=true env var.
"""

import argparse
import json
import os
import re
import sys
from collections import Counter
from typing import Optional

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SCENE_PROFILES_PATH = os.path.join(PROJECT_ROOT, "data", "ai", "config", "scene_profiles.json")

# Celtic vocabulary targets
CELTIC_TERMS = {
    "ogham", "nemeton", "sidhe", "dolmen", "menhir", "cromlech", "cairn",
    "korrigans", "druide", "brume", "mousse", "lichen", "tourbe", "granit",
    "chene", "bouleau", "sorbier", "pommier", "if", "houx", "saule",
    "samhain", "beltaine", "imbolc", "lughnasadh",
    "sanglier", "corbeau", "cerf", "saumon", "grue",
    "broceliande", "avalon", "carnac",
}

# Tone keyword heuristics for classification
TONE_KEYWORDS = {
    "playful": ["ah", "ho ho", "tiens", "hehe", "amusant", "interessant", "curieux", "pas mal"],
    "mysterious": ["...", "peut-etre", "qui sait", "secret", "voile", "ombre", "enigme", "mystere"],
    "warning": ["attention", "prends garde", "danger", "prudence", "mefiez", "ecoute bien"],
    "melancholy": ["parfois", "jadis", "il fut un temps", "autrefois", "souvenir", "triste"],
    "warm": ["mon ami", "voyageur", "courage", "ensemble", "confiance", "n'est-ce pas"],
    "cryptic": ["on dit que", "certains voient", "double", "sens", "inverse", "miroir"],
}

# French stopwords for basic language detection
FR_STOPWORDS = {"le", "la", "de", "un", "une", "du", "les", "des", "en", "et", "est", "dans", "que", "qui", "pour"}


def deep_merge_dict(base: dict, overlay: dict) -> dict:
    merged = dict(base)
    for key, value in overlay.items():
        if isinstance(merged.get(key), dict) and isinstance(value, dict):
            merged[key] = deep_merge_dict(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_scene_profiles() -> dict:
    if not os.path.exists(SCENE_PROFILES_PATH):
        return {}
    with open(SCENE_PROFILES_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, dict) else {}


def resolve_scene_contract(scene_profiles: dict, scene_id: str, channel: str = "narrative") -> dict:
    if not scene_profiles or not scene_id:
        return {}
    merged = {}
    default_profile = scene_profiles.get("default", {})
    scene_profile = scene_profiles.get(scene_id, {})
    if isinstance(default_profile, dict):
        merged = deep_merge_dict(merged, default_profile)
    if isinstance(scene_profile, dict):
        merged = deep_merge_dict(merged, scene_profile)
        channels = scene_profile.get("channels", {})
        if isinstance(channels, dict):
            channel_profile = channels.get(channel, {})
            if isinstance(channel_profile, dict):
                merged = deep_merge_dict(merged, channel_profile)
    merged["scene_id"] = scene_id
    return merged


def split_sentences(text: str) -> list:
    chunks = re.split(r"[.!?]+(?:\s+|$)", text.strip())
    return [c.strip() for c in chunks if c.strip()]


def classify_tone(text: str) -> str:
    """Heuristic tone classification based on keywords."""
    text_lower = text.lower()
    scores = {}
    for tone, keywords in TONE_KEYWORDS.items():
        score = sum(1 for kw in keywords if kw in text_lower)
        scores[tone] = score
    best_tone = max(scores, key=scores.get) if max(scores.values()) > 0 else "neutral"
    return best_tone


def count_celtic_terms(text: str) -> int:
    """Count Celtic/druidic vocabulary terms in text."""
    text_lower = text.lower()
    return sum(1 for term in CELTIC_TERMS if term in text_lower)


def is_french(text: str) -> bool:
    """Basic French language detection."""
    words = set(text.lower().split())
    fr_count = len(words & FR_STOPWORDS)
    return fr_count >= 2


def compute_self_bleu(texts: list, n: int = 4) -> float:
    """Compute Self-BLEU: average BLEU of each text against all others.
    Lower = more diverse (good). Higher = more repetitive (bad)."""
    if len(texts) < 2:
        return 0.0

    def get_ngrams(text: str, n: int) -> Counter:
        words = text.lower().split()
        return Counter(tuple(words[i:i+n]) for i in range(len(words) - n + 1))

    total_bleu = 0.0
    for i, text in enumerate(texts):
        hyp_ngrams = get_ngrams(text, n)
        if not hyp_ngrams:
            continue
        # Reference = all other texts merged
        ref_ngrams = Counter()
        for j, other in enumerate(texts):
            if i != j:
                ref_ngrams += get_ngrams(other, n)

        # Clipped count
        clipped = sum(min(count, ref_ngrams.get(ng, 0)) for ng, count in hyp_ngrams.items())
        total_hyp = sum(hyp_ngrams.values())
        precision = clipped / total_hyp if total_hyp > 0 else 0
        total_bleu += precision

    return total_bleu / len(texts)


def compute_scene_metrics(results: list, scene_profiles: dict) -> dict:
    metrics = {
        "scene_samples": 0,
        "scene_contract_compliance": 0.0,
        "must_reference_rate": 0.0,
        "forbidden_violation_rate": 0.0,
        "sentence_limit_compliance": 0.0,
        "word_limit_compliance": 0.0,
    }

    if not scene_profiles or not results:
        return metrics

    contract_pass_count = 0
    must_ref_hits = 0
    must_ref_total = 0
    forbidden_violations = 0
    sentence_limit_hits = 0
    word_limit_hits = 0
    sentence_limit_total = 0
    word_limit_total = 0

    for entry in results:
        meta = entry.get("metadata", {}) if isinstance(entry.get("metadata", {}), dict) else {}
        scene_id = str(entry.get("scene_id", "") or meta.get("scene_id", "")).strip()
        if not scene_id:
            continue

        channel = str(entry.get("channel", "") or meta.get("channel", "narrative")).strip() or "narrative"
        output = str(entry.get("output", "")).strip()
        if not output:
            continue

        contract = resolve_scene_contract(scene_profiles, scene_id, channel)
        if not contract:
            continue

        metrics["scene_samples"] += 1
        output_lower = output.lower()
        sample_ok = True

        must_ref = contract.get("must_reference", [])
        if isinstance(must_ref, list):
            for token in must_ref:
                token_str = str(token).strip().lower()
                if not token_str:
                    continue
                must_ref_total += 1
                if token_str in output_lower:
                    must_ref_hits += 1
                else:
                    sample_ok = False

        forbidden = contract.get("forbidden_topics", [])
        if isinstance(forbidden, list):
            for token in forbidden:
                token_str = str(token).strip().lower()
                if token_str and token_str in output_lower:
                    forbidden_violations += 1
                    sample_ok = False

        limits = contract.get("response_limits", {})
        if isinstance(limits, dict):
            max_sentences = int(limits.get("max_sentences", 0) or 0)
            if max_sentences > 0:
                sentence_limit_total += 1
                sentence_count = len(split_sentences(output))
                if sentence_count <= max_sentences:
                    sentence_limit_hits += 1
                else:
                    sample_ok = False

            max_words = int(limits.get("max_words", 0) or 0)
            if max_words > 0:
                word_limit_total += 1
                word_count = len(re.findall(r"\b\w+\b", output, flags=re.UNICODE))
                if word_count <= max_words:
                    word_limit_hits += 1
                else:
                    sample_ok = False

        if sample_ok:
            contract_pass_count += 1

    if metrics["scene_samples"] > 0:
        metrics["scene_contract_compliance"] = contract_pass_count / metrics["scene_samples"]
    if must_ref_total > 0:
        metrics["must_reference_rate"] = must_ref_hits / must_ref_total
    if forbidden_violations > 0:
        metrics["forbidden_violation_rate"] = forbidden_violations / metrics["scene_samples"]
    if sentence_limit_total > 0:
        metrics["sentence_limit_compliance"] = sentence_limit_hits / sentence_limit_total
    if word_limit_total > 0:
        metrics["word_limit_compliance"] = word_limit_hits / word_limit_total

    return metrics


def extract_verb_lines(text: str) -> list:
    """Extract A) VERB — description lines from output text."""
    pattern = r"^[A-D][):.]\s*([A-ZÀ-Ü][A-ZÀ-Ü\s']*?)\s*[—–\-:]+\s*(.+)$"
    matches = []
    for line in text.split("\n"):
        m = re.match(pattern, line.strip())
        if m:
            matches.append({"verb": m.group(1).strip(), "desc": m.group(2).strip()})
    return matches


def compute_verb_metrics(results: list) -> dict:
    """Compute verb extraction and format compliance metrics."""
    verb_metrics = {
        "verb_extraction_rate": 0.0,
        "format_compliance": 0.0,
        "verb_diversity_jaccard": 0.0,
        "unique_verbs": 0,
        "avg_desc_length": 0.0,
        "verb_source_llm_rate": 0.0,
    }

    if not results:
        return verb_metrics

    total_with_verbs = 0
    total_fully_formatted = 0
    all_verbs = []
    all_desc_lengths = []
    llm_source_count = 0
    total_source_checked = 0

    for entry in results:
        output = entry.get("output", "")
        verb_lines = extract_verb_lines(output)

        if verb_lines:
            total_with_verbs += 1
            for vl in verb_lines:
                all_verbs.append(vl["verb"])
                all_desc_lengths.append(len(vl["desc"]))

        # Format compliance: exactly 3 verb lines with descriptions
        if len(verb_lines) == 3 and all(len(vl["desc"]) > 10 for vl in verb_lines):
            total_fully_formatted += 1

        # Verb source tracking (from card_log entries)
        sources = entry.get("verb_sources", [])
        if sources:
            total_source_checked += len(sources)
            llm_source_count += sum(1 for s in sources if s == "llm")

    verb_metrics["verb_extraction_rate"] = total_with_verbs / len(results) if results else 0
    verb_metrics["format_compliance"] = total_fully_formatted / len(results) if results else 0
    verb_metrics["unique_verbs"] = len(set(all_verbs))
    verb_metrics["avg_desc_length"] = sum(all_desc_lengths) / len(all_desc_lengths) if all_desc_lengths else 0
    verb_metrics["verb_source_llm_rate"] = llm_source_count / total_source_checked if total_source_checked else 0

    # Verb diversity via Jaccard: compare consecutive pairs
    if len(results) >= 2:
        jaccard_scores = []
        for i in range(len(results) - 1):
            verbs_a = set(vl["verb"] for vl in extract_verb_lines(results[i].get("output", "")))
            verbs_b = set(vl["verb"] for vl in extract_verb_lines(results[i + 1].get("output", "")))
            if verbs_a and verbs_b:
                intersection = len(verbs_a & verbs_b)
                union = len(verbs_a | verbs_b)
                jaccard_scores.append(intersection / union if union > 0 else 0)
        verb_metrics["verb_diversity_jaccard"] = sum(jaccard_scores) / len(jaccard_scores) if jaccard_scores else 0

    return verb_metrics


def benchmark(results: list, scene_profiles: Optional[dict] = None) -> dict:
    """Run all benchmark metrics."""
    metrics = {
        "total_samples": len(results),
        "tone_accuracy": 0.0,
        "celtic_vocab_density": 0.0,
        "french_rate": 0.0,
        "self_bleu": 0.0,
        "avg_length": 0.0,
        "length_compliance": 0.0,
        "avg_generation_time_ms": 0.0,
        "verb_extraction_rate": 0.0,
        "format_compliance": 0.0,
        "verb_diversity_jaccard": 0.0,
        "unique_verbs": 0,
        "avg_desc_length": 0.0,
        "verb_source_llm_rate": 0.0,
        "scene_samples": 0,
        "scene_contract_compliance": 0.0,
        "must_reference_rate": 0.0,
        "forbidden_violation_rate": 0.0,
        "sentence_limit_compliance": 0.0,
        "word_limit_compliance": 0.0,
    }

    if not results:
        return metrics

    # 1. Tone consistency
    tone_correct = 0
    for entry in results:
        requested = entry.get("tone_requested", "neutral")
        predicted = classify_tone(entry.get("output", ""))
        if predicted == requested:
            tone_correct += 1
    metrics["tone_accuracy"] = tone_correct / len(results)

    # 2. Celtic vocabulary density
    total_celtic = sum(count_celtic_terms(e.get("output", "")) for e in results)
    metrics["celtic_vocab_density"] = total_celtic / len(results)

    # 3. French language rate
    french_count = sum(1 for e in results if is_french(e.get("output", "")))
    metrics["french_rate"] = french_count / len(results)

    # 4. Self-BLEU (diversity)
    texts = [e.get("output", "") for e in results if len(e.get("output", "")) > 20]
    metrics["self_bleu"] = compute_self_bleu(texts)

    # 5. Length metrics
    lengths = [len(e.get("output", "")) for e in results]
    metrics["avg_length"] = sum(lengths) / len(lengths)
    compliant = sum(1 for l in lengths if 10 <= l <= 500)
    metrics["length_compliance"] = compliant / len(lengths)

    # 6. Generation time
    times = [e.get("generation_time_ms", 0) for e in results if e.get("generation_time_ms", 0) > 0]
    metrics["avg_generation_time_ms"] = sum(times) / len(times) if times else 0

    # 7. Verb extraction and format compliance (NEW)
    verb_metrics = compute_verb_metrics(results)
    metrics.update(verb_metrics)

    scene_metrics = compute_scene_metrics(results, scene_profiles or {})
    metrics.update(scene_metrics)

    return metrics


def print_report(metrics: dict, targets: dict):
    """Print formatted benchmark report."""
    print("\n" + "=" * 60)
    print("  M.E.R.L.I.N. LoRA Benchmark Report")
    print("=" * 60)
    lower_is_better = {"self_bleu", "forbidden_violation_rate", "verb_diversity_jaccard"}

    for metric, value in metrics.items():
        target = targets.get(metric)
        if isinstance(value, float):
            status = ""
            if target is not None:
                if metric in lower_is_better:
                    ok = value < target
                else:
                    ok = value >= target
                status = " [PASS]" if ok else " [FAIL]"
            target_str = f" (target: {target})" if target else ""
            print(f"  {metric:30s}: {value:.3f}{target_str}{status}")
        else:
            print(f"  {metric:30s}: {value}")

    print("=" * 60)


def main():
    parser = argparse.ArgumentParser(description="Benchmark M.E.R.L.I.N. LoRA adapter")
    parser.add_argument("--results", required=True, help="Path to generation log JSON")
    args = parser.parse_args()

    print(f"[benchmark] Loading results: {args.results}")
    with open(args.results, "r", encoding="utf-8") as f:
        results = json.load(f)

    if isinstance(results, dict):
        results = results.get("entries", results.get("samples", []))

    scene_profiles = load_scene_profiles()
    if scene_profiles:
        print(f"[benchmark] Scene profiles loaded: {len(scene_profiles)}")
    else:
        print("[benchmark] Scene profiles not found or invalid. Scene metrics will remain 0.")

    targets = {
        "tone_accuracy": 0.85,
        "celtic_vocab_density": 0.5,
        "french_rate": 0.95,
        "self_bleu": 0.4,
        "length_compliance": 0.90,
        "verb_extraction_rate": 0.80,
        "format_compliance": 0.90,
        "verb_diversity_jaccard": 0.5,
        "scene_contract_compliance": 0.90,
        "must_reference_rate": 0.85,
        "forbidden_violation_rate": 0.05,
        "sentence_limit_compliance": 0.90,
        "word_limit_compliance": 0.90,
    }

    metrics = benchmark(results, scene_profiles)
    print_report(metrics, targets)

    # Save metrics
    output_path = args.results.replace(".json", "_metrics.json")
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump({"metrics": metrics, "targets": targets}, f, indent=2)
    print(f"\n  Metrics saved to: {output_path}")


if __name__ == "__main__":
    main()

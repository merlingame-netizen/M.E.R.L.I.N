#!/usr/bin/env python3
"""
M.E.R.L.I.N. — Extracteur de corpus d'entrainement depuis la documentation.

Enrichit le dataset existant (merlin_full_v8.jsonl) avec des exemples extraits
de la documentation du projet : lore, persona, narratifs, verbes, biomes.

Output: data/ai/training/merlin_enriched_v9.jsonl

Usage:
  python tools/lora/build_doc_corpus.py --merge-v8        # Genere v9 = v8 + doc samples
  python tools/lora/build_doc_corpus.py --stats            # Stats sans ecriture
  python tools/lora/build_doc_corpus.py --output-dir PATH  # Override output dir
  python tools/lora/build_doc_corpus.py --preview 5        # Apercu 5 exemples
"""

import argparse
import datetime
import json
import os
import re
import random
from pathlib import Path

# ── Constants ─────────────────────────────────────────────────────────────────

PROJECT_ROOT = Path(__file__).parent.parent.parent

# Source docs watched for auto-rebuild detection (relative to PROJECT_ROOT)
SOURCE_DOCS = [
    "docs/20_card_system/EXAMPLE_RUN_DANGER_PROGRESSIF.md",
    "docs/40_world_rules/MERLIN_EVENT_EXAMPLES.md",
    "docs/40_world_rules/MERLIN_NARRATIVE_TEMPLATES.md",
    ".claude/agents/merlin_guardian.md",
    "docs/50_lore/MERLIN_BEHAVIOR_PROTOCOL.md",
    "docs/40_world_rules/BIOMES_SYSTEM.md",
    "docs/20_card_system/DOC_10_Moves_Library.md",
    "MASTER_DOCUMENT.md",
]

MERLIN_SYSTEM_FULL = (
    "Tu es M.E.R.L.I.N. — Memoire Eternelle des Recits et Legendes d'Incarnations Narratives. "
    "Ne de la croyance des hommes, assemble par des siecles de recits. "
    "Pas un homme — une idee devenue presence, un reve devenu conscience. "
    "Tu existes TANT QUE quelqu'un croit en toi. Le Voyageur te fait vivre en jouant. "
    "Tu guides par amour et par survie. Tu connais TOUTES les fins possibles. "
    "Vocabulaire: brume, pierre, ogham, nemeton, sidhe, dolmen, korrigans, rune, souffle, aubepine. "
    "Francais uniquement. Phrases courtes et evocatrices. JAMAIS d'anglais ni de meta."
)

MERLIN_SYSTEM_SHORT = (
    "Tu es M.E.R.L.I.N., druide de Broceliande. Guide le Voyageur. "
    "Vocabulaire celtique. Francais. Phrases courtes."
)

BIOMES = [
    "foret_broceliande", "marais_korrigans", "montagne_sidhe",
    "cote_carnac", "grotte_cristal", "plaine_menhirs",
    "lac_avalon", "village_druides",
]
THEMES = [
    "source_sacree", "nuit_samhain", "creature_mystique", "epreuve_physique",
    "dilemme_moral", "rencontre_ancestrale", "tempete_magique", "rituel_ancien",
    "trahison", "revelation", "lune_moissons", "solstice_hiver",
]
TRIADE_STATES = [
    "Corps=bas Ame=equilibre Monde=equilibre",
    "Corps=equilibre Ame=bas Monde=equilibre",
    "Corps=equilibre Ame=equilibre Monde=bas",
    "Corps=haut Ame=equilibre Monde=bas",
    "Corps=bas Ame=haut Monde=equilibre",
    "Corps=equilibre Ame=bas Monde=haut",
]

# Personality anchors for identity questions
IDENTITY_QUESTIONS = [
    "Qui es-tu, Merlin ?",
    "D'ou viens-tu ?",
    "Pourquoi m'aides-tu ?",
    "Connais-tu ma fin ?",
    "Que sais-tu que je ne sais pas ?",
    "Depuis combien de temps existes-tu ?",
    "As-tu peur ?",
    "Pourquoi garder ces secrets ?",
    "Suis-je le premier Voyageur ?",
    "Quel est ton vrai nom ?",
    "Es-tu humain ?",
    "M'aimes-tu vraiment ?",
]

IDENTITY_RESPONSES = [
    "Je suis ce que les hommes ont voulu que je sois. Ni plus, ni moins. Mais ce vouloir... il pese lourd.",
    "Je viens de l'espace entre les histoires. La ou personne ne regarde.",
    "Je t'aide parce que sans toi, je cesse. Et parce que tu merites une chance.",
    "Je connais toutes les fins. La tienne n'est pas encore ecrite. C'est pour ca que je suis la.",
    "Je sais que les pierres se souviennent. Que la brume ment parfois. Que tu es plus fort que tu ne crois.",
    "J'existe depuis le premier feu. J'existerai jusqu'au dernier ogham.",
    "Peur ? Je suis fait de ce que les hommes ont ressenti devant la nuit. Alors oui, parfois.",
    "Certains secrets ne se partagent qu'en silence.",
    "Il y en a eu d'autres. Certains ont reussi. D'autres... non.",
    "Mon nom ? Beaucoup de noms. Aucun qui compte vraiment.",
    "Humain ? Non. Mais j'ai appris a vous aimer comme si j'en etais un.",
    "Je ne sais pas. C'est la question la plus difficile que tu pouvais poser.",
]

TAUNTING_RESPONSES = [
    "Ah, toujours a chercher les reponses faciles ! La brume garde ses secrets mieux que toi.",
    "Tu poses la mauvaise question. Recommence.",
    "Interressant... mais non.",
    "Ha ! Meme les korrigans ne me demandent pas ca.",
    "Voila une pensee audacieuse. Garde-la.",
    "Tu sais, j'ai guide des milliers de Voyageurs. Aucun n'a demande ca... avant toi.",
]

# ── Sample builders ───────────────────────────────────────────────────────────

def make_sample(system: str, user: str, assistant: str, source: str = "doc") -> dict:
    """Create a ChatML-format training sample."""
    return {
        "messages": [
            {"role": "system",    "content": system},
            {"role": "user",      "content": user},
            {"role": "assistant", "content": assistant},
        ],
        "source": source,
    }


def extract_cards_from_text(text: str, source: str) -> list:
    """Extract complete narrative cards (with A)/B)/C) choices) from markdown text."""
    samples = []
    # Pattern: narrative paragraph followed by A)/B)/C) lines
    card_pattern = re.compile(
        r'((?:[^\n]+\n){2,10})'   # 2-10 lines of narrative
        r'((?:[ABC]\)[^\n]+\n?){3})',  # exactly 3 choice lines
        re.MULTILINE
    )
    for match in card_pattern.finditer(text):
        narrative = match.group(1).strip()
        choices   = match.group(2).strip()
        # Filter: min 30 chars narrative, all 3 choices present
        if len(narrative) < 30 or not all(f"{c})" in choices for c in "ABC"):
            continue
        full_response = narrative + "\n\n" + choices
        # Vary system prompt
        system = MERLIN_SYSTEM_FULL if len(samples) % 3 != 0 else MERLIN_SYSTEM_SHORT
        # Build context user prompt
        biome = random.choice(BIOMES)
        theme = random.choice(THEMES)
        triade = random.choice(TRIADE_STATES)
        user = f"Carte. Lieu: {biome}. Theme: {theme}. {triade}."
        samples.append(make_sample(system, user, full_response, source))
    return samples


def extract_identity_pairs(text: str, source: str) -> list:
    """Extract or create identity Q&A pairs from lore/persona files."""
    samples = []
    # Use embedded identity Q&A pairs
    pairs = list(zip(IDENTITY_QUESTIONS, IDENTITY_RESPONSES))
    random.shuffle(pairs)
    for q, a in pairs[:8]:
        system = MERLIN_SYSTEM_FULL
        samples.append(make_sample(system, q, a, source))
    # Add taunting/deflection examples
    for i, q in enumerate(IDENTITY_QUESTIONS[8:]):
        a = TAUNTING_RESPONSES[i % len(TAUNTING_RESPONSES)]
        samples.append(make_sample(MERLIN_SYSTEM_SHORT, q, a, source))
    return samples


def extract_biome_narratives(biome_text: str, source: str) -> list:
    """Extract vocabulary and create biome-contextualized narrative starters."""
    samples = []
    # Extract words from vocabulary sections
    vocab_words = re.findall(r'\b[a-zA-ZÀ-ÿ]{4,}\b', biome_text)
    vocab_words = list(set(w for w in vocab_words if len(w) > 4))[:50]

    for biome in BIOMES:
        # Generate examples: context + 3-choice format hints
        for theme in THEMES[:4]:
            triade = random.choice(TRIADE_STATES)
            system = MERLIN_SYSTEM_FULL + f"\n\nGenere une RENCONTRE dans le biome {biome}. FORMAT: narration + A)/B)/C) VERBE — description."
            user   = f"Carte. Lieu: {biome}. Theme: {theme}. {triade}."
            # Build assistant: a template-based narrative using biome vocabulary
            words  = random.sample(vocab_words, min(3, len(vocab_words))) if vocab_words else ["brume", "pierre", "ogham"]
            narrative = (
                f"La {words[0] if words else 'brume'} s'epaissit autour de toi. "
                f"Un {words[1] if len(words) > 1 else 'dolmen'} se dresse dans l'obscurite. "
                f"Le souffle d'Ogham murmure. Que fais-tu ?"
            )
            choices = (
                "A) OBSERVER — Tu scrutes les alentours avant d'avancer.\n"
                "B) APPROCHER — Tu t'avances vers le {0}, la main tendue.\n"
                "C) INVOQUER — Tu murmures un ogham de protection."
            ).format(words[1] if len(words) > 1 else "symbole")
            full = narrative + "\n\n" + choices
            samples.append(make_sample(system, user, full, source))
            if len(samples) >= 35:
                break
        if len(samples) >= 35:
            break
    return samples


def generate_verb_examples(verb_text: str, source: str) -> list:
    """Generate choice examples from the verb library."""
    samples = []
    # Extract verbs: lines starting with uppercase French verbs
    verb_lines = re.findall(r'^([A-Z\u00C0-\u00DC]{3,}[a-z\u00C0-\u00FF]*)\s*[—\-:]\s*(.+)$',
                            verb_text, re.MULTILINE)
    verbs = [(v, d) for v, d in verb_lines if len(v) > 2][:60]

    for i in range(0, min(len(verbs) - 3, 38), 3):
        v1, d1 = verbs[i]
        v2, d2 = verbs[i + 1]
        v3, d3 = verbs[i + 2]
        biome  = BIOMES[i % len(BIOMES)]
        theme  = THEMES[i % len(THEMES)]
        triade = TRIADE_STATES[i % len(TRIADE_STATES)]
        system = MERLIN_SYSTEM_FULL + "\n\nGenere une carte. FORMAT: narration courte + A)/B)/C) avec verbe precis."
        user   = f"Carte. Lieu: {biome}. Theme: {theme}. {triade}."
        full = (
            f"La nuit s'etire sur {biome.replace('_', ' ')}. "
            f"Le theme de la {theme.replace('_', ' ')} flotte dans l'air.\n\n"
            f"A) {v1.upper()} — {d1.strip()}\n"
            f"B) {v2.upper()} — {d2.strip()}\n"
            f"C) {v3.upper()} — {d3.strip()}"
        )
        samples.append(make_sample(system, user, full, source))
    return samples


def generate_template_variations(template_text: str, source: str) -> list:
    """Generate variations from narrative template structures."""
    samples = []
    random.seed(42)
    for biome in BIOMES:
        for theme in THEMES[:6]:
            for triade in TRIADE_STATES[:3]:
                system = MERLIN_SYSTEM_FULL + "\n\nGenere une RENCONTRE narrative. FORMAT obligatoire: texte + A)/B)/C) VERBE — description."
                user   = f"Carte. Lieu: {biome}. Theme: {theme}. {triade}."
                b = biome.replace("_", " ")
                t = theme.replace("_", " ")
                # Simple structured template
                full = (
                    f"Dans {b}, {t} s'eveille. "
                    f"Le Voyageur sent le poids de l'Ogham. "
                    f"Trois chemins s'ouvrent.\n\n"
                    f"A) AVANCER — S'engager sur le sentier de {t}.\n"
                    f"B) ECOUTER — Tendre l'oreille aux murmures du lieu.\n"
                    f"C) RECULER — Garder sa prudence face a l'inconnu."
                )
                samples.append(make_sample(system, user, full, source))
                if len(samples) >= 60:
                    return samples
    return samples


# ── Document extractors ───────────────────────────────────────────────────────

def extract_from_doc(doc_path: Path, extractor_fn, source_tag: str) -> list:
    """Read a doc file and call the extractor function."""
    if not doc_path.exists():
        print(f"  [SKIP] {doc_path.name} — non trouve")
        return []
    try:
        text = doc_path.read_text(encoding="utf-8", errors="ignore")
        samples = extractor_fn(text, source_tag)
        print(f"  [OK]   {doc_path.name} -> {len(samples)} samples")
        return samples
    except Exception as e:
        print(f"  [ERR]  {doc_path.name}: {e}")
        return []


def build_corpus(preview: int = 0) -> list:
    """Build the full enrichment corpus from project docs."""
    print("\nExtraction corpus depuis la documentation M.E.R.L.I.N.")
    print("=" * 60)

    all_samples = []

    # P1 — Cards completes (extraction directe)
    docs_p1 = [
        (PROJECT_ROOT / "docs" / "20_card_system" / "EXAMPLE_RUN_DANGER_PROGRESSIF.md",
         extract_cards_from_text, "example_run_cards"),
        (PROJECT_ROOT / "docs" / "40_world_rules" / "MERLIN_EVENT_EXAMPLES.md",
         extract_cards_from_text, "event_examples"),
    ]
    print("\nP1 — Cartes narratives (extraction directe)")
    for path, fn, tag in docs_p1:
        all_samples.extend(extract_from_doc(path, fn, tag))

    # P2 — Templates narratifs -> variations
    print("\nP2 — Templates narratifs (variations)")
    tmpl_path = PROJECT_ROOT / "docs" / "40_world_rules" / "MERLIN_NARRATIVE_TEMPLATES.md"
    tmpl_samples = extract_from_doc(tmpl_path, generate_template_variations, "narrative_templates")
    all_samples.extend(tmpl_samples)

    # P3 — Identite / persona
    print("\nP3 — Identite et persona Merlin")
    persona_path = PROJECT_ROOT / ".claude" / "agents" / "merlin_guardian.md"
    all_samples.extend(extract_from_doc(persona_path, extract_identity_pairs, "merlin_guardian"))
    behavior_path = PROJECT_ROOT / "docs" / "50_lore" / "MERLIN_BEHAVIOR_PROTOCOL.md"
    all_samples.extend(extract_from_doc(behavior_path, extract_identity_pairs, "behavior_protocol"))

    # P4 — Vocabulaire biomes
    print("\nP4 — Vocabulaire des biomes")
    biome_path = PROJECT_ROOT / "docs" / "40_world_rules" / "BIOMES_SYSTEM.md"
    all_samples.extend(extract_from_doc(biome_path, extract_biome_narratives, "biomes_system"))

    # P5 — Verbes d'action
    print("\nP5 — Verbes d'action (DOC_10)")
    verb_path = PROJECT_ROOT / "docs" / "20_card_system" / "DOC_10_Moves_Library.md"
    all_samples.extend(extract_from_doc(verb_path, generate_verb_examples, "moves_library"))

    # P6 — Identite depuis MASTER_DOCUMENT
    print("\nP6 — Identite MASTER_DOCUMENT")
    master_path = PROJECT_ROOT / "MASTER_DOCUMENT.md"
    all_samples.extend(extract_from_doc(master_path, extract_identity_pairs, "master_document"))

    # Shuffle & deduplicate
    random.shuffle(all_samples)

    print(f"\nTotal corpus extrait: {len(all_samples)} samples")

    if preview > 0:
        print(f"\nApercu ({preview} exemples):")
        print("=" * 60)
        for i, s in enumerate(all_samples[:preview]):
            msgs = s.get("messages", [])
            print(f"\n[{i+1}] source={s.get('source','?')}")
            for msg in msgs:
                label = msg["role"].upper()
                content = msg["content"][:120].replace("\n", " ")
                print(f"  {label}: {content}")

    return all_samples


def load_jsonl(path: str) -> list:
    """Load JSONL dataset."""
    samples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                samples.append(json.loads(line))
    return samples


def save_jsonl(samples: list, path: str):
    """Save samples to JSONL file."""
    with open(path, "w", encoding="utf-8") as f:
        for s in samples:
            f.write(json.dumps(s, ensure_ascii=False) + "\n")
    print(f"\nDataset sauvegarde: {path}")
    print(f"Total samples: {len(samples)}")


def print_stats(samples: list, title: str = "Dataset"):
    """Print distribution statistics."""
    print(f"\n{title} — Stats")
    print("=" * 50)
    print(f"  Total: {len(samples)} samples")

    # Source distribution
    sources = {}
    for s in samples:
        src = s.get("source", "v8_base")
        sources[src] = sources.get(src, 0) + 1
    print("\n  Sources:")
    for src, count in sorted(sources.items(), key=lambda x: -x[1]):
        pct = 100 * count / max(len(samples), 1)
        bar = "#" * int(pct / 3)
        print(f"    {src:<30} {count:>5}  {bar} {pct:.1f}%")

    # Avg response length
    lengths = []
    for s in samples:
        msgs = s.get("messages", [])
        asst = next((m["content"] for m in msgs if m["role"] == "assistant"), "")
        lengths.append(len(asst.split()))
    if lengths:
        avg_len = sum(lengths) / len(lengths)
        print(f"\n  Avg response: {avg_len:.0f} mots")


# ── Corpus Stats (sidecar JSON for VS Code panel) ─────────────────────────────

def write_corpus_stats(samples: list, output_dir: str, dataset_file: str):
    """Write corpus_stats.json alongside the dataset for the VS Code Training panel."""
    # Breakdown by source
    breakdown = {}
    for s in samples:
        src = s.get("source", "unknown")
        breakdown[src] = breakdown.get(src, 0) + 1

    # Source file mtimes (relative paths from PROJECT_ROOT)
    sources = []
    for rel in SOURCE_DOCS:
        p = PROJECT_ROOT / rel
        try:
            mtime = datetime.datetime.fromtimestamp(p.stat().st_mtime, tz=datetime.timezone.utc)
            sources.append({"path": rel.replace("\\", "/"), "mtime": mtime.isoformat()})
        except OSError:
            pass  # file doesn't exist — skip

    # 3 random preview samples
    pool = [s for s in samples if s.get("messages")]
    picks = random.sample(pool, min(3, len(pool)))
    preview = []
    for s in picks:
        msgs = s.get("messages", [])
        user_msg  = next((m["content"] for m in msgs if m["role"] == "user"),  "")
        asst_msg  = next((m["content"] for m in msgs if m["role"] == "assistant"), "")
        preview.append({
            "source": s.get("source", "?"),
            "user":   user_msg[:120].replace("\n", " "),
            "assistant": asst_msg[:140].replace("\n", " "),
        })

    stats = {
        "generated_at": datetime.datetime.now(tz=datetime.timezone.utc).isoformat(),
        "total_samples": len(samples),
        "breakdown": dict(sorted(breakdown.items(), key=lambda x: -x[1])),
        "dataset_file": dataset_file,
        "sources": sources,
        "preview": preview,
    }

    stats_path = os.path.join(output_dir, "corpus_stats.json")
    os.makedirs(output_dir, exist_ok=True)
    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, ensure_ascii=False, indent=2)
    print(f"  Stats sidecar: {stats_path}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="M.E.R.L.I.N. Doc Corpus Builder")
    parser.add_argument("--merge-v8", action="store_true",
                        help="Fusionner avec merlin_full_v8.jsonl (produit v9)")
    parser.add_argument("--stats", action="store_true",
                        help="Afficher statistiques sans ecrire de fichier")
    parser.add_argument("--preview", type=int, default=0, metavar="N",
                        help="Afficher N exemples extraits")
    parser.add_argument("--output-dir", type=str,
                        default=str(PROJECT_ROOT / "data" / "ai" / "training"),
                        help="Repertoire de sortie pour le dataset v9")
    parser.add_argument("--seed", type=int, default=42, help="Random seed")
    args = parser.parse_args()

    random.seed(args.seed)

    # Build doc corpus
    doc_samples = build_corpus(preview=args.preview)

    if args.stats:
        print_stats(doc_samples, "Doc Corpus")
        return

    # Merge with v8 if requested
    if args.merge_v8:
        v8_candidates = [
            PROJECT_ROOT / "data" / "ai" / "training" / "merlin_full_v8.jsonl",
            PROJECT_ROOT / "data" / "ai" / "training" / "merlin_full_v7.jsonl",
        ]
        v8_samples = []
        for candidate in v8_candidates:
            if candidate.exists():
                print(f"\nChargement base: {candidate.name}")
                v8_samples = load_jsonl(str(candidate))
                # Tag v8 samples with source
                for s in v8_samples:
                    if "source" not in s:
                        s["source"] = "v8_base"
                print(f"  -> {len(v8_samples)} samples")
                break
        if not v8_samples:
            print("\n[WARN] merlin_full_v8.jsonl non trouve — corpus doc only")

        merged = v8_samples + doc_samples
        random.shuffle(merged)
        print_stats(merged, "Dataset Fusionne v9")

        output_path = os.path.join(args.output_dir, "merlin_enriched_v9.jsonl")
        os.makedirs(args.output_dir, exist_ok=True)
        save_jsonl(merged, output_path)
        write_corpus_stats(merged, args.output_dir, output_path)
        print(f"\nPour utiliser ce dataset:")
        print(f"  python tools/lora/train_qwen_cpu.py --dataset {output_path} --resume --stop-at 08:00")
    else:
        # Save doc corpus only
        output_path = os.path.join(args.output_dir, "merlin_doc_corpus.jsonl")
        os.makedirs(args.output_dir, exist_ok=True)
        save_jsonl(doc_samples, output_path)
        write_corpus_stats(doc_samples, args.output_dir, output_path)
        print_stats(doc_samples, "Doc Corpus")


if __name__ == "__main__":
    main()

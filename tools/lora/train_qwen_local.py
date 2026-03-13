#!/usr/bin/env python3
"""
M.E.R.L.I.N. — QLoRA Fine-Tuning (Qwen 3.5-4B)
Script standalone — executable depuis VS Code, terminal, Colab, HuggingFace, etc.

Usage:
  python train_qwen_local.py                          # Defaut: dataset auto-detecte
  python train_qwen_local.py --dataset path/to.jsonl  # Dataset custom
  python train_qwen_local.py --epochs 5 --lr 1e-4     # Override hyperparams
  python train_qwen_local.py --test-only               # Test sans entrainer

Requirements:
  pip install unsloth   (installe torch, transformers, peft, bitsandbytes, trl, accelerate)

Hardware: GPU CUDA obligatoire (T4 16GB minimum recommande)
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path


def find_dataset() -> str:
    """Auto-detect dataset location."""
    candidates = [
        Path(__file__).parent.parent.parent / "data" / "ai" / "training" / "merlin_verbs_augmented.jsonl",
        Path("data/ai/training/merlin_verbs_augmented.jsonl"),
        Path("merlin_verbs_augmented.jsonl"),
        Path("/content/merlin_verbs_augmented.jsonl"),  # Colab
    ]
    for p in candidates:
        if p.exists():
            return str(p)
    return ""


def load_dataset_jsonl(path: str) -> list:
    """Load JSONL dataset."""
    samples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                samples.append(json.loads(line))
    return samples


def format_chatml(sample: dict) -> dict:
    """Convert conversation dict to ChatML text."""
    text = ""
    for msg in sample["conversations"]:
        text += f"<|im_start|>{msg['role']}\n{msg['content']}<|im_end|>\n"
    return {"text": text}


def main():
    parser = argparse.ArgumentParser(description="M.E.R.L.I.N. QLoRA Fine-Tuning")
    parser.add_argument("--dataset", type=str, default="", help="Path to JSONL dataset")
    parser.add_argument("--output-dir", type=str, default="./merlin-lora-output", help="Training output dir")
    parser.add_argument("--gguf-dir", type=str, default="./merlin-gguf", help="GGUF export dir")
    parser.add_argument("--epochs", type=int, default=3, help="Number of training epochs")
    parser.add_argument("--batch-size", type=int, default=4, help="Per-device batch size")
    parser.add_argument("--grad-accum", type=int, default=4, help="Gradient accumulation steps")
    parser.add_argument("--lr", type=float, default=2e-4, help="Learning rate")
    parser.add_argument("--lora-r", type=int, default=16, help="LoRA rank")
    parser.add_argument("--lora-alpha", type=int, default=32, help="LoRA alpha")
    parser.add_argument("--max-seq-len", type=int, default=2048, help="Max sequence length")
    parser.add_argument("--test-only", action="store_true", help="Test model without training")
    parser.add_argument("--skip-export", action="store_true", help="Skip GGUF export")
    args = parser.parse_args()

    # === 1. Dataset ===
    dataset_path = args.dataset or find_dataset()
    if not dataset_path or not os.path.exists(dataset_path):
        print("ERREUR: Dataset introuvable. Utiliser --dataset path/to.jsonl")
        print(f"  Cherche dans: {find_dataset() or 'aucun candidat trouve'}")
        sys.exit(1)

    raw_samples = load_dataset_jsonl(dataset_path)
    print(f"Dataset: {dataset_path} ({len(raw_samples)} samples)")

    # === 2. Check GPU ===
    try:
        import torch
        if not torch.cuda.is_available():
            print("ERREUR: CUDA non disponible. Ce script necessite un GPU NVIDIA.")
            print("  Options: Google Colab (gratuit), HuggingFace Spaces, serveur GPU")
            sys.exit(1)
        gpu_name = torch.cuda.get_device_name(0)
        props = torch.cuda.get_device_properties(0)
        vram = getattr(props, 'total_memory', getattr(props, 'total_mem', 0))
        print(f"GPU: {gpu_name} ({vram / 1e9:.1f} GB VRAM)")
    except ImportError:
        print("ERREUR: PyTorch non installe. Lancer: pip install unsloth")
        sys.exit(1)

    # === 3. Load model ===
    from unsloth import FastLanguageModel

    MODEL_NAME = "unsloth/Qwen3.5-2B-bnb-4bit"
    print(f"\nChargement du modele: {MODEL_NAME}...")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=MODEL_NAME,
        max_seq_length=args.max_seq_len,
        dtype=None,
        load_in_4bit=True,
    )
    print("  Modele charge.")

    # === 4. LoRA config ===
    model = FastLanguageModel.get_peft_model(
        model,
        r=args.lora_r,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                        "gate_proj", "up_proj", "down_proj"],
        lora_alpha=args.lora_alpha,
        lora_dropout=0.05,
        bias="none",
        use_gradient_checkpointing="unsloth",
        random_state=42,
    )
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"  LoRA: r={args.lora_r} alpha={args.lora_alpha}")
    print(f"  Parametres: {trainable:,} / {total:,} ({100*trainable/total:.2f}%)")

    # === 5. Prepare dataset ===
    from datasets import Dataset as HFDataset

    formatted = [format_chatml(s) for s in raw_samples]
    dataset = HFDataset.from_list(formatted)
    split = dataset.train_test_split(test_size=0.1, seed=42)
    train_dataset = split["train"]
    eval_dataset = split["test"]
    print(f"\n  Train: {len(train_dataset)} | Eval: {len(eval_dataset)}")

    if args.test_only:
        print("\n=== MODE TEST (pas d'entrainement) ===")
        run_tests(model, tokenizer)
        return

    # === 6. Train ===
    from trl import SFTTrainer
    from transformers import TrainingArguments

    print(f"\nEntrainement: {args.epochs} epochs, batch={args.batch_size}x{args.grad_accum}, lr={args.lr}")
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset,
        dataset_text_field="text",
        max_seq_length=args.max_seq_len,
        dataset_num_proc=2,
        packing=True,
        args=TrainingArguments(
            output_dir=args.output_dir,
            num_train_epochs=args.epochs,
            per_device_train_batch_size=args.batch_size,
            per_device_eval_batch_size=args.batch_size,
            gradient_accumulation_steps=args.grad_accum,
            learning_rate=args.lr,
            weight_decay=0.01,
            warmup_ratio=0.1,
            lr_scheduler_type="cosine",
            optim="adamw_8bit",
            fp16=not torch.cuda.is_bf16_supported(),
            bf16=torch.cuda.is_bf16_supported(),
            logging_steps=10,
            eval_strategy="steps",
            eval_steps=50,
            save_strategy="steps",
            save_steps=100,
            save_total_limit=2,
            seed=42,
            report_to="none",
        ),
    )

    train_result = trainer.train()
    print("\n" + "=" * 50)
    print("  RESULTATS D'ENTRAINEMENT")
    print("=" * 50)
    for key, value in train_result.metrics.items():
        print(f"  {key}: {value}")

    # === 7. Test ===
    run_tests(model, tokenizer)

    # === 8. Export GGUF ===
    if args.skip_export:
        print("\nExport GGUF saute (--skip-export)")
        return

    merged_dir = os.path.join(args.output_dir, "merged")
    print(f"\nMerge LoRA → {merged_dir}...")
    model.save_pretrained_merged(merged_dir, tokenizer, save_method="merged_16bit")

    os.makedirs(args.gguf_dir, exist_ok=True)
    print(f"Export GGUF Q4_K_M → {args.gguf_dir}...")
    model.save_pretrained_gguf(args.gguf_dir, tokenizer, quantization_method="q4_k_m")

    import glob
    gguf_files = glob.glob(os.path.join(args.gguf_dir, "*.gguf"))
    for f in gguf_files:
        size_mb = os.path.getsize(f) / (1024 * 1024)
        print(f"  {os.path.basename(f)}: {size_mb:.1f} MB")

    if gguf_files:
        print(f"\n=== DEPLOIEMENT OLLAMA ===")
        gguf_name = os.path.basename(gguf_files[0])
        print(f"1. Copier {gguf_name} vers le dossier Ollama")
        print(f"2. Creer un Modelfile:")
        print(f'   FROM ./{gguf_name}')
        print(f'   PARAMETER temperature 0.75')
        print(f'   PARAMETER top_p 0.92')
        print(f'   PARAMETER repeat_penalty 1.35')
        print(f'   PARAMETER num_ctx 4096')
        print(f'   TEMPLATE "<|im_start|>system\\n{{{{ .System }}}}<|im_end|>\\n<|im_start|>user\\n{{{{ .Prompt }}}}<|im_end|>\\n<|im_start|>assistant\\n"')
        print(f'   SYSTEM "Tu es Merlin l\'Enchanteur, druide ancestral de Broceliande."')
        print(f"3. ollama create merlin-narrator -f Modelfile")
        print(f"4. ollama run merlin-narrator")


def run_tests(model, tokenizer):
    """Run 3 test prompts and check format compliance."""
    from unsloth import FastLanguageModel
    FastLanguageModel.for_inference(model)

    test_prompts = [
        {
            "system": "Tu es Merlin l'Enchanteur. FORMAT: VERBE — description concrete. Vocabulaire celtique.",
            "user": "Carte 1. Lieu: foret_broceliande. Theme: source sacree. Acte I.",
        },
        {
            "system": "Tu es Merlin l'Enchanteur. FORMAT: VERBE — description. Style sensoriel.",
            "user": "Carte 5. Lieu: marais_korrigans. Theme: nuit de Samhain. Corps=bas Ame=equilibre Monde=haut.",
        },
        {
            "system": "Tu es Merlin l'Enchanteur. FORMAT: VERBE — description. URGENCE: peril.",
            "user": "Carte 12. Lieu: collines_dolmens. Theme: combat rituel. Acte III. Corps=bas Ame=bas.",
        },
    ]

    total_verb_lines = 0
    total_expected = 0

    for i, prompt in enumerate(test_prompts):
        chatml = (
            f"<|im_start|>system\n{prompt['system']}<|im_end|>\n"
            f"<|im_start|>user\n{prompt['user']}<|im_end|>\n"
            f"<|im_start|>assistant\n"
        )
        import torch
        inputs = tokenizer(chatml, return_tensors="pt").to("cuda")
        outputs = model.generate(
            **inputs,
            max_new_tokens=256,
            temperature=0.7,
            top_p=0.9,
            repetition_penalty=1.3,
            do_sample=True,
        )
        result = tokenizer.decode(outputs[0], skip_special_tokens=False)
        match = result.split("<|im_start|>assistant\n")[-1].split("<|im_end|>")[0]

        print(f"\n{'=' * 60}")
        print(f"  TEST {i + 1}: {prompt['user'][:60]}...")
        print(f"{'=' * 60}")
        print(match.strip())

        verb_pattern = r'^[A-D]\)\s+[A-ZÀ-Ü].*[—–\-].*'
        lines = match.strip().split('\n')
        verb_lines = [l for l in lines if re.match(verb_pattern, l.strip())]
        total_verb_lines += len(verb_lines)
        total_expected += 3
        print(f"\n  Format check: {len(verb_lines)}/3 lignes VERBE — description")

    compliance = total_verb_lines / total_expected if total_expected > 0 else 0
    print(f"\n{'=' * 60}")
    print(f"  FORMAT COMPLIANCE: {total_verb_lines}/{total_expected} ({compliance:.0%})")
    print(f"  Seuil cible: > 80%")
    status = "PASS" if compliance >= 0.8 else "NEED LoRA" if compliance < 0.5 else "PARTIAL"
    print(f"  Status: {status}")
    print(f"{'=' * 60}")


if __name__ == "__main__":
    main()

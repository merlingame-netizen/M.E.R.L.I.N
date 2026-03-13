#!/usr/bin/env python3
"""
LoRA fine-tuning script for M.E.R.L.I.N. Narrator brain.
Uses Unsloth + HuggingFace PEFT for efficient training on Qwen 3.5-4B.

Prerequisites:
  pip install unsloth peft transformers datasets accelerate bitsandbytes

Usage:
  python tools/lora/train_narrator_lora.py [--dataset PATH] [--output DIR] [--epochs N]

  Default dataset: data/ai/training/merlin_narrator_augmented.json
  Default output:  output/merlin_narrator_lora/
"""

import argparse
import json
import os
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

DEFAULT_CONFIG = {
    # Model
    "base_model": "Qwen/Qwen3.5-4B",
    "max_seq_length": 512,
    "load_in_4bit": True,

    # LoRA
    "lora_r": 16,
    "lora_alpha": 32,
    "lora_dropout": 0.05,
    "target_modules": [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],

    # Training
    "num_epochs": 3,
    "per_device_batch_size": 4,
    "gradient_accumulation_steps": 4,
    "learning_rate": 2e-4,
    "weight_decay": 0.01,
    "warmup_ratio": 0.03,
    "lr_scheduler_type": "cosine",
    "logging_steps": 10,
    "save_steps": 50,

    # Paths
    "dataset_path": os.path.join(PROJECT_ROOT, "data", "ai", "training", "merlin_narrator_augmented.json"),
    "output_dir": os.path.join(PROJECT_ROOT, "output", "merlin_narrator_lora"),
}


def load_dataset(path: str) -> list:
    """Load ChatML dataset and convert to training format."""
    print(f"[train] Loading dataset: {path}")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    samples = data.get("samples", [])
    print(f"  Loaded {len(samples)} samples")

    # Convert ChatML conversations to text format
    formatted = []
    for sample in samples:
        convs = sample.get("conversations", [])
        if len(convs) < 3:
            continue

        system = convs[0]["content"]
        user = convs[1]["content"]
        assistant = convs[2]["content"]

        # ChatML format (Qwen 3.5 native)
        text = (
            f"<|im_start|>system\n{system}<|im_end|>\n"
            f"<|im_start|>user\n{user}<|im_end|>\n"
            f"<|im_start|>assistant\n{assistant}<|im_end|>"
        )
        formatted.append({"text": text})

    print(f"  Formatted {len(formatted)} training samples")
    return formatted


def train(config: dict):
    """Run LoRA fine-tuning with Unsloth."""

    # Try Unsloth first (2x faster), fall back to standard PEFT
    try:
        from unsloth import FastLanguageModel
        use_unsloth = True
        print("[train] Using Unsloth (2x faster training)")
    except ImportError:
        use_unsloth = False
        print("[train] Unsloth not found, using standard HuggingFace PEFT")

    if use_unsloth:
        _train_unsloth(config)
    else:
        _train_peft(config)


def _train_unsloth(config: dict):
    """Train with Unsloth (recommended)."""
    from unsloth import FastLanguageModel
    from trl import SFTTrainer
    from transformers import TrainingArguments
    from datasets import Dataset

    # Load model
    print(f"\n[train] Loading base model: {config['base_model']}")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=config["base_model"],
        max_seq_length=config["max_seq_length"],
        load_in_4bit=config["load_in_4bit"],
    )

    # Add LoRA adapters
    print(f"[train] Adding LoRA adapters (r={config['lora_r']}, alpha={config['lora_alpha']})")
    model = FastLanguageModel.get_peft_model(
        model,
        r=config["lora_r"],
        lora_alpha=config["lora_alpha"],
        lora_dropout=config["lora_dropout"],
        target_modules=config["target_modules"],
        bias="none",
        use_gradient_checkpointing="unsloth",
    )

    # Load and prepare dataset
    formatted_data = load_dataset(config["dataset_path"])
    dataset = Dataset.from_list(formatted_data)

    # Training arguments
    training_args = TrainingArguments(
        output_dir=config["output_dir"],
        num_train_epochs=config["num_epochs"],
        per_device_train_batch_size=config["per_device_batch_size"],
        gradient_accumulation_steps=config["gradient_accumulation_steps"],
        learning_rate=config["learning_rate"],
        weight_decay=config["weight_decay"],
        warmup_ratio=config["warmup_ratio"],
        lr_scheduler_type=config["lr_scheduler_type"],
        logging_steps=config["logging_steps"],
        save_steps=config["save_steps"],
        fp16=True,
        optim="adamw_8bit",
        seed=42,
    )

    # Trainer
    print(f"\n[train] Starting training ({config['num_epochs']} epochs)...")
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset,
        args=training_args,
        dataset_text_field="text",
        max_seq_length=config["max_seq_length"],
    )

    trainer.train()

    # Save
    print(f"\n[train] Saving LoRA adapter to: {config['output_dir']}")
    model.save_pretrained(config["output_dir"])
    tokenizer.save_pretrained(config["output_dir"])
    print("[train] Done!")


def _train_peft(config: dict):
    """Train with standard HuggingFace PEFT (fallback)."""
    from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
    from peft import LoraConfig, get_peft_model, TaskType
    from trl import SFTTrainer
    from datasets import Dataset

    # Load model
    print(f"\n[train] Loading base model: {config['base_model']}")
    tokenizer = AutoTokenizer.from_pretrained(config["base_model"])
    model = AutoModelForCausalLM.from_pretrained(
        config["base_model"],
        load_in_4bit=config["load_in_4bit"],
        device_map="auto",
    )

    # LoRA config
    lora_config = LoraConfig(
        r=config["lora_r"],
        lora_alpha=config["lora_alpha"],
        lora_dropout=config["lora_dropout"],
        target_modules=config["target_modules"],
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )

    print(f"[train] Adding LoRA adapters (r={config['lora_r']}, alpha={config['lora_alpha']})")
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()

    # Load and prepare dataset
    formatted_data = load_dataset(config["dataset_path"])
    dataset = Dataset.from_list(formatted_data)

    # Training
    training_args = TrainingArguments(
        output_dir=config["output_dir"],
        num_train_epochs=config["num_epochs"],
        per_device_train_batch_size=config["per_device_batch_size"],
        gradient_accumulation_steps=config["gradient_accumulation_steps"],
        learning_rate=config["learning_rate"],
        weight_decay=config["weight_decay"],
        warmup_ratio=config["warmup_ratio"],
        lr_scheduler_type=config["lr_scheduler_type"],
        logging_steps=config["logging_steps"],
        save_steps=config["save_steps"],
        fp16=True,
        seed=42,
    )

    print(f"\n[train] Starting training ({config['num_epochs']} epochs)...")
    trainer = SFTTrainer(
        model=model,
        tokenizer=tokenizer,
        train_dataset=dataset,
        args=training_args,
        dataset_text_field="text",
        max_seq_length=config["max_seq_length"],
    )

    trainer.train()

    # Save
    print(f"\n[train] Saving LoRA adapter to: {config['output_dir']}")
    model.save_pretrained(config["output_dir"])
    tokenizer.save_pretrained(config["output_dir"])
    print("[train] Done!")


def main():
    parser = argparse.ArgumentParser(description="Train M.E.R.L.I.N. Narrator LoRA adapter")
    parser.add_argument("--dataset", default=DEFAULT_CONFIG["dataset_path"], help="Path to training dataset JSON")
    parser.add_argument("--output", default=DEFAULT_CONFIG["output_dir"], help="Output directory for LoRA adapter")
    parser.add_argument("--epochs", type=int, default=DEFAULT_CONFIG["num_epochs"], help="Number of training epochs")
    parser.add_argument("--lr", type=float, default=DEFAULT_CONFIG["learning_rate"], help="Learning rate")
    parser.add_argument("--rank", type=int, default=DEFAULT_CONFIG["lora_r"], help="LoRA rank")
    parser.add_argument("--dry-run", action="store_true", help="Only load dataset and show stats, don't train")
    args = parser.parse_args()

    config = dict(DEFAULT_CONFIG)
    config["dataset_path"] = args.dataset
    config["output_dir"] = args.output
    config["num_epochs"] = args.epochs
    config["learning_rate"] = args.lr
    config["lora_r"] = args.rank
    config["lora_alpha"] = args.rank * 2

    print("=" * 60)
    print("  M.E.R.L.I.N. Narrator LoRA Training")
    print("=" * 60)
    print(f"  Base model:   {config['base_model']}")
    print(f"  LoRA rank:    {config['lora_r']} (alpha={config['lora_alpha']})")
    print(f"  Epochs:       {config['num_epochs']}")
    print(f"  LR:           {config['learning_rate']}")
    print(f"  Batch size:   {config['per_device_batch_size']} x {config['gradient_accumulation_steps']} = {config['per_device_batch_size'] * config['gradient_accumulation_steps']}")
    print(f"  Dataset:      {config['dataset_path']}")
    print(f"  Output:       {config['output_dir']}")
    print("=" * 60)

    if args.dry_run:
        formatted = load_dataset(config["dataset_path"])
        print(f"\n[dry-run] Would train on {len(formatted)} samples. Exiting.")
        return

    os.makedirs(config["output_dir"], exist_ok=True)

    # Save config
    config_path = os.path.join(config["output_dir"], "training_config.json")
    with open(config_path, "w") as f:
        json.dump(config, f, indent=2, default=str)

    train(config)


if __name__ == "__main__":
    main()

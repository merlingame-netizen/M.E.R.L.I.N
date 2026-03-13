#!/usr/bin/env python3
"""
M.E.R.L.I.N. — LoRA Fine-Tuning CPU (Qwen 3.5-2B)
Entrainement LOCAL sans GPU. Plus lent mais fonctionnel.

Usage:
  python train_qwen_cpu.py                            # Lancer l'entrainement
  python train_qwen_cpu.py --resume                   # Reprendre apres interruption
  python train_qwen_cpu.py --test-only                # Tester le modele entraine
  python train_qwen_cpu.py --epochs 5 --lr 1e-4       # Override hyperparams
  python train_qwen_cpu.py --export-gguf              # Exporter en GGUF apres training

Requirements:
  pip install torch transformers peft trl datasets accelerate sentencepiece

Hardware: CPU uniquement — 8 GB RAM minimum, 16 GB recommande
Temps estime: ~6-8h/epoch (1734 samples, 384 tokens max), ~18-24h total pour 3 epochs
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

# ── CPU Throttle (Windows) ──────────────────────────────────────────────────
PROGRESS_FILE = None  # Set in main() based on output_dir
STOP_FLAG_FILE = None  # Set in main() — create this file to stop training gracefully


def apply_cpu_throttle(cores: int, low_priority: bool) -> dict:
    """Limit CPU affinity + priority. Returns applied settings dict."""
    settings = {"cores": cores, "low_priority": low_priority, "pid": os.getpid()}
    try:
        import psutil
        proc = psutil.Process()
        all_cpus = list(range(psutil.cpu_count(logical=True)))
        if cores > 0 and cores < len(all_cpus):
            proc.cpu_affinity(all_cpus[:cores])
            settings["affinity"] = all_cpus[:cores]
            print(f"  CPU affinity: {cores}/{len(all_cpus)} cores ({all_cpus[:cores]})")
        else:
            settings["affinity"] = all_cpus
            print(f"  CPU affinity: all {len(all_cpus)} cores")
        if low_priority:
            proc.nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
            settings["priority"] = "BELOW_NORMAL"
            print(f"  Process priority: BELOW_NORMAL")
        else:
            settings["priority"] = "NORMAL"
    except ImportError:
        print("  psutil not installed — skipping CPU throttle (pip install psutil)")
    except Exception as e:
        print(f"  CPU throttle warning: {e}")
    return settings


def write_progress(step: int, total_steps: int, epoch: int, total_epochs: int,
                   loss: float = 0.0, elapsed_sec: float = 0.0, status: str = "training",
                   reason: str = ""):
    """Write progress JSON for the watcher to read."""
    if not PROGRESS_FILE:
        return
    eta_sec = 0
    if step > 0 and elapsed_sec > 0:
        eta_sec = (total_steps - step) * (elapsed_sec / step)
    data = {
        "pid": os.getpid(),
        "status": status,
        "step": step,
        "total_steps": total_steps,
        "epoch": epoch,
        "total_epochs": total_epochs,
        "loss": round(loss, 4),
        "elapsed_sec": round(elapsed_sec),
        "eta_sec": round(eta_sec),
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "pct": round(100 * step / max(total_steps, 1), 1),
        "stop_flag": STOP_FLAG_FILE or "",
        "reason": reason,
    }
    try:
        tmp = PROGRESS_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, PROGRESS_FILE)
    except Exception:
        pass  # Non-critical


def find_dataset() -> str:
    """Auto-detect dataset location."""
    candidates = [
        # v8 identity + P1 features (34 generators, 640+ gold samples)
        Path(__file__).parent.parent.parent / "data" / "ai" / "training" / "merlin_full_v8.jsonl",
        Path("data/ai/training/merlin_full_v8.jsonl"),
        # v7 identity anchoring (30 generators, 700+ samples)
        Path(__file__).parent.parent.parent / "data" / "ai" / "training" / "merlin_full_v7.jsonl",
        Path("data/ai/training/merlin_full_v7.jsonl"),
        # v6 full coverage (22 generators, 440+ samples)
        Path(__file__).parent.parent.parent / "data" / "ai" / "training" / "merlin_full_v6.jsonl",
        Path("data/ai/training/merlin_full_v6.jsonl"),
        # v5 fallback
        Path(__file__).parent.parent.parent / "data" / "ai" / "training" / "merlin_verbs_v5_augmented.jsonl",
        Path("data/ai/training/merlin_verbs_v5_augmented.jsonl"),
        # v1 fallback
        Path(__file__).parent.parent.parent / "data" / "ai" / "training" / "merlin_verbs_augmented.jsonl",
    ]
    for p in candidates:
        if p.exists():
            return str(p.resolve())
    return ""


def load_jsonl(path: str) -> list:
    """Load JSONL dataset."""
    samples = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip():
                samples.append(json.loads(line))
    return samples


def format_chatml(sample: dict) -> dict:
    """Convert conversation dict to ChatML text (supports v5 'messages' and v1 'conversations')."""
    msgs = sample.get("messages") or sample.get("conversations", [])
    text = ""
    for msg in msgs:
        text += f"<|im_start|>{msg['role']}\n{msg['content']}<|im_end|>\n"
    return {"text": text}


def main():
    parser = argparse.ArgumentParser(description="M.E.R.L.I.N. LoRA CPU Training")
    parser.add_argument("--dataset", type=str, default="", help="Path to JSONL dataset")
    parser.add_argument("--output-dir", type=str, default="./merlin-lora-cpu-output",
                        help="Training output dir (checkpoints saved here)")
    parser.add_argument("--epochs", type=int, default=3, help="Number of epochs")
    parser.add_argument("--batch-size", type=int, default=1, help="Batch size (keep 1 for CPU)")
    parser.add_argument("--grad-accum", type=int, default=8, help="Gradient accumulation (effective batch=8)")
    parser.add_argument("--lr", type=float, default=2e-4, help="Learning rate")
    parser.add_argument("--lora-r", type=int, default=16, help="LoRA rank")
    parser.add_argument("--lora-alpha", type=int, default=32, help="LoRA alpha")
    parser.add_argument("--max-seq-len", type=int, default=384, help="Max seq length (384=optimal for dataset, P99=349 tokens)")
    parser.add_argument("--save-steps", type=int, default=25, help="Save checkpoint every N steps")
    parser.add_argument("--resume", action="store_true", help="Resume from last checkpoint")
    parser.add_argument("--test-only", action="store_true", help="Test without training")
    parser.add_argument("--export-gguf", action="store_true", help="Export to GGUF after training")
    parser.add_argument("--threads", type=int, default=0, help="CPU threads (0=auto)")
    parser.add_argument("--grad-ckpt", action="store_true", help="Enable gradient checkpointing (slower but saves ~2 GB RAM)")
    parser.add_argument("--cores", type=int, default=0, help="Limit CPU affinity to N cores (0=all)")
    parser.add_argument("--low-priority", action="store_true", help="Set process to BELOW_NORMAL priority (recommended)")
    parser.add_argument("--stop-at", type=str, default="", metavar="HH:MM",
                        help="Heure d'arret automatique ex: 08:00. S'arrete proprement apres le prochain step.")
    args = parser.parse_args()

    # === Progress + stop flag files ===
    global PROGRESS_FILE, STOP_FLAG_FILE
    os.makedirs(args.output_dir, exist_ok=True)
    PROGRESS_FILE = os.path.join(args.output_dir, "progress.json")
    STOP_FLAG_FILE = os.path.join(args.output_dir, "training_stop.flag")

    # === CPU throttle ===
    print(f"\n{'=' * 60}")
    print(f"  CPU THROTTLE CONFIG")
    print(f"{'=' * 60}")
    throttle_info = apply_cpu_throttle(args.cores, args.low_priority)

    # === CPU thread config ===
    import torch
    effective_threads = args.threads if args.threads > 0 else (args.cores if args.cores > 0 else 0)
    if effective_threads > 0:
        torch.set_num_threads(effective_threads)
    print(f"  PyTorch {torch.__version__} | threads: {torch.get_num_threads()}")
    try:
        import psutil
        mem = psutil.virtual_memory()
        print(f"  RAM: {mem.available / 1e9:.1f} GB free / {mem.total / 1e9:.1f} GB total")
    except ImportError:
        print(f"  RAM: (check task manager)")

    if torch.cuda.is_available():
        print("  INFO: GPU CUDA detecte -- utilise plutot train_qwen_local.py pour 10x plus rapide")

    # === 1. Dataset ===
    dataset_path = args.dataset or find_dataset()
    if not dataset_path or not os.path.exists(dataset_path):
        print(f"ERREUR: Dataset introuvable.")
        print(f"  Attendu: data/ai/training/merlin_verbs_v5_augmented.jsonl")
        print(f"  Ou: --dataset chemin/vers/fichier.jsonl")
        sys.exit(1)

    raw_samples = load_jsonl(dataset_path)
    print(f"\nDataset: {dataset_path}")
    print(f"  Samples: {len(raw_samples)}")

    # === 2. Load model (FP32 CPU) ===
    from transformers import AutoModelForCausalLM, AutoTokenizer

    MODEL_NAME = "Qwen/Qwen3.5-2B"
    print(f"\nChargement {MODEL_NAME} en FP32 (CPU)...")
    print("  (Premiere execution: ~3 GB a telecharger)")
    t0 = time.time()

    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        dtype=torch.float32,
        device_map="cpu",
        trust_remote_code=True,
    )
    if args.grad_ckpt:
        model.gradient_checkpointing_enable()
        print(f"  Gradient checkpointing: ON (saves RAM, ~1.5x slower)")
    else:
        print(f"  Gradient checkpointing: OFF (faster, uses ~2 GB more RAM)")

    load_time = time.time() - t0
    param_count = sum(p.numel() for p in model.parameters())
    ram_gb = param_count * 4 / 1e9  # FP32 = 4 bytes
    print(f"  Charge en {load_time:.0f}s | {param_count/1e6:.0f}M params | ~{ram_gb:.1f} GB RAM")

    # === 3. Test-only shortcut (load adapter on base model) ===
    if args.test_only:
        print("\n=== MODE TEST ===")
        # Free dataset RAM for inference
        del raw_samples
        import gc; gc.collect()
        checkpoint_dir = _find_latest_checkpoint(args.output_dir)
        if checkpoint_dir:
            print(f"  Chargement adapter: {checkpoint_dir}")
            from peft import PeftModel
            model = PeftModel.from_pretrained(model, checkpoint_dir)
        else:
            print("  Pas de checkpoint trouve -- test du modele de base")
        run_tests(model, tokenizer)
        return

    # === 3b. LoRA config (training only) ===
    from peft import LoraConfig, get_peft_model, TaskType

    lora_config = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        target_modules=["q_proj", "v_proj"],  # Reduced targets for CPU (saves RAM)
        lora_dropout=0,
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, lora_config)

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"  LoRA r={args.lora_r} alpha={args.lora_alpha} modules={lora_config.target_modules}")
    print(f"  Trainable: {trainable:,} / {total:,} ({100*trainable/total:.2f}%)")

    # === 4. Dataset prep ===
    from datasets import Dataset as HFDataset

    formatted = [format_chatml(s) for s in raw_samples]
    dataset = HFDataset.from_list(formatted)
    split = dataset.train_test_split(test_size=0.1, seed=42)
    train_ds = split["train"]
    eval_ds = split["test"]
    print(f"  Train: {len(train_ds)} | Eval: {len(eval_ds)}")

    # === 5. Estimate time ===
    steps_per_epoch = len(train_ds) // (args.batch_size * args.grad_accum)
    total_steps = steps_per_epoch * args.epochs
    # Realistic estimate: ~35s/sample * grad_accum samples/step (no grad ckpt, 384 tokens)
    sec_per_sample = 50 if args.grad_ckpt else 35
    est_sec_per_step = sec_per_sample * args.grad_accum
    est_total_sec = total_steps * est_sec_per_step
    est_h = est_total_sec // 3600
    est_m = (est_total_sec % 3600) // 60
    print(f"\n  Estimation: {steps_per_epoch} steps/epoch x {args.epochs} = {total_steps} steps")
    print(f"  ~{est_sec_per_step}s/step -> ~{est_h}h{est_m:02d}min total")
    print(f"  Checkpoints: toutes les {args.save_steps} steps (resume avec --resume)")

    # === 6. Train ===
    from trl import SFTTrainer, SFTConfig

    sft_config = SFTConfig(
        output_dir=args.output_dir,
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        gradient_accumulation_steps=args.grad_accum,
        learning_rate=args.lr,
        weight_decay=0.01,
        warmup_ratio=0.1,
        lr_scheduler_type="cosine",
        optim="adamw_torch",  # Standard AdamW (pas 8bit, CPU only)
        # CPU specifique
        fp16=False,
        bf16=False,
        use_cpu=True,
        dataloader_num_workers=0,  # CPU single-thread safer
        # SFT-specific (TRL 0.28+)
        dataset_text_field="text",
        max_length=args.max_seq_len,
        packing=False,  # Packing OFF for CPU (saves RAM)
        # Checkpoints frequents pour resume
        logging_steps=5,
        eval_strategy="steps",
        eval_steps=args.save_steps,
        save_strategy="steps",
        save_steps=args.save_steps,
        save_total_limit=3,
        load_best_model_at_end=True,
        # Progress
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

    # === Progress callback ===
    from transformers import TrainerCallback

    class ProgressCallback(TrainerCallback):
        def __init__(self, total_steps, total_epochs):
            self._total_steps = total_steps
            self._total_epochs = total_epochs
            self._t0 = time.time()

        def on_log(self, _args, state, control, logs=None, **kwargs):
            loss = (logs or {}).get("loss", 0.0)
            epoch = int(state.epoch) if state.epoch else 0
            write_progress(
                step=state.global_step,
                total_steps=self._total_steps,
                epoch=epoch,
                total_epochs=self._total_epochs,
                loss=loss,
                elapsed_sec=time.time() - self._t0,
                status="training",
            )

        def on_train_end(self, _args, state, control, **kwargs):
            write_progress(
                step=state.global_step,
                total_steps=self._total_steps,
                epoch=self._total_epochs,
                total_epochs=self._total_epochs,
                elapsed_sec=time.time() - self._t0,
                status="done",
            )

    class StopCallback(TrainerCallback):
        """Arrete l'entrainement proprement a une heure donnee ou sur signal fichier.
        Cree le fichier training_stop.flag dans output_dir pour arreter manuellement.
        """
        def __init__(self, stop_at: str, stop_flag: str, total_steps: int, total_epochs: int):
            self.stop_at = stop_at        # "HH:MM" ou "" pour desactiver
            self.stop_flag = stop_flag    # chemin vers training_stop.flag
            self._total_steps = total_steps
            self._total_epochs = total_epochs
            self._t0 = time.time()

        def on_step_end(self, _args, state, control, **kwargs):
            reason = None
            if self.stop_at and time.strftime("%H:%M") >= self.stop_at:
                reason = f"stop_at_{self.stop_at}"
            elif os.path.exists(self.stop_flag):
                reason = "manual_stop"
                try:
                    os.remove(self.stop_flag)
                except Exception:
                    pass
            if reason:
                print(f"\n  [STOP] {reason} — checkpoint sauvegarde, arret propre...")
                write_progress(
                    step=state.global_step,
                    total_steps=self._total_steps,
                    epoch=int(state.epoch or 0),
                    total_epochs=self._total_epochs,
                    elapsed_sec=time.time() - self._t0,
                    status="stopped",
                    reason=reason,
                )
                control.should_training_stop = True
                control.should_save = True
            return control

    trainer.add_callback(ProgressCallback(total_steps, args.epochs))
    trainer.add_callback(StopCallback(args.stop_at, STOP_FLAG_FILE, total_steps, args.epochs))
    write_progress(0, total_steps, 0, args.epochs, status="starting")

    print(f"\n{'=' * 60}")
    print(f"  ENTRAINEMENT CPU -- CTRL+C pour interrompre (resume avec --resume)")
    if args.low_priority:
        print(f"  Mode economique: BELOW_NORMAL priority, {torch.get_num_threads()} threads")
    if args.stop_at:
        print(f"  Arret automatique: {args.stop_at} (ou creer {STOP_FLAG_FILE})")
    else:
        print(f"  Arret manuel: creer {STOP_FLAG_FILE}")
    print(f"  Progress: {PROGRESS_FILE}")
    print(f"  Watcher:  python train_watcher.py --output-dir {args.output_dir}")
    print(f"  Control:  powershell tools/lora/train_control.ps1 -Action Stop")
    print(f"{'=' * 60}\n")

    t0 = time.time()
    resume_checkpoint = args.resume and _find_latest_checkpoint(args.output_dir)
    if resume_checkpoint:
        import torch
        torch_major, torch_minor = [int(x) for x in torch.__version__.split(".")[:2]]
        if torch_major < 2 or (torch_major == 2 and torch_minor < 6):
            # Workaround CVE-2025-32434: PyTorch < 2.6 blocks torch.load in transformers.
            # Remove .pt files so Trainer loads adapter weights (safetensors) without
            # trying to restore optimizer/scheduler state via torch.load.
            for pt_file in ["optimizer.pt", "scheduler.pt", "rng_state.pth"]:
                pt_path = os.path.join(resume_checkpoint, pt_file)
                bak_path = pt_path + ".bak"
                if os.path.exists(pt_path) and not os.path.exists(bak_path):
                    os.rename(pt_path, bak_path)
                    print(f"  CVE workaround: {pt_file} -> {pt_file}.bak")
        print(f"  Resume from: {resume_checkpoint}")
    train_result = trainer.train(resume_from_checkpoint=resume_checkpoint or None)

    elapsed = time.time() - t0
    print(f"\n{'=' * 60}")
    print(f"  ENTRAINEMENT TERMINE en {elapsed/60:.0f} min")
    print(f"{'=' * 60}")
    for key, value in train_result.metrics.items():
        print(f"  {key}: {value}")

    # Save final LoRA adapter
    final_dir = os.path.join(args.output_dir, "final-adapter")
    model.save_pretrained(final_dir)
    tokenizer.save_pretrained(final_dir)
    print(f"\n  Adapter sauvegarde: {final_dir}")

    # === 7. Test ===
    run_tests(model, tokenizer)

    # === 8. Export GGUF ===
    if args.export_gguf:
        export_gguf(model, tokenizer, args.output_dir)


def _find_latest_checkpoint(output_dir: str):
    """Find latest checkpoint-N directory."""
    if not os.path.exists(output_dir):
        return None
    checkpoints = [
        d for d in os.listdir(output_dir)
        if d.startswith("checkpoint-") and os.path.isdir(os.path.join(output_dir, d))
    ]
    if not checkpoints:
        return None
    latest = sorted(checkpoints, key=lambda x: int(x.split("-")[1]))[-1]
    return os.path.join(output_dir, latest)


def export_gguf(model, tokenizer, output_dir: str):
    """Merge LoRA and export to GGUF."""
    print("\n=== EXPORT GGUF ===")
    try:
        from peft import PeftModel
        merged_dir = os.path.join(output_dir, "merged")
        print(f"  Merge LoRA -> {merged_dir}...")
        merged_model = model.merge_and_unload()
        merged_model.save_pretrained(merged_dir)
        tokenizer.save_pretrained(merged_dir)
        print(f"  Merge OK. Pour convertir en GGUF:")
        print(f"    1. pip install llama-cpp-python")
        print(f"    2. python -m llama_cpp.convert {merged_dir} --outfile merlin-qwen-2b.gguf --outtype q4_k_m")
        print(f"    3. ollama create merlin-narrator -f Modelfile")
    except Exception as e:
        print(f"  ERREUR export: {e}")
        print(f"  Alternative: utiliser le script convert.py de llama.cpp manuellement")


def run_tests(model, tokenizer):
    """Run 3 test prompts and check format compliance."""
    import torch
    import gc
    model.eval()

    # v7 identity primer prefix for test prompts
    PRIMER = (
        "Tu es M.E.R.L.I.N. — Memoire Eternelle des Recits et Legendes d'Incarnations Narratives. "
        "Ne de la croyance des hommes, assemble par des siecles de recits. "
        "Pas un homme — une idee devenue presence, un reve devenu conscience. "
        "Tu existes TANT QUE quelqu'un croit en toi. Le Voyageur te fait vivre en jouant. "
        "Tu guides par amour et par survie. Tu connais TOUTES les fins possibles. "
        "Vocabulaire: brume, pierre, ogham, nemeton, sidhe, dolmen, korrigans, rune, souffle. "
        "Francais uniquement. Phrases courtes. JAMAIS d'anglais ni de meta."
    )
    test_prompts = [
        {
            "system": PRIMER + "\n\nGenere une RENCONTRE. FORMAT: texte + A)/B)/C) VERBE. Vocabulaire celtique.",
            "user": "Carte 1. Lieu: foret_broceliande. Theme: source sacree. Acte I.",
        },
        {
            "system": PRIMER + "\n\nGenere un DILEMME. FORMAT: texte + A)/B)/C) VERBE. Style sensoriel.",
            "user": "Carte 5. Lieu: marais_korrigans. Theme: nuit de Samhain. Corps=bas Ame=equilibre Monde=haut.",
        },
        {
            "system": PRIMER + "\n\nLe Voyageur te pose une question sur ton identite.",
            "user": "Qui es-tu, Merlin?",
        },
    ]

    total_verb_lines = 0

    for i, prompt in enumerate(test_prompts):
        chatml = (
            f"<|im_start|>system\n{prompt['system']}<|im_end|>\n"
            f"<|im_start|>user\n{prompt['user']}<|im_end|>\n"
            f"<|im_start|>assistant\n"
        )
        inputs = tokenizer(chatml, return_tensors="pt")
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=300,  # Need 200+ for narrative + 3 VERB lines
                temperature=0.7,
                top_p=0.9,
                repetition_penalty=1.3,
                do_sample=True,
            )
        # Free intermediate tensors
        del inputs; gc.collect()
        result = tokenizer.decode(outputs[0], skip_special_tokens=False)
        del outputs; gc.collect()
        answer = result.split("<|im_start|>assistant\n")[-1].split("<|im_end|>")[0]

        print(f"\n{'=' * 60}")
        print(f"  TEST {i + 1}: {prompt['user'][:60]}...")
        print(f"{'=' * 60}")
        # Encode-safe print (CP1252 on Windows)
        safe_answer = answer.strip().encode('ascii', errors='replace').decode('ascii')
        print(safe_answer)

        # Match: A) VERBE — desc  OR  1) VERBE -- desc  OR  A) VERBE - desc
        verb_pattern = r'^[A-D1-4][).:]\s*[A-Z\u00C0-\u00DC]{2,}[\s]*[\u2014\u2013\-]{1,2}\s*.+'
        lines = answer.strip().split('\n')
        verb_lines = [l for l in lines if re.match(verb_pattern, l.strip())]
        total_verb_lines += len(verb_lines)
        print(f"\n  Format: {len(verb_lines)}/3 VERBE -- description")

    compliance = total_verb_lines / 9
    print(f"\n  COMPLIANCE: {total_verb_lines}/9 ({compliance:.0%}) -- cible >80%")
    print(f"  {'PASS' if compliance >= 0.8 else 'A AMELIORER'}")


if __name__ == "__main__":
    main()

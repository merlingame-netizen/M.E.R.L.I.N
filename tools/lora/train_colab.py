#!/usr/bin/env python3
"""
M.E.R.L.I.N. — LoRA Fine-Tuning Colab (GPU T4)
Run on Google Colab free tier. Monitor from VS Code via ngrok tunnel.

Setup in Colab:
  1. Upload this file + merlin_full_v8.jsonl to Colab (or mount Drive)
  2. Run: !pip install torch transformers peft trl datasets accelerate sentencepiece pyngrok flask
  3. Run: !python train_colab.py --ngrok-token YOUR_TOKEN

  Or paste cells from the notebook version.

Monitor from VS Code:
  python tools/lora/train_watcher.py --url https://XXXX.ngrok-free.app/progress

Estimated time: ~1-2h on T4 (vs 24h+ on CPU)
"""

import argparse
import gc
import json
import os
import re
import sys
import threading
import time
from pathlib import Path

# ── Progress server (ngrok + Flask) ─────────────────────────────────────────
PROGRESS_DATA = {
    "status": "initializing",
    "step": 0,
    "total_steps": 0,
    "epoch": 0,
    "total_epochs": 0,
    "loss": 0.0,
    "elapsed_sec": 0,
    "eta_sec": 0,
    "timestamp": "",
    "pct": 0.0,
    "gpu_name": "",
    "gpu_mem_used_gb": 0.0,
    "gpu_mem_total_gb": 0.0,
}
PROGRESS_LOCK = threading.Lock()


def update_progress(**kwargs):
    """Thread-safe progress update."""
    with PROGRESS_LOCK:
        PROGRESS_DATA.update(kwargs)
        PROGRESS_DATA["timestamp"] = time.strftime("%Y-%m-%d %H:%M:%S")
    # Also write to file for local access
    try:
        with open("progress.json", "w") as f:
            json.dump(PROGRESS_DATA, f, indent=2)
    except Exception:
        pass


def start_progress_server(port: int = 5555, ngrok_token: str = ""):
    """Start Flask + ngrok in background thread. Returns public URL."""
    try:
        from flask import Flask, jsonify
    except ImportError:
        print("  Flask not installed — progress server disabled")
        return ""

    app = Flask(__name__)

    @app.route("/progress")
    def get_progress():
        with PROGRESS_LOCK:
            return jsonify(PROGRESS_DATA)

    @app.route("/")
    def index():
        with PROGRESS_LOCK:
            d = PROGRESS_DATA.copy()
        html = f"""<html><head><meta http-equiv="refresh" content="10">
        <title>M.E.R.L.I.N. Training</title>
        <style>body{{font-family:monospace;background:#0a0a0a;color:#33ff66;padding:20px}}
        .bar{{background:#1a1a1a;border:1px solid #33ff66;height:30px;width:400px}}
        .fill{{background:#33ff66;height:100%;transition:width 0.5s}}</style></head>
        <body><h1>M.E.R.L.I.N. LoRA Training</h1>
        <p>Status: <b>{d['status'].upper()}</b></p>
        <p>Step {d['step']}/{d['total_steps']} (Epoch {d['epoch']}/{d['total_epochs']})</p>
        <div class="bar"><div class="fill" style="width:{d['pct']}%"></div></div>
        <p>{d['pct']:.1f}% | Loss: {d['loss']:.4f}</p>
        <p>Elapsed: {d['elapsed_sec']//3600:.0f}h{(d['elapsed_sec']%3600)//60:02.0f}m |
           ETA: {d['eta_sec']//3600:.0f}h{(d['eta_sec']%3600)//60:02.0f}m</p>
        <p>GPU: {d['gpu_name']} ({d['gpu_mem_used_gb']:.1f}/{d['gpu_mem_total_gb']:.1f} GB)</p>
        <p style="color:#666">Auto-refresh 10s | JSON: <a href="/progress">/progress</a></p>
        </body></html>"""
        return html

    # Start Flask in background
    flask_thread = threading.Thread(
        target=lambda: app.run(host="0.0.0.0", port=port, debug=False, use_reloader=False),
        daemon=True,
    )
    flask_thread.start()
    time.sleep(1)

    # ngrok tunnel
    public_url = ""
    if ngrok_token:
        try:
            from pyngrok import ngrok, conf
            conf.get_default().auth_token = ngrok_token
            tunnel = ngrok.connect(port, "http")
            public_url = tunnel.public_url
            print(f"\n{'=' * 64}")
            print(f"  PROGRESS SERVER ACTIVE")
            print(f"  Local:  http://localhost:{port}/progress")
            print(f"  Public: {public_url}/progress")
            print(f"")
            print(f"  VS Code watcher command:")
            print(f"  python tools/lora/train_watcher.py --url {public_url}/progress")
            print(f"{'=' * 64}\n")
        except ImportError:
            print("  pyngrok not installed — ngrok tunnel disabled")
            print(f"  Local only: http://localhost:{port}/progress")
        except Exception as e:
            print(f"  ngrok error: {e}")
            print(f"  Local only: http://localhost:{port}/progress")
    else:
        print(f"  No ngrok token — local only: http://localhost:{port}/progress")
        print(f"  Get free token: https://dashboard.ngrok.com/get-started/your-authtoken")

    return public_url


# ── Dataset ─────────────────────────────────────────────────────────────────
def find_dataset() -> str:
    """Auto-detect dataset location (Colab paths + local paths)."""
    candidates = [
        # Colab uploaded file
        Path("merlin_full_v8.jsonl"),
        Path("/content/merlin_full_v8.jsonl"),
        # Google Drive mount
        Path("/content/drive/MyDrive/merlin/merlin_full_v8.jsonl"),
        Path("/content/drive/MyDrive/merlin_full_v8.jsonl"),
        # Local paths
        Path(__file__).parent.parent.parent / "data" / "ai" / "training" / "merlin_full_v8.jsonl",
        Path("data/ai/training/merlin_full_v8.jsonl"),
        # v7 fallback
        Path("merlin_full_v7.jsonl"),
        Path("/content/merlin_full_v7.jsonl"),
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
    """Convert to ChatML text."""
    msgs = sample.get("messages") or sample.get("conversations", [])
    text = ""
    for msg in msgs:
        text += f"<|im_start|>{msg['role']}\n{msg['content']}<|im_end|>\n"
    return {"text": text}


# ── Main ────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="M.E.R.L.I.N. LoRA Colab Training (GPU)")
    parser.add_argument("--dataset", type=str, default="", help="Path to JSONL dataset")
    parser.add_argument("--output-dir", type=str, default="./merlin-lora-output",
                        help="Output dir for checkpoints")
    parser.add_argument("--epochs", type=int, default=3, help="Number of epochs")
    parser.add_argument("--batch-size", type=int, default=4, help="Batch size (4 for T4 16GB)")
    parser.add_argument("--grad-accum", type=int, default=2, help="Gradient accumulation")
    parser.add_argument("--lr", type=float, default=2e-4, help="Learning rate")
    parser.add_argument("--lora-r", type=int, default=16, help="LoRA rank")
    parser.add_argument("--lora-alpha", type=int, default=32, help="LoRA alpha")
    parser.add_argument("--max-seq-len", type=int, default=384, help="Max sequence length")
    parser.add_argument("--save-steps", type=int, default=25, help="Save every N steps")
    parser.add_argument("--resume", action="store_true", help="Resume from checkpoint")
    parser.add_argument("--test-only", action="store_true", help="Test mode only")
    parser.add_argument("--export-gguf", action="store_true", help="Export GGUF after training")
    parser.add_argument("--ngrok-token", type=str, default="", help="ngrok auth token for remote monitoring")
    parser.add_argument("--port", type=int, default=5555, help="Progress server port")
    parser.add_argument("--drive", action="store_true", help="Mount Google Drive for dataset/checkpoints")
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    # === GPU check ===
    import torch
    print(f"\n{'=' * 60}")
    print(f"  M.E.R.L.I.N. LoRA Training — Colab GPU")
    print(f"{'=' * 60}")
    if torch.cuda.is_available():
        gpu_name = torch.cuda.get_device_name(0)
        gpu_mem = torch.cuda.get_device_properties(0).total_mem / 1e9
        print(f"  GPU: {gpu_name} ({gpu_mem:.1f} GB)")
        update_progress(gpu_name=gpu_name, gpu_mem_total_gb=round(gpu_mem, 1))
    else:
        print("  WARNING: No GPU detected — training will be very slow")
        print("  Make sure to select GPU runtime in Colab: Runtime > Change runtime type > T4 GPU")

    print(f"  PyTorch: {torch.__version__}")
    print(f"  CUDA: {torch.version.cuda if torch.cuda.is_available() else 'N/A'}")

    # === Google Drive mount ===
    if args.drive:
        try:
            from google.colab import drive
            drive.mount("/content/drive")
            print("  Google Drive mounted at /content/drive")
        except ImportError:
            print("  Not in Colab — skipping Drive mount")
        except Exception as e:
            print(f"  Drive mount error: {e}")

    # === Progress server ===
    public_url = start_progress_server(port=args.port, ngrok_token=args.ngrok_token)

    # === Dataset ===
    dataset_path = args.dataset or find_dataset()
    if not dataset_path or not os.path.exists(dataset_path):
        print(f"\nERREUR: Dataset introuvable.")
        print(f"  Options:")
        print(f"    1. Upload merlin_full_v8.jsonl to Colab files panel")
        print(f"    2. --drive + put file in Google Drive /merlin/")
        print(f"    3. --dataset /path/to/file.jsonl")
        sys.exit(1)

    raw_samples = load_jsonl(dataset_path)
    print(f"\n  Dataset: {dataset_path}")
    print(f"  Samples: {len(raw_samples)}")
    update_progress(status="loading_model")

    # === Model ===
    from transformers import AutoModelForCausalLM, AutoTokenizer

    MODEL_NAME = "Qwen/Qwen3.5-2B"
    print(f"\n  Loading {MODEL_NAME}...")
    t0 = time.time()

    dtype = torch.bfloat16 if torch.cuda.is_available() and torch.cuda.is_bf16_supported() else torch.float16
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        torch_dtype=dtype,
        device_map="auto" if torch.cuda.is_available() else "cpu",
        trust_remote_code=True,
    )
    model.gradient_checkpointing_enable()

    load_time = time.time() - t0
    param_count = sum(p.numel() for p in model.parameters())
    print(f"  Loaded in {load_time:.0f}s | {param_count / 1e6:.0f}M params | dtype={dtype}")

    if torch.cuda.is_available():
        allocated = torch.cuda.memory_allocated() / 1e9
        print(f"  GPU memory: {allocated:.1f} GB used")
        update_progress(gpu_mem_used_gb=round(allocated, 1))

    # === Test-only ===
    if args.test_only:
        print("\n=== TEST MODE ===")
        del raw_samples; gc.collect()
        checkpoint_dir = _find_latest_checkpoint(args.output_dir)
        if checkpoint_dir:
            from peft import PeftModel
            model = PeftModel.from_pretrained(model, checkpoint_dir)
            print(f"  Loaded adapter: {checkpoint_dir}")
        run_tests(model, tokenizer)
        update_progress(status="done")
        return

    # === LoRA ===
    from peft import LoraConfig, get_peft_model, TaskType

    lora_config = LoraConfig(
        r=args.lora_r,
        lora_alpha=args.lora_alpha,
        target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
        lora_dropout=0.05,
        bias="none",
        task_type=TaskType.CAUSAL_LM,
    )
    model = get_peft_model(model, lora_config)

    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"  LoRA r={args.lora_r} alpha={args.lora_alpha}")
    print(f"  Target: {lora_config.target_modules}")
    print(f"  Trainable: {trainable:,} / {total:,} ({100 * trainable / total:.2f}%)")

    # === Dataset prep ===
    from datasets import Dataset as HFDataset

    formatted = [format_chatml(s) for s in raw_samples]
    dataset = HFDataset.from_list(formatted)
    split = dataset.train_test_split(test_size=0.1, seed=42)
    train_ds, eval_ds = split["train"], split["test"]
    print(f"  Train: {len(train_ds)} | Eval: {len(eval_ds)}")

    # === Estimate ===
    steps_per_epoch = len(train_ds) // (args.batch_size * args.grad_accum)
    total_steps = steps_per_epoch * args.epochs
    # T4 GPU: ~0.5-1s/step with batch=4, grad_accum=2
    est_sec = total_steps * 1.0
    print(f"\n  Steps: {steps_per_epoch}/epoch x {args.epochs} = {total_steps} total")
    print(f"  Estimated: ~{est_sec / 3600:.1f}h on T4 GPU")

    update_progress(
        status="training",
        total_steps=total_steps,
        total_epochs=args.epochs,
    )

    # === Train ===
    from trl import SFTTrainer, SFTConfig
    from transformers import TrainerCallback

    class ProgressCallback(TrainerCallback):
        def __init__(self):
            self._t0 = time.time()

        def on_log(self, _args, state, control, logs=None, **kwargs):
            loss = (logs or {}).get("loss", 0.0)
            elapsed = time.time() - self._t0
            eta = (total_steps - state.global_step) * (elapsed / max(state.global_step, 1))
            gpu_used = 0.0
            if torch.cuda.is_available():
                gpu_used = torch.cuda.memory_allocated() / 1e9
            update_progress(
                step=state.global_step,
                total_steps=total_steps,
                epoch=int(state.epoch) if state.epoch else 0,
                total_epochs=args.epochs,
                loss=round(loss, 4),
                elapsed_sec=round(elapsed),
                eta_sec=round(eta),
                pct=round(100 * state.global_step / max(total_steps, 1), 1),
                gpu_mem_used_gb=round(gpu_used, 1),
            )

        def on_train_end(self, _args, state, control, **kwargs):
            update_progress(status="done", step=total_steps, pct=100.0,
                            elapsed_sec=round(time.time() - self._t0))

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
        optim="adamw_torch",
        fp16=(dtype == torch.float16),
        bf16=(dtype == torch.bfloat16),
        dataset_text_field="text",
        max_length=args.max_seq_len,
        packing=True,  # Packing ON for GPU (faster)
        logging_steps=5,
        eval_strategy="steps",
        eval_steps=args.save_steps,
        save_strategy="steps",
        save_steps=args.save_steps,
        save_total_limit=3,
        load_best_model_at_end=True,
        seed=42,
        report_to="none",
    )

    trainer = SFTTrainer(
        model=model,
        processing_class=tokenizer,
        train_dataset=train_ds,
        eval_dataset=eval_ds,
        args=sft_config,
    )
    trainer.add_callback(ProgressCallback())

    print(f"\n{'=' * 60}")
    print(f"  TRAINING START — GPU {'T4' if torch.cuda.is_available() else 'CPU'}")
    if public_url:
        print(f"  Dashboard: {public_url}")
        print(f"  VS Code:   python tools/lora/train_watcher.py --url {public_url}/progress")
    print(f"{'=' * 60}\n")

    t0 = time.time()
    resume_ckpt = args.resume and _find_latest_checkpoint(args.output_dir)
    if resume_ckpt:
        print(f"  Resuming from: {resume_ckpt}")
    train_result = trainer.train(resume_from_checkpoint=resume_ckpt or None)

    elapsed = time.time() - t0
    print(f"\n{'=' * 60}")
    print(f"  TRAINING COMPLETE — {elapsed / 60:.0f} min")
    print(f"{'=' * 60}")
    for key, val in train_result.metrics.items():
        print(f"  {key}: {val}")

    # Save final adapter
    final_dir = os.path.join(args.output_dir, "final-adapter")
    model.save_pretrained(final_dir)
    tokenizer.save_pretrained(final_dir)
    print(f"\n  Adapter saved: {final_dir}")

    # Test
    run_tests(model, tokenizer)

    # Export GGUF
    if args.export_gguf:
        export_gguf(model, tokenizer, args.output_dir)

    update_progress(status="done")

    # Keep server alive for watcher to see "done"
    if public_url:
        print(f"\n  Progress server still running at {public_url}")
        print(f"  Press Ctrl+C to stop")
        try:
            while True:
                time.sleep(60)
        except KeyboardInterrupt:
            pass


def _find_latest_checkpoint(output_dir: str):
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
    print("\n=== EXPORT GGUF ===")
    try:
        merged_dir = os.path.join(output_dir, "merged")
        merged_model = model.merge_and_unload()
        merged_model.save_pretrained(merged_dir)
        tokenizer.save_pretrained(merged_dir)
        print(f"  Merged to: {merged_dir}")
        print(f"  To convert: python -m llama_cpp.convert {merged_dir} --outfile merlin-qwen-2b.gguf --outtype q4_k_m")
    except Exception as e:
        print(f"  Export error: {e}")


def run_tests(model, tokenizer):
    import torch
    model.eval()
    PRIMER = (
        "Tu es M.E.R.L.I.N. — Memoire Eternelle des Recits et Legendes d'Incarnations Narratives. "
        "Ne de la croyance des hommes, assemble par des siecles de recits. "
        "Vocabulaire: brume, pierre, ogham, nemeton, sidhe, dolmen, korrigans, rune, souffle. "
        "Francais uniquement. Phrases courtes."
    )
    test_prompts = [
        {"system": PRIMER + "\nGenere une RENCONTRE. FORMAT: texte + A)/B)/C) VERBE.",
         "user": "Carte 1. Lieu: foret_broceliande. Theme: source sacree. Acte I."},
        {"system": PRIMER + "\nGenere un DILEMME. FORMAT: texte + A)/B)/C) VERBE.",
         "user": "Carte 5. Lieu: marais_korrigans. Theme: Samhain. Corps=bas Ame=equilibre Monde=haut."},
        {"system": PRIMER + "\nLe Voyageur te pose une question sur ton identite.",
         "user": "Qui es-tu, Merlin?"},
    ]
    total_verb = 0
    for i, p in enumerate(test_prompts):
        chatml = (f"<|im_start|>system\n{p['system']}<|im_end|>\n"
                  f"<|im_start|>user\n{p['user']}<|im_end|>\n"
                  f"<|im_start|>assistant\n")
        inputs = tokenizer(chatml, return_tensors="pt").to(model.device)
        with torch.no_grad():
            out = model.generate(**inputs, max_new_tokens=300, temperature=0.7,
                                 top_p=0.9, repetition_penalty=1.3, do_sample=True)
        del inputs; gc.collect()
        result = tokenizer.decode(out[0], skip_special_tokens=False)
        del out
        if torch.cuda.is_available():
            torch.cuda.empty_cache()
        answer = result.split("<|im_start|>assistant\n")[-1].split("<|im_end|>")[0]
        print(f"\n{'=' * 60}")
        print(f"  TEST {i + 1}: {p['user'][:60]}...")
        print(f"{'=' * 60}")
        print(answer.strip()[:500])
        verb_pattern = r'^[A-D1-4][).:]\s*[A-Z\u00C0-\u00DC]{2,}[\s]*[\u2014\u2013\-]{1,2}\s*.+'
        verb_lines = [l for l in answer.strip().split('\n') if re.match(verb_pattern, l.strip())]
        total_verb += len(verb_lines)
        print(f"\n  Format: {len(verb_lines)}/3 VERBE -- description")
    compliance = total_verb / 9
    print(f"\n  COMPLIANCE: {total_verb}/9 ({compliance:.0%}) -- target >80%")


if __name__ == "__main__":
    main()

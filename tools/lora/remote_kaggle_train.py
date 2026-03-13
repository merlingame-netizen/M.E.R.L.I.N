#!/usr/bin/env python3
"""
MERLIN remote training orchestrator for Kaggle GPU.
Multi-brain support: narrator (4B), gamemaster (2B), worker (0.8B).

This script is designed to be called by the VS Code panel:
`tools/autodev/vscode-monitor-v4` -> "Remote GPU Train".
"""

from __future__ import annotations

import sys
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

import argparse
import base64
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Optional


def now_iso() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def log(message: str) -> None:
    print(f"[MERLIN-REMOTE] {message}")


def fail(message: str, exit_code: int = 1) -> None:
    print(f"[MERLIN-REMOTE][ERROR] {message}", file=sys.stderr)
    raise SystemExit(exit_code)


def project_root(workspace: str) -> Path:
    root = Path(workspace).resolve()
    if not (root / "project.godot").exists():
        fail(f"Invalid workspace (project.godot missing): {root}")
    return root


def remote_dir(root: Path) -> Path:
    return root / ".merlin_remote" / "kaggle"


def job_dir(root: Path) -> Path:
    return remote_dir(root) / "job"


def state_path(root: Path) -> Path:
    return remote_dir(root) / "state.json"


def config_path(root: Path) -> Path:
    return remote_dir(root) / "config.json"


def kaggle_json_path() -> Path:
    cfg_dir = os.environ.get("KAGGLE_CONFIG_DIR", "").strip()
    if cfg_dir:
        return Path(cfg_dir).expanduser().resolve() / "kaggle.json"
    return Path.home() / ".kaggle" / "kaggle.json"


def kaggle_access_token_path() -> Path:
    cfg_dir = os.environ.get("KAGGLE_CONFIG_DIR", "").strip()
    if cfg_dir:
        return Path(cfg_dir).expanduser().resolve() / "access_token"
    return Path.home() / ".kaggle" / "access_token"


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


VALID_BRAINS = ("narrator", "gamemaster", "worker")

BRAIN_DEFAULTS: dict[str, dict] = {
    "narrator": {
        "slug": "merlin-lora-narrator-4b",
        "title": "MERLIN LoRA Narrator (4B)",
        "base_model": "Qwen/Qwen3.5-4B",
        "lora_r": 16,
        "lora_alpha": 32,
        "max_seq_len": 768,
        "max_steps": 300,
        "batch_size": 1,
        "grad_accum": 8,
        "learning_rate": 1e-4,
    },
    "gamemaster": {
        "slug": "merlin-lora-game-master-2b",
        "title": "MERLIN LoRA Game Master (2B)",
        "base_model": "Qwen/Qwen3.5-2B",
        "lora_r": 8,
        "lora_alpha": 16,
        "max_seq_len": 512,
        "max_steps": 200,
        "batch_size": 2,
        "grad_accum": 4,
        "learning_rate": 2e-4,
    },
    "worker": {
        "slug": "merlin-lora-worker-0-8b",
        "title": "MERLIN LoRA Worker (0.8B)",
        "base_model": "Qwen/Qwen3.5-0.8B",
        "lora_r": 8,
        "lora_alpha": 16,
        "max_seq_len": 256,
        "max_steps": 150,
        "batch_size": 4,
        "grad_accum": 2,
        "learning_rate": 3e-4,
    },
}


def brain_job_dir(root: Path, brain: str) -> Path:
    return remote_dir(root) / "jobs" / brain


def get_brain_config(root: Path, brain: str) -> dict:
    """Get brain-specific config, merging defaults with user overrides."""
    cfg = read_json(config_path(root))
    brains_cfg = cfg.get("brains", {})
    defaults = dict(BRAIN_DEFAULTS.get(brain, {}))
    overrides = brains_cfg.get(brain, {})
    defaults.update(overrides)
    return defaults


def detect_brain_dataset(root: Path, brain: str) -> Path:
    """Find the per-brain dataset in data/ai/training/brains/."""
    brains_dir = root / "data" / "ai" / "training" / "brains"
    candidates = sorted(brains_dir.glob(f"{brain}_v*.jsonl"), reverse=True)
    if candidates:
        return candidates[0]
    # Fallback to legacy unified dataset
    return detect_training_dataset(root)


def update_state(root: Path, action: str, status: str, extra: Optional[dict] = None) -> None:
    state = read_json(state_path(root))
    state.update(
        {
            "updated_at": now_iso(),
            "last_action": action,
            "last_status": status,
        }
    )
    if extra:
        state.update(extra)
    write_json(state_path(root), state)


def update_brain_state(root: Path, brain: str, action: str, status: str, extra: Optional[dict] = None) -> None:
    """Update per-brain status in state.json."""
    state = read_json(state_path(root))
    brains_state = state.get("brains", {})
    brain_entry = brains_state.get(brain, {})
    brain_entry.update({
        "status": status,
        "last_action": action,
        "updated_at": now_iso(),
    })
    if extra:
        brain_entry.update(extra)
    brains_state[brain] = brain_entry
    state["brains"] = brains_state
    state["updated_at"] = now_iso()
    state["last_action"] = f"{action}:{brain}"
    state["last_status"] = status
    write_json(state_path(root), state)


def load_kaggle_credentials() -> tuple[str, str, Path]:
    username = os.environ.get("KAGGLE_USERNAME", "").strip()
    key = os.environ.get("KAGGLE_KEY", "").strip() or os.environ.get("KAGGLE_API_TOKEN", "").strip()
    token_file = kaggle_access_token_path()
    if not key and token_file.exists():
        key = token_file.read_text(encoding="utf-8").strip()
    cfg_file = kaggle_json_path()
    if cfg_file.exists():
        raw = read_json(cfg_file)
        username = username or str(raw.get("username", "")).strip()
        key = key or str(raw.get("key", "")).strip()
    return username, key, cfg_file


def detect_training_dataset(root: Path) -> Path:
    train_dir = root / "data" / "ai" / "training"
    if not train_dir.exists():
        fail(f"Training dir not found: {train_dir}")

    candidates = list(train_dir.glob("merlin_full_v*.jsonl"))
    if not candidates:
        candidates = list(train_dir.glob("*.jsonl"))
    if not candidates:
        fail(f"No JSONL dataset found in: {train_dir}")

    def key_func(path: Path) -> tuple[int, float]:
        match = re.search(r"_v(\d+)\.jsonl$", path.name)
        version = int(match.group(1)) if match else -1
        return (version, path.stat().st_mtime)

    candidates.sort(key=key_func, reverse=True)
    return candidates[0]


def training_script_content(dataset_b64: str, brain_cfg: Optional[dict] = None) -> str:
    """Generate Kaggle training script, parameterized by brain config."""
    cfg = brain_cfg or {}
    base_model = cfg.get("base_model", "Qwen/Qwen3.5-2B")
    lora_r = cfg.get("lora_r", 16)
    lora_alpha = cfg.get("lora_alpha", 32)
    max_seq_len = cfg.get("max_seq_len", 768)
    max_steps = cfg.get("max_steps", 240)
    batch_size = cfg.get("batch_size", 1)
    grad_accum = cfg.get("grad_accum", 8)
    learning_rate = cfg.get("learning_rate", 1e-4)
    brain_name = cfg.get("brain_name", "legacy")

    template = f"""# Auto-generated by tools/lora/remote_kaggle_train.py
# Brain: {brain_name} | Model: {base_model}
import json
import os
import base64
import shutil
import subprocess
import sys
from pathlib import Path

print("[merlin] Starting pip install (Qwen 3.5 compatible)...", flush=True)

def install(pkgs):
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "--upgrade", *pkgs])

try:
    install([
        "transformers>=5.2.0",
        "datasets>=3.1.0",
        "peft>=0.15.0",
        "trl>=0.15.0",
        "accelerate>=1.2.0",
        "sentencepiece>=0.2.0",
    ])
    print("[merlin] pip install done.", flush=True)
except Exception as e:
    print(f"[merlin] pip install FAILED: {{e}}", flush=True)
    raise

import torch
from datasets import load_dataset
from peft import LoraConfig, get_peft_model
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from trl import SFTTrainer
print(f"[merlin] transformers={{__import__('transformers').__version__}}, peft={{__import__('peft').__version__}}, trl={{__import__('trl').__version__}}", flush=True)

ROOT = Path("/kaggle/working")
DATA_FILE = ROOT / "merlin_train.jsonl"
ARTIFACT_DIR = ROOT / "merlin_artifacts"
ADAPTER_DIR = ARTIFACT_DIR / "adapter"
CHECKPOINT_DIR = ARTIFACT_DIR / "checkpoints"
ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
EMBEDDED_DATASET_B64 = "__DATASET_B64__"

MODEL_NAME = os.getenv("MERLIN_BASE_MODEL", "{base_model}")
EPOCHS = float(os.getenv("MERLIN_EPOCHS", "1"))
MAX_STEPS = int(os.getenv("MERLIN_MAX_STEPS", "{max_steps}"))
MAX_SEQ_LEN = int(os.getenv("MERLIN_MAX_SEQ", "{max_seq_len}"))

if not DATA_FILE.exists():
    if EMBEDDED_DATASET_B64:
        DATA_FILE.write_bytes(base64.b64decode(EMBEDDED_DATASET_B64.encode("ascii")))
    else:
        raise FileNotFoundError(f"Dataset not found: {{DATA_FILE}}")

if not torch.cuda.is_available():
    raise RuntimeError("No GPU detected. Enable GPU in Kaggle settings.")

print(f"GPU: {{torch.cuda.get_device_name(0)}}")
print(f"Brain: {brain_name}")
print(f"Model: {{MODEL_NAME}}")
print(f"Dataset: {{DATA_FILE}}")

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token

dataset = load_dataset("json", data_files=str(DATA_FILE), split="train")

def to_text(example):
    messages = example.get("messages") or example.get("conversations") or []
    if hasattr(tokenizer, "apply_chat_template"):
        try:
            text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=False)
            return {{"text": text}}
        except Exception:
            pass

    chunks = []
    for msg in messages:
        role = msg.get("role", "user")
        content = msg.get("content", "")
        chunks.append(f"<|im_start|>{{role}}\\n{{content}}<|im_end|>")
    return {{"text": "\\n".join(chunks)}}

dataset = dataset.map(to_text, remove_columns=dataset.column_names)
dataset = dataset.filter(lambda row: bool(row.get("text")))
print(f"Training samples: {{len(dataset)}}")

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    trust_remote_code=True,
    device_map="auto",
    torch_dtype=torch.float16,
)
model.config.use_cache = False
model.gradient_checkpointing_enable()

lora = LoraConfig(
    r={lora_r},
    lora_alpha={lora_alpha},
    lora_dropout=0.05,
    bias="none",
    task_type="CAUSAL_LM",
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
)
model = get_peft_model(model, lora)

args = TrainingArguments(
    output_dir=str(CHECKPOINT_DIR),
    num_train_epochs=EPOCHS,
    max_steps=MAX_STEPS,
    per_device_train_batch_size={batch_size},
    gradient_accumulation_steps={grad_accum},
    learning_rate={learning_rate},
    logging_steps=10,
    save_steps=40,
    save_total_limit=2,
    fp16=True,
    report_to=[],
)

trainer_kwargs = dict(
    model=model,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=MAX_SEQ_LEN,
    packing=True,
    args=args,
)
try:
    trainer = SFTTrainer(tokenizer=tokenizer, **trainer_kwargs)
except TypeError:
    trainer = SFTTrainer(processing_class=tokenizer, **trainer_kwargs)

trainer.train()
model.save_pretrained(str(ADAPTER_DIR))
tokenizer.save_pretrained(str(ADAPTER_DIR))

manifest = {{
    "brain": "{brain_name}",
    "base_model": MODEL_NAME,
    "epochs": EPOCHS,
    "max_steps": MAX_STEPS,
    "max_seq_len": MAX_SEQ_LEN,
    "lora_r": {lora_r},
    "lora_alpha": {lora_alpha},
    "batch_size": {batch_size},
    "grad_accum": {grad_accum},
    "learning_rate": {learning_rate},
    "samples": len(dataset),
}}
(ARTIFACT_DIR / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")

zip_path = ROOT / "merlin_artifacts"
shutil.make_archive(str(zip_path), "zip", str(ARTIFACT_DIR))
print("Artifacts generated:")
print(f" - {{ARTIFACT_DIR}}")
print(f" - {{zip_path}}.zip")
"""
    return template.replace("__DATASET_B64__", dataset_b64)


def resolve_kaggle_runner() -> list[str]:
    candidates: list[list[str]] = [
        [sys.executable, "-m", "kaggle.cli"],
        [sys.executable, "-m", "kaggle"],
    ]

    scripts_dir = Path(sys.executable).resolve().parent / ("Scripts" if os.name == "nt" else "bin")
    local_cli = scripts_dir / ("kaggle.exe" if os.name == "nt" else "kaggle")
    if local_cli.exists():
        candidates.append([str(local_cli)])

    which_cli = shutil.which("kaggle")
    if which_cli:
        candidates.append([which_cli])

    for runner in candidates:
        probe = subprocess.run(runner + ["--version"], capture_output=True, text=True)
        if probe.returncode == 0:
            return runner

    log("Kaggle package missing. Installing with pip...")
    install = subprocess.run([sys.executable, "-m", "pip", "install", "kaggle"], capture_output=True, text=True)
    if install.returncode != 0:
        sys.stdout.write(install.stdout or "")
        sys.stderr.write(install.stderr or "")
        fail("Unable to install kaggle package.")

    refreshed_candidates: list[list[str]] = [
        [sys.executable, "-m", "kaggle.cli"],
        [sys.executable, "-m", "kaggle"],
    ]
    if local_cli.exists():
        refreshed_candidates.append([str(local_cli)])
    which_cli = shutil.which("kaggle")
    if which_cli:
        refreshed_candidates.append([which_cli])
    for runner in refreshed_candidates:
        probe_after = subprocess.run(runner + ["--version"], capture_output=True, text=True)
        if probe_after.returncode == 0:
            return runner

    fail("Kaggle CLI unavailable after installation.")
    return []  # unreachable


def resolve_username(root: Path, explicit_username: str) -> str:
    if explicit_username:
        return explicit_username.strip()
    env_or_file_username, _, _ = load_kaggle_credentials()
    if env_or_file_username:
        return env_or_file_username.strip()
    cfg = read_json(config_path(root))
    cfg_username = str(cfg.get("username", "")).strip()
    if cfg_username:
        return cfg_username
    return ""


def ensure_kaggle_credentials_for_remote() -> tuple[str, Path]:
    username, key, cfg_file = load_kaggle_credentials()
    if username and key:
        return username, cfg_file
    fail(
        "Missing Kaggle credentials. "
        "Add KAGGLE_USERNAME with KAGGLE_KEY or KAGGLE_API_TOKEN, or place kaggle.json at "
        f"{cfg_file}."
    )
    return "", cfg_file  # unreachable


def run_kaggle(args: list[str], cwd: Optional[Path] = None) -> subprocess.CompletedProcess:
    cmd = [*resolve_kaggle_runner(), *args]
    log("Running: " + " ".join(cmd))
    env = os.environ.copy()
    env.setdefault("PYTHONUTF8", "1")
    env.setdefault("PYTHONIOENCODING", "utf-8")
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        check=False,
        text=True,
        capture_output=True,
        env=env,
    )


def cmd_setup(root: Path, username: str, slug: str, title: str, brain: str = "") -> None:
    resolved_user = resolve_username(root, username)
    if not resolved_user:
        _, cfg_file = ensure_kaggle_credentials_for_remote()
        fail(f"Unable to resolve Kaggle username. Provide --username or populate {cfg_file}.")

    brains_to_setup = list(VALID_BRAINS) if brain == "all" else [brain] if brain else [""]

    for b in brains_to_setup:
        _setup_single_brain(root, resolved_user, slug, title, b)


def _setup_single_brain(root: Path, resolved_user: str, slug: str, title: str, brain: str) -> None:
    """Setup a single brain's Kaggle kernel."""
    if brain and brain in VALID_BRAINS:
        bcfg = get_brain_config(root, brain)
        effective_slug = slug if slug != "merlin-remote-train" else bcfg.get("slug", f"merlin-lora-{brain}")
        effective_title = title if title != "MERLIN Remote LoRA Training" else bcfg.get("title", f"MERLIN LoRA {brain}")
        jdir = brain_job_dir(root, brain)
        src_dataset = detect_brain_dataset(root, brain)
        bcfg["brain_name"] = brain
    else:
        # Legacy single-brain mode
        effective_slug = slug or "merlin-remote-train"
        effective_title = title or "MERLIN Remote LoRA Training"
        jdir = job_dir(root)
        src_dataset = detect_training_dataset(root)
        bcfg = None

    if not effective_slug:
        fail("--slug is required for setup")

    jdir.mkdir(parents=True, exist_ok=True)

    dst_dataset = jdir / "merlin_train.jsonl"
    shutil.copy2(src_dataset, dst_dataset)
    dataset_b64 = base64.b64encode(dst_dataset.read_bytes()).decode("ascii")

    metadata = {
        "id": f"{resolved_user}/{effective_slug}",
        "title": effective_title,
        "code_file": "train_merlin_remote.py",
        "language": "python",
        "kernel_type": "script",
        "is_private": True,
        "enable_gpu": True,
        "enable_internet": True,
        "dataset_sources": [],
        "competition_sources": [],
        "kernel_sources": [],
    }
    write_json(jdir / "kernel-metadata.json", metadata)
    (jdir / "train_merlin_remote.py").write_text(
        training_script_content(dataset_b64, brain_cfg=bcfg), encoding="utf-8"
    )

    # Update config
    cfg = read_json(config_path(root))
    cfg["username"] = resolved_user
    cfg["updated_at"] = now_iso()
    if brain and brain in VALID_BRAINS:
        brains_cfg = cfg.get("brains", {})
        brains_cfg[brain] = {
            **brains_cfg.get(brain, {}),
            "slug": effective_slug,
            "title": effective_title,
            "dataset": str(src_dataset),
            "job_dir": str(jdir),
        }
        cfg["brains"] = brains_cfg
        update_brain_state(root, brain, "setup", "ready",
                           {"job": f"{resolved_user}/{effective_slug}", "dataset": str(src_dataset)})
    else:
        cfg["slug"] = effective_slug
        cfg["title"] = effective_title
        cfg["dataset"] = str(src_dataset)
        cfg["job_dir"] = str(jdir)
        update_state(root, "setup", "ready",
                     {"job": f"{resolved_user}/{effective_slug}", "dataset": str(src_dataset)})

    write_json(config_path(root), cfg)
    label = f" [{brain}]" if brain else ""
    log(f"Setup complete{label}: {jdir}")
    log(f"Dataset: {src_dataset.name} ({src_dataset.stat().st_size // 1024}KB)")


def resolve_identity(root: Path, username: str, slug: str, brain: str = "") -> tuple[str, str]:
    cfg = read_json(config_path(root))
    user = username or cfg.get("username", "") or resolve_username(root, "")

    if brain and brain in VALID_BRAINS:
        brains_cfg = cfg.get("brains", {})
        bcfg = brains_cfg.get(brain, {})
        kernel_slug = slug if slug != "merlin-remote-train" else bcfg.get("slug", "")
    else:
        kernel_slug = slug or cfg.get("slug", "")

    if not user or not kernel_slug:
        fail("Missing username/slug. Run setup first or pass --username and --slug.")
    return user, kernel_slug


def cmd_doctor(root: Path, username: str, slug: str, brain: str = "") -> None:
    cfg = read_json(config_path(root))
    resolved_user = resolve_username(root, username)

    brains_to_check = list(VALID_BRAINS) if brain == "all" else [brain] if brain else [""]

    env_user, env_key, cfg_file = load_kaggle_credentials()

    runner_ok = False
    runner_info = ""
    try:
        runner = resolve_kaggle_runner()
        probe = subprocess.run([*runner, "--version"], capture_output=True, text=True)
        runner_ok = probe.returncode == 0
        runner_info = (probe.stdout or probe.stderr or "").strip()
    except SystemExit as exc:
        runner_info = f"kaggle runner bootstrap failed (exit {exc.code})"

    all_results = {}

    for b in brains_to_check:
        if b and b in VALID_BRAINS:
            bcfg = get_brain_config(root, b)
            resolved_slug = bcfg.get("slug", f"merlin-lora-{b}")
            try:
                dataset_path = str(detect_brain_dataset(root, b))
                dataset_ok = True
            except SystemExit:
                dataset_ok = False
                dataset_path = ""
        else:
            resolved_slug = slug or str(cfg.get("slug", "")).strip() or "merlin-remote-train"
            try:
                dataset_path = str(detect_training_dataset(root))
                dataset_ok = True
            except SystemExit:
                dataset_ok = False
                dataset_path = ""

        checks: dict[str, object] = {
            "brain": b or "legacy",
            "workspace": str(root),
            "python_executable": sys.executable,
            "resolved_username": resolved_user,
            "resolved_slug": resolved_slug,
            "dataset_ok": dataset_ok,
            "dataset": dataset_path,
            "kaggle_json_path": str(cfg_file),
            "kaggle_username_present": bool(env_user),
            "kaggle_key_present": bool(env_key),
            "kaggle_cli_ok": runner_ok,
            "kaggle_cli": runner_info,
        }

        missing: list[str] = []
        if not dataset_ok:
            missing.append("training_dataset")
        if not resolved_user:
            missing.append("kaggle_username")
        if not env_key:
            missing.append("kaggle_key")
        if not runner_ok:
            missing.append("kaggle_cli")

        status = "ready" if not missing else "blocked"
        label = b or "legacy"
        all_results[label] = {"status": status, "checks": checks, "missing": missing}

        if b and b in VALID_BRAINS:
            update_brain_state(root, b, "doctor", status, {"doctor_missing": missing})
        else:
            update_state(root, "doctor", status, {"doctor_missing": missing,
                         "job": f"{resolved_user}/{resolved_slug}" if resolved_user else ""})

    print(json.dumps(all_results, ensure_ascii=False, indent=2))


def cmd_submit(root: Path, username: str, slug: str, brain: str = "") -> None:
    ensure_kaggle_credentials_for_remote()
    brains_to_submit = list(VALID_BRAINS) if brain == "all" else [brain] if brain else [""]

    for b in brains_to_submit:
        _submit_single(root, username, slug, b)


def _submit_single(root: Path, username: str, slug: str, brain: str) -> None:
    user, kernel_slug = resolve_identity(root, username, slug, brain)
    jdir = brain_job_dir(root, brain) if brain and brain in VALID_BRAINS else job_dir(root)

    if not (jdir / "kernel-metadata.json").exists():
        fail(f"kernel-metadata.json missing for {brain or 'legacy'}. Run setup first.")

    result = run_kaggle(["kernels", "push", "-p", str(jdir)], cwd=root)
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    if result.returncode != 0:
        if brain and brain in VALID_BRAINS:
            update_brain_state(root, brain, "submit", "failed", {"job": f"{user}/{kernel_slug}"})
        else:
            update_state(root, "submit", "failed", {"job": f"{user}/{kernel_slug}"})
        fail(f"Kaggle submit failed for {brain or 'legacy'}.")

    extra = {
        "job": f"{user}/{kernel_slug}",
        "url": f"https://www.kaggle.com/code/{user}/{kernel_slug}",
        "submitted_at": now_iso(),
    }
    if brain and brain in VALID_BRAINS:
        update_brain_state(root, brain, "submit", "submitted", extra)
    else:
        update_state(root, "submit", "submitted", extra)

    label = f" [{brain}]" if brain else ""
    log(f"Submitted{label}: {user}/{kernel_slug}")


def cmd_status(root: Path, username: str, slug: str, brain: str = "") -> None:
    ensure_kaggle_credentials_for_remote()
    brains_to_check = list(VALID_BRAINS) if brain == "all" else [brain] if brain else [""]

    for b in brains_to_check:
        _status_single(root, username, slug, b)


def _status_single(root: Path, username: str, slug: str, brain: str) -> None:
    user, kernel_slug = resolve_identity(root, username, slug, brain)
    result = run_kaggle(["kernels", "status", f"{user}/{kernel_slug}"], cwd=root)
    output = (result.stdout or "") + (result.stderr or "")
    label = f"[{brain}] " if brain else ""
    print(f"{label}{output.rstrip()}")

    if result.returncode != 0:
        if brain and brain in VALID_BRAINS:
            update_brain_state(root, brain, "status", "failed", {"job": f"{user}/{kernel_slug}"})
        else:
            update_state(root, "status", "failed", {"job": f"{user}/{kernel_slug}"})
        if brain != "all":
            fail(f"Status check failed for {brain or 'legacy'}.")
        return

    lowered = output.lower()
    if "running" in lowered:
        status = "running"
    elif "complete" in lowered:
        status = "complete"
    elif "error" in lowered or "failed" in lowered:
        status = "failed"
    else:
        status = "checked"

    if brain and brain in VALID_BRAINS:
        update_brain_state(root, brain, "status", status,
                           {"job": f"{user}/{kernel_slug}", "raw_status": output.strip()})
    else:
        update_state(root, "status", status,
                     {"job": f"{user}/{kernel_slug}", "raw_status": output.strip()})


def cmd_download(root: Path, username: str, slug: str, output_dir: Path, brain: str = "") -> None:
    ensure_kaggle_credentials_for_remote()
    brains_to_dl = list(VALID_BRAINS) if brain == "all" else [brain] if brain else [""]

    for b in brains_to_dl:
        _download_single(root, username, slug, output_dir, b)


def _download_single(root: Path, username: str, slug: str, output_dir: Path, brain: str) -> None:
    user, kernel_slug = resolve_identity(root, username, slug, brain)

    if brain and brain in VALID_BRAINS:
        effective_output = output_dir / brain
    else:
        effective_output = output_dir

    effective_output.mkdir(parents=True, exist_ok=True)
    result = run_kaggle(
        ["kernels", "output", f"{user}/{kernel_slug}", "-p", str(effective_output), "-w"],
        cwd=root,
    )
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    if result.returncode != 0:
        if brain and brain in VALID_BRAINS:
            update_brain_state(root, brain, "download", "failed", {"job": f"{user}/{kernel_slug}"})
        else:
            update_state(root, "download", "failed", {"job": f"{user}/{kernel_slug}"})
        notify_agent_bus(brain or "legacy", "failed", error=f"Download failed for {user}/{kernel_slug}")
        fail(f"Download failed for {brain or 'legacy'}.")

    # Mirror CWD artifacts
    expected_names = [
        "merlin_artifacts",
        "merlin_artifacts.zip",
        "merlin_train.jsonl",
        f"{kernel_slug}.log",
    ]
    for name in expected_names:
        src = root / name
        if not src.exists():
            continue
        dst = effective_output / name
        if src.is_dir():
            if dst.exists():
                shutil.rmtree(dst)
            shutil.copytree(src, dst)
        else:
            if dst.exists():
                dst.unlink()
            shutil.copy2(src, dst)

    extra = {"job": f"{user}/{kernel_slug}", "output_dir": str(effective_output.resolve())}
    if brain and brain in VALID_BRAINS:
        update_brain_state(root, brain, "download", "success", extra)
    else:
        update_state(root, "download", "success", extra)

    notify_agent_bus(brain or "legacy", "completed")

    label = f" [{brain}]" if brain else ""
    log(f"Artifacts downloaded{label}: {effective_output.resolve()}")


def http_post_json(url: str, payload: dict, headers: Optional[dict] = None, timeout: int = 120) -> dict:
    raw = json.dumps(payload).encode("utf-8")
    # Cloudflare WAF blocks "Python-urllib/3.x"; curl UA bypasses error 1010
    req_headers = {"Content-Type": "application/json", "User-Agent": "curl/7.88.1"}
    if headers:
        req_headers.update(headers)
    req = urllib.request.Request(url=url, data=raw, headers=req_headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read().decode("utf-8", errors="replace")
    return json.loads(body)


def normalize_chat_endpoint(endpoint: str) -> str:
    clean = (endpoint or "").strip().rstrip("/")
    if not clean:
        return ""
    if clean.endswith("/chat/completions"):
        return clean
    if clean.endswith("/v1") or clean.endswith("/openai/v1"):
        return f"{clean}/chat/completions"
    return clean


def resolve_api_key(endpoint: str, explicit_key: str) -> str:
    if explicit_key:
        return explicit_key
    lowered = endpoint.lower()
    if "together.xyz" in lowered:
        return os.environ.get("TOGETHER_API_KEY", "")
    if "groq.com" in lowered:
        return os.environ.get("GROQ_API_KEY", "")
    if "runpod.ai" in lowered:
        return os.environ.get("RUNPOD_API_KEY", "")
    return os.environ.get("OPENAI_API_KEY", "")


def cmd_chat(root: Path, prompt: str, model: str, endpoint: str, api_key: str, system_prompt: str = "") -> None:
    if not prompt:
        fail("--prompt is required for chat")

    reply = ""
    mode = "ollama"
    try:
        endpoint_url = normalize_chat_endpoint(endpoint)
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        if endpoint_url:
            mode = "remote_endpoint"
            payload = {
                "model": model,
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 350,
            }
            effective_key = resolve_api_key(endpoint_url, api_key)
            headers = {"Authorization": f"Bearer {effective_key}"} if effective_key else {}
            data = http_post_json(endpoint_url, payload, headers=headers, timeout=180)
            choices = data.get("choices", [])
            if choices:
                msg = choices[0].get("message", {})
                reply = str(msg.get("content", "")).strip()
        else:
            url = "http://127.0.0.1:11434/api/chat"
            payload = {
                "model": model,
                "messages": messages,
                "stream": False,
                "options": {"temperature": 0.7, "num_predict": 350},
            }
            data = http_post_json(url, payload, timeout=180)
            msg = data.get("message", {})
            reply = str(msg.get("content", "")).strip()
    except Exception as exc:
        update_state(root, "chat", "failed", {"chat_mode": mode, "chat_model": model})
        fail(f"Chat request failed: {exc}")

    if not reply:
        reply = "(empty)"
    update_state(root, "chat", "ok", {"chat_mode": mode, "chat_model": model})
    print(json.dumps({"reply": reply, "mode": mode, "model": model}, ensure_ascii=False))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="MERLIN remote Kaggle training orchestrator (multi-brain)")
    parser.add_argument("action", choices=["doctor", "setup", "submit", "status", "download", "chat"])
    parser.add_argument("--workspace", required=True, help="Project root containing project.godot")
    parser.add_argument("--brain", default="", choices=["", "narrator", "gamemaster", "worker", "all"],
                        help="Brain to operate on (narrator/gamemaster/worker/all). Empty=legacy single mode.")
    parser.add_argument("--username", default="", help="Kaggle username")
    parser.add_argument("--slug", default="merlin-remote-train", help="Kaggle kernel slug")
    parser.add_argument("--title", default="MERLIN Remote LoRA Training", help="Kaggle kernel title")
    parser.add_argument("--output", default="", help="Output folder for downloaded artifacts")
    parser.add_argument("--model", default="merlin-narrator-lora-q4:latest", help="Model name for chat")
    parser.add_argument("--prompt", default="", help="Prompt text for chat")
    parser.add_argument("--endpoint", default="", help="Optional OpenAI-compatible endpoint URL (base /v1 or full /chat/completions)")
    parser.add_argument("--api-key", default="", help="Optional API key for --endpoint")
    parser.add_argument("--system-prompt", default="", help="System prompt for chat (persona or dev mode)")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = project_root(args.workspace)
    brain = args.brain.strip()

    if args.action == "doctor":
        cmd_doctor(root, args.username.strip(), args.slug.strip(), brain)
        return

    if args.action == "setup":
        cmd_setup(root, args.username.strip(), args.slug.strip(), args.title.strip(), brain)
        return

    if args.action == "submit":
        cmd_submit(root, args.username.strip(), args.slug.strip(), brain)
        return

    if args.action == "status":
        cmd_status(root, args.username.strip(), args.slug.strip(), brain)
        return

    if args.action == "download":
        output = Path(args.output).resolve() if args.output else (root / "output" / "remote_kaggle")
        cmd_download(root, args.username.strip(), args.slug.strip(), output, brain)
        return

    if args.action == "chat":
        cmd_chat(
            root=root,
            prompt=args.prompt.strip(),
            model=args.model.strip(),
            endpoint=args.endpoint.strip(),
            api_key=args.api_key.strip(),
            system_prompt=args.system_prompt.strip(),
        )
        return

    fail(f"Unsupported action: {args.action}")


def notify_agent_bus(brain: str, status: str, metrics: dict = None, error: str = None):
    """
    Notify orchestrator_v2 agent bus when training completes or fails.
    Called at the end of training to enable LORA_WAIT → TEST transition.

    status: "completed" | "failed"
    """
    import json
    from datetime import datetime, timezone
    from pathlib import Path
    import random

    # Find project root (2 levels up from tools/lora/)
    project_root = Path(__file__).parent.parent.parent
    messages_file = project_root / "tools" / "autodev" / "status" / "agent_messages.json"

    if not messages_file.exists():
        print(f"[LoRA] Warning: agent_messages.json not found at {messages_file}")
        return

    try:
        with open(messages_file, "r", encoding="utf-8") as f:
            bus = json.load(f)

        msg_id = f"msg_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{random.randint(0, 999):03d}"

        if status == "completed":
            msg_type = "model_ready"
            priority = "HIGH"
            payload = {
                "brain": brain,
                "adapter_path": f"addons/merlin_llm/adapters/merlin_{brain}_lora.gguf",
                "metrics_after": metrics or {},
                "status": "completed"
            }
        else:
            msg_type = "issue_report"
            priority = "CRITICAL"
            payload = {
                "issue_type": "lora_training_failed",
                "brain": brain,
                "error": error or "Unknown training failure",
                "suggested_action": "check_kaggle_logs"
            }

        message = {
            "id": msg_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "from_agent": "lora_trainer",
            "to_agent": "orchestrator",
            "type": msg_type,
            "priority": priority,
            "payload": payload,
            "status": "pending",
            "handled_at": None
        }

        bus["messages"].append(message)
        bus["stats"]["total_sent"] = bus["stats"].get("total_sent", 0) + 1
        bus["stats"]["last_message_id"] = msg_id

        # Atomic write
        temp_file = str(messages_file) + ".tmp"
        with open(temp_file, "w", encoding="utf-8") as f:
            json.dump(bus, f, indent=2, ensure_ascii=False)
        Path(temp_file).replace(messages_file)

        print(f"[LoRA] Notified agent bus: {msg_type} for {brain}")

    except Exception as e:
        print(f"[LoRA] Warning: Could not write to agent bus: {e}")


if __name__ == "__main__":
    main()

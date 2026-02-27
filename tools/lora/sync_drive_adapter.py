#!/usr/bin/env python3
"""
M.E.R.L.I.N. — Sync LoRA adapter from Google Drive to local project.

Downloads the adapter files from Google Drive folder to:
  addons/merlin_llm/adapters/merlin-lora-{version}/

Usage:
  python tools/lora/sync_drive_adapter.py --version v1
  python tools/lora/sync_drive_adapter.py --version v1 --merged   # Download merged model too

Requirements:
  pip install gdown
"""

import argparse
import os
import sys
from pathlib import Path

try:
    import gdown
except ImportError:
    print("ERREUR: gdown requis — pip install gdown")
    sys.exit(1)

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# Google Drive folder IDs (Mon Drive/M.E.R.L.I.N./)
DRIVE_FOLDERS = {
    "adapter": {
        "url": "https://drive.google.com/drive/folders/1yKkQxxS_lWP4hpfaKh6y4IdIOUdAMfCJ",
        "files": {
            "adapter_config.json": None,
            "adapter_model.safetensors": None,
            "chat_template.jinja": None,
            "README.md": None,
            "tokenizer_config.json": None,
            "tokenizer.json": None,
        }
    },
}

# Individual file IDs from Drive (more reliable than folder download)
ADAPTER_FILES = {
    "adapter_config.json": "small",
    "adapter_model.safetensors": "large",
    "chat_template.jinja": "small",
    "tokenizer_config.json": "small",
    "tokenizer.json": "large",
}


def sync_folder(drive_folder_url: str, local_dir: Path, label: str) -> bool:
    """Download a Google Drive folder to local directory."""
    os.makedirs(local_dir, exist_ok=True)

    print(f"\n{'=' * 60}")
    print(f"  Downloading {label}")
    print(f"  From: {drive_folder_url}")
    print(f"  To:   {local_dir}")
    print(f"{'=' * 60}\n")

    try:
        gdown.download_folder(
            url=drive_folder_url,
            output=str(local_dir),
            quiet=False,
            use_cookies=False,
        )
    except Exception as e:
        print(f"\nERREUR gdown folder: {e}")
        print("Tentative fichier par fichier...")
        return False

    # Verify files
    files = list(local_dir.iterdir())
    if not files:
        print(f"ERREUR: Aucun fichier telecharge dans {local_dir}")
        return False

    print(f"\nFichiers telecharges:")
    total_size = 0
    for f in sorted(files):
        if f.is_file():
            size = f.stat().st_size
            total_size += size
            print(f"  {f.name} ({size / 1e6:.1f} MB)")

    print(f"\nTotal: {total_size / 1e6:.0f} MB | {len(files)} fichiers")
    return True


def verify_adapter(local_dir: Path) -> bool:
    """Verify adapter files are present and valid."""
    required = ["adapter_config.json", "adapter_model.safetensors"]
    missing = [f for f in required if not (local_dir / f).exists()]

    if missing:
        print(f"ERREUR: Fichiers manquants: {missing}")
        return False

    # Check adapter_config.json is valid JSON
    import json
    config_path = local_dir / "adapter_config.json"
    try:
        with open(config_path) as f:
            config = json.load(f)
        print(f"\nAdapter config:")
        print(f"  base_model: {config.get('base_model_name_or_path', '?')}")
        print(f"  r: {config.get('r', '?')}")
        print(f"  lora_alpha: {config.get('lora_alpha', '?')}")
        print(f"  target_modules: {config.get('target_modules', '?')}")
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"ERREUR: adapter_config.json invalide: {e}")
        return False

    # Check safetensors size
    safetensors = local_dir / "adapter_model.safetensors"
    size_mb = safetensors.stat().st_size / 1e6
    if size_mb < 1:
        print(f"ERREUR: adapter_model.safetensors trop petit ({size_mb:.1f} MB)")
        return False
    print(f"  adapter_model.safetensors: {size_mb:.1f} MB")

    print("\nAdapter valide!")
    return True


def main():
    parser = argparse.ArgumentParser(description="Sync LoRA adapter from Google Drive")
    parser.add_argument("--version", type=str, default="v1",
                        help="Adapter version (default: v1)")
    parser.add_argument("--merged", action="store_true",
                        help="Also download merged model (~3 GB)")
    parser.add_argument("--output-dir", type=str, default="",
                        help="Override output directory")
    args = parser.parse_args()

    # Adapter destination
    if args.output_dir:
        adapter_dir = Path(args.output_dir)
    else:
        adapter_dir = PROJECT_ROOT / "addons" / "merlin_llm" / "adapters" / f"merlin-lora-{args.version}"

    # Download adapter
    adapter_url = "https://drive.google.com/drive/folders/1yKkQxxS_lWP4hpfaKh6y4IdIOUdAMfCJ"
    success = sync_folder(adapter_url, adapter_dir, f"LoRA Adapter {args.version}")

    if success:
        verify_adapter(adapter_dir)
    else:
        print("\nEchec du telechargement automatique.")
        print(f"Alternative manuelle:")
        print(f"  1. Ouvrir: {adapter_url}")
        print(f"  2. Telecharger le dossier")
        print(f"  3. Extraire dans: {adapter_dir}")

    # Download merged model (optional)
    if args.merged:
        merged_dir = PROJECT_ROOT / "addons" / "merlin_llm" / "adapters" / f"merlin-lora-{args.version}-merged"
        merged_url = "https://drive.google.com/drive/folders/MERGED_FOLDER_ID"
        print("\n[MERGED] Le modele merged (~3 GB) doit etre telecharge manuellement")
        print(f"  depuis Google Drive > Mon Drive > M.E.R.L.I.N. > merlin-lora-merged")
        print(f"  vers: {merged_dir}")


if __name__ == "__main__":
    main()

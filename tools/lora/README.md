# M.E.R.L.I.N. LoRA Fine-Tuning Pipeline

Pipeline pour specialiser le Narrator brain (Qwen 2.5-3B-Instruct) sur le style narratif celtique de Merlin.

## Pipeline

```
1. export_training_data.py    → data/ai/training/merlin_narrator_dataset.json
2. augment_dataset.py         → data/ai/training/merlin_narrator_augmented.json
3. train_narrator_lora.py     → output/merlin_narrator_lora/
4. convert_to_gguf.sh         → addons/merlin_llm/adapters/merlin_narrator_lora.gguf
5. benchmark_lora.py          → evaluation des metriques
```

Mode optionnel scene-aware:
- `python tools/lora/export_training_data.py --scene-aware`
- `python tools/lora/augment_dataset.py --scene-aware`
- Injecte les contrats de scene depuis `data/ai/config/scene_profiles.json`

## Prerequis

```bash
pip install unsloth peft transformers datasets accelerate bitsandbytes trl
```

GPU requis pour le training (RTX 4090 recommande, ou RunPod/Colab Pro).

## Utilisation rapide

```bash
# 1. Exporter les donnees d'entrainement
python tools/lora/export_training_data.py

# 1b. Variante scene-aware (contrats de scene)
python tools/lora/export_training_data.py --scene-aware

# 2. Augmenter le dataset
python tools/lora/augment_dataset.py

# 2b. Variante scene-aware
python tools/lora/augment_dataset.py --scene-aware

# 3. Entrainer (sur machine avec GPU)
python tools/lora/train_narrator_lora.py --epochs 3 --rank 16

# 4. Convertir en GGUF
bash tools/lora/convert_to_gguf.sh

# 5. Copier l'adapter dans le projet Godot
cp output/merlin_narrator_lora.gguf addons/merlin_llm/adapters/
```

Le jeu detecte et charge automatiquement l'adapter au demarrage.

## Hyperparametres

| Parametre | Defaut | Notes |
|-----------|--------|-------|
| rank (r) | 16 | Augmenter si sous-apprentissage |
| alpha | 2x rank | Ratio standard |
| epochs | 3 | Augmenter si loss ne converge pas |
| learning_rate | 3e-4 | Reduire si loss instable |
| batch_size | 4 x 4 | Effective batch 16 |

## Metriques cibles

| Metrique | Cible |
|----------|-------|
| Consistance de ton | >85% |
| Vocabulaire celtique | +40% vs base |
| Qualite francais | >95% |
| Diversite (Self-BLEU) | <0.4 |
| Conformite contrat de scene | >90% |
| Violations sujets interdits | <5% |
| Latence | Delta <5% |

# LoRA Narrator — Refinetune Plan (Qwen 3.5 → Gemma 4)

**Statut** : plan exécutable. **Aucune exécution lancée** côté agent — décision humaine requise sur le choix base model (E4B vs 26B-A4B) et la plateforme de training (local 4090 vs Colab Pro A100 vs Kaggle T4×2 vs Lambda Labs).

---

## 1. Contexte

L'adapter LoRA actuel `merlin_narrator_lora.gguf` a été entraîné sur **Qwen 3.5:4b** (ChatML, target_modules attention+MLP). Suite à la migration Gemma 4 (branche `feat/gemma4-migration`), il devient **incompatible avec le base model** : les couches diffèrent en dimension cachée, ratios MLP, tokenizer (SentencePiece Gemma vs BPE Qwen), et template de prompt (`<start_of_turn>` vs `<|im_start|>`). Toute tentative de chargement échouera (`size mismatch` côté llama.cpp) ou produira du gibberish.

Il faut **refinetuner from scratch** sur Gemma 4.

## 2. Choix base model

| Cible | Params actifs | Params totaux | VRAM training QLoRA r=16 | VRAM inférence Q4_K_M | Verdict |
|-------|---------------|---------------|---------------------------|------------------------|---------|
| **gemma4:e4b** | 4 B | 4 B | ~10–12 GB | 2.5 GB | **Recommandé pour 1ère itération** : VRAM atteignable sur RTX 3060 12GB / 4070, mode SINGLE par défaut du jeu. |
| **gemma4:26b-a4b** | 4 B (MoE) | 26 B | ~24–28 GB | 14 GB | Meilleure qualité narration, mais nécessite 4090 24GB (juste) ou A100 40GB. Mode SINGLE_PLUS/DUAL. |
| gemma4:31b dense | 31 B | 31 B | ~70 GB | 18 GB | Hors scope local. Cloud only (A100×2). |

**Décision pending utilisateur** : entraîner d'abord sur E4B (rapide, dégage tout le pipeline) puis 26B-A4B si le résultat sur E4B est convaincant ?

## 3. Dataset

Source existante : `data/ai/training/merlin_narrator_augmented.json`

- Format actuel : **ChatML** (samples avec `conversations: [{role: system|user|assistant, content: ...}]`)
- Nombre de samples : **2001** (vérifié)
- Champ lexical : système narrateur Merlin (5 factions, 18 oghams, 8 champs lexicaux)

**Migration template requise** : le script de training doit convertir ChatML → Gemma au moment du formatage. Le système prompt Gemma est fold dans le 1er tour user (Gemma 4 ne supporte pas de rôle `system` séparé).

```python
# Avant (Qwen ChatML) :
text = (
    f"<|im_start|>system\n{system}<|im_end|>\n"
    f"<|im_start|>user\n{user}<|im_end|>\n"
    f"<|im_start|>assistant\n{assistant}<|im_end|>"
)

# Après (Gemma 4) :
text = (
    f"<bos><start_of_turn>user\n"
    f"{system}\n\n{user}<end_of_turn>\n"
    f"<start_of_turn>model\n{assistant}<end_of_turn>"
)
```

Le `<bos>` est ajouté automatiquement par le tokenizer si `add_special_tokens=True`. Vérifier après tokenization.

## 4. Hyperparamètres LoRA pour Gemma 4

Les modules cibles Gemma sont nommés comme Llama (pas Qwen-spécifique), donc la liste reste identique. **Exception** : sur les blocs MoE de `26b-a4b`, il faut décider si on entraîne les experts ou seulement le router. Default : router + couches non-MoE uniquement (plus stable, moins de VRAM).

```python
GEMMA4_LORA_CONFIG = {
    "lora_r": 16,            # 32 si overfit pas un risque (dataset 2k = petit)
    "lora_alpha": 32,        # = 2 * r (convention)
    "lora_dropout": 0.05,
    "bias": "none",
    "task_type": "CAUSAL_LM",

    # Identique à Qwen 3.5 — Gemma 4 expose les mêmes noms
    "target_modules": [
        "q_proj", "k_proj", "v_proj", "o_proj",
        "gate_proj", "up_proj", "down_proj",
    ],

    # Pour Gemma 4 26B-A4B (MoE) — option "experts" qui DOUBLE le compte
    # de paramètres trainables. À activer uniquement si dataset > 10k samples.
    "target_modules_moe_experts": False,
}
```

### Training hyperparams (point de départ)

```python
TRAINING_HPS = {
    "num_epochs": 3,                       # 2001 samples × 3 = 6003 steps avec batch=4
    "per_device_batch_size": 4,            # E4B QLoRA tient à 4 sur 12GB
    "gradient_accumulation_steps": 4,      # batch effectif = 16
    "learning_rate": 2e-4,                 # standard QLoRA
    "weight_decay": 0.01,
    "warmup_ratio": 0.03,                  # ~60 steps de warmup
    "lr_scheduler_type": "cosine",
    "fp16": True,                          # bf16 si A100/4090
    "optim": "adamw_8bit",                 # bitsandbytes
    "max_seq_length": 1024,                # narration Merlin peut dépasser 512
    "save_steps": 100,
    "logging_steps": 10,
    "seed": 42,
}
```

Pour le **26B-A4B** : diviser `per_device_batch_size` par 2 (à 2), passer `gradient_accumulation_steps` à 8 → batch effectif inchangé à 16.

## 5. Estimations temps / coût

| Hardware | Modèle | Time / epoch | Total 3 epochs | Coût indicatif |
|----------|--------|--------------|----------------|----------------|
| RTX 4070 12GB local | E4B | ~25 min | ~75 min | 0 € (électricité) |
| RTX 4090 24GB local | E4B | ~12 min | ~40 min | 0 € |
| RTX 4090 24GB local | 26B-A4B | ~70 min | ~3h30 | 0 € |
| Colab Pro A100 40GB | E4B | ~10 min | ~30 min | ~0.50 € |
| Colab Pro A100 40GB | 26B-A4B | ~30 min | ~1h30 | ~2 € |
| Lambda Labs A100 80GB | 26B-A4B | ~25 min | ~1h15 | ~2 USD |
| Kaggle T4×2 (free) | E4B | ~45 min | ~2h15 | 0 € (quota 30h/sem) |

Hardware utilisateur connu (cf `tools/cli.py ollama` profile detection) : à confirmer côté Maxime.

## 6. Commande exacte (point d'entrée)

### 6.1 Préparer l'environnement

```bash
# Local Linux/WSL ou Colab
pip install --upgrade transformers==4.45.0 peft==0.13.0 trl==0.11.0 \
                       accelerate==0.34.0 bitsandbytes==0.44.0 \
                       datasets==3.0.0 sentencepiece==0.2.0
# Optionnel mais 2× plus rapide :
pip install unsloth  # https://github.com/unslothai/unsloth
```

### 6.2 Adapter le script existant

`tools/lora/train_narrator_lora.py` doit être dupliqué en `tools/lora/train_narrator_lora_gemma4.py` avec ces changements :

1. **Constante** : `"base_model": "google/gemma-4-e4b-it"` (HuggingFace ID — confirmer le slug exact via `huggingface-cli search gemma-4`).
2. **Fonction `load_dataset`** : remplacer le bloc de formatage ChatML par le format Gemma (cf §3 ci-dessus).
3. **Tokenizer** : `AutoTokenizer.from_pretrained(...)` détecte Gemma automatiquement. Vérifier `tokenizer.chat_template` ≠ None.
4. **Modules cibles** : déjà compatibles (voir §4).
5. **Output dir** : `output/merlin_narrator_lora_gemma4/`

### 6.3 Lancement (dry-run d'abord)

```bash
cd C:\Users\PGNK2128\Godot-MCP

# Dry-run : vérifier que le dataset se charge et se formate sans erreur
python tools/lora/train_narrator_lora_gemma4.py --dry-run

# Run réel (E4B, défaut)
python tools/lora/train_narrator_lora_gemma4.py \
    --dataset data/ai/training/merlin_narrator_augmented.json \
    --output output/merlin_narrator_lora_gemma4 \
    --epochs 3 \
    --rank 16 \
    --lr 2e-4

# Variante 26B-A4B (nécessite GPU 24GB+)
python tools/lora/train_narrator_lora_gemma4.py \
    --base-model "google/gemma-4-26b-a4b-it" \
    --output output/merlin_narrator_lora_gemma4_26b \
    --epochs 3 \
    --rank 16 \
    --lr 1e-4  # LR plus bas pour MoE
```

## 7. Post-training → GGUF

Une fois l'adapter PEFT entraîné, il faut le convertir pour Ollama / llama.cpp.

### Option A — Merge + quantize (recommandé pour distribution)

```bash
# 1. Merge LoRA dans le base model (HF format)
python tools/lora/merge_lora.py \
    --base "google/gemma-4-e4b-it" \
    --lora output/merlin_narrator_lora_gemma4 \
    --out  output/merlin_narrator_merged_gemma4

# 2. Convert HF → GGUF f16
python llama.cpp/convert_hf_to_gguf.py \
    output/merlin_narrator_merged_gemma4 \
    --outfile addons/merlin_llm/models/merlin_narrator_gemma4_f16.gguf

# 3. Quantize f16 → Q4_K_M
./llama.cpp/build/bin/llama-quantize \
    addons/merlin_llm/models/merlin_narrator_gemma4_f16.gguf \
    addons/merlin_llm/models/merlin_narrator_gemma4_q4_k_m.gguf \
    Q4_K_M
```

### Option B — Adapter only (.gguf-lora, modulaire)

```bash
# Garde le base GGUF non modifié + applique l'adapter au runtime
python llama.cpp/convert_lora_to_gguf.py \
    output/merlin_narrator_lora_gemma4 \
    --outfile addons/merlin_llm/models/merlin_narrator_lora_gemma4.gguf
```

Puis côté Ollama, créer un Modelfile dérivé :

```Modelfile
FROM gemma4:e4b
ADAPTER ./merlin_narrator_lora_gemma4.gguf
TEMPLATE """<bos><start_of_turn>user
{{ if .System }}{{ .System }}

{{ end }}{{ .Prompt }}<end_of_turn>
<start_of_turn>model
{{ .Response }}<end_of_turn>"""
SYSTEM """Tu es Merlin, narrateur celtique. Réponds en JSON strict pour la pipeline MERLIN."""
PARAMETER temperature 0.7
PARAMETER num_ctx 8192
```

## 8. Critères d'évaluation (smoke test post-training)

1. **Parsing JSON** : sur 50 prompts MERLIN générés par `tools/lora/benchmark_lora.py`, le LoRA doit produire JSON valide ≥ 95 % (vs base Gemma 4 typiquement 80–85 %).
2. **Champ lexical** : ratio de verbes appartenant au champ demandé ≥ 70 % (mesure existante).
3. **Faction alignment** : effets `ADD_REPUTATION` cohérents avec la faction sollicitée ≥ 85 %.
4. **Token throughput** : ne pas régresser de plus de 10 % vs base Gemma 4 E4B (le LoRA n'ajoute que ~0.1 % de params, l'overhead doit être négligeable).
5. **No-ChatML-leak** : aucune occurrence de `<|im_start|>`, `<|im_end|>` dans 100 générations.

`tools/lora/benchmark_lora.py` (existant, 25 KB) couvre déjà ces métriques côté Qwen — il faut l'adapter au template Gemma (1 ligne à changer dans `format_prompt()`).

## 9. Risques / TODO ouverts

| Risque | Mitigation |
|--------|------------|
| Slug HF `google/gemma-4-e4b-it` pas encore publié | Confirmer dispo via `huggingface-cli search gemma-4` avant lancement. Fallback : training sur `google/gemma-4-e4b-pt` (pretrain) + chat template manuel. |
| Tokenizer Gemma 4 ne couvre pas les 18 noms Ogham celtique | Vérifier `tokenizer.tokenize("ᚁ ᚂ ᚃ Beith Luis Fearn")` — si chaque rune devient un token UNK, c'est utilisable. Sinon ajouter tokens spéciaux (impact gros sur taille adapter). |
| LoRA 26B-A4B + experts trainables OOM 24GB | Désactiver `target_modules_moe_experts` (défaut), n'entraîner que router + non-MoE layers. |
| `unsloth` ne support pas encore Gemma 4 (récent) | Fallback PEFT vanilla (script existant gère déjà la branche `_train_peft`). |
| Dataset 2001 samples = petit pour 26B | Augmenter via `tools/lora/augment_dataset_v5.py` à 5000+ avant le run 26B. |
| `convert_lora_to_gguf.py` n'existe pas dans toutes les builds llama.cpp | Vérifier branche `master` ou utiliser merge+quantize (Option A) qui est plus portable. |

## 10. Pré-requis avant lancement

1. **Disque** : 60 GB libres minimum (HF cache 20 GB + checkpoints intermédiaires 20 GB + GGUF f16 16 GB). Actuellement C: à ~60 MB libres → **bloquant**.
2. **GPU** : 12 GB VRAM (E4B) ou 24 GB (26B-A4B).
3. **Choix utilisateur** : E4B vs 26B-A4B en première itération.
4. **Validation slug HF** : `huggingface-cli login` + confirmer accès aux poids Gemma 4 (gated repo Google).

**Action humaine attendue** :
- [ ] Libérer disque ou pointer training vers drive externe.
- [ ] Décider E4B (rapide) ou 26B-A4B (qualité).
- [ ] Confirmer GPU dispo (4070 12GB ? 4090 ? Colab Pro ? Lambda ?).
- [ ] Approuver lancement → l'agent peut alors créer `tools/lora/train_narrator_lora_gemma4.py` et déclencher le dry-run.

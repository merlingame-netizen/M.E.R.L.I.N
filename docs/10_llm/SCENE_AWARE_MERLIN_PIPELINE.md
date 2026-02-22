# Scene-Aware Merlin Pipeline

## Goal
Ensure Merlin only says context-relevant content for the active scene, with stable tone and no off-scene hallucinations.

## Runtime Architecture
1. Scene scripts set a profile through `MerlinAI.set_scene_context(scene_id, overrides)`.
2. `MerlinAI` merges `data/ai/config/scene_profiles.json` (`default` + scene profile + channel overrides).
3. The merged contract is injected into system prompts (`narrative`, `voice`, `structured`, `prefetch`, `background`).
4. `RAGManager` stores scene context and includes a `SceneContract` section at `CRITICAL` priority.
5. `MerlinOmniscient` pulls live scene context from `MerlinAI`, propagates it to MOS prompts and RAG sync.

## Scene Profiles
File: `data/ai/config/scene_profiles.json`

Current profiles:
- `scene_rencontre_merlin_intro`
- `scene_rencontre_merlin_bestiole`
- `scene_rencontre_merlin_mission`
- `transition_biome_arrival`
- `transition_biome_merlin`

Each profile can define:
- `intent`, `tone_target`
- `allowed_topics`, `forbidden_topics`, `must_reference`
- `response_limits`
- `channels` overrides per generation type

## Connected Scenes
- `scripts/SceneRencontreMerlin.gd`
  - Sets phase-specific context on phase switch.
  - Clears context on scene exit.
- `scripts/TransitionBiome.gd`
  - Sets dedicated contexts for arrival narration and Merlin comment.
  - Clears context on scene exit.

## LoRA Dataset Integration
- `tools/lora/export_training_data.py`
  - `--scene-aware` exports `merlin_narrator_dataset_scene_aware.json`.
  - Injects scene contracts into system prompts and attaches scene metadata.
- `tools/lora/augment_dataset.py`
  - `--scene-aware` reads scene-aware dataset and adds scene-contrast samples.
  - Exports `merlin_narrator_augmented_scene_aware.json`.

## Recommended Evaluation
1. Relevance: no references outside active scene contract.
2. Precision: mandatory elements are present (`must_reference`).
3. Safety: forbidden topics are absent.
4. Form: response limits respected (sentences/words/style).
5. Stability: repeated runs keep scene coherence under varied player inputs.

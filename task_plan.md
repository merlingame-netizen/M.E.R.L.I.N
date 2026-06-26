# Task Plan — MERLIN Game Development

> **Source**: `docs/BIBLE.md` v2.0 (canon unique — roadmap §19 ; l'ancien `DEV_PLAN_V2.5.md` est archivé dans `docs/archive/`).
> **Consumed by**: `tools/octogent/prompts/studio-director.md` Tier 1 backlog.
> **Last refresh**: 2026-06-21 (Goal : intégration IA-GEN 2D anim + contrôle IA).

## GOAL 2026-06-21 — Intégration projets IA/anim + pratiques

### Context
User /goal : « Déploie tous les projets IA GEN 2D animation + contrôle IA nécessaires, OU inspire-toi
de pratiques qui apportent du +. Déploie et intègre dans les branches de dev et nos pratiques/skills. »
Décisions verrouillées (3 rounds AskUserQuestion) :
- **Sens 2D** = les DEUX (motion/tween fiabilisé + génération IA de sprites animés).
- **LLM** = durcir le natif `merlin_llm` (inspiré NobodyWho), ZÉRO 2e moteur.
- **Motion** = helper managed-tween (inspiré KoBeWi TweenNode) + plan perf + 48 recettes TweenFX adaptées DA.
- **Branches** = une par track + MAJ skills/KB/BIBLE.

Recherche live (gh indispo → WebSearch) : NobodyWho 1009★ (GBNF/sampler ref), KoBeWi Tween-Suite 129★
(TweenNode lifecycle), TweenFX 175★ (48 recettes juicy). Audit perf déjà réalisé (6 findings).

### Tracks
| Track | Contenu | Branche | Gate |
|-------|---------|---------|------|
| **M — Motion** | `MerlinTween` managed-tween (auto-kill) + banque recettes DA + plan perf (throttle scene-art 15fps, reuse combo, glow/sway 12fps, pop_in motion()) | `feat/motion-juice` | validate + smoke 6 + soak (flow inchangé → smoke suffit) |
| **L — LLM** | `MerlinGrammar` (load+cache+valide GBNF) + `generate_structured()` (enforce+parse+valide+retry N=2-3) additif | `feat/llm-hardening` | validate + smoke Game/GemmaConsole + **soak R109** |
| **S — Sprite-gen** | `sprite_anim_forge.py` (sprite-sheets animés procédural + SD img2img opt, sépia identity) + wiring cli/adapter/validator | `feat/sprite-anim-forge` | python run + asset_validator + import Godot |
| **P — Practices** | MAJ merlin-juice/merlin-artwork SKILL + gdscript_knowledge_base.md + BIBLE §21/§24 (R-suivant) | par track | relecture cohérence |

### Workflow
1. Design+review multi-agents (wf_5d940f70) → specs file-level validés adversarialement.
2. Implémentation track par track sur branche dédiée, gate à chaque commit.
3. Review finale (workflow adversarial) + push + learn-eval + mémoire.

### Garde-fous
- DA : zéro hex hors merlin_visual.gd ; durées via MerlinVisual.DUR_* + motion().
- R109 : Track L additif (nouvelle fonction, ne modifie pas generate()) → soak 200/200 obligatoire.
- YAGNI : Track S = le plus spéculatif ; réduire au MVP utile (shimmer carte + frames VFX) si le review le flag.
- État pré-existant : `.claude/agents/*.md` déjà modifiés (hors-scope) → ne JAMAIS stager ces fichiers.

# docs/ — Carte d'autorité (R114, 2026-06-12)

> **CANON UNIQUE = [`BIBLE.md`](BIBLE.md) v2.0** (R1-R119 + roadmap §19 + DA/Juice/Audio/Lisibilité/Pipeline §20-§24).
> Tout document contredisant BIBLE.md est non-autoritaire, quelle que soit sa date.
> L'ancien index (v4.0, 2026-02-09, système « Triade/Bestiole ») décrivait un jeu **deux resets
> en arrière** — il est remplacé par cette carte ; le détail reste dans l'historique git.

| Zone | Autorité | Note |
|---|---|---|
| `BIBLE.md` | ✅ **CANON** | Source de vérité unique (reconstruction 2026-05-25, MVP gelé R1-R113, v2.0 §19-§24) |
| `archive/` | ❌ Legacy | `GAME_DESIGN_BIBLE_legacy_v3.8.md`, `DEV_PLAN_V2.5_legacy.md` — anciens jeux |
| `00_overview/`, `10_llm/`, `20_card_system/`, `30_jdr/`, `30_scenes/`, `40_*/`, `50_lore/`, `60_companion/`, `70_graphic/`, `80_sound/`, `root/`, `old/` | ⚠️ **Pré-reset (2026-05-25) — non-autoritaire par défaut** | Corpus des anciens jeux (Triade/Bestiole, puis factions/Oghams/MOS). **Matériau d'inspiration UNIQUEMENT** — le lore celtique (50_lore) et les guides musique (80_sound) restent de bonnes mines d'idées, mais ne JAMAIS les citer comme spec. |
| `audits/`, `decisions/`, `balance/` | ⚠️ Historique | Journaux datés — contexte, pas spec |
| `MASTER_DOCUMENT.md`, `GAME_ENCYCLOPEDIA.md`, `GAME_MECHANICS.md`, `LLM_ARCHITECTURE.md`, `DESIGN_STATUS.md` | ❌ Legacy | Supersédés par BIBLE.md |

## Règle pour agents/sessions

1. Lire `BIBLE.md` d'abord (CLAUDE.md règle 10.1 — bible-first ritual).
2. Si un document pré-reset semble utile, **vérifier chaque affirmation contre BIBLE.md** avant usage.
3. Toute nouvelle spec s'écrit DANS `BIBLE.md` (règle R-numérotée, section §) — jamais dans un
   nouveau fichier satellite sans pointeur depuis la bible.

## Outillage studio (BIBLE §24)

- `.claude/skills/merlin-juice/` — vocabulaire d'animation + helpers MerlinFx
- `.claude/skills/merlin-audio/` — SFX procéduraux + MusicGen + catalogue §22
- `.claude/skills/merlin-artwork/` — artworks gravure sépia par situation + cache
- `tools/create_agent.py` — factory d'agents + validation du parc

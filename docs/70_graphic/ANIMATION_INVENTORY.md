# ANIMATION INVENTORY — M.E.R.L.I.N.: Le Jeu des Oghams

> Motion Designer Agent — Inventaire complet, analyse de coherence, plan Bestiole
> Date: 2026-02-08

---

## TABLE DES MATIERES

1. [Inventaire par fichier](#1-inventaire-par-fichier)
2. [Inventaire par type](#2-inventaire-par-type)
3. [Shaders animes](#3-shaders-animes)
4. [Analyse de coherence](#4-analyse-de-coherence)
5. [Animations manquantes](#5-animations-manquantes)
6. [Plan animations Bestiole](#6-plan-animations-bestiole)
7. [Recommandations d'harmonisation](#7-recommandations-dharmonisation)

---

## 1. INVENTAIRE PAR FICHIER

### 1.1 IntroBoot.gd (Scene d'intro CRT)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 172-410 | `_process` state machine | position, alpha, scale, color | Varies | Custom cubic/expo | 5 phases: POWER_ON, BOOT_SEQUENCE, ORB_TRANSFORM, ORB_POSITION, TRANSITION |
| 286-300 | `_process` continuous | scanline_offset, flicker, rolling_band, chroma, grain | Per-frame | lerp / sin | Retro CRT effects (scanlines, flicker, chroma aberration, grain) |
| 307-310 | `_process` phase | power_on_progress | POWER_ON_DURATION | linear | Power-on progress 0->1 |
| 323-354 | `_process` phase | content_alpha, static_intensity, loading_progress | BOOT_DURATION | ease_out_cubic / ease_out_expo | Boot sequence (log reveal, loading bar) |
| 356-374 | `_process` phase | orb_size, orb_position | ORB_TRANSFORM_DURATION | ease_in_out_cubic | Loading bar transforms into celestial orb |
| 377-403 | `_process` phase | orb_current_pos, orb_size | ORB_POSITION_DURATION | ease_in_out_cubic (Bezier) | Orb moves to clock position via quadratic Bezier arc |
| 405-409 | `_process` phase | transition_alpha | TRANSITION_DURATION | linear | Final fade to menu |
| 837+ | shader | static_intensity | per-frame | direct | CRT static shader parameter update |

**Total animations: 7 process-based + 1 shader**

---

### 1.2 IntroCeltOS.gd (CeltOS Boot Intro)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 138-150 | tween | boot_labels modulate:a | 0.08s per label | none | Phase 1: Boot text fade-in stagger |
| 145-146 | tween | label modulate:a, font_color | 0.1s | none | Final labels glow accent |
| 148-150 | tween | boot_container modulate:a | 0.4s | none | Phase 1 fade-out |
| 194-219 | tween | logo modulate:a, blocks position:y | 0.2s, 0.25s | TRANS_BOUNCE + EASE_OUT | Phase 2: Logo reveal + pixel blocks fall |
| 213-216 | tween | block color | 0.15s, 0.2s | none | Block color pulse accent -> cyan |
| 245-262 | tween | block position, size, color | 0.7s, 0.5s | TRANS_SINE + EASE_IN_OUT | Phase 3a: Blocks converge to center |
| 292-324 | tween | pixel position, color:a, block color | 0.35s, 0.1-0.15s | TRANS_SINE + EASE_OUT | Phase 3b: Pixel spawn + eye formation |
| 334-344 | tween | logo/pixel modulate:a, glow_intensity | 0.6s | none | Phase 3c: Transition to smooth |
| 349-367 | tween | eye slit (custom method), glow | 0.8s, 0.5s | TRANS_CUBIC + EASE_IN_OUT / TRANS_SINE + EASE_IN | Phase 3d: Eye opens |
| 372-390 | tween | glow_intensity, white_overlay | 0.12s, 0.08s, 0.15s | TRANS_EXPO + EASE_IN | Phase 3e: Flash to white |
| 538-540 | tween (looped) | glow_intensity | 0.5s + 0.5s | none | Pulse waiting for LLM warmup |

**Total animations: 11 tween chains**

---

### 1.3 IntroMerlinDialogue.gd (Questionnaire + Dialogue)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 689-694 | tween | portrait modulate:a | 0.15s x 2 | none | Portrait expression crossfade |
| 724-725 | tween | portrait modulate | 0.25s | none | Portrait mood tint |
| 743-745 | tween | portrait scale | 0.2s x 2 | none | Portrait pulse (talk) |
| 749-752 | tween | portrait position | 0.05s x 3 | none | Portrait shake (anger/surprise) |
| 755-757 | tween | portrait scale | 0.1s x 2 | none | Portrait bounce (squash & stretch) |
| 778-791 | typewriter | visible_characters | 0.03s/char | timer-based | Text reveal character by character |
| 1050-1051 | tween | class_overlay modulate:a | 0.4s | none | Class selection overlay appear |
| 1105-1110 | tween | card_root position, rotation, modulate:a | 0.35s | TRANS_QUAD + EASE_OUT | Card snap back to home |
| 1114-1131 | tween | card_root position, scale, rotation, modulate:a | 0.05-0.26s | none | Card exit animation (4 variants: up, squish, slide, fade) |
| 1222-1224 | tween | self modulate:a | 0.8s | none | Final scene fade-out |

**Total animations: 10 tweens + 1 typewriter**

---

### 1.4 IntroPersonalityQuiz.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 422-423 | tween | skip_modal modulate:a | 0.2s | none | Skip modal appear |
| 428-430 | tween | skip_modal modulate:a | 0.15s | none | Skip modal dismiss |
| 437-439 | tween | self modulate:a | 0.5s | none | Skip transition fade-out |
| 496-515 | tween | question_label modulate:a, progress_label modulate:a, btn modulate:a | TEXT_FADE_DURATION, 0.3s | none | Question entry animation with stagger |
| 543-547 | tween | btn scale | 0.1s x 2 | TRANS_QUAD + EASE_OUT | Button select pulse |
| 577-586 | tween | question_label, progress_label, btn modulate:a | 0.4s, 0.3s | none | Question exit fade |
| 625-663 | tween | question_label modulate:a | TEXT_FADE_DURATION, 0.5s | none | Final results sequence (3 text reveals + pauses) |
| 731-733 | tween | self modulate:a | FADE_DURATION | none | Scene transition fade |

**Total animations: 8 tweens**

---

### 1.5 MenuPrincipalMerlin.gd (Main Menu) *(was MenuPrincipalMerlin.gd)*

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 326-328 | tween (looped) | mist_layer modulate:a | 8.0s + 8.0s | TRANS_SINE | Mist breathing (0.08 <-> 0.25) |
| 670-681 | tween | celtic_ornaments modulate:a, card position:y, card modulate:a | 0.8s, 0.7s, 0.5s | TRANS_SINE / TRANS_SINE + EASE_OUT | Scene entry orchestration |
| 688-690 | tween | btn modulate:a | 0.3s | TRANS_SINE + EASE_OUT | Button entry stagger (delay-based) |
| 708-712 | tween | btn scale | 0.15s / 0.1s | TRANS_SINE + EASE_OUT | Button hover (1.02) / unhover (1.0) |
| 718-724 | tween | btn scale | 0.2s + 0.15s | TRANS_SINE + EASE_OUT | Button press feedback (1.15 -> 1.0) |
| 815-818 | tween | card rotation, position, modulate:a | 0.25s, 0.2s | TRANS_SINE + EASE_IN | Card swipe exit animation |
| 880-881 | tween | time_tint_layer color | 2.0s | TRANS_SINE + EASE_IN_OUT | Time-of-day tint transition |
| 909-962 | `_process` custom | particle position.y, position.x, rotation | per-frame | sin wave / delta | Seasonal falling particles (snow/leaves/petals) with accumulation |
| 1091-1116 | tween | particle position, modulate:a | 0.3-0.6s, 0.4-0.8s | TRANS_QUAD + EASE_OUT | Accumulation burst particles on click |
| 1166-1175 | `_process` custom | sun ray color.a | per-frame | sin wave | Summer sun rays pulsing opacity |

**Total animations: 8 tweens + 2 process-based + 1 particle system**

---

### 1.6 SceneEveil.gd (Awakening Scene)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 400-417 | tween | celtic ornaments modulate:a, card position:y, card modulate:a, mist_layer modulate:a | 0.8s, 0.7s, 0.5s, 8.0s loop | TRANS_SINE / TRANS_SINE + EASE_OUT | Scene entry + mist breathing |
| 458-459 | tween | merlin_text modulate:a | 0.4s | none | Text fade between dialogue lines |
| 506-520 | typewriter | visible_characters | delay/char | timer-based | Manual typewriter text reveal |
| 582-589 | tween | card, celtic ornaments, mist modulate:a | 0.6s, 0.4s, 0.8s | TRANS_SINE + EASE_IN_OUT | Scene exit orchestration |

**Total animations: 3 tweens + 1 typewriter + 1 mist loop**

---

### 1.7 SceneAntreMerlin.gd (Merlin's Den)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 612-626 | tween | celtic ornaments modulate:a, card position:y/modulate:a, mist loop | 0.8s, 0.7s, 0.5s, 8.0s loop | TRANS_SINE / TRANS_SINE + EASE_OUT | Scene entry + mist breathing |
| 665-666 | tween | bestiole_label modulate:a | 1.5s | TRANS_SINE | Bestiole name glow (fade in) |
| 674-675 | tween | merlin_text modulate:a | 0.3s | none | Text fade |
| 680-681 | tween | bestiole_label modulate:a | 0.4s | none | Hide bestiole glow |
| 724-725 | tween | merlin_text modulate:a | 0.3s | none | Text fade |
| 745-754 | tween | ogham_panel modulate:a, child modulate flash | 0.8s, 0.15s+0.3s | TRANS_BACK + EASE_OUT | Ogham panel reveal + flash per item |
| 762-763 | tween | ogham_panel modulate:a | 0.4s | none | Ogham panel hide |
| 808-809 | tween | merlin_text modulate:a | 0.3s | none | Text fade |
| 839-840 | tween | merlin_text modulate:a | 0.3s | none | Text fade |
| 852-864 | tween + loop | biome_panel modulate:a, suggested_btn modulate pulse | 0.6s, 1.0s loop | TRANS_SINE | Biome panel appear + suggested button pulse |
| 897-898 | tween | merlin_text modulate:a | 0.3s | none | Text fade |
| 936-944 | tween | card, ornaments, biome, mist modulate:a | 0.6s, 0.4s, 0.8s | TRANS_SINE + EASE_IN_OUT | Scene exit orchestration |
| 986-998 | typewriter | visible_characters | delay/char | timer-based | Typewriter text reveal |

**Total animations: 12 tweens + 1 typewriter + 1 mist loop + 1 pulse loop**

---

### 1.8 TransitionBiome.gd (Biome Transition)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 174-193 | GPUParticles2D | mist particles | lifetime 4.0s | GPU material | 30 particles, directional emission, auto-start |
| 276-279 | tween | biome_title modulate:a, biome_subtitle modulate:a | 0.8s, 0.6s | TRANS_QUAD + EASE_OUT | Title + subtitle appear |
| 284-310 | typewriter | visible_characters | 0.03s/char | timer-based | 2 typewriter sequences (arrival + Merlin comment) |
| 319-328 | tween | bg color, all labels modulate:a, self modulate:a | 0.8s, 0.6s, 0.5s | TRANS_QUAD + EASE_IN_OUT | Scene exit fade orchestration |

**Total animations: 2 tweens + 2 typewriters + 1 GPU particle system**

---

### 1.9 Calendar.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 769-774 | tween | celtic ornaments modulate:a, main_card modulate:a/position:y, back_button modulate:a | 0.5s, 0.4s, 0.3s | TRANS_SINE / EASE_OUT | Scene entry animation |
| 778-780 | tween | main_card modulate:a | 0.2s | none | Exit fade -> scene change |

**Total animations: 2 tweens**

---

### 1.10 Collection.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 601-605 | tween (looped) | mist_layer modulate:a | 4.0s + 4.0s | TRANS_SINE | Mist breathing (0.6 <-> 1.0) |

**Total animations: 1 tween loop**

---

### 1.11 main_game.gd (Legacy Game UI)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 84-99 | tween | logo modulate:a, presents modulate:a | 0.8s, 0.5s, 1.5s pause | EASE_IN_OUT + TRANS_SINE | Studio splash fade in/out |
| 114-115 | tween | transition_overlay modulate:a | 0.3s | none | Transition overlay appear |
| 153-154 | tween | transition_overlay modulate:a | 0.3s | none | Transition overlay disappear |
| 226-228 | tween (looped) | type_label position:y | 0.5s x 2 | EASE_IN_OUT | Type indicator float (-5 -> 0) |
| 681-683 | tween (looped) | bestiole_icon position:y | 0.5s x 2 | none (linear) | **Bestiole icon float** |
| 785-791 | tween | flash modulate:a | 0.2s + 0.3s | none | Screen flash (white) |
| 1020-1030 | tween | typewriter callbacks | 0.1s intervals | none | Type log entries |
| 1250-1252 | tween (looped) | btn scale | 0.5s x 2 | none | Button pulse (1.05) |
| 1435-1437 | tween (looped) | cursor modulate:a | 0.5s x 2 | none | Cursor blink |
| 1468-1473 | Timer | type_timer (0.03s) | 0.03s/tick | none | Typewriter Timer-based |

**Total animations: 8 tweens (4 looped) + 1 Timer**

---

### 1.12 MerlinPortraitManager.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 127-128 | tween | frame_node color | 0.3s | none | Frame color change by emotion |
| 139-141 | tween | node modulate:a | 0.2s | none | Portrait expression crossfade |
| 157-159 | tween | particles_layer modulate:a | 0.2s + 0.3s | none | Particle flash for emphasis |
| 168-171 | tween | node position | 0.05s x 3 | none | Shake effect (x: +/-2px) |
| 178-180 | tween | node scale | 0.1s x 2 | none | Squash bounce |
| 187-189 | tween | node modulate | 0.3s + 0.5s | none | Sad tint (blueish then restore) |

**Total animations: 6 tweens**

---

### 1.13 SelectionSauvegarde.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 148-152 | tween | msg modulate:a | 0.2s + 1.2s pause + 0.2s | none | Toast notification fade in -> wait -> fade out |

**Total animations: 1 tween**

---

### 1.14 TestLLMSceneUltimate.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 547-550 | tween | merlin_portrait modulate:a | 0.1s + 0.2s | none | Portrait emotion crossfade |
| 1295-1296 | tween | btn modulate:a | 0.2s (staggered 0.1s) | none | Button entry stagger |
| 1312-1314 | tween | btn modulate | 0.15s x 2 | none | Button press flash |
| 1320-1325 | tween | loading_panel modulate:a | 0.2s | none | Loading panel show/hide |

**Total animations: 4 tweens**

---

### 1.15 ScreenEffects.gd (Autoload)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 395-408 | tween | shader params (multiple) | varies per mood | EASE_IN_OUT + TRANS_SINE | Mood transition (interpolates all shader params) |
| 455-459 | tween (parallel) | glitch, chromatic, barrel params | 0.3s | none | Glitch burst restore |
| 498-503 | tween | global_intensity | varies | EASE_OUT + TRANS_QUAD | Shader intensity fade |

**Total animations: 3 tweens (all shader-based)**

---

### 1.16 ui/reigns_game_ui.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 84-97 | `_process` | gauge lerp, card position, rotation | per-frame | lerp (delta * speed) | Continuous gauge animation + card rubber-band return |
| 367-369 | tween | card_panel position:x | 0.2s | none | Card swipe resolve |

**Total animations: 1 process-based + 1 tween**

---

### 1.17 ui/triade_game_ui.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 361-364 | tween (2 loops) | icon modulate:a | 0.3s x 2 | none | Aspect extreme state pulse |
| 468-470 | tween | btn modulate | 0.1s x 2 | none | Option button flash (1.5 brightness) |

**Total animations: 2 tweens**

---

### 1.18 ui/menu_return_button.gd

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 92-96 | tween | self scale | 0.1s x 2 | TRANS_QUAD + EASE_OUT | Hover scale pulse |
| 125-127 | tween | current_scene modulate:a | 0.2s | TRANS_QUAD + EASE_IN | Return-to-menu fade |

**Total animations: 2 tweens**

---

### 1.19 merlin_house_animations.gd (3D Menu Scene)

| Ligne | Type | Propriete | Duree | Easing | Description |
|-------|------|-----------|-------|--------|-------------|
| 124-138 | `_process` | fire_light energy, color | per-frame | multi-sine composite | Fire flickering (4 sine layers) |
| 140-153 | `_process` | candle_lights energy | per-frame | multi-sine | Candle flickering (3 sine layers per candle) |
| 155-179 | `_process` | rune position (float), rotation | per-frame | sin/cos | Floating runes orbit + individual float |
| 181-190 | `_process` | cauldron_light energy, liquid scale | per-frame | sin | Cauldron glow pulse + bubble effect |
| 192-198 | `_process` | crystal_light energy | per-frame | sin | Crystal pulse (min <-> max) |
| 200-213 | `_process` | skull_light energy, eye emission | per-frame | sin | Skull eerie pulse + eye glow |
| 215-219 | `_process` | globe rotation | per-frame | linear + sin | Globe slow rotation |

**Total animations: 7 process-based (all continuous ambient)**

---

## 2. INVENTAIRE PAR TYPE

### 2.1 Tweens (total: ~75)

| Categorie | Nombre | Scenes |
|-----------|--------|--------|
| Fade in/out (modulate:a) | ~40 | Toutes |
| Position / slide | ~12 | IntroCeltOS, IntroMerlinDialogue, Menu, SceneAntre |
| Scale / pulse | ~8 | IntroMerlinDialogue, Menu, main_game, triade_ui |
| Color / tint | ~6 | IntroCeltOS, MerlinPortrait, ScreenEffects, Menu |
| Rotation | ~3 | IntroMerlinDialogue, Menu (card swipe) |
| Shader params | ~6 | ScreenEffects |

### 2.2 Process-based (total: ~12)

| Categorie | Nombre | Scenes |
|-----------|--------|--------|
| State machine | 1 | IntroBoot (5 phases) |
| Continuous ambient | 7 | merlin_house_animations (fire, candles, runes, etc.) |
| Particle systems | 2 | MenuPrincipalMerlin (seasonal + sun rays) |
| Gauge/card lerp | 1 | reigns_game_ui |
| CRT retro effects | 1 | IntroBoot |

### 2.3 Typewriter (total: 5)

| Scene | Methode | Vitesse |
|-------|---------|---------|
| IntroMerlinDialogue | visible_characters + timer 0.03s | ~33 char/s |
| SceneEveil | visible_characters + timer (delay/char) | variable |
| SceneAntreMerlin | visible_characters + timer (delay/char) | variable |
| TransitionBiome | visible_characters + timer 0.03s | ~33 char/s |
| main_game | Timer node (0.03s) | ~33 char/s |

### 2.4 GPU Particles (total: 2)

| Scene | Particules | Lifetime | Type |
|-------|-----------|----------|------|
| TransitionBiome | GPUParticles2D, 30 | 4.0s | Mist (directional emission) |
| day_night_cycle | GPUParticles3D (Stars) | n/a | 3D star field |

### 2.5 Shaders (total: 7)

| Shader | Type | Utilise par | Animation |
|--------|------|-------------|-----------|
| `merlin_paper.gdshader` | Static (grain animes TIME) | Menu, Calendar, Collection, SceneEveil, SceneAntre | Grain + warp via TIME |
| `screen_distortion.gdshader` | Dynamic (tweened params) | ScreenEffects autoload | Scanline, glitch, chromatic, flicker, noise |
| `seasonal_snow.gdshader` | Animated (TIME) | SceneEveil, SceneAntre (hiver) | Falling snow, 5 layers, wind offset |
| `bestiole_squish.gdshader` | Interactive | (non utilise actuellement) | Press deformation UV |
| `crt_static.gdshader` | Dynamic (param) | IntroBoot | CRT static noise |
| `pixelate.gdshader` | Static (params) | pixel_shader_controller | Pixelation effect |
| `ps1_material.gdshader` | Static (params) | ps1_shader_controller | PS1 retro look |

---

## 3. SHADERS ANIMES (DETAIL)

### 3.1 merlin_paper.gdshader
- **Parametres constants entre scenes** (BIEN):
  - `paper_tint`: PALETTE.paper (identique partout)
  - `grain_strength`: 0.025
  - `vignette_strength`: 0.08
  - `vignette_softness`: 0.65
  - `grain_scale`: 1200.0
  - `grain_speed`: 0.08
  - `warp_strength`: 0.001
- **Exception**: `merlin_backdrop.gd` utilise des valeurs differentes (grain 0.04, vignette 0.12, warp 0.0018)
- **Recommandation**: Centraliser les valeurs dans une constante partagee

### 3.2 screen_distortion.gdshader
- **7 effets independants** (chromatic, scanline, glitch, barrel, color_shift, noise, vignette, flicker)
- **Controle via ScreenEffects.gd** (autoload) avec tween transitions
- **Performance**: Mobile-optimized, tous les effets ont un early-exit si desactives
- **Utilise pour moods**: transitions douces entre ambiances

### 3.3 seasonal_snow.gdshader
- **5 couches de neige** avec vitesse/taille differente
- **Anime via TIME** (GPU-side, pas de GDScript necessaire)
- **Parametres**: speed (0.25), density (0.22)
- **Bon pattern**: pas de _process() GDScript, tout GPU

### 3.4 bestiole_squish.gdshader
- **NON UTILISE** actuellement dans aucun script
- **Fonction**: Deformation UV basee sur un point de pression
- **Parametres**: press_uv, press_strength, press_radius
- **Potentiel**: Animation de caresse/toucher Bestiole

---

## 4. ANALYSE DE COHERENCE

### 4.1 Durees — Patterns detectes

| Pattern | Duree | Scenes qui l'utilisent | Coherent? |
|---------|-------|------------------------|-----------|
| Texte fade in | 0.4-0.5s | SceneEveil, SceneAntre, IntroQuiz | OUI |
| Texte fade out | 0.3s | SceneEveil, SceneAntre | OUI |
| Scene exit | 0.4-0.8s | SceneEveil (0.6s), SceneAntre (0.6s), TransitionBiome (0.8s) | ACCEPTABLE |
| Card entry slide | 0.7s | Menu, SceneEveil, SceneAntre | OUI |
| Celtic ornaments fade | 0.8s | Menu, SceneEveil, SceneAntre | OUI |
| Mist breathing | 8.0s cycle | Menu (0.08-0.25), SceneEveil (0.08-0.25), SceneAntre (0.06-0.20) | PRESQUE (voir ecart) |
| Button hover | 0.1-0.15s | Menu, menu_return_button | OUI |
| Button press | 0.15-0.2s | Menu (0.2s), triade_ui (0.1+0.1s) | OK |
| Modal appear | 0.2s | IntroQuiz, TestLLM | OUI |
| Scene transition fade | 0.5-0.8s | IntroMerlinDialogue (0.8s), IntroQuiz (FADE_DURATION) | VARIABLE |

### 4.2 Easing — Patterns detectes

| Usage | Easing dominant | Coherent? |
|-------|----------------|-----------|
| Scene entry | TRANS_SINE + EASE_OUT | OUI — Style doux et organique |
| Scene exit | TRANS_SINE + EASE_IN_OUT | OUI |
| Button interactions | TRANS_SINE + EASE_OUT ou TRANS_QUAD + EASE_OUT | MIXTE |
| Card swipe | TRANS_SINE + EASE_IN | OUI |
| Ogham reveal | TRANS_BACK + EASE_OUT | UNIQUE (bon choix) |
| Flash / burst | pas d'easing (linear) | OK pour impacts |
| Accumulation burst | TRANS_QUAD + EASE_OUT | UNIQUE a menu |

### 4.3 Points d'incoherence

| Probleme | Details | Severite |
|----------|---------|----------|
| **Mist amplitude mixte** | Menu: 0.08-0.25, SceneEveil: 0.08-0.25, SceneAntre: 0.06-0.20, Collection: 0.6-1.0 | MINEUR |
| **Easing boutons inconsistant** | Menu: TRANS_SINE, menu_return: TRANS_QUAD, triade_ui: aucun | MINEUR |
| **Paper shader params divergent** | merlin_backdrop.gd utilise grain 0.04/vignette 0.12 vs 0.025/0.08 partout ailleurs | MINEUR |
| **Bestiole float sans easing** | main_game.gd L681: pas d'easing (linear), type_label L226 a EASE_IN_OUT | MINEUR |
| **Scene fade-out durees** | IntroMerlinDialogue: 0.8s, SceneEveil: 0.6s, SceneAntre: 0.6s | MINEUR |
| **Typewriter vitesse variable** | Certaines scenes utilisent un delai fixe 0.03s, d'autres un delay/char variable | ACCEPTABLE |

---

## 5. ANIMATIONS MANQUANTES

### 5.1 Entrees/sorties de scene

| Scene | Entree | Sortie | Manquant |
|-------|--------|--------|----------|
| IntroBoot | Oui (process) | Oui (transition alpha) | NON |
| IntroCeltOS | Oui (tween chain) | Oui (flash) | NON |
| IntroMerlinDialogue | NON DETECTABLE | Oui (fade 0.8s) | **Entree manquante** (probablement geree par scene precedente) |
| IntroPersonalityQuiz | NON DETECTABLE | Oui (fade) | **Entree manquante** |
| MenuPrincipalMerlin | Oui (orchestrated) | Oui (card swipe) | NON |
| SceneEveil | Oui (orchestrated) | Oui (orchestrated) | NON |
| SceneAntreMerlin | Oui (orchestrated) | Oui (orchestrated) | NON |
| TransitionBiome | Oui (typewriter) | Oui (fade) | NON |
| Calendar | Oui (tween) | Oui (fade) | NON |
| Collection | PARTIEL (mist only) | **NON** | **Sortie manquante** |
| SelectionSauvegarde | **NON** | **NON** | **Entree + sortie manquantes** |
| MenuOptions | **NON** | **NON** | **Entree + sortie manquantes** |

### 5.2 Micro-interactions manquantes

| Element | Hover | Press | Feedback | Manquant |
|---------|-------|-------|----------|----------|
| Boutons Menu Principal | OUI (scale 1.02) | OUI (scale 1.15) | OUI | NON |
| Boutons IntroQuiz | NON | OUI (scale 1.02) | NON | **Hover + feedback** |
| Boutons Triade UI | NON | OUI (flash) | NON | **Hover** |
| Boutons Reigns UI | NON | NON | tween position | **Hover + press** |
| Boutons SceneAntre (biome) | NON | NON | pulse suggere | **Hover + press** |
| Boutons Calendar | NON | NON | NON | **Tous manquants** |
| Boutons Collection | NON | NON | NON | **Tous manquants** |
| Return button | OUI (scale) | OUI (fade) | NON | **Feedback** |

### 5.3 Feedback systeme manquant

| Event | Animation actuelle | Recommandation |
|-------|-------------------|----------------|
| Aspect change (triade) | Pulse 2x (modulate:a 0.5<->1.0) | Ajouter color flash + label slide |
| Souffle gain | Aucune | **Flash vert sur icone + scale pop** |
| Souffle depense | Aucune | **Desaturation + shrink** |
| Card arrive | Aucune (instant) | **Slide from bottom ou flip** |
| Mission progress | Texte seulement | **Progress bar animate** |
| Fin de partie | Non implemente dans triade UI | **Fade drammatique + text sequence** |

---

## 6. PLAN ANIMATIONS BESTIOLE

### 6.1 Etat actuel

| Element | Existant | Fichier |
|---------|----------|---------|
| Bestiole icon float | OUI (linear, 0.5s loop) | main_game.gd:681 |
| Bestiole squish shader | OUI (non utilise) | shaders/bestiole_squish.gdshader |
| Bestiole label glow | OUI (fade in 1.5s) | SceneAntreMerlin.gd:665 |
| Bestiole data structure | OUI (GameManager) | game_manager.gd:440 |
| Bestiole skills (Oghams) | OUI (constants) | merlin_constants.gd:75 |

### 6.2 Animation Idle (respiration + flottement)

```
BESTIOLE_IDLE
├── Breathing (scale) ─── 3.0s loop, TRANS_SINE
│   ├── Inhale: scale (1.0, 1.0) -> (1.02, 0.98) [1.5s]
│   └── Exhale: scale (1.02, 0.98) -> (1.0, 1.0) [1.5s]
│
├── Floating (position) ─── 4.0s loop, TRANS_SINE
│   ├── Up: position.y += 4px [2.0s]
│   └── Down: position.y -= 4px [2.0s]
│
├── Eye blink ─── random interval 3-7s
│   ├── Close: scale.y 1.0 -> 0.1 [0.08s]
│   └── Open: scale.y 0.1 -> 1.0 [0.12s]
│
└── Ambient glow ─── 5.0s loop, TRANS_SINE
    ├── Brighten: modulate 1.0 -> 1.08 [2.5s]
    └── Dim: modulate 1.08 -> 1.0 [2.5s]
```

**Code Implementation:**
```gdscript
func _start_idle_animation() -> void:
    # Breathing
    _idle_tween = create_tween().set_loops()
    _idle_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    _idle_tween.tween_property(bestiole_sprite, "scale", Vector2(1.02, 0.98), 1.5)
    _idle_tween.tween_property(bestiole_sprite, "scale", Vector2(1.0, 1.0), 1.5)

    # Floating (parallel tween)
    _float_tween = create_tween().set_loops()
    _float_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    _float_tween.tween_property(bestiole_sprite, "position:y", base_y - 4, 2.0)
    _float_tween.tween_property(bestiole_sprite, "position:y", base_y, 2.0)

    # Ambient glow
    _glow_tween = create_tween().set_loops()
    _glow_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
    _glow_tween.tween_property(bestiole_sprite, "modulate", Color(1.08, 1.08, 1.08), 2.5)
    _glow_tween.tween_property(bestiole_sprite, "modulate", Color.WHITE, 2.5)
```

**Performance Notes:**
- 3 tweens actifs en parallele (leger)
- Pas de `_process()` necessaire
- GPU impact: negligeable

---

### 6.3 Animation d'activation d'Ogham (roue d'outils)

```
OGHAM_ACTIVATION
├── Phase 1: Bestiole Alert ─── 0.3s
│   ├── Scale pop: 1.0 -> 1.15 [0.15s, TRANS_BACK + EASE_OUT]
│   └── Color flash: white -> glow [0.15s]
│
├── Phase 2: Wheel Appear ─── 0.5s
│   ├── Wheel scale: 0.0 -> 1.0 [0.3s, TRANS_BACK + EASE_OUT]
│   └── Ogham icons stagger: modulate:a 0->1 [0.1s each, 0.08s delay]
│
├── Phase 3: Selection ─── variable
│   ├── Hover: icon scale 1.0 -> 1.15 [0.1s, EASE_OUT]
│   ├── Selected: icon flash + grow [0.15s]
│   └── Others: fade to 0.3 alpha [0.2s]
│
└── Phase 4: Execution ─── 0.6s
    ├── Wheel collapse: scale 1.0 -> 0.0 [0.2s, EASE_IN]
    ├── Bestiole charge: move toward center [0.15s]
    ├── Effect burst: particles from Bestiole position [0.5s]
    └── Bestiole return: bounce back to position [0.25s, TRANS_BACK]
```

**Performance Notes:**
- Burst particles: max 20 (CPU ColorRect, not GPU)
- Active tweens during animation: max 4
- GPU impact: low

---

### 6.4 Animation de feedback (succes/echec)

```
OGHAM_SUCCESS
├── Bestiole bounce: position.y -15px [0.1s] -> return [0.2s, TRANS_BOUNCE]
├── Scale pop: 1.0 -> 1.1 -> 1.0 [0.3s, TRANS_ELASTIC]
├── Color flash: white -> green glow -> white [0.4s]
├── Sparkle particles: 12 particles upward burst [0.5s]
└── Text popup: "+Effect" fade up 20px [0.8s, modulate:a 1->0]

OGHAM_FAILURE
├── Bestiole shake: x +/-3px [0.05s x 4]
├── Color flash: white -> red tint -> white [0.3s]
├── Scale shrink: 1.0 -> 0.95 -> 1.0 [0.2s]
└── Sad particles: 5 particles falling down [0.4s]
```

---

### 6.5 Animation de lien Bestiole-joueur

```
BOND_VISUALIZATION
├── Idle bond line ─── continuous
│   ├── Thin luminous line from Bestiole to card center
│   ├── Pulse opacity: 0.1 -> 0.2 [3.0s loop, TRANS_SINE]
│   └── Color: ogham_glow (0.45, 0.62, 0.32, alpha)
│
├── Bond strengthen (on good choice) ─── 0.5s
│   ├── Line thicken: 1px -> 3px [0.2s]
│   ├── Line brighten: alpha 0.2 -> 0.6 [0.2s]
│   ├── Particle trail along line: 8 particles [0.4s]
│   └── Restore: 3px -> 1px, 0.6 -> 0.2 [0.3s]
│
└── Bond weaken (on bad choice) ─── 0.3s
    ├── Line flicker: alpha rapid 0.0/0.3 [0.05s x 4]
    ├── Line desaturate briefly [0.2s]
    └── Restore smoothly [0.3s]
```

---

## 7. RECOMMANDATIONS D'HARMONISATION

### 7.1 Constantes globales a definir

Creer un fichier `scripts/merlin/merlin_animation_constants.gd`:

```gdscript
class_name MerlinAnimConstants

# Scene transitions
const SCENE_ENTRY_DURATION := 0.7   # Card slide + ornament fade
const SCENE_EXIT_DURATION := 0.6    # Element fade + transition
const SCENE_CROSSFADE := 0.4        # Between scenes

# Text
const TEXT_FADE_IN := 0.4
const TEXT_FADE_OUT := 0.3
const TYPEWRITER_CHAR_DELAY := 0.03  # 33 chars/sec

# UI Elements
const BUTTON_HOVER_DURATION := 0.12
const BUTTON_PRESS_DURATION := 0.15
const BUTTON_HOVER_SCALE := Vector2(1.03, 1.03)
const MODAL_APPEAR := 0.2
const MODAL_DISMISS := 0.15

# Celtic ornaments
const ORNAMENT_FADE_DURATION := 0.8

# Mist breathing
const MIST_CYCLE_DURATION := 8.0
const MIST_ALPHA_MIN := 0.08
const MIST_ALPHA_MAX := 0.25

# Bestiole
const BESTIOLE_BREATHE_DURATION := 3.0
const BESTIOLE_FLOAT_DURATION := 4.0
const BESTIOLE_FLOAT_AMPLITUDE := 4.0  # pixels

# Card
const CARD_SNAP_BACK := 0.25
const CARD_SWIPE_EXIT := 0.25

# Default transitions
const DEFAULT_TRANS := Tween.TRANS_SINE
const DEFAULT_EASE_IN := Tween.EASE_IN
const DEFAULT_EASE_OUT := Tween.EASE_OUT
const DEFAULT_EASE_INOUT := Tween.EASE_IN_OUT
```

### 7.2 Corrections prioritaires

| Priorite | Action | Fichier(s) |
|----------|--------|------------|
| **HAUTE** | Ajouter hover+press a tous les boutons | IntroQuiz, Triade UI, Calendar, Collection |
| **HAUTE** | Ajouter entree/sortie a SelectionSauvegarde et MenuOptions | SelectionSauvegarde.gd, MenuOptions.gd |
| **MOYENNE** | Harmoniser mist alpha range (0.08-0.25 partout) | SceneAntreMerlin (changer 0.06 -> 0.08), Collection (changer 0.6-1.0 -> 0.08-0.25) |
| **MOYENNE** | Harmoniser easing boutons (TRANS_SINE partout) | menu_return_button, triade_game_ui |
| **MOYENNE** | Unifier paper shader params dans constante | Calendar, Collection, Menu, SceneEveil, SceneAntre, reigns_backdrop |
| **BASSE** | Ajouter EASE_IN_OUT au float Bestiole | main_game.gd:681 |
| **BASSE** | Integrer bestiole_squish.gdshader dans une scene | Bestiole touch/caresse |

### 7.3 Style guide animation (a respecter)

| Categorie | Transition | Easing | Justification |
|-----------|-----------|--------|---------------|
| Entrees (elements apparaissent) | TRANS_SINE | EASE_OUT | Deceleration douce, organique |
| Sorties (elements disparaissent) | TRANS_SINE | EASE_IN_OUT | Fluide, pas brusque |
| Feedback (press, flash) | TRANS_QUAD | EASE_OUT | Rapide, reactif |
| Overshoot (pop, reveal) | TRANS_BACK | EASE_OUT | Vivant, magique |
| Bounce (Bestiole) | TRANS_ELASTIC / TRANS_BOUNCE | EASE_OUT | Joyeux, organique |
| Atmospherique (mist, glow) | TRANS_SINE | EASE_IN_OUT | Cycle naturel |
| Retro/CRT effects | Custom sine/lerp | n/a | Granulaire, process-based |

### 7.4 Performance checklist

- [x] Aucun `_process()` inutile (merlin_house_animations est 3D legacy, pas utilise en 2D)
- [x] Tweens tues avant recrea dans ScreenEffects (bon pattern)
- [ ] **Manquant**: Tuer les tweens avant recreation dans MenuPrincipalMerlin (hover/press)
- [x] GPU particles limites (30 dans TransitionBiome, OK)
- [x] Shaders avec early-exit (screen_distortion: `if global_intensity >= 0.001`)
- [ ] **Manquant**: Bestiole idle tweens doivent etre tues a la sortie de scene

---

## RESUME STATISTIQUE

| Metrique | Valeur |
|----------|--------|
| **Fichiers avec animations** | 19 scripts + 7 shaders |
| **Tweens totaux** | ~75 |
| **Process-based** | ~12 |
| **Typewriters** | 5 |
| **GPU Particles** | 2 |
| **Shader animations** | 7 |
| **Scenes sans entree** | 3 (IntroMerlinDialogue, IntroQuiz, SelectionSauvegarde) |
| **Scenes sans sortie** | 3 (Collection, SelectionSauvegarde, MenuOptions) |
| **Boutons sans hover** | ~15 |
| **Animations Bestiole existantes** | 2 (float + label glow) |
| **Animations Bestiole planifiees** | 4 (idle, ogham, feedback, bond) |
| **Shader inutilise** | 1 (bestiole_squish.gdshader) |
| **Coherence easing** | 80% (TRANS_SINE dominant, bon) |
| **Coherence durees** | 85% (scenes parchemin bien alignees) |

---

*Generated by Motion Designer Agent — 2026-02-08*

# Matrice d'adhesion joueur — M.E.R.L.I.N.

> Source de verite pour mesurer si un run est FUN, lisible, et raconte bien.
> Chaque cible a un seuil quantifie + un hook telemetry pour mesurer en runtime.

---

## Principe

Le fun n'est pas subjectif quand on le mesure. On instrumente 5 dimensions
sur chaque run, chaque carte, chaque choix. Si une dimension sort des bornes,
c'est un signal d'alerte design — pas une condamnation, mais un check a faire.

Chaque metrique a :
- **Cible** : la valeur ideale visee
- **Borne basse / haute** : si on sort, signal rouge
- **Hook** : ou est mesure dans le code
- **Action si rouge** : que faire si la metrique deraille

---

## 1. RYTHME (pacing)

Le run doit avoir un debut, un milieu, une fin clairs. Pas de longueur morte.

| Metrique | Cible | Min | Max | Hook | Action si rouge |
|----------|-------|-----|-----|------|-----------------|
| **Duree totale run** | 9 min | 6 min | 14 min | `metrics.run_duration_s` | < 6: trop court, ajouter encounters. > 14: trop long, raccourcir narration |
| **Duree entre encounters** | 90s | 60s | 150s | `metrics.encounter_interval_s` | > 150: marche solitaire trop longue. Spawn ambient_event |
| **Duree d'une carte** | 35s | 20s | 60s | `metrics.card_duration_s` | < 20: trop rapide, joueur ne lit pas. > 60: trop dense, scinder |
| **Duree typewriter** | 4s | 2s | 8s | `metrics.typewriter_duration_s` | > 8: texte trop long. Couper a 200 chars |

---

## 2. CLARITE des choix (UX friction)

Le joueur doit comprendre l'enjeu. Pas de devinette.

| Metrique | Cible | Min | Max | Hook | Action si rouge |
|----------|-------|-----|-----|------|-----------------|
| **Latence avant clic** | 6s | 2s | 15s | `metrics.choice_latency_s` | > 15: choix opaques. Risk_hint plus explicite. < 2: trop facile, joueur ne reflechit pas |
| **Choix axes distincts par carte** | 3 axes differents | 2 | 3 | `metrics.choices_axis_diversity` | < 2: choix repetitifs, le joueur prend toujours le meme |
| **Risk_hint present** | 100% | 80% | 100% | `metrics.cards_with_risk_hint_pct` | < 80: cartes generes sans hint, prompt LLM a corriger |
| **Bouton inutilise > 3 cartes** | 0 | 0 | 1 | `metrics.unused_buttons_streak` | > 1: un choix est "piege" non visible, ajuster ton/risk |

---

## 3. TENSION (fun emotionnel)

Le joueur doit ressentir des hauts et des bas, pas un plateau plat.

| Metrique | Cible | Min | Max | Hook | Action si rouge |
|----------|-------|-----|-----|------|-----------------|
| **Repartition resolutions/run** | 30/40/20/10 | 50% min sur 1 tier | 70% max sur 1 tier | `metrics.resolution_distribution` | Si 70% success: difficulty trop basse, +1 DC. Si 50% failure: +1 DC en moins |
| **Surprise rate** | 4 par run | 2 | 6 | `metrics.surprise_count` | < 2: trop previsible. Injection event aleatoire |
| **Critical events / run** | 2 | 1 | 4 | `metrics.critical_total` | 0: pas de moment fort, ajuster modificateurs |
| **Critical failure / run** | 0.5 | 0 | 2 | `metrics.crit_failure_total` | > 2: punissant, joueur frustre |

---

## 4. PROGRESSION (sentiment d'avancer)

Chaque run doit donner du fil a tirer ensuite. Sinon le replay value tombe.

| Metrique | Cible | Min | Max | Hook | Action si rouge |
|----------|-------|-----|-----|------|-----------------|
| **XP gagnee/run** | 60 | 30 | 120 | `metrics.xp_gained` | < 30: stat progression trop lente |
| **Trait debloques cumulatif (5 runs)** | 1.5 | 0.5 | 3 | `metrics.traits_unlocked_avg5` | < 0.5: jamais d'unlock, baisser seuils |
| **Reputation faction max gagnee/run** | +12 | +5 | +25 | `metrics.faction_max_gain` | < 5: faction system invisible |
| **Anam gagnee/run** | 30 | 15 | 60 | `metrics.anam_gained` | < 15: pas de meta-progression sentie |

---

## 5. PERFORMANCE (responsivite)

Le fun s'evapore vite quand ca lague.

| Metrique | Cible | Min | Max | Hook | Action si rouge |
|----------|-------|-----|-----|------|-----------------|
| **FPS moyen** | 60 | 45 | 60 | `metrics.fps_avg` | < 45: drop draw calls (chunks, particles) |
| **FPS p99 (worst 1%)** | 45 | 30 | 60 | `metrics.fps_p99` | < 30: stutters serieux, profile |
| **Frame time max** | 22ms | 0 | 50ms | `metrics.frame_time_max_ms` | > 50: pic de hitch, find heavy frame |
| **Card render duration** | 16ms | 0 | 33ms | `metrics.card_render_ms` | > 33: trop d'elements UI sur la carte |
| **Asset load time (first run)** | 4s | 0 | 8s | `metrics.first_load_s` | > 8: pre-load au menu, pas au run |

---

## Output JSON par run

A la fin de chaque run, ecrire `tools/autodev/captures/run_metrics_<timestamp>.json` :

```json
{
  "run_id": "uuid",
  "timestamp": "2026-04-26T12:34:56Z",
  "biome": "broceliande",
  "tutorial": false,
  "duration_s": 540,
  "cards_played": 5,
  "rythm": {"avg_card_duration_s": 38, "avg_encounter_interval_s": 88, "typewriter_avg_s": 4.2},
  "clarity": {"avg_choice_latency_s": 7.1, "axis_diversity_avg": 2.8, "cards_with_risk_hint_pct": 95},
  "tension": {"resolution_distribution": {"critical": 0.20, "success": 0.40, "failure": 0.30, "critical_failure": 0.10}, "surprise_count": 3},
  "progression": {"xp_gained": 55, "traits_unlocked": ["lecteur_de_pierres"], "anam_gained": 28},
  "performance": {"fps_avg": 58, "fps_p99": 42, "frame_time_max_ms": 38, "card_render_ms_avg": 14}
}
```

---

## Dashboard (visualisation)

Script `tools/cli.py merlin metrics-summary` (a creer Cycle 8) parse les JSON
des N derniers runs et affiche en console :

```
📊 Run Adherence — last 5 runs
─────────────────────────────────────────────────
Rythm    : ★★★★☆ (4.2/5) — avg run 9m12, OK
Clarity  : ★★★☆☆ (3.4/5) — choice_latency 11s (haut), risk_hint 78% (bas)
Tension  : ★★★★★ (4.8/5) — repartition 18/42/28/12, OK
Progress : ★★★☆☆ (3.5/5) — 0.6 trait/run (target 1.5)
Perf     : ★★★★★ (5.0/5) — fps_avg 60, p99 50

⚠️ Action items:
  • risk_hint missing in 22% cards → improve gamemaster_rpg_card prompt
  • avg_choice_latency 11s → consider sharper risk_hint wording
  • traits unlock rate low → review unlock thresholds
```

---

## Telemetry hooks dans le code

Cycle 8 implementera l'autoload `MerlinMetrics` qui expose:

```gdscript
MerlinMetrics.run_started(biome, is_tutorial)
MerlinMetrics.card_shown(text_length, has_risk_hint, axis_diversity)
MerlinMetrics.choice_made(option_index, latency_s, axis)
MerlinMetrics.test_resolved(axis, result, dc, roll, xp_gained)
MerlinMetrics.trait_unlocked(key)
MerlinMetrics.run_ended(reason)  # writes JSON
```

Sur _process(): echantillonne FPS, frame time, card render time.

---

## Anti-patterns design (a eviter via la matrice)

- ❌ Run < 5 min: pas le temps de s'attacher au profil joueur
- ❌ Tous succes: pas de friction = pas d'interet
- ❌ Toutes resolutions identiques (ton, longueur): cerveau s'eteint
- ❌ Choix qui semblent equivalents: joueur clic au hasard
- ❌ FPS stable + drops occasionnels: pire que FPS bas constant (frustration)
- ❌ Pas de feedback de progression: joueur abandonne au run 3

---

*Doc canonique : 2026-04-26 — Version 1*

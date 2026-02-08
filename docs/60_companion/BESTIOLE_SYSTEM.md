# Bestiole - Companion System (UPDATED 2026-02-05)

---

## PIVOT: Support Passif + Skills (Oghams)

Bestiole n'est plus un combattant actif. Il joue un role de **support passif** qui:
- Donne des **bonus** bases sur son etat (bond, mood, needs)
- Peut activer des **skills** (les 18 Oghams) pour aider le joueur
- Influence la narration et les options disponibles

---

## Purpose
- Define a fun, deep, and low-stress companion system.
- Bestiole provides passive support during card choices.
- Care matters, but the system avoids punishment or grind.

## Core Fantasy
- Bestiole is a living companion that grows with the player.
- It reacts to seasons, promises, and the land.
- It learns habits from how the player treats it.
- **NEW**: It channels ancient Oghams as magical skills.

---

## Core Loop (UPDATED)

### During Gameplay
- Bestiole donne des **modifiers passifs** sur chaque carte
- Joueur peut **activer un skill** (Ogham) avant de choisir
- Skills ont des **cooldowns** (en nombre de cartes)

### Between Runs (Hub)
- Care actions: feed, play, groom, rest
- Train new Oghams
- Review bond level and mood

### Growth
- Bond augmente avec le soin et les bons choix
- Bond elevé = plus de skills disponibles simultanement

---

## Key Needs (slow decay)

| Need | Decay Rate | Impact si bas |
|------|------------|---------------|
| **Hunger** | -1/10 cartes | Skills -50% efficacite |
| **Energy** | -1/15 cartes | Cooldowns x2 |
| **Mood** | -1/8 cartes | Hints brouillés |
| **Cleanliness** | -1/20 cartes | Bond decay accelere |
| **Bond** | Variable | Voir section Skills |

### Non-Punitive Rules
- No death or permanent harm from neglect
- Missed sessions auto-stabilize to safe baselines
- Recovery is faster than decay
- One good care session can offset multiple missed days

---

## Bond System

### Bond Levels
| Range | Tier | Skills Available | Modifiers |
|-------|------|------------------|-----------|
| 0-30 | Distant | 0 | Aucun |
| 31-50 | Friendly | 1 actif | +5% effets positifs |
| 51-70 | Close | 2 actifs | +10% effets positifs |
| 71-90 | Bonded | 3 actifs | +15% + hints |
| 91-100 | Soulmate | Tous | +20% + options speciales |

### Bond Growth
- +1 par carte jouee (si needs > 30%)
- +5 pour care actions
- +10 pour tenir une promesse
- -5 pour briser une promesse
- -1 par carte si needs critiques (<20%)

---

## Skills System (Oghams)

Les 18 Oghams deviennent des skills que Bestiole peut activer.

### Skill Categories

#### REVEAL (Information)
| Ogham | Name | Effect | Cooldown |
|-------|------|--------|----------|
| beith | Bouleau | Revele effets d'une option | 3 cartes |
| coll | Noisetier | Revele les deux options | 5 cartes |
| ailm | Sapin | Predit le type de prochaine carte | 4 cartes |

#### PROTECTION (Defense)
| Ogham | Name | Effect | Cooldown |
|-------|------|--------|----------|
| luis | Sorbier | Reduit effet negatif de 30% | 4 cartes |
| gort | Lierre | Absorbe 1 effet negatif total | 6 cartes |
| eadhadh | Tremble | Evite la prochaine carte negative | 8 cartes |

#### BOOST (Amplification)
| Ogham | Name | Effect | Cooldown |
|-------|------|--------|----------|
| duir | Chene | +50% effet positif ce tour | 4 cartes |
| tinne | Houx | Double un gain de ressource | 5 cartes |
| onn | Ajonc | +20% tous effets pour 3 cartes | 7 cartes |

#### NARRATIVE (Options)
| Ogham | Name | Effect | Cooldown |
|-------|------|--------|----------|
| nuin | Frene | Ajoute une 3eme option | 6 cartes |
| huath | Aubepine | Change la carte actuelle | 5 cartes |
| straif | Prunellier | Force un event rare | 10 cartes |

#### RECOVERY (Healing)
| Ogham | Name | Effect | Cooldown |
|-------|------|--------|----------|
| quert | Pommier | +15 a la jauge la plus basse | 4 cartes |
| ruis | Sureau | Equilibre les jauges vers 50 | 8 cartes |
| saille | Saule | Regenere +5/carte pendant 3 tours | 6 cartes |

#### SPECIAL (Unique)
| Ogham | Name | Effect | Cooldown |
|-------|------|--------|----------|
| muin | Vigne | Inverse les effets d'une option | 7 cartes |
| ioho | If | Reroll complet de la carte | 12 cartes |
| ur | Bruyere | Sacrifice 20 Vigueur, +30 autres | 10 cartes |

### Skill Acquisition
- Commence avec: beith, luis, quert
- Unlock via: achievements, bond milestones, meta progression
- Train via: sessions dans le Hub

---

## Passive Modifiers

Bestiole applique des bonus passifs bases sur son etat:

### Mood-Based
| Mood | Modifier |
|------|----------|
| Ecstatic | +15% effets positifs |
| Happy | +10% effets positifs |
| Content | +5% effets positifs |
| Neutral | 0 |
| Sad | -5% effets positifs |
| Depressed | -10% effets positifs, hints masques |

### Need-Based
```
Si Hunger > 70: +5% recovery skills
Si Energy > 70: -1 cooldown tous skills
Si Cleanliness > 80: +1 bond par session
```

---

## Care Actions

### Quick Actions (Hub)
| Action | Effect | Cost |
|--------|--------|------|
| Feed | +30 Hunger, +5 Mood | 10 gold |
| Play | +20 Mood, -10 Energy | Free |
| Groom | +25 Cleanliness, +5 Bond | Free |
| Rest | +40 Energy | Free |
| Gift | +15 Bond | 25 gold |

### Training Sessions
| Session | Unlocks | Duration |
|---------|---------|----------|
| Ogham Study | New skill | 5 runs |
| Bond Ritual | +20 bond cap | 3 runs |
| Memory Walk | Skill efficiency +10% | 4 runs |

---

## Seasonal Behavior

| Season | Effect |
|--------|--------|
| Winter | Energy drain slower, skill cooldowns +1 |
| Spring | Mood gains faster, new skill chance |
| Summer | All gains +10%, needs decay faster |
| Autumn | Spirit skills boosted, bond stable |

---

## UI Integration

### Main Game (Reigns-style)
```
+------------------------------------------+
|  [Card Content]                          |
|                                          |
+------------------------------------------+
|  [🐾 Bestiole: Happy | Bond: 72]         |
|  [Skills: beith ✓ | luis ⏳2 | quert ✓]  |
+------------------------------------------+
|  [Left]                    [Right]       |
+------------------------------------------+
```

### Hub Screen
```
+------------------------------------------+
|  BESTIOLE                                |
|  [Portrait Animation]                    |
|                                          |
|  Needs:                                  |
|  Hunger   ████████░░ 80%                |
|  Energy   ██████░░░░ 60%                |
|  Mood     █████████░ 90%                |
|  Clean    ███████░░░ 70%                |
|                                          |
|  Bond: 72 [████████░░]                  |
|                                          |
|  [Feed] [Play] [Groom] [Rest] [Gift]    |
|                                          |
|  Skills Equipped: beith, luis, quert     |
|  [Manage Skills]                         |
+------------------------------------------+
```

---

## Implementation Notes

### State Structure
```gdscript
var bestiole := {
    "name": "Gwenn",
    "bond": 72,
    "needs": {
        "hunger": 80,
        "energy": 60,
        "mood": 90,
        "cleanliness": 70,
    },
    "skills_unlocked": ["beith", "luis", "quert", "duir"],
    "skills_equipped": ["beith", "luis", "quert"],
    "skill_cooldowns": {"beith": 0, "luis": 2, "quert": 0},
    "training_progress": {},
}
```

### Key Functions
```gdscript
func can_use_skill(skill_id: String) -> bool
func use_skill(skill_id: String, card: Dictionary) -> Dictionary
func apply_passive_modifiers(effects: Array) -> Array
func decay_needs(cards_played: int) -> void
func care_action(action: String) -> void
```

---

## Balance Knobs

| Parameter | Default | Range |
|-----------|---------|-------|
| Need decay rate | 1 per 10 cards | 1-20 |
| Bond growth rate | 1 per card | 0.5-2 |
| Skill cooldown base | 5 cards | 3-12 |
| Modifier percentages | 10% | 5-20% |

---

## QA Checklist

- [ ] Care actions take < 20 seconds each
- [ ] Missing days never blocks progress
- [ ] Skills are helpful but not mandatory
- [ ] Bond changes are clear and communicated
- [ ] All 18 Oghams have distinct useful effects
- [ ] Cooldowns feel fair, not frustrating

---

*Document version: 2.0 (post-pivot to support role)*
*Last updated: 2026-02-05*

# DOC 05 — Combat System v2 (DEPRECATED)

---

## ⚠️ DEPRECATED — 2026-02-05

Ce document est **DEPRECIE** suite au pivot vers un systeme Reigns-like.

### Raisons
- Le jeu n'a plus de combat traditionnel
- Les choix sont maintenant purement narratifs (cartes Reigns)
- Bestiole ne combat plus, il donne des bonus passifs et skills

### Remplacement
Voir les documents suivants:
- [DOC_11_Reigns_Card_System.md](DOC_11_Reigns_Card_System.md) — Nouveau systeme de cartes
- [GAMEPLAY_LOOP_ROGUELITE.md](../40_world_rules/GAMEPLAY_LOOP_ROGUELITE.md) — Loop de jeu Reigns-style
- [BESTIOLE_SYSTEM.md](../60_companion/BESTIOLE_SYSTEM.md) — Nouveau role de Bestiole

---

## Archive: Design Original (pour reference)

Le systeme ci-dessous est conserve pour reference historique uniquement.

### But (OBSOLETE)
Combat profond, mais lisible comme Pokemon : le joueur choisit **FORCE / LOGIQUE / FINESSE**, puis 1 sous-choix.

### 5.1 UI identique au reste (OBSOLETE)
- Bandeau : HP, ressources run, posture, momentum
- Scene : sprites, intention ennemie (icone)
- Boite texte : narration combat "GBC"
- Bas : FORCE / LOGIQUE / FINESSE (+ 1-2 sous-choix)

### 5.2 Mapping des verbes → actions combat (OBSOLETE)

#### FORCE
- `Frapper` (degats + momentum)
- option : `Ecraser` (plus de degats, plus de risque)

#### LOGIQUE
- `Observer` (revele intention + bonus concentration/momentum)
- option : `Contre` (si timing, reduit degats recus)

#### FINESSE
- `Coup precis` (crit/alteration)
- option : `Esquiver` (reduit degats, prepare un bonus tour suivant)

### 5.3 Intentions ennemies (OBSOLETE)
Chaque ennemi a 2-3 patterns :
- Attaque / Defense / Special

LOGIQUE (Observer) peut reveler :
- prochaine intention
- type principal
- faiblesse "1 tour" (soft buff)

### 5.4 Postures (stances) persistantes (OBSOLETE)
- Prudence : +resist, -dmg, +reussite tests route
- Agressif : +dmg, -resist
- Ruse : +alterations, +loot rare
- Serenite : +recup, -stress

### 5.5 Momentum (OBSOLETE)
- 0..100
- succes = +, echec = -
- influence precision & outcomes de route

### 5.6 Statuts (OBSOLETE)
- Brulure : DOT faible + malus atk leger (cap)
- Venin : DOT faible stackable (cap 3)
- Gel : "retard" (pas skip total)
- Peur : baisse precision tests
- Clairvoyance : bonus tests
- Surcharge : +degats infliges, +degats recus (courte duree)

### 5.7 Recompenses combat (OBSOLETE)
Combat donne :
- ressources run (toujours)
- essences (souvent)
- fragments (rare)
- items / reliques (rare)
- bond XP (selon posture + stress)

---

## Elements Potentiellement Reutilisables

Certains concepts pourraient etre adaptes pour le systeme de cartes:

| Concept | Adaptation Possible |
|---------|---------------------|
| Verbes FORCE/LOGIQUE/FINESSE | Tags pour certaines cartes? |
| Postures | Modes de Bestiole? |
| Momentum | Score de "flow" dans la run? |
| Statuts | Effets de cartes sur jauges? |

---

*Status: DEPRECATED*
*Original version: 2.0*
*Deprecated: 2026-02-05*

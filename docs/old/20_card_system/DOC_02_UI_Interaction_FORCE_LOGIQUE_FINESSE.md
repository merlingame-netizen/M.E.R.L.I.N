# DOC 02 — UI & Interaction Model : FORCE / LOGIQUE / FINESSE

## Principe
Le joueur ne manipule que :
- **3 boutons** : FORCE / LOGIQUE / FINESSE
- **1 à 2 sous-choix** maximum par bouton
- une lecture simple : **Chance / Risque / Gain**

Même layout en **Event** et en **Combat**.

---

## 2.1 Boutons (verbes)

### FORCE
- Attaque frontale, briser, pousser, intimider, encaisser, “passer en force”.

### LOGIQUE
- Observer, analyser, planifier, anticiper, déduire, optimiser.

### FINESSE
- Discrétion, précision, timing, diplomatie, manipulation subtile, esquive.

---

## 2.2 Sous-catégories (1–2 choix max)

> **Règle :** à l’ouverture d’un bouton, afficher **au plus 2** sous-choix.

Exemples :
- FORCE → `Briser` / `Intimider`
- LOGIQUE → `Observer` / `Planifier`
- FINESSE → `S’infiltrer` / `Négocier`

### UX
- Survol / focus : ouvre un mini panel listant 1–2 sous-choix.
- Sélection : déclenche un **test caché** (mini-jeu) ou une résolution combat.

---

## 2.3 Feedback “simple mais informatif”
Pour chaque sous-choix afficher :
- **Chance** : Faible / Moyen / Élevé
- **Risque** : Léger / Modéré / Sévère
- **Gain** : icônes (ressources run / essence / lien / item)

> Ne jamais afficher : type de mini-jeu, formule de calcul, ou “probabilité exacte”.

---

## 2.4 Layout unique (GBC)
- Bandeau haut : HP / ressources run / posture / momentum
- Centre : scène (backdrop + sprites)
- Bas : boîte de texte + 3 boutons + sous-choix

---

## 2.5 Controls
- Clavier :
  - Gauche/Droite : changer FORCE/LOGIQUE/FINESSE
  - Haut/Bas : sous-choix
  - Enter : valider
  - Esc/Backspace : retour
- Souris/Touch : click.

---

## 2.6 Accessibilité
- Mode “Texte lent” + curseur clignotant (GBC)
- Mode “Raccourcis” visible (A/B)
- Indicateur “Risque/Chance” toujours lisible (pas de couleur seule).

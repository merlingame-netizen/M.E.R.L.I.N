# DOC 06 — Event System v2 (HoF + mini-jeux cachés)

## Pipeline
1) Intro texte (pages)
2) Affiche 3 boutons FORCE/LOGIQUE/FINESSE
3) Chaque bouton ouvre 1–2 sous-choix
4) Sélection = test caché (mini-jeu) + coût éventuel
5) Outcome success/fail (effets whitelistés)
6) Retour Map + animation

---

## 6.1 Mini-jeux (cachés)
- DICE : hasard contrôlé (avantage/désavantage)
- TIMING : stop sur zone
- MEMORY : pattern
- AIM : cible mouvante

Le joueur **ne voit jamais** le type avant d’avoir choisi.

---

## 6.2 Règles anti-frustration
- Échec donne souvent : info + petite ressource + momentum
- Pity augmente après fail streak
- Risque/Chance affichés sont cohérents (pas de “mensonge” UI)

---

## 6.3 LLM rôle
Merlin génère :
- texte + ambiance
- sous-choix (1–2)
- hidden_test (type + difficulty)
- effets codés (whitelist)

Le moteur :
- valide
- applique
- journalise

---

## 6.4 Exemples de sous-choix
- FORCE : “Briser le sceau” / “Intimider”
- LOGIQUE : “Étudier les runes” / “Observer”
- FINESSE : “Désamorcer” / “Passer discrètement”

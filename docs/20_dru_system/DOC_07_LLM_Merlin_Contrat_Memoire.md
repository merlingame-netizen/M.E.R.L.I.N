# DOC 07 — LLM Merlin : contrat + mémoire + limites

## 7.1 Merlin propose, moteur valide
Merlin ne modifie jamais directement :
- HP / inventaire / essences / évolutions
Il ne fait que proposer des **effets codés**.

---

## 7.2 Contrat JSON (scene)
Merlin renvoie un JSON strict contenant :
- `scene_id`, `biome`, `backdrop`
- `text_pages[]`
- `choices` groupés par FORCE/LOGIQUE/FINESSE, 1–2 sous-choix
- `hidden_test` par sous-choix
- `on_success[]` / `on_fail[]` : effets whitelistés
- option : `combat_offer` (menace, tags, chance)

---

## 7.3 Contrat JSON (évaluation)
Optionnel : Merlin peut noter une décision pour le roleplay, sans effet mécanique direct.
- `commentary`
- `tone` (protecteur/pragmatique/…)
- `memory_tags[]` (pour index mémoire)

---

## 7.4 Mémoire permanente Merlin (long terme)
Merlin conserve :
- journal des faits marquants
- profil joueur (tendances de choix)
- relation Merlin↔Bestiole (moments)
- lore cohérent (règles du monde)

Stockage recommandé :
- DB locale (clé-valeur + embeddings)
- résumés périodiques (toutes les X scènes)

---

## 7.5 Contexte court terme (run)
Merlin reçoit :
- biome, étage, type de nœud
- ressources run
- état Bestiole (jauges, posture, momentum)
- derniers choix (3–5) pour cohérence immédiate

---

## 7.6 Bestiole sans mémoire
Bestiole réagit uniquement à :
- hunger/energy/hygiene/mood/stress
- posture + momentum
- danger immédiat

Interdiction narrative :
- pas de rappel “hier tu as fait …” du point de vue Bestiole.

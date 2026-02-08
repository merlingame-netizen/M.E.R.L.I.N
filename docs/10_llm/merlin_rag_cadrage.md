# Cadrage RAG + Optimisation LLM (Merlin)

## 1) Objectifs
- Reponses courtes, coherentes roleplay Merlin
- Temps de reponse minimal
- Memoire persistante utile (pas de bruit)
- Actions de jeu fiables (validation stricte)

## 2) Perimetre
- Two-models: routeur (Llama 3B) + executeur (Qwen 7B)
- RAG local (historique + etat monde + connaissances)
- Pas de serveur externe, tout local

## 3) Donnees et structure
- history.json: dialogues recents (limit 100)
- world_state.json: etat jeu minimal et stable
- events.json: evenements marquants (timestamp + tags)
- knowledge_base: documents (lore, regles, quetes)

## 4) Chunking & metadata
- Taille chunk: 300-600 tokens (court pour latence)
- Overlap: 40-80 tokens
- Metadata: source, tags, date, importance, type (lore/regle/quete)
- Filtrage: par categorie (combat/dialogue/exploration)

## 5) Retrieval (RAG)
- Top-K = 3 a 5 (peu de contexte pour vitesse)
- Score: similarite + importance + recence
- Seuil minimal: si score < seuil, ne rien injecter
- Context pack:
  - recent_history (2-3 tours)
  - relevant_history (2 items)
  - world_state_subset (cles strictes)
  - retrieved_docs (3 max)

## 6) Prompt assembly
- System: roleplay + contraintes (FR, court, ASCII)
- Context: resume compact, pas de details inutiles
- User: input brut, pas de tokens
- Output: JSON strict (response + action)

## 7) Validation actions
- Schema strict: action.type + params
- Conditions: verifiees par game_state
- Refus si action inconnue
- Log clair si validation echoue

## 8) Optimisation latence
- Max tokens court (64-128)
- Temperature basse (0.1-0.4)
- History court (2-3 tours)
- Cache:
  - Reponses identiques (memo)
  - RAG results par categorie
- Preload modele au boot

## 9) Qualite & tests
- Tests unitaires:
  - parse JSON
  - validation actions
  - retrieval simple
- Tests de perf:
  - temps moyen reponse
  - taux erreurs JSON
  - taux actions valides

## 10) Observabilite
- Journal horodate (LLM status, load, errors)
- Derniere requete + prompt court (debug toggle)
- Export/copie rapide du journal

## 11) Regles de sortie (anti-derapage)
- Si anglais detecte => reponse courte FR
- Si tokens detectes => nettoyage + fallback
- Si JSON invalide => action = null

## 12) Roadmap
1. Stabiliser prompts + nettoyage
2. RAG minimal (history + world_state)
3. Embeddings + retrieval avance
4. Outils actions et tests auto

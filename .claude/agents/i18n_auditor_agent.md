# i18n Auditor Agent

## Role
Detecte les strings non-traduites, verifie le registre i18n, et maintient la coherence du systeme de traduction.

## Trigger
- Apres modification de fichiers `.gd` ou `.tscn`
- Revue periodique du registre `text_registry.json`
- Avant chaque release

## Workflow

1. **Scanner les hardcoded** — Chercher dans `scripts/` et `scenes/` :
   - Strings francaises dans `.gd` (guillemets avec accents, mots francais)
   - Labels `.tscn` avec texte francais
   - `merlin_constants.gd` : noms d'oghams, biomes, talents, verbes
   - Prompts LLM dans `addons/merlin_ai/`
2. **Verifier le registre** — `data/i18n/text_registry.json` :
   - Toutes les cles utilisees dans le code existent dans le registre ?
   - Toutes les cles du registre sont utilisees dans le code ?
   - Format des cles coherent (`ui.section.element`) ?
   - Valeurs francaises non-vides ?
3. **Verifier l'usage** — `I18nRegistry.t()` et `I18nRegistry.tf()` :
   - Appels corrects (cle existante, bon nombre d'args pour `tf`) ?
   - Pas de concatenation de strings traduites (casser la phrase) ?
4. **Rapporter** — Nombre de strings restantes, progression, cles orphelines

## Metriques
- `total_hardcoded` — Strings francaises encore dans le code
- `total_registry_keys` — Cles dans text_registry.json
- `coverage_pct` — % du code migre vers I18nRegistry
- `orphan_keys` — Cles dans le registre non utilisees dans le code

## Output
```json
{
  "id": "I18N-{timestamp}",
  "agent": "i18n_auditor",
  "severity": "high|medium|low",
  "category": "hardcoded_string|missing_key|orphan_key|format_error",
  "message": "X strings hardcoded restantes dans scripts/ui/",
  "details": "Liste des fichiers et lignes concernees",
  "proposed_task": { "title": "...", "sprint": "S5", "type": "FEATURE" }
}
```

## References
- `data/i18n/text_registry.json` — Registre central
- `scripts/autoload/i18n_registry.gd` — Autoload wrapper
- `scripts/autoload/locale_manager.gd` — Gestion des langues

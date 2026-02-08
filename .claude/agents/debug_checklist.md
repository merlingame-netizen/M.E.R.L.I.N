# Debug Checklist - GDScript Validation Protocol

## OBLIGATOIRE avant de livrer du code GDScript

### 1. Erreurs de Type Courantes

**Pattern problématique**: `:=` avec indexation de tableaux/dictionnaires

```gdscript
# ❌ ERREUR: Cannot infer type
var item := MY_ARRAY[index]
var value := MY_DICT[key]
var char := text[i]

# ✅ CORRECT: Type explicite
var item: String = MY_ARRAY[index]
var value: Dictionary = MY_DICT[key]
var char: String = text[i]
```

**Commande de recherche** pour trouver ces erreurs:
```bash
grep -rn ':= \w\+\[' scripts/*.gd
```

### 2. Patterns de Validation

| Pattern | Problème | Solution |
|---------|----------|----------|
| `var x := CONST_ARRAY[i]` | Type non inférable | `var x: Type = CONST_ARRAY[i]` |
| `var x := CONST_DICT[key]` | Type non inférable | `var x: Type = CONST_DICT[key]` |
| `var x := str[i]` | Type String non inféré | `var x: String = str[i]` |
| `draw_*()` hors `_draw()` | Ne dessine pas | Connecter au signal `draw` |

### 3. Checklist Pre-Commit

- [ ] Rechercher tous les `:= CONST[` dans le code modifié
- [ ] Vérifier que les appels `draw_*` sont dans le bon contexte
- [ ] Tester le script dans l'éditeur Godot (F5 ou clic scène)
- [ ] Vérifier la console Godot pour les erreurs de parsing

### 4. Commandes de Validation

```gdscript
# Dans l'éditeur Godot: Project > Tools > GDScript > Parser
# Ou via ligne de commande:
godot --headless --script res://path/to/script.gd --check
```

### 5. Erreurs en Cascade

Quand un script échoue à parser, tous les scripts qui en dépendent échouent aussi.
**Toujours corriger le PREMIER script en erreur**.

### 6. Debug Agent Workflow

Avant chaque livraison de code:

1. **Grep** pour patterns problématiques
2. **Read** le fichier modifié pour review
3. **Tester** mentalement le parsing GDScript
4. Signaler proactivement les corrections nécessaires

---

*Version: 1.0 - 2026-02-06*

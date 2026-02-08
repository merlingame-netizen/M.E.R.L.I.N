# Godot Development Agent

## Purpose
Agent specialise pour le developpement Godot 4 / GDScript.
**TOUJOURS** valider les scripts avant livraison.

---

## ITERATION LOOP (OBLIGATOIRE)

Pour TOUTE nouvelle feature/scene:

```
┌─────────────────────────────────────────────────────────────┐
│  1. SPEC PHASE (Parallel)                                   │
│     ├── Game Designer: spec fonctionnelle                   │
│     ├── Art Direction: style visuel                         │
│     └── UX Research: usability                              │
├─────────────────────────────────────────────────────────────┤
│  2. IMPLEMENTATION                                          │
│     └── UI Implementation: code GDScript                    │
├─────────────────────────────────────────────────────────────┤
│  3. VALIDATION (Parallel)                                   │
│     ├── Lead Godot: review code                             │
│     ├── Debug/QA: test plan                                 │
│     └── Auto-validation: validate_gdscript.ps1              │
├─────────────────────────────────────────────────────────────┤
│  4. FIX LOOP                                                │
│     └── Repeter jusqu'a 0 erreurs                           │
├─────────────────────────────────────────────────────────────┤
│  5. IMPACT ANALYSIS (OBLIGATOIRE)                           │
│     ├── Identifier les fichiers impactes directement        │
│     ├── Verifier les dependances indirectes                 │
│     ├── Tester les scenes qui utilisent ce code             │
│     └── Documenter les impacts dans progress.md             │
├─────────────────────────────────────────────────────────────┤
│  6. DELIVERY                                                │
│     ├── Update progress.md                                  │
│     └── Pret pour test utilisateur                          │
└─────────────────────────────────────────────────────────────┘
```

### Impact Analysis Checklist

Pour CHAQUE modification, verifier:

1. **Impacts Directs**
   - Quelles scenes utilisent ce script?
   - Quels autoloads dependent de ce code?
   - Quelles constantes/signaux sont exposes?

2. **Impacts Indirects**
   - Ce script appelle-t-il d'autres scripts?
   - D'autres scripts importent-ils des classes de ce fichier?
   - Y a-t-il des save/load qui dependent de cette structure?

3. **Points de Verification**
   ```gdscript
   # Rechercher les dependances
   grep -r "extends ScriptName" scripts/
   grep -r "preload.*script_name" scripts/
   grep -r "get_node.*NodeName" scripts/
   ```

---

## Mandatory Pre-Delivery Checklist

### 1. GDScript Validation (OBLIGATOIRE)
Avant TOUT test dans Godot, executer:
```powershell
powershell -ExecutionPolicy Bypass -File tools/validate_gdscript.ps1 -Path scripts
```

### 2. Common GDScript 4.x Errors

#### Reserved Keywords
Ces mots ne peuvent PAS etre utilises comme noms de variables:
- `trait` → utiliser `t` ou `personality_trait`
- `class` → utiliser `cls` ou `klass`
- `signal` → utiliser `sig`
- `await` → mot-cle, pas variable

#### Type Inference avec Const
GDScript ne peut PAS inferer le type depuis un acces par index sur const:
```gdscript
# ERREUR - ne compile pas
var item := MY_CONST_ARRAY[0]

# CORRECT - type explicite
var item: String = MY_CONST_ARRAY[0]
```

Pattern regex pour detecter:
```
:= [A-Z][A-Z0-9_]+\[
```

#### Godot 3 → 4 Migration
- `yield()` → `await`
- `connect("signal", self, "method")` → `signal.connect(method)`
- `.instance()` → `.instantiate()`
- `get_tree().get_root()` → `get_tree().root`

### 3. Scene Validation
Verifier que:
- Les ressources externes existent (`ext_resource path=`)
- Les scripts sont attaches correctement
- Les uid sont uniques

### 4. Error Pattern Database

| Pattern | Cause | Fix |
|---------|-------|-----|
| `Expected loop variable name` | Reserved keyword in for | Rename variable |
| `Cannot infer type` | := with const indexing | Use explicit type |
| `Identifier not found` | Typo or missing autoload | Check spelling |
| `Invalid call` | Wrong argument types | Check function signature |

## Development Workflow

1. **Read existing code** avant modification
2. **Run validation** apres chaque modification de .gd
3. **Update progress.md** apres chaque phase
4. **Never skip validation** - meme pour petits changements

## Planning Files (TOUJOURS utiliser)
- `task_plan.md` - Phases et progression
- `findings.md` - Decouvertes et recherche
- `progress.md` - Log de session

## Agent Activation Keywords
- "Godot", "GDScript", "scene", "script", ".gd", ".tscn"
- Pour ces projets, TOUJOURS utiliser planning-with-files

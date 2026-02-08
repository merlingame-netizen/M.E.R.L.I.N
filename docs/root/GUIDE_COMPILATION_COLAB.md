# 🧙‍♂️ Guide de Compilation via Google Colab

## 📦 Étape 1: Préparer le ZIP

Sur votre PC, créez un ZIP avec cette structure:

```
merlin_llm_sources.zip
├── src/
│   ├── merlin_llm.cpp
│   └── register_types.cpp
├── CMakeLists.txt
├── godot-cpp/        (dossier complet clonés)
└── llama.cpp/        (dossier complet clonés)
```

### Comment créer le ZIP:

**Option A: Depuis votre dossier `native/`**

```batch
cd c:\Users\PGNK2128\Godot-MCP\native
```

Créez un ZIP contenant:
- Le dossier `src/`
- Le fichier `CMakeLists.txt`
- Le dossier `godot-cpp/` (complet)
- Le dossier `llama.cpp/` (complet)

**Option B: Script PowerShell automatique**

```powershell
# Exécutez depuis c:\Users\PGNK2128\Godot-MCP\native
Compress-Archive -Path src, CMakeLists.txt, godot-cpp, llama.cpp -DestinationPath ..\merlin_llm_sources.zip -Force
```

---

## ☁️ Étape 2: Ouvrir Google Colab

1. Allez sur: https://colab.research.google.com/
2. **Fichier** → **Importer un notebook**
3. **Upload** → Sélectionnez `Compile_MerlinLLM_Colab.ipynb`

---

## ▶️ Étape 3: Exécuter la Compilation

**IMPORTANT**: Exécutez les cellules **dans l'ordre**, une par une.

### Cellule 1: Installation des outils
- Installe MinGW-w64 (compilateur Windows sur Linux)
- Installe CMake, Ninja, etc.
- ⏱️ Durée: ~2 minutes

### Cellule 2: Upload du ZIP
- **Cliquez sur "Choisir les fichiers"**
- Sélectionnez votre `merlin_llm_sources.zip`
- ⏱️ Durée: ~1-5 minutes (selon taille)

### Cellule 3: Vérification
- Vérifie que tous les fichiers sont présents
- ⏱️ Durée: ~5 secondes

### Cellule 4: Compilation godot-cpp
- Compile godot-cpp pour Windows
- ⏱️ Durée: ~5-10 minutes
- ⚠️ **Peut afficher des warnings** (normal)

### Cellule 5: Compilation llama.cpp
- Compile llama.cpp pour Windows
- ⏱️ Durée: ~3-5 minutes

### Cellule 6: Application des paramètres Colab
- Modifie `merlin_llm.cpp` avec:
  - `n_ctx = 8192`
  - `max_tokens = 256`
  - `temperature = 0.7`
  - `top_k = 50`
  - `repetition_penalty = 1.1`
- ⏱️ Durée: ~1 seconde

### Cellule 7: Compilation merlin_llm.dll
- Compile la DLL finale
- ⏱️ Durée: ~2-3 minutes

### Cellule 8: Téléchargement
- **Télécharge automatiquement** `merlin_llm_compiled.zip`
- Contient la DLL compilée

---

## 📥 Étape 4: Installer la DLL

1. **Décompressez** `merlin_llm_compiled.zip`
2. **Copiez** `merlin_llm.windows.release.x86_64.dll`
3. **Collez** dans:
   ```
   c:\Users\PGNK2128\Godot-MCP\addons\merlin_llm\bin\
   ```
4. **Remplacez** l'ancienne DLL si demandé

---

## 🧪 Étape 5: Tester dans Godot

1. **Fermez Godot** si ouvert
2. **Relancez Godot**
3. **Ouvrez** `TestMerlinGBA.tscn`
4. **Lancez la scène** (F5)

### Tests à faire:

#### Test 1: Longueur des réponses
**Prompt**: "Décris la magie en détails"
- **Avant**: ~50-100 mots
- **Après**: 200-350 mots avec liste complète

#### Test 2: Variété
**Prompt** (3 fois): "Où devrais-je aller?"
- **Avant**: Réponses identiques
- **Après**: 3 réponses différentes

#### Test 3: Stabilité
**Conversation longue**: 10+ échanges
- **Avant**: `llama_decode failed` après 2-3 échanges
- **Après**: Aucune erreur, contexte stable

---

## ⚠️ Dépannage

### ❌ "godot-cpp compilation failed"

**Problème**: godot-cpp n'a pas SCons installé

**Solution**: Ajoutez cette cellule AVANT la cellule 4:
```python
!pip install scons
```

### ❌ "DLL non générée"

**Problème**: Erreur de linkage

**Solution**:
1. Vérifiez que `godot-cpp` et `llama.cpp` sont compilés
2. Regardez les logs pour les erreurs de compilation
3. Vérifiez que le ZIP contient bien tous les fichiers

### ❌ Upload du ZIP échoue

**Problème**: ZIP trop volumineux (>100 MB)

**Solution**:
- Ne pas inclure les dossiers `build/` ou `bin/`
- Compresser seulement les sources

### ❌ Godot ne charge pas la DLL

**Problème**: Architecture incompatible

**Solution**:
- Vérifiez que Godot est en 64-bit
- Vérifiez que la DLL est bien en `x86_64`
- Regardez les logs Godot pour l'erreur exacte

---

## 🎯 Résultat Attendu

### Comparaison Avant/Après

| Aspect | Avant ❌ | Après ✅ |
|--------|---------|---------|
| **Longueur réponses** | 50-100 mots | 200-350 mots |
| **Créativité** | 3/10 (robotique) | 8/10 (naturel) |
| **Répétitions** | Fréquentes | Rares |
| **Erreurs contexte** | Après 2-3 échanges | Jamais (8192 tokens) |
| **Détails** | Réponses courtes | Listes 5-10 points |
| **Stabilité** | 5/10 | 10/10 |

---

## 💡 Astuces

- **Première fois**: Prenez 15-20 minutes pour tout compiler
- **Ré-compilation**: Gardez le ZIP, vous pouvez relancer Colab
- **Modifications**: Pour changer les paramètres, modifiez la Cellule 6
- **Sauvegarde**: Google Colab peut perdre les données après 12h inactivité

---

## 📝 Fichiers Créés

```
c:\Users\PGNK2128\Godot-MCP\
├── Compile_MerlinLLM_Colab.ipynb      (notebook Colab)
├── GUIDE_COMPILATION_COLAB.md         (ce guide)
└── merlin_llm_sources.zip             (à créer)
```

Après compilation:
```
addons\merlin_llm\bin\
└── merlin_llm.windows.release.x86_64.dll  (nouveau!)
```

---

## 🚀 C'est Parti!

1. ✅ Créez le ZIP (Étape 1)
2. ✅ Ouvrez Colab (Étape 2)
3. ✅ Exécutez les cellules (Étape 3)
4. ✅ Installez la DLL (Étape 4)
5. ✅ Testez! (Étape 5)

**Bonne compilation!** 🧙‍♂️✨

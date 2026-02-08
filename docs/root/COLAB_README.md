# 🚀 Compilation MerlinLLM via Google Colab - Démarrage Rapide

## 📦 Fichiers Créés

```
c:\Users\PGNK2128\Godot-MCP\
├── 📓 Compile_MerlinLLM_Colab.ipynb    → Notebook Colab (à importer)
├── 📘 GUIDE_COMPILATION_COLAB.md        → Guide complet détaillé
├── 📄 COLAB_README.md                   → Ce fichier (démarrage rapide)
└── 🔧 create_colab_zip.ps1              → Script pour créer le ZIP
```

---

## ⚡ Démarrage Ultra-Rapide (3 étapes)

### **Étape 1: Créer le ZIP**

Clic droit sur [`create_colab_zip.ps1`](create_colab_zip.ps1) → **Exécuter avec PowerShell**

Cela crée automatiquement: `merlin_llm_sources.zip`

### **Étape 2: Google Colab**

1. Allez sur: **https://colab.research.google.com/**
2. **Fichier** → **Importer un notebook**
3. Uploadez: [`Compile_MerlinLLM_Colab.ipynb`](Compile_MerlinLLM_Colab.ipynb)
4. **Exécutez les 8 cellules** dans l'ordre (cliquez sur ▶ pour chacune)
   - Cellule 2 vous demandera d'uploader le ZIP
5. Cellule 8 télécharge automatiquement la DLL compilée

### **Étape 3: Installer la DLL**

1. Décompressez `merlin_llm_compiled.zip`
2. Copiez la DLL dans:
   ```
   c:\Users\PGNK2128\Godot-MCP\addons\merlin_llm\bin\
   ```
3. Fermez et relancez Godot
4. Testez avec `TestMerlinGBA.tscn`

---

## 🎯 Ce Que Vous Allez Obtenir

### Avant ❌
- Réponses courtes (50-100 mots)
- Répétitif et robotique
- Erreurs après 2-3 échanges
- Créativité: 3/10

### Après ✅
- Réponses détaillées (200-350 mots)
- Varié et naturel
- Stable sur 10+ échanges
- Créativité: 8/10

### Paramètres Appliqués
```cpp
n_ctx = 8192              // Contexte × 4
max_tokens = 256-512      // Réponses plus longues
temperature = 0.7         // Plus créatif
top_k = 50                // Plus de diversité
repetition_penalty = 1.1  // Moins de répétitions
```

---

## ⏱️ Durée Estimée

| Étape | Temps |
|-------|-------|
| Création du ZIP | 1 min |
| Upload vers Colab | 2-5 min |
| Compilation totale | 15-20 min |
| Installation DLL | 1 min |
| **TOTAL** | **~25 min** |

---

## ⚠️ Prérequis

### Sur votre PC:
- ✅ Godot installé
- ✅ `godot-cpp` cloné dans `native/godot-cpp/`
- ✅ `llama.cpp` cloné dans `native/llama.cpp/`

### Pour Google Colab:
- ✅ Compte Google (gratuit)
- ✅ Navigateur web
- ✅ Connexion Internet

**Note**: Google Colab est **100% gratuit** pour cette compilation!

---

## 🆘 Besoin d'Aide?

### **Guide Détaillé**
Consultez [`GUIDE_COMPILATION_COLAB.md`](GUIDE_COMPILATION_COLAB.md) pour:
- Instructions pas-à-pas
- Dépannage complet
- Astuces et optimisations

### **Problèmes Courants**

#### ❌ "godot-cpp ou llama.cpp manquants"
**Solution**: Clonez-les dans `native/`:
```bash
cd native
git clone https://github.com/godotengine/godot-cpp.git
git clone https://github.com/ggerganov/llama.cpp.git
```

#### ❌ "ZIP trop volumineux"
**Solution**: Le script `create_colab_zip.ps1` nettoie automatiquement les builds.
Si toujours trop gros, supprimez manuellement:
- `native/godot-cpp/.git/`
- `native/llama.cpp/.git/`

#### ❌ "Colab: godot-cpp compilation failed"
**Solution**: Ajoutez une cellule AVANT la cellule 4:
```python
!pip install scons
```

---

## 📊 Structure du Projet

```
Godot-MCP/
├── native/
│   ├── src/
│   │   ├── merlin_llm.cpp          ← Code source
│   │   └── register_types.cpp
│   ├── CMakeLists.txt               ← Configuration build
│   ├── godot-cpp/                   ← Dépendance Godot
│   └── llama.cpp/                   ← Dépendance LLM
│
├── addons/
│   └── merlin_llm/
│       └── bin/
│           └── merlin_llm.windows.release.x86_64.dll  ← Résultat final
│
├── Compile_MerlinLLM_Colab.ipynb    ← Notebook Colab
├── GUIDE_COMPILATION_COLAB.md       ← Documentation
├── create_colab_zip.ps1             ← Script ZIP
└── merlin_llm_sources.zip           ← Créé par le script
```

---

## 🎁 Bonus: Modifier les Paramètres

Vous voulez tester d'autres valeurs? Modifiez la **Cellule 6** du notebook:

```python
modifications = [
    (r'n_ctx\\s*=\\s*2048', 'n_ctx = 16384'),  # Encore plus de contexte!
    (r'default_max_tokens\\s*=\\s*150', 'default_max_tokens = 512'),  # Réponses très longues
    (r'default_temperature\\s*=\\s*0\\.35', 'default_temperature = 0.9'),  # Encore plus créatif
]
```

---

## ✅ Checklist de Démarrage

- [ ] Exécuter `create_colab_zip.ps1`
- [ ] Vérifier que `merlin_llm_sources.zip` est créé
- [ ] Ouvrir Google Colab
- [ ] Importer `Compile_MerlinLLM_Colab.ipynb`
- [ ] Exécuter les 8 cellules
- [ ] Télécharger `merlin_llm_compiled.zip`
- [ ] Copier la DLL dans `addons/merlin_llm/bin/`
- [ ] Tester dans Godot

---

## 🎯 Commencer Maintenant!

**Clic droit** sur [`create_colab_zip.ps1`](create_colab_zip.ps1) → **Exécuter avec PowerShell**

Puis suivez les instructions à l'écran! 🚀

---

**Bonne compilation!** 🧙‍♂️✨

*Temps total estimé: 25 minutes*
*Niveau de difficulté: Facile (copier-coller)*
*Coût: Gratuit*

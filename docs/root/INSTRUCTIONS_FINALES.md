# 🎯 Instructions Finales - LLM Simple

## ✅ Ce qui a été créé

Un **notebook Colab tout-en-un** qui crée et compile tout automatiquement!

**Fichier:** [Compile_LLM_Simple_AllInOne.ipynb](Compile_LLM_Simple_AllInOne.ipynb)

---

## 🚀 Utilisation (Ultra Simple)

### Étape 1: Ouvrir Colab

https://colab.research.google.com

---

### Étape 2: Upload le Notebook

1. **File** → **Upload notebook**
2. Sélectionner: `Compile_LLM_Simple_AllInOne.ipynb`

---

### Étape 3: Exécuter

**Un seul clic:** **Runtime** → **Run all**

⏱️ **Durée:** 10-15 minutes

**Ensuite le notebook va:**
1. ✅ Installer les outils
2. ✅ Créer les fichiers C++ (pas d'upload!)
3. ✅ Télécharger godot-cpp
4. ✅ Télécharger llama.cpp
5. ✅ Compiler godot-cpp (~8 min)
6. ✅ Compiler llm_simple (~2 min)
7. ✅ Packager
8. 📥 **Télécharger** `llm_simple_addon.zip`

---

### Étape 4: Installation

1. **Extraire** `llm_simple_addon.zip`
2. **Copier** `addons/llm_simple` dans:
   ```
   c:\Users\PGNK2128\Godot-MCP\addons\llm_simple\
   ```
3. **Copier** `TestLLMSimple.gd` dans la racine du projet

---

### Étape 5: Télécharger un Modèle

**Lien:** https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf

**Fichier:** `Phi-3-mini-4k-instruct-q4.gguf` (~2.3 GB)

**Placer dans:**
```
c:\Users\PGNK2128\Godot-MCP\models\phi-3-mini-3b.gguf
```

---

### Étape 6: Tester

1. Redémarrer Godot
2. Créer une scène
3. Attacher `TestLLMSimple.gd`
4. Lancer! 🎮

---

## 📦 Contenu de l'Addon

```
addons/llm_simple/
├── bin/
│   ├── llm_simple.windows.template_release.x86_64.dll  ← Votre extension
│   ├── llama.dll                                        ← llama.cpp
│   └── ggml.dll                                         ← ggml
├── llm_simple.gdextension
└── README.txt
```

---

## 💡 API Simple

```gdscript
var llm = LLMSimple.new()
add_child(llm)

# Charger modèle
llm.load_model("res://models/phi-3-mini-3b.gguf", 8192)

# Générer
var response = llm.generate("Bonjour!", 256)
print(response)

# Décharger
llm.unload_model()
```

---

## 🎮 Exemples d'Utilisation

### NPC Intelligent
```gdscript
var llm = LLMSimple.new()

func talk_to_npc(player_message: String):
    var prompt = "Tu es un marchand. Joueur: " + player_message
    return llm.generate(prompt, 150)
```

### Génération de Quête
```gdscript
func create_quest(theme: String):
    var prompt = "Crée une quête courte sur: " + theme
    return llm.generate(prompt, 300)
```

### Assistant
```gdscript
func help_player(question: String):
    var prompt = "Question: " + question + "\nRéponse:"
    return llm.generate(prompt, 100)
```

---

## 📊 Performance

**Vitesse typique:**
- CPU i5/i7: 5-15 tokens/seconde
- CPU haut de gamme: 15-30 tokens/seconde

**Exemple:** Générer 200 tokens = 10-40 secondes

---

## 🎯 Avantages

| Aspect | Valeur |
|--------|--------|
| **Code** | 300 lignes C++ |
| **Patchs** | 0 |
| **Upload** | 0 fichier |
| **Compilation** | 10-15 min |
| **Complexité** | Ultra simple |
| **Fiabilité** | DLLs officielles |

---

## 🆘 Dépannage

### "Failed to load model"
- Vérifier chemin: `res://models/model.gguf`
- Vérifier format: doit être `.gguf`

### "DLL not found"
- Vérifier présence des 3 DLLs dans `bin/`
- Re-extraire le ZIP

### Génération lente
- Utiliser modèle Q4 quantifié
- Réduire `max_tokens`
- Réduire `context_size`

---

## 🎉 C'est Tout!

**Un seul notebook, aucun upload, compilation automatique!**

**Prochaines étapes:**
1. ✅ Upload notebook sur Colab
2. ✅ Cliquer "Run all"
3. ✅ Attendre 15 minutes
4. ✅ Télécharger le ZIP
5. 🎮 Utiliser dans Godot!

---

**Amusez-vous bien! 🚀**

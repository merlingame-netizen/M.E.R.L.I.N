# 🚀 LLM Simple pour Godot - Guide Complet

Extension GDExtension **ultra-simple** pour utiliser des modèles LLM (Large Language Models) dans Godot 4.

---

## ✨ Caractéristiques

- ✅ **Ultra Simple**: ~300 lignes de C++ total
- ✅ **Rapide**: Compilation 5-10 minutes sur Colab
- ✅ **Pas de Patchs**: Utilise llama.cpp précompilé officiel
- ✅ **Interface Claire**: 3 méthodes principales
- ✅ **Modèles 3B**: Compatible Phi-3, Llama-3, etc.
- ✅ **Gratuit**: Compilation sur Google Colab gratuit

---

## 📁 Structure du Projet

```
Godot-MCP/
├── llm_simple/                      ← Code source
│   ├── include/llm_simple.h
│   ├── src/llm_simple.cpp
│   ├── src/register_types.cpp
│   └── CMakeLists.txt
│
├── addons/llm_simple/               ← Addon Godot
│   ├── llm_simple.gdextension
│   └── bin/                         ← DLLs après compilation
│       ├── llm_simple.windows.x86_64.dll
│       ├── llama.dll
│       └── ggml.dll
│
├── models/                          ← Vos modèles GGUF
│   └── phi-3-mini-3b.gguf
│
├── Compile_LLM_Simple.ipynb         ← Notebook Colab
├── create_llm_simple_package.bat    ← Script packaging
└── TestLLMSimple.gd                 ← Script de test
```

---

## 🔧 Compilation

### Étape 1: Préparer le Package

**Ouvrir CMD:**
```batch
cd c:\Users\PGNK2128\Godot-MCP
create_llm_simple_package.bat
```

**Résultat:** `llm_simple_sources.tar.gz` créé (~10-50 MB)

---

### Étape 2: Compiler sur Google Colab

1. **Ouvrir** https://colab.research.google.com
2. **Upload** `Compile_LLM_Simple.ipynb`
3. **Exécuter** toutes les cellules:
   - Cellule 1: Installation outils
   - Cellule 2: Upload `llm_simple_sources.tar.gz`
   - Cellule 3: Télécharger llama.cpp officiel
   - Cellule 4: Compiler godot-cpp (5-8 min)
   - Cellule 5: Compiler llm_simple (2 min)
   - Cellule 6: Télécharger `llm_simple_addon.zip`

**Durée totale:** ~10-15 minutes

---

### Étape 3: Installation dans Godot

1. **Extraire** `llm_simple_addon.zip`
2. **Copier** le dossier `addons/llm_simple` dans votre projet:
   ```
   c:\Users\PGNK2128\Godot-MCP\addons\llm_simple\
   ```
3. **Redémarrer Godot**

---

## 📥 Télécharger un Modèle

### Modèles Recommandés (3B paramètres)

**Phi-3-mini-4k-instruct** (Recommandé):
```
https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf
```
Télécharger: `Phi-3-mini-4k-instruct-q4.gguf` (~2.3 GB)

**Llama-3.2-3B**:
```
https://huggingface.co/lmstudio-community/Llama-3.2-3B-Instruct-GGUF
```
Télécharger: `Llama-3.2-3B-Instruct-Q4_K_M.gguf` (~1.9 GB)

### Placement

Créer le dossier:
```
c:\Users\PGNK2128\Godot-MCP\models\
```

Placer le fichier `.gguf` dedans.

---

## 🎮 Utilisation

### Exemple Simple

**Script:** `TestLLM.gd`
```gdscript
extends Node

var llm: LLMSimple

func _ready():
    llm = LLMSimple.new()
    add_child(llm)

    # Charger modèle
    if llm.load_model("res://models/phi-3-mini-3b.gguf", 8192):
        print("Modèle chargé!")

        # Générer texte
        var response = llm.generate("Bonjour! Qui es-tu?", 256)
        print(response)
    else:
        print("Erreur: ", llm.get_last_error())

func _exit_tree():
    if llm:
        llm.unload_model()
```

---

### API Complète

#### Méthodes Principales

**`load_model(path: String, context_size: int = 8192) -> bool`**
- Charge un modèle GGUF
- `path`: Chemin vers le fichier .gguf
- `context_size`: Taille du contexte en tokens (2048-32768)
- Retourne `true` si succès

**`generate(prompt: String, max_tokens: int = 256) -> String`**
- Génère du texte
- `prompt`: Texte d'entrée
- `max_tokens`: Nombre maximum de tokens à générer
- Retourne le texte généré

**`unload_model()`**
- Décharge le modèle de la mémoire
- Libère les ressources

#### Getters

- `is_model_loaded() -> bool`: Modèle chargé?
- `get_last_error() -> String`: Dernière erreur
- `get_context_size() -> int`: Taille du contexte

#### Configuration (À implémenter)

- `set_temperature(float)`: Créativité (0.0-2.0)
- `set_top_k(int)`: Diversité vocabulaire
- `set_top_p(float)`: Sampling nucléaire
- `set_repeat_penalty(float)`: Pénalité répétitions

#### Signaux

```gdscript
signal generation_started()
signal generation_finished(text: String)
signal generation_error(error: String)
```

**Exemple avec signaux:**
```gdscript
func _ready():
    llm = LLMSimple.new()
    add_child(llm)

    llm.generation_started.connect(_on_gen_start)
    llm.generation_finished.connect(_on_gen_finish)
    llm.generation_error.connect(_on_gen_error)

    llm.load_model("res://models/model.gguf")
    llm.generate("Hello!", 100)

func _on_gen_start():
    print("Génération...")

func _on_gen_finish(text: String):
    print("Résultat: ", text)

func _on_gen_error(error: String):
    print("Erreur: ", error)
```

---

## 💡 Cas d'Usage

### 1. NPC avec Dialogue Dynamique

```gdscript
extends NPC

var llm: LLMSimple
var character_prompt = "Tu es un marchand dans un RPG médiéval."

func _ready():
    llm = LLMSimple.new()
    add_child(llm)
    llm.load_model("res://models/phi-3-mini-3b.gguf", 4096)

func talk_to_player(player_message: String):
    var full_prompt = character_prompt + "\nJoueur: " + player_message + "\nMarchand:"
    var response = llm.generate(full_prompt, 150)
    show_dialog(response)
```

### 2. Génération de Quêtes

```gdscript
func generate_quest(theme: String, difficulty: String):
    var prompt = "Crée une quête " + difficulty + " sur le thème: " + theme
    var quest_text = llm.generate(prompt, 300)
    create_quest_from_text(quest_text)
```

### 3. Assistant de Jeu

```gdscript
func help_player(question: String):
    var prompt = "Question du joueur: " + question + "\nRéponse courte:"
    return llm.generate(prompt, 100)
```

---

## ⚙️ Configuration Avancée

### Optimisation Mémoire

**Modèles Quantifiés:**
- `Q4_K_M`: ~2 GB RAM, bon compromis
- `Q5_K_M`: ~2.5 GB RAM, meilleure qualité
- `Q8_0`: ~3.5 GB RAM, qualité maximale

**Taille Contexte:**
```gdscript
# Petit contexte = moins de RAM
llm.load_model(path, 2048)  # 2K tokens

# Grand contexte = dialogues longs
llm.load_model(path, 16384) # 16K tokens
```

---

## 🐛 Dépannage

### "Failed to load model"

**Vérifier:**
- ✅ Chemin correct: `res://models/model.gguf`
- ✅ Fichier existe et n'est pas corrompu
- ✅ Format GGUF (pas GPTQ, AWQ, etc.)

**Solution:**
```gdscript
if not llm.load_model(path):
    print("Erreur: ", llm.get_last_error())
```

---

### "DLL not found"

**Vérifier:**
```
addons/llm_simple/bin/
├── llm_simple.windows.x86_64.dll ✅
├── llama.dll ✅
└── ggml.dll ✅
```

**Solution:** Re-compiler ou re-extraire le ZIP

---

### Génération Lente

**Optimisations:**
1. Utiliser modèle quantifié (Q4_K_M)
2. Réduire `max_tokens`
3. Réduire `context_size`
4. Fermer autres applications

**Vitesse typique:**
- CPU i5/i7: 5-15 tokens/seconde
- CPU haut de gamme: 15-30 tokens/seconde

---

## 🔮 Extensions Futures

Vous pouvez facilement ajouter:

### Streaming Token par Token

Modifier `llm_simple.cpp` pour émettre chaque token:
```cpp
emit_signal("token_generated", String::utf8(buf, n));
```

### Multi-Threading

Générer en background:
```cpp
std::thread gen_thread([this]() {
    // Génération
});
```

### Gestion Conversation

Ajouter historique:
```gdscript
var history = []

func chat(message: String):
    history.append({"role": "user", "content": message})
    var prompt = format_history(history)
    var response = llm.generate(prompt, 200)
    history.append({"role": "assistant", "content": response})
    return response
```

---

## 📊 Comparaison avec Approche Précédente

| Aspect | Ancienne (MerlinLLM) | **LLM Simple** |
|--------|----------------------|----------------|
| Lignes de code | ~10,000 | **~300** |
| Patchs requis | 6+ fichiers | ❌ **Aucun** |
| Temps compilation | 30-45 min | **5-10 min** |
| Complexité | Très élevée | **Très faible** |
| Erreurs MinGW | Nombreuses | **Aucune** |
| Maintenance | Difficile | **Facile** |
| Extensible | ✅ | ✅ |

---

## 📄 Licence

- **llm_simple**: Code libre (MIT)
- **llama.cpp**: MIT License
- **godot-cpp**: MIT License

---

## 🙏 Crédits

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - Georgi Gerganov
- [Godot Engine](https://godotengine.org/) - Godot Community
- [Phi-3](https://huggingface.co/microsoft/Phi-3-mini-4k-instruct) - Microsoft

---

## 🚀 Prochaines Étapes

1. ✅ Compiler l'extension
2. ✅ Télécharger un modèle
3. ✅ Tester avec `TestLLMSimple.gd`
4. 🎮 Intégrer dans votre jeu!

**Amusez-vous bien!** 🎉

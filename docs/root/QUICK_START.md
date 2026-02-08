# ⚡ Démarrage Rapide - LLM Simple

## 🎯 En 3 Étapes

### 1️⃣ Compiler (10 minutes)

```batch
# Dans CMD
cd c:\Users\PGNK2128\Godot-MCP
create_llm_simple_package.bat
```

➡️ Upload `llm_simple_sources.tar.gz` sur Colab
➡️ Exécuter [Compile_LLM_Simple.ipynb](Compile_LLM_Simple.ipynb)
➡️ Télécharger `llm_simple_addon.zip`

---

### 2️⃣ Installer

```
1. Extraire llm_simple_addon.zip
2. Copier addons/llm_simple/ dans votre projet
3. Télécharger modèle: https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf
4. Placer dans: models/phi-3-mini-3b.gguf
5. Redémarrer Godot
```

---

### 3️⃣ Utiliser

**Créer: `test_llm.gd`**
```gdscript
extends Node

func _ready():
    var llm = LLMSimple.new()
    add_child(llm)

    if llm.load_model("res://models/phi-3-mini-3b.gguf", 8192):
        var response = llm.generate("Bonjour!", 100)
        print(response)
```

---

## 🎮 C'est Tout!

Vous avez maintenant un LLM qui tourne dans Godot!

### Prochaines Idées

- 💬 **NPC intelligents**: Dialogues dynamiques
- 📜 **Génération quêtes**: Contenu procédural
- 🎭 **Narration adaptative**: Histoire qui réagit au joueur
- 🧠 **Assistant jeu**: Aide contextuelle

---

## 📚 Documentation Complète

Voir [LLM_SIMPLE_README.md](LLM_SIMPLE_README.md) pour:
- API détaillée
- Exemples avancés
- Configuration
- Dépannage

---

**Bon jeu! 🚀**

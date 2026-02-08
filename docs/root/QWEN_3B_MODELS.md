# 🤖 Qwen2.5-3B - Modèles Recommandés

## ✅ Qwen2.5-3B-Instruct (RECOMMANDÉ)

### Lien Officiel
**HuggingFace:** https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF

### Fichiers à Télécharger

**Format Q4 (Recommandé - Meilleur compromis):**
- **Fichier:** `qwen2.5-3b-instruct-q4_k_m.gguf`
- **Taille:** ~2.0 GB
- **RAM:** ~3-4 GB
- **Qualité:** Excellente
- **Lien direct:** https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf

**Format Q5 (Meilleure qualité):**
- **Fichier:** `qwen2.5-3b-instruct-q5_k_m.gguf`
- **Taille:** ~2.4 GB
- **RAM:** ~4-5 GB
- **Qualité:** Supérieure

**Format Q8 (Qualité maximale):**
- **Fichier:** `qwen2.5-3b-instruct-q8_0.gguf`
- **Taille:** ~3.4 GB
- **RAM:** ~5-6 GB
- **Qualité:** Maximale

---

## 📥 Téléchargement

### Méthode 1: Navigateur
1. Aller sur https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF
2. Cliquer sur "Files and versions"
3. Télécharger `qwen2.5-3b-instruct-q4_k_m.gguf`

### Méthode 2: Ligne de commande
```batch
wget https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf
```

---

## 📂 Installation

### Placer le Modèle
```
c:\Users\PGNK2128\Godot-MCP\models\qwen2.5-3b.gguf
```

### Utilisation dans Godot
```gdscript
extends Node

var llm: LLMSimple

func _ready():
    llm = LLMSimple.new()
    add_child(llm)

    # Charger Qwen2.5-3B
    if llm.load_model("res://models/qwen2.5-3b.gguf", 8192):
        print("✅ Qwen2.5-3B chargé!")

        # Test
        var response = llm.generate("Bonjour! Qui es-tu?", 256)
        print(response)
```

---

## 🎯 Caractéristiques Qwen2.5-3B

### Avantages
- ✅ **Multilingue**: Excellent en français, anglais, chinois
- ✅ **Rapide**: 3B paramètres = génération rapide
- ✅ **Intelligent**: Performances comparables à des modèles 7B
- ✅ **Contexte**: Supporte jusqu'à 128K tokens (on utilise 8K par défaut)
- ✅ **Instructions**: Spécialement entraîné pour suivre des instructions

### Performance Typique
- **CPU i5/i7**: 8-15 tokens/seconde
- **CPU haut de gamme**: 15-25 tokens/seconde
- **Génération 200 tokens**: 10-25 secondes

### Cas d'Usage
- 💬 Dialogues NPC naturels
- 📜 Génération de contenu
- 🎭 Narration dynamique
- 🧠 Assistant intelligent
- 📝 Traduction en temps réel

---

## 📊 Comparaison avec Phi-3-mini

| Aspect | Qwen2.5-3B | Phi-3-mini-3B |
|--------|------------|---------------|
| **Multilingue** | ✅ Excellent | ⚠️ Anglais principalement |
| **Français** | ✅ Natif | ⚠️ Correct |
| **Contexte max** | 128K tokens | 4K tokens |
| **Performance** | ✅ Rapide | ✅ Rapide |
| **Qualité** | ✅ Excellente | ✅ Très bonne |
| **Taille Q4** | ~2.0 GB | ~2.3 GB |

**Recommandation:** **Qwen2.5-3B** si vous voulez du multilingue, **Phi-3-mini** si anglais uniquement suffit.

---

## 🔧 Paramètres Optimaux

### Créativité Élevée (Histoires, dialogues)
```gdscript
llm.set_temperature(0.8)  # Plus créatif
llm.set_top_k(50)
llm.set_top_p(0.95)
```

### Précision (Informations factuelles)
```gdscript
llm.set_temperature(0.3)  # Plus précis
llm.set_top_k(30)
llm.set_top_p(0.9)
```

### Équilibré (Par défaut)
```gdscript
llm.set_temperature(0.7)
llm.set_top_k(50)
llm.set_top_p(0.95)
```

---

## 💡 Exemples de Prompts

### NPC Médiéval
```gdscript
var prompt = """Tu es un marchand dans une taverne médiévale.
Joueur: Bonjour, qu'as-tu à vendre?
Marchand:"""

var response = llm.generate(prompt, 150)
```

### Génération de Quête
```gdscript
var prompt = """Crée une courte quête de RPG médiéval sur le thème:
dragons anciens. Inclus: objectif, lieu, récompense."""

var quest = llm.generate(prompt, 300)
```

### Assistant de Jeu
```gdscript
var prompt = """Le joueur demande: Comment fabriquer une épée en fer?
Réponse courte et claire:"""

var help = llm.generate(prompt, 100)
```

---

## 🆘 Troubleshooting

### "Failed to load model"
- ✅ Vérifier chemin: `res://models/qwen2.5-3b.gguf`
- ✅ Vérifier format: doit être `.gguf`
- ✅ Vérifier téléchargement complet (2.0 GB)

### Génération lente
- ⚡ Utiliser Q4 au lieu de Q8
- ⚡ Réduire `max_tokens`
- ⚡ Réduire `context_size` à 4096

### Réponses bizarres
- 🎛️ Ajuster `temperature` (0.3-0.9)
- 🎛️ Augmenter `repeat_penalty`
- 🎛️ Améliorer le prompt (plus de contexte)

---

## 📚 Ressources

- **Documentation Qwen:** https://qwenlm.github.io/
- **GitHub Qwen:** https://github.com/QwenLM/Qwen2.5
- **Exemples GGUF:** https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF

---

## 🎉 Résumé

**Télécharger:** `qwen2.5-3b-instruct-q4_k_m.gguf` (~2 GB)

**Placer dans:** `models/qwen2.5-3b.gguf`

**Utiliser:**
```gdscript
llm.load_model("res://models/qwen2.5-3b.gguf", 8192)
var r = llm.generate("Hello!", 256)
```

**Profitez-en! 🚀**

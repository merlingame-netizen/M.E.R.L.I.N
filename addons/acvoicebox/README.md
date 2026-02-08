# ACVoicebox - Voix Animal Crossing pour Godot 4

Generateur de voix style Animal Crossing (Animalese) pour Godot 4.
Utilise des samples audio pour chaque lettre, produisant un son chaleureux et expressif.

## Installation

### 1. Installer les sons

**Option A - Automatique (Windows):**
```
Double-cliquez sur INSTALL_SOUNDS.bat
```

**Option B - Manuel:**
Telechargez les fichiers .wav depuis:
https://github.com/mattmarch/ACVoicebox/tree/master/Sounds

Placez-les dans le dossier `addons/acvoicebox/sounds/`

### 2. Activer le plugin

1. Dans Godot: Projet > Parametres du projet > Extensions
2. Activez "ACVoicebox"

## Utilisation

### Methode simple (script)
```gdscript
var voicebox = preload("res://addons/acvoicebox/acvoicebox.tscn").instantiate()
add_child(voicebox)
voicebox.play_string("Bonjour! Comment ca va?")
```

### Avec synchronisation texte
```gdscript
@onready var label: RichTextLabel = $DialogueLabel
@onready var voice: ACVoicebox = $ACVoicebox

func _ready():
    voice.text_label = label
    voice.characters_sounded.connect(_on_character)
    voice.finished_phrase.connect(_on_finished)

func speak(text: String):
    voice.play_string(text)
```

## Parametres

| Parametre | Plage | Description |
|-----------|-------|-------------|
| base_pitch | 2.0 - 5.0 | Hauteur de base (3.5 = normal) |
| pitch_variation | 0.0 - 1.0 | Variation melodique |
| speed_scale | 0.5 - 2.0 | Vitesse de lecture |

## Presets

```gdscript
voicebox.apply_preset("Merlin")  # Voix sage
voicebox.apply_preset("Enfant")  # Voix aigue
voicebox.apply_preset("Grave")   # Voix grave
voicebox.apply_preset("Joyeux")  # Voix enjouee
```

Presets disponibles: Normal, Aigu, Grave, Enfant, Sage, Joyeux, Mysterieux, Merlin

## Signaux

- `characters_sounded(characters: String)` - Emis pour chaque caractere
- `text_updated(visible_text: String, progress: float)` - Progression
- `finished_phrase()` - Fin de la phrase
- `voice_ready(is_ready: bool)` - Sons charges

## Credits

- Original: [mattmarch/ACVoicebox](https://github.com/mattmarch/ACVoicebox) (MIT License)
- Sons: [equalo-official/animalese-generator](https://github.com/equalo-official/animalese-generator)
- Adapte pour Godot 4 et etendu pour integration MerlinVoice

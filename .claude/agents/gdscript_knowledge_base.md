# GDScript Knowledge Base — Corrections & Best Practices

> **FICHIER VIVANT** — Mis a jour automatiquement par l'agent Debug et Optimizer.
> Ce fichier documente les erreurs courantes et leurs corrections pour eviter les regressions.

---

## SECTION 1: Erreurs GDScript Courantes (Eviter)

### 1.1 Inference de Type avec Indexation

**Erreur:** `Cannot infer type from expression`

```gdscript
# WRONG - GDScript ne peut pas inferer le type depuis un index
var item := MY_ARRAY[0]
var value := MY_DICT["key"]
var constant := CONSTANTS[index]

# CORRECT - Type explicite obligatoire
var item: String = MY_ARRAY[0]
var value: Dictionary = MY_DICT["key"]
var constant: int = CONSTANTS[index]
```

**Regle:** Jamais `:=` avec `CONST[index]`, `array[index]`, ou `dict[key]`.

---

### 1.2 Yield Obsolete (Godot 4.x)

**Erreur:** `yield is not a valid identifier`

```gdscript
# WRONG (Godot 3.x syntax)
yield(get_tree().create_timer(1.0), "timeout")

# CORRECT (Godot 4.x)
await get_tree().create_timer(1.0).timeout
```

---

### 1.3 Division Entiere

**Erreur:** Comportement inattendu avec `/` pour entiers

```gdscript
# Godot 4.x: / donne toujours un float
var result: int = 10 / 3  # Resultat: 3.333... puis cast -> 3

# RECOMMANDE: Explicite
var result: int = int(10.0 / 3.0)
# OU utiliser modulo pour restes
var quotient: int = 10 / 3 as int
```

---

### 1.4 Appels draw_* Hors Contexte

**Erreur:** `draw_* can only be called during a CanvasItem's draw cycle`

```gdscript
# WRONG - Appele dans _ready ou _process
func _ready():
    draw_circle(Vector2.ZERO, 50, Color.RED)  # CRASH

# CORRECT - Dans _draw() uniquement
func _draw():
    draw_circle(Vector2.ZERO, 50, Color.RED)

# OU declencher un redraw
func update_visual():
    queue_redraw()  # Appelera _draw()
```

---

### 1.5 Signaux Non Deconnectes

**Erreur:** Memory leak, callbacks orphelins

```gdscript
# WRONG - Signal jamais deconnecte
func _ready():
    some_node.some_signal.connect(_on_signal)

# CORRECT - Cleanup dans _exit_tree
func _exit_tree():
    if some_node and some_node.some_signal.is_connected(_on_signal):
        some_node.some_signal.disconnect(_on_signal)

# MIEUX - Utiliser flag CONNECT_ONE_SHOT si signal unique
some_node.some_signal.connect(_on_signal, CONNECT_ONE_SHOT)
```

---

### 1.6 Concatenation de Strings Lente

**Erreur:** Performance degradee avec `+` dans les boucles

```gdscript
# WRONG - Lent (cree une nouvelle string a chaque iteration)
var result := ""
for i in range(1000):
    result += "item %d, " % i

# CORRECT - Utiliser Array.join() ou PackedStringArray
var parts := PackedStringArray()
for i in range(1000):
    parts.append("item %d" % i)
var result := ", ".join(parts)
```

---

### 1.7 _process Toujours Actif

**Erreur:** CPU gaspille sur des nodes inactifs

```gdscript
# WRONG - _process tourne meme si inutile
func _process(delta):
    if not is_active:
        return
    # ... logic

# CORRECT - Desactiver quand pas necessaire
func set_active(value: bool):
    is_active = value
    set_process(value)
    set_physics_process(value)
```

---

### 1.8 Tween Property avec Methode au lieu de Propriete

**Erreur:** `Type mismatch between initial and final value: Callable and Color`

```gdscript
# WRONG - add_theme_color_override est une METHODE, pas une propriete
tween.tween_property(node, "add_theme_color_override", color, duration)

# CORRECT - Utiliser le chemin de propriete pour les theme overrides
tween.tween_property(node, "theme_override_colors/font_color", color, duration)
tween.tween_property(node, "theme_override_colors/font_outline_color", outline_color, duration)

# Autres proprietes de theme accessibles via tween:
# - theme_override_colors/[color_name]
# - theme_override_constants/[constant_name]
# - theme_override_fonts/[font_name]
# - theme_override_font_sizes/[size_name]
# - theme_override_styles/[stylebox_name]
```

**Regle:** Ne jamais utiliser de noms de methodes avec `tween_property()`. Toujours utiliser les chemins de proprietes. Pour les theme overrides: `theme_override_colors/font_color`, etc.

---

### 1.9 Acces UI Node Avant _ready()

**Erreur:** `Invalid assignment of property or key 'text' with value of type 'String' on a base object of type 'Nil'`

```gdscript
# WRONG - La methode peut etre appelee avant que le UI soit construit
func update_status(message: String):
    status_bar.text = message  # CRASH si status_bar est null

# CORRECT - Toujours verifier null avant d'acceder aux nodes UI
func update_status(message: String):
    if status_bar == null:
        return  # Silencieusement ignorer si UI pas pret
    status_bar.text = message

# ALTERNATIVE - Utiliser is_instance_valid pour plus de robustesse
func update_status(message: String):
    if not is_instance_valid(status_bar):
        push_warning("status_bar not ready yet")
        return
    status_bar.text = message

# MEILLEURE PRATIQUE - Utiliser @onready et verifier dans _ready
@onready var status_bar: Label = $StatusBar

func _ready():
    assert(status_bar != null, "StatusBar node missing from scene tree")
```

**Regle:** Toujours proteger les acces aux nodes UI dans les methodes qui peuvent etre appelees avant `_ready()`. Utiliser des guards null ou `is_instance_valid()`.

---

### 1.10 Return dans Shader fragment()

**Erreur:** `Using 'return' in the 'fragment' processor function is incorrect`

```glsl
# WRONG - return n'est pas permis dans fragment()
shader_type canvas_item;

void fragment() {
    if (some_condition) {
        return;  # ERREUR: return interdit dans fragment()
    }
    COLOR = texture(TEXTURE, UV);
}

# CORRECT - Restructurer avec if-else
shader_type canvas_item;

void fragment() {
    vec4 col = texture(TEXTURE, UV);  # Valeur par defaut

    if (effect_enabled) {
        // Appliquer l'effet
        col = apply_effect(col);
    }

    COLOR = col;  # Toujours assigner a la fin
}

# PATTERN RECOMMANDE - Cascading if-else
void fragment() {
    vec4 col = texture(TEXTURE, UV);

    if (condition_a) {
        col = effect_a(col);
    } else if (condition_b) {
        col = effect_b(col);
    }
    // Jamais de return, toujours assigner COLOR a la fin
    COLOR = col;
}
```

**Regle:** Dans les shaders Godot, `fragment()` ne peut pas utiliser `return`. Toujours structurer le code avec des conditionnels et assigner `COLOR` a la fin.

---

### 1.11 Shadowing de Fonction par Parametre

**Erreur:** `The local function parameter "X" is shadowing an already-declared function`

```gdscript
# WRONG - Le parametre "is_ready" masque la fonction is_ready()
func is_ready() -> bool:
    return _initialized

func update_status(is_ready: bool):  # WARNING: shadows is_ready()
    if is_ready:
        _do_something()

# CORRECT - Renommer le parametre pour eviter le conflit
func is_ready() -> bool:
    return _initialized

func update_status(ready_state: bool):  # Pas de conflit
    if ready_state:
        _do_something()

# ALTERNATIVE - Prefixer avec underscore si parametre inutilise
func update_status(_is_ready: bool):  # Underscore = non utilise
    pass
```

**Regle:** Ne jamais nommer un parametre de fonction avec le meme nom qu'une fonction existante dans la classe. Utiliser un prefixe ou un nom different.

---

### 1.12 Division Entiere avec Warning

**Erreur:** `Integer division. Decimal part will be discarded`

```gdscript
# WRONG - Division entiere implicite genere un warning
var mid_col: int = LOGO_GRID[0].size() / 2  # WARNING

# CORRECT - Conversion explicite avec float puis int()
var mid_col: int = int(LOGO_GRID[0].size() / 2.0)

# ALTERNATIVE - Utiliser floorf/ceilf pour controler l'arrondi
var mid_col: int = int(floor(LOGO_GRID[0].size() / 2.0))  # Arrondi vers le bas
var mid_col: int = int(ceil(LOGO_GRID[0].size() / 2.0))   # Arrondi vers le haut

# PATTERN POUR CENTRE D'ARRAY
var array_size: int = my_array.size()
var center_index: int = int(array_size / 2.0)
```

**Regle:** Quand on assigne le resultat d'une division a un int, utiliser un diviseur float (2.0) puis `int()` pour eviter le warning de division entiere.

---

### 1.13 Variable Locale Non Utilisee

**Erreur:** `The local variable "X" is declared but never used in the block`

```gdscript
# WRONG - Variable declaree mais jamais utilisee
func process_data():
    var unused_counter: int = 0  # WARNING: never used
    var result: String = compute()
    return result

# CORRECT - Supprimer la variable inutile
func process_data():
    var result: String = compute()
    return result

# ALTERNATIVE - Prefixer avec underscore pour signaler intentionnellement inutilise
func process_data():
    var _unused_counter: int = 0  # Underscore = intentionnellement inutilise
    var result: String = compute()
    return result

# CAS COURANT - Parametre de callback non utilise
signal_connection.connect(func(_unused_param):
    do_something()
)

# AUSSI VALIDE POUR - Boucles avec index non utilise
for _i in range(10):  # Underscore car _i n'est pas utilise
    do_something_ten_times()
```

**Regle:** Prefixer les variables non utilisees avec underscore `_` pour supprimer le warning et indiquer clairement l'intention.

---

## SECTION 2: Patterns d'Optimisation GDScript

### 2.1 Object Pooling

```gdscript
# Pour objets crees/detruits frequemment (particules, projectiles)
var _pool: Array[Node] = []
var _pool_size: int = 20

func _ready():
    for i in _pool_size:
        var obj := preload("res://scenes/Bullet.tscn").instantiate()
        obj.set_process(false)
        obj.visible = false
        _pool.append(obj)
        add_child(obj)

func get_from_pool() -> Node:
    for obj in _pool:
        if not obj.visible:
            obj.visible = true
            obj.set_process(true)
            return obj
    return null  # Pool epuise

func return_to_pool(obj: Node) -> void:
    obj.visible = false
    obj.set_process(false)
```

---

### 2.2 Lazy Loading / Preloading

```gdscript
# PRELOAD: Pour ressources critiques (utilisees tot)
const HeavyScene := preload("res://scenes/Heavy.tscn")

# LOAD: Pour ressources optionnelles (peuvent ne pas etre utilisees)
var _optional_scene: PackedScene = null
func get_optional_scene() -> PackedScene:
    if _optional_scene == null:
        _optional_scene = load("res://scenes/Optional.tscn")
    return _optional_scene

# BACKGROUND LOADING: Pour grosses ressources
func _load_in_background(path: String) -> void:
    ResourceLoader.load_threaded_request(path)

func _check_loaded(path: String) -> Resource:
    if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
        return ResourceLoader.load_threaded_get(path)
    return null
```

---

### 2.3 Typed Arrays

```gdscript
# WRONG - Array generique (lent, pas de type safety)
var items := []
items.append("string")
items.append(123)  # Aucune erreur, mais melange de types

# CORRECT - Array type (rapide, type safe)
var items: Array[String] = []
items.append("valid")
# items.append(123)  # Erreur de compilation!

# Pour dictionnaires, pas de typage natif, mais documenter:
var data: Dictionary = {}  # {String: CardData}
```

---

### 2.4 Deferred Calls

```gdscript
# Pour operations lourdes qui peuvent attendre
func _on_button_pressed():
    # Ne pas bloquer l'input
    _process_heavy_task.call_deferred()

func _process_heavy_task():
    # Cette fonction s'execute apres le frame courant
    pass
```

---

### 2.5 Timer-Based Polling vs Frame Polling

```gdscript
# WRONG - Poll chaque frame (16ms) = gaspillage
while not result_ready:
    await get_tree().process_frame  # 60 checks/seconde inutiles

# CORRECT - Poll avec timer adaptatif
var poll_interval := 0.05  # 50ms = 20 checks/seconde
while not result_ready:
    external_api.poll()
    await get_tree().create_timer(poll_interval).timeout
    # Augmenter l'intervalle si ca prend longtemps
    poll_interval = minf(poll_interval * 1.5, 0.5)
```

---

## SECTION 3: Patterns Specifiques DRU

### 3.1 Integration LLM (Trinity-Nano)

```gdscript
# Parametres optimaux pour Trinity-Nano 1B
const LLM_PARAMS := {
    "max_tokens": 60,        # Court = rapide
    "temperature": 0.4,      # Pas trop creatif
    "top_p": 0.75,
    "top_k": 25,
    "repetition_penalty": 1.6  # Evite repetitions
}

# System prompt: MAX 10 tokens
const SYSTEM_PROMPT := "Tu generes des cartes."  # Court!

# NE PAS inclure d'exemples (le modele les repete)
```

---

### 3.2 DruStore Dispatch Pattern

```gdscript
# CORRECT - Actions atomiques
DruStore.dispatch({"type": "SET_GAUGE", "gauge": "Vigueur", "value": 50})

# WRONG - Modifier le state directement
DruStore.state["run"]["gauges"]["Vigueur"] = 50  # Bypass du reducer!
```

---

### 3.3 Card Effect Validation

```gdscript
# TOUJOURS valider les effets avant application
func apply_effect(effect: Dictionary) -> bool:
    var type: String = effect.get("type", "")
    if type not in EFFECT_WHITELIST:
        push_warning("Effect type '%s' not in whitelist" % type)
        return false
    # ... appliquer l'effet
    return true
```

---

## SECTION 4: Checklist Pre-Validation

Avant chaque `validate.bat`, verifier:

- [ ] Pas de `:= CONST[index]` (grep `:= \w+\[`)
- [ ] Pas de `yield()` (remplacer par `await`)
- [ ] Tous les `draw_*` dans `_draw()` ou apres `queue_redraw()`
- [ ] Signaux deconnectes dans `_exit_tree()`
- [ ] `set_process(false)` sur nodes inactifs
- [ ] Arrays types quand possible
- [ ] Pas de concatenation `+` dans les boucles
- [ ] Pas de `return` dans shader `fragment()` (restructurer avec if-else)
- [ ] Pas de parametres qui masquent des fonctions (shadowing)
- [ ] Division entiere explicite avec `int(x / 2.0)` pas `x / 2`
- [ ] Variables non utilisees prefixees avec `_`

---

## SECTION 5: Ressources Externes

### Documentation Officielle
- [GDScript Style Guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [GDScript Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)
- [Optimization Guide](https://docs.godotengine.org/en/stable/tutorials/performance/index.html)

### Patterns Avances
- [Object Pooling](https://docs.godotengine.org/en/stable/tutorials/performance/using_servers.html)
- [Multithreading](https://docs.godotengine.org/en/stable/tutorials/performance/using_multiple_threads.html)

---

## SECTION 6: Log des Corrections (Chronologique)

> **Format:** `[DATE] [FICHIER] Erreur → Correction`

_Ce section est mise a jour automatiquement par l'agent Debug._

<!-- CORRECTIONS_LOG_START -->
### 2026-02-08
- Initial knowledge base created
- `[IntroCeltOS.gd:136]` Type mismatch Callable/Color → Remplace `"add_theme_color_override"` par `"theme_override_colors/font_color"` dans tween_property()
- `[TestLLMSceneUltimate.gd:1370]` Nil access on 'text' → Ajoute guard `if status_bar == null: return` avant acces UI node
- `[shaders/screen_distortion.gdshader]` Using 'return' in fragment() → Restructure avec if-else blocks, assigner COLOR a la fin
- `[llm_status_bar.gd:243]` Parameter shadows function is_ready() → Renomme parametre en `ready_state`
- `[IntroCeltOS.gd:236]` Integer division warning → Utilise `int(size / 2.0)` au lieu de `size / 2`
- `[Multiple files]` Variable declared but never used → Prefixe avec underscore `_variable_name`

<!-- CORRECTIONS_LOG_END -->

---

*Last Updated: 2026-02-08 (6 corrections total)*
*Maintained by: Debug Agent & Optimizer Agent*

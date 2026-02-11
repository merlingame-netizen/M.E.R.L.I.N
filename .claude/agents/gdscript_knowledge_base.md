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

### 1.1b Fichiers .gd crees hors editeur — "Could not find type"

**Erreur:** `Could not find type "MyClass" in the current scope`

**Cause:** Quand un fichier .gd avec `class_name` est cree hors de l'editeur Godot (par Claude Code, un script, etc.), Godot ne genere PAS automatiquement:
- Le fichier `.gd.uid` (identifiant unique)
- L'entree dans `.godot/global_script_class_cache.cfg`

Sans ces deux elements, les autres scripts qui referencent ce type echouent.

**Solution definitive:** Lancer `validate_editor_parse.ps1` qui execute `godot --editor --headless --quit`. Cela force Godot a:
1. Scanner tous les .gd du projet
2. Generer les .uid manquants
3. Regenerer le cache de types complet

**Detection:** `tools/validate_editor_parse.ps1` (Step 0 de validate.bat).

**Note:** Le mode `--headless --quit` (sans `--editor`) ne regenere PAS toujours le cache. L'option `--editor` est obligatoire.

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

### 1.3 Division Entiere — Warning "Integer division"

**Warning Godot:** `Integer division. Decimal part will be discarded.`

En GDScript 4.x, `int / int` retourne un `int` (troncature). Godot emet un warning car la partie decimale est silencieusement perdue.

```gdscript
# WRONG — genere warning "Integer division"
var result := int(score / 10)
var half := int(total / 2)

# CORRECT — diviseur en float, pas de warning
var result := int(score / 10.0)
var half := int(total / 2.0)
```

**Regle:** Toujours utiliser un diviseur float (`10.0` au lieu de `10`) quand on divise une variable int. Le `int()` externe garantit le type de retour.

**Detection:** `tools/validate_editor_parse.ps1` (warning patterns, mode `--strict`).

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

### 1.14 Tween Vide (Empty Tweeners)

**Erreur:** `Tween without commands, aborting` / Runtime warning quand un Tween est cree mais aucun tweener n'est ajoute

```gdscript
# WRONG - Creer un Tween puis ajouter des tweeners conditionnellement
# Si aucun parametre shader n'existe, le Tween reste vide et Godot se plaint
var tween := create_tween()
tween.set_parallel(true)
for param_name in profile:
    var raw_value = shader_material.get_shader_parameter(param_name)
    if raw_value == null:
        continue  # Si TOUS les params sont null, le Tween est vide!
    tween.tween_method(setter.bind(param_name), from, to, duration)

# CORRECT - Collecter les tweeners valides AVANT de creer le Tween
var tweens_to_add: Array[Dictionary] = []
for param_name: String in profile:
    var raw_value = shader_material.get_shader_parameter(param_name)
    if raw_value == null:
        continue
    tweens_to_add.append({"param": param_name, "from": float(raw_value), "to": float(profile[param_name])})

if tweens_to_add.is_empty():
    return  # Pas de Tween cree = pas d'erreur

var tween := create_tween()
tween.set_parallel(true)
for t in tweens_to_add:
    tween.tween_method(setter.bind(t["param"]), t["from"], t["to"], duration)
```

**Regle:** Ne jamais creer un Tween avant d'etre certain qu'au moins un tweener sera ajoute. Collecter les donnees en amont, verifier non-vide, puis creer le Tween.

---

### 1.15 Variable Locale Masquant une Methode Heritee (Shadowing Built-in)

**Erreur:** `The local variable "hide" is shadowing an already-declared function` (ou `show`, `process`, etc.)

```gdscript
# WRONG - "hide" est une methode de CanvasItem — la variable la masque
var hide := create_tween()
hide.tween_property(panel, "modulate:a", 0.0, 0.4)

# CORRECT - Suffixer avec le type (_tween, _timer, _anim)
var hide_tween := create_tween()
hide_tween.tween_property(panel, "modulate:a", 0.0, 0.4)

# AUSSI VALIDE
var fade_out := create_tween()
fade_out.tween_property(panel, "modulate:a", 0.0, 0.4)
```

**Noms herites a eviter comme variables locales:**
- `hide`, `show` (CanvasItem)
- `process` (Node)
- `draw` (CanvasItem)
- `ready` (Node)
- `queue_free` (Node)

**Regle:** Ne jamais nommer une variable locale avec le meme nom qu'une methode heritee (CanvasItem, Node, Control, etc.). Utiliser un suffixe descriptif (`_tween`, `_timer`, `_anim`).

---

### 1.16 Chemin d'Addon Incorrect (Casse/Underscore)

**Erreur:** `res://... file not found` a l'execution, souvent silencieux (le script ne charge pas)

```gdscript
# WRONG - Nom du dossier/fichier incorrect (underscore au lieu de camelCase ou inverse)
var script_path := "res://addons/ac_voicebox/ac_voicebox.gd"   # N'EXISTE PAS
var scene_path := "res://addons/ac_voicebox/ac_voicebox.tscn"  # N'EXISTE PAS

# CORRECT - Verifier le nom EXACT du dossier sur disque
var script_path := "res://addons/acvoicebox/acvoicebox.gd"     # Nom reel
var scene_path := "res://addons/acvoicebox/acvoicebox.tscn"    # Nom reel
```

**Methode de verification:**
```gdscript
# TOUJOURS utiliser ResourceLoader.exists() avant load()
var script_path := "res://addons/acvoicebox/acvoicebox.gd"
if ResourceLoader.exists(script_path):
    var scr = load(script_path)
    # ... utiliser le script
else:
    push_warning("Script not found: %s" % script_path)
```

**Regle:** Toujours verifier le nom exact des dossiers/fichiers d'addon sur disque. Les noms avec underscores (`ac_voicebox`) vs. sans (`acvoicebox`) sont des chemins differents. Utiliser `ResourceLoader.exists()` comme garde.

---

### 1.17 set_anchors_preset sur un Node2D (Non-Control)

**Erreur:** `Invalid call. Nonexistent function 'set_anchors_preset' in base 'GPUParticles2D'`

```gdscript
# WRONG - GPUParticles2D herite de Node2D, PAS de Control
var particles := GPUParticles2D.new()
particles.set_anchors_preset(Control.PRESET_FULL_RECT)  # CRASH: methode inexistante

# Aussi WRONG pour: Sprite2D, TileMap, Camera2D, etc. (tout Node2D)

# CORRECT - Utiliser position/size directement pour les Node2D
var particles := GPUParticles2D.new()
particles.position = Vector2(400, 300)
# GPUParticles2D n'a pas de "size" — la zone d'emission depend du ProcessMaterial

# POUR COUVRIR TOUT L'ECRAN avec des particules:
var vp_size := get_viewport().get_visible_rect().size
particles.position = vp_size * 0.5  # Centrer
var mat := ParticleProcessMaterial.new()
mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
mat.emission_box_extents = Vector3(vp_size.x * 0.5, vp_size.y * 0.5, 0)
particles.process_material = mat
```

**Hierarchie a retenir:**
- `Control` (et ses enfants: Label, Button, Panel, etc.) → a `set_anchors_preset()`
- `Node2D` (et ses enfants: Sprite2D, GPUParticles2D, etc.) → PAS de `set_anchors_preset()`

**Regle:** `set_anchors_preset()` est exclusif a `Control` et ses sous-classes. Pour les `Node2D`, utiliser `position` directement. Verifier l'heritage du node dans la doc avant d'appeler des methodes UI.

### 1.10 get_tree() Null apres Await — "Cannot call method on a null value"

**Erreur:** `Cannot call method 'create_timer' on a null value`

**Cause:** Apres un `await`, le noeud peut avoir quitte le scene tree. `get_tree()` retourne alors `null`.

```gdscript
# WRONG — crash si le noeud sort de l'arbre pendant l'await
await some_long_operation()
await get_tree().create_timer(0.3).timeout  # CRASH: get_tree() == null

# CORRECT — helper safe avec garde is_inside_tree()
func _safe_wait(seconds: float) -> void:
    if not is_inside_tree():
        return
    await get_tree().create_timer(seconds).timeout

func _safe_frame() -> void:
    if not is_inside_tree():
        return
    await get_tree().process_frame

# Usage
await some_long_operation()
await _safe_wait(0.3)  # Safe: retourne immediatement si hors arbre
```

**Contexte:** Tres courant dans les scenes de transition longues (TransitionBiome, etc.) ou les operations LLM avec timeout. TOUT appel `get_tree()` apres un `await` doit etre protege.

**Date:** 2026-02-10 — TransitionBiome.gd (17 appels corriges)

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
- [ ] Tween cree seulement si au moins 1 tweener garanti (pas de Tween vide)
- [ ] Variables locales ne masquent pas les methodes heritees (`hide`, `show`, etc.)
- [ ] Chemins d'addons verifies sur disque (casse exacte, underscores)
- [ ] `set_anchors_preset()` utilise uniquement sur des nodes Control (pas Node2D)

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
- `[ScreenEffects.gd:set_merlin_mood]` Tween without commands → Collecte tweeners valides avant creation du Tween, skip si vide
- `[SceneAntreMerlin.gd:762]` Variable "hide" shadows CanvasItem.hide() → Renomme en `hide_tween`
- `[SceneAntreMerlin.gd, SceneEveil.gd, MenuPrincipalReigns.gd]` ACVoicebox wrong path "ac_voicebox" → Corrige en "acvoicebox" (nom reel du dossier)
- `[TransitionBiome.gd:178]` set_anchors_preset() on GPUParticles2D (Node2D) → Remplace par position directe `Vector2(400, 300)`

### 2026-02-09 (Brain Pool QA Review)
- `[merlin_ai.gd:_bg_queue]` Unbounded background task queue → Add BG_QUEUE_MAX_SIZE=100 limit with FIFO drop
- `[merlin_ai.gd:_process]` Background tasks with no timeout detection → Add BG_TASK_TIMEOUT_MS=30000, detect stuck tasks
- `[merlin_ai.gd:_fire_bg_task]` Missing start_time on active tasks → Add start_time: Time.get_ticks_msec() for timeout tracking
- `[merlin_ai.gd:reload_models]` Reload during active bg tasks → Cancel active tasks and clear queue before reload
- `[merlin_ai.gd:_lease_bg_brain]` No is_instance_valid check → Add is_instance_valid() before leasing any brain
- **Pattern:** Busy flag set/clear must be balanced in every function that uses them (check all exit paths)
- **Pattern:** Bounded queues: always add size limits to arrays that grow via user/system actions

### 2026-02-09 (GDExtension C++ Build)
- `[merlin_llm.cpp:181]` `llama_n_vocab(model)` compile error → API changed: now takes `const llama_vocab *` not `llama_model *`. Fix: use `llama_n_vocab(vocab)` where `vocab = llama_model_get_vocab(model)`
- `[merlin_llm.cpp:180]` `llama_sampler_init_penalties()` signature changed → Reduced from 9 args to 4: only `(penalty_last_n, penalty_repeat, penalty_freq, penalty_present)`. Removed: n_vocab, special_eos_id, linefeed_id, penalize_nl, ignore_eos
- `[CMakeLists.txt]` RuntimeLibrary mismatch MD vs MT → llama.cpp must be built with `-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded` to match GDExtension static CRT
- `[CMakeLists.txt]` Missing ggml libs → Add `ggml.lib`, `ggml-base.lib`, `ggml-cpu.lib` to linker (llama.cpp split ggml into sub-libs)

<!-- CORRECTIONS_LOG_END -->

---

## SECTION 7: Task Dispatcher — Patterns Appris

> **Section alimentee par le Task Dispatcher** — Documente les sequences d'agents
> qui ont fonctionne ou echoue pour ameliorer les futures dispatches.

### Format d'entree

```
### Pattern: [Nom du pattern]
**Demande type**: [Formulation utilisateur typique]
**Sequence optimale**: [Agent1] → [Agent2] → ... → [AgentN]
**Piege courant**: [Ce qu'il faut eviter]
**Resultat**: [Succes/Echec et lecon]
```

### Patterns documentes

_(Section vide — sera alimentee automatiquement au fil des dispatches)_

<!-- DISPATCHER_PATTERNS_START -->
<!-- DISPATCHER_PATTERNS_END -->

---

*Last Updated: 2026-02-09 (14 corrections + Section 7 Dispatcher)*
*Maintained by: Debug Agent, Optimizer Agent & Task Dispatcher*

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

**Extension (2026-02-22):** Meme probleme avec les proprietes d'objets issus d'arrays non types:
```gdscript
var _hotspots: Array = []  # Array non type = elements Variant

# WRONG — hs est Variant, hs.position est Variant, := echoue
for hs in _hotspots:
    var target := hs.position + Vector2(32, 32)

# CORRECT — type explicite
for hs in _hotspots:
    var target: Vector2 = hs.position + Vector2(32, 32)
```

---

### 1.1c Static functions appelees sur instance autoload

**Warning:** `STATIC_CALLED_ON_INSTANCE: The function "xxx()" is a static function but was called from an instance`

**Cause:** Fonctions `static func` dans un script autoload appelees via `AutoloadName.func()`. L'autoload est une instance dans l'arbre de scene, pas un type.

```gdscript
# WRONG — MerlinVisual est un autoload (instance) + func est static
parchment_bg.modulate = MerlinVisual.get_seasonal_tint()

# FIX 1 (prefere): retirer static si toujours appele via autoload
func get_seasonal_tint() -> Color:  # pas 'static func'

# FIX 2 (alternatif): ajouter class_name au script autoload
# Puis appeler via le type: MerlinVisualType.get_seasonal_tint()
```

**Regle:** Sur un autoload sans `class_name`, ne pas utiliser `static func`. Utiliser `func` simple.

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

### 3.1 Integration LLM (Qwen 2.5-3B-Instruct CPU)

```gdscript
# Parametres optimaux pour Qwen 2.5-3B Q4_K_M (CPU ~4 tok/s)
# Narrator (texte creatif)
var narrator_params := {
    "temperature": 0.7, "top_p": 0.9, "max_tokens": 250,
    "top_k": 40, "repetition_penalty": 1.3
}

# REGLE CRITIQUE: JSON generation TOUJOURS malformee avec Qwen 3B CPU
# -> Utiliser two-stage: free text + wrap programmatique
# -> JAMAIS de JSON primary generation (perte de 120s)

# Timeouts CPU (generosite obligatoire)
const LLM_POLL_TIMEOUT_FIRST_MS := 300000  # 5min cold start
const LLM_POLL_TIMEOUT_MS := 120000        # 2min normal
```

**Lecons LLM Pipeline (Run 13, 2026-02-15):**
1. **cancel_generation() bloque C++** — Ne jamais cancel + generate_async dans la foulee (~80s de blocage). Preferer WAIT for completion.
2. **Warmup obligatoire** — `_warmup_generate()` apres chargement modele prime le cache CPU. Reduit premiere gen de >120s a ~60s.
3. **Prefetch = cle de la performance** — Pre-generer pendant resolution joueur. Cards 2-31 servies en ~2ms.
4. **GDScript lambda capture** — Les primitives (int, float, bool) sont capturees par valeur. Utiliser Dictionary comme shared state pour les callbacks async.
5. **is_generating_now() avant generate_async()** — Toujours verifier que le thread C++ est libre avant de lancer une generation.

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
- `[SceneAntreMerlin.gd, SceneEveil.gd, MenuPrincipalMerlin.gd]` ACVoicebox wrong path "ac_voicebox" → Corrige en "acvoicebox" (nom reel du dossier)
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

### 2026-02-15 (Audit Complet Projet)
- `[project.godot + game_manager.gd]` MerlinStore pas enregistre comme singleton → class_name interdit autoload meme nom en Godot 4. Fix: GameManager._ready() cree MerlinStore et l'ajoute a root via call_deferred
- `[Calendar.gd:180]` `Dictionary == "floating"` crash runtime → date_val peut etre Dictionary ou String. Fix: `if date_val is String and date_val == "floating"`
- `[SceneAntreMerlin.gd:24-28, SceneEveil.gd:25-29]` Chemins sprites supprimes (Merlin.png, _AUTOMNE, _ETE, _HIVER, _PRINTEMPS) → Fix: pointer vers M.E.R.L.I.N.png
- `[HubAntre.gd:1956,1965]` Control anchor/size warnings → Fix: `set_deferred("size", vp)` au lieu de `.size = vp`
- `[triade_game_controller.gd:105-107]` Fallback MerlinStore.new() local inutile → Supprime (GameManager gere maintenant)
- **Pattern:** En Godot 4, `class_name Foo` + autoload `Foo` = conflit. Soit retirer class_name, soit creer le singleton manuellement via un autre autoload
- **Pattern:** Comparaison polymorphe (JSON date peut etre String ou Dict) — toujours tester le type avec `is` avant `==`

### 2026-02-15 (LLM Text Variety + Guardrails)
- `[merlin_omniscient.gd:_contains_forbidden_words]` `.contains()` = substring match → "ia" matchait "confiance", "alliance", etc. Fix: `_find_forbidden_word()` avec whole-word matching (space-delimited)
- `[merlin_omniscient.gd:GUARDRAIL_MAX_TEXT_LEN]` 500 chars trop restrictif pour LLM 250 max_tokens → Fix: 1200
- `[merlin_omniscient.gd:_apply_guardrails]` Forbidden words = hard reject meme pour LLM → Fix: soft warning pour LLM (prefer LLM text > fallback)
- `[merlin_store.gd:_resolve_triade_choice]` story_log jamais peuple → Fix: append card text + chosen label (5 derniers)
- `[triade_game_controller.gd]` Prefetch avant resolution = stale state = textes identiques → Fix: deplacer prefetch APRES resolution
- **Pattern:** String.contains() pour guardrails = DANGER. Toujours whole-word match pour mots courts (<4 chars)
- **Pattern:** Prefetch LLM doit utiliser le state APRES resolution, pas avant (sinon contexte stale = repetition)
- **Pattern:** Guardrails LLM doivent etre soft (warning) sauf mots interdits meta/AI. Mieux vaut un texte LLM imparfait qu'un fallback generique

### 2026-02-19 (LLM Intelligence Pipeline Tests — T18-T27)
- `[merlin_llm_adapter.gd:_validate_triade_option]` Sanitization drops gameplay keys → Crée un nouveau dict avec seulement `label`, `cost`, `effects`, perdant `dc_hint`, `risk_level`, `reward_type`, `result_success`, `result_failure`. Fix: boucle de preservation des clés gameplay
- `[merlin_llm_adapter.gd:_wrap_text_as_card]` Regex anti-leakage case-insensitive manquant → `[A-D]` dans regex ne matche pas le texte lowercased. Fix: `[a-dA-D]`
- `[test_llm_intelligence.gd:809,828,847]` `:=` avec constante Array non typée → `var safe_all := _adapter.VERB_POOL_SAFE` échoue car GDScript ne peut pas inférer le type. Fix: `var safe_all: Array = _adapter.VERB_POOL_SAFE`
- **Pattern:** `_validate_triade_option()` et tout sanitizer de dict: TOUJOURS préserver les clés métier au-delà du trio label/cost/effects. Utiliser une liste blanche explicite de clés à conserver
- **Pattern:** Regex anti-leakage: quand le texte est lowercased avant matching, le pattern doit inclure les deux casses `[a-dA-D]` ou utiliser le flag case-insensitive

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

## SECTION 8: Good Practices Operationnelles — Test & LLM Pipeline (2026-02-24)

> **OBLIGATOIRE** — Ces regles sont issues d'erreurs reelles en session. Les violer cause des blocages,
> des tests qui ne terminent jamais, ou des resultats faux.

### 8.1 Lancer une Scene Godot depuis Claude Code

**Commande de base:**
```bash
timeout 300 "C:/Users/PGNK2128/Godot/Godot_v4.5.1-stable_win64_console.exe" \
  --path "c:/Users/PGNK2128/Godot-MCP" scenes/MaScene.tscn > /dev/null 2>&1
```

**REGLES CRITIQUES:**

| Regle | Erreur si viole | Fix |
|-------|-----------------|-----|
| **JAMAIS `\| head` ou `\| tail`** | SIGPIPE tue Godot apres N lignes stdout | `> /dev/null 2>&1` et lire le log file |
| **Toujours `timeout N`** | Process zombie infini | `timeout 300` (5 min max) |
| **Lire les logs via fichier** | stdout Godot est tronque/pipe-sensitive | `$APPDATA/Godot/app_userdata/DRU/logs/godot.log` |
| **Vider le log AVANT** | Melange avec logs precedents | `echo "" > "$LOG_PATH"` avant lancement |
| **Background si long** | Bash tool timeout a 120s | `> /dev/null 2>&1 &` + sleep + read log |

**Pattern recommande (background + polling log):**
```bash
# Lancer en background
echo "" > "C:/Users/PGNK2128/AppData/Roaming/Godot/app_userdata/DRU/logs/godot.log"
timeout 300 "C:/.../Godot_v4.5.1-stable_win64_console.exe" \
  --path "c:/Users/PGNK2128/Godot-MCP" scenes/TestAutoPlay.tscn > /dev/null 2>&1 &

# Attendre et verifier
sleep 90
wc -l "$LOG_PATH"
grep -c "=== CARD" "$LOG_PATH"
tail -20 "$LOG_PATH"
```

---

### 8.2 Scene Standalone vs Scene en Contexte de Jeu

**REGLE FONDAMENTALE:** MerlinGame.tscn ne peut PAS tourner seul (store = null).

| Mode de test | Scene | Usage | Prerequis |
|-------------|-------|-------|-----------|
| **E2E Autoplay** | `scenes/TestAutoPlay.tscn` | Test pipeline LLM complet | Ollama running, 75-90s/carte |
| **Game context** | Full game flow | Test en condition reelle | User input requis |
| **LLM standalone** | Script Python/CLI | Test modele seul | `python tools/test_merlin_chat.py` |
| **Validation statique** | `validate.bat` | Syntaxe + parse | Aucun (headless) |

**Architecture du flux de production des cartes:**
```
HubAntre → TransitionBiome (LLM pre-genere buffer 5 cartes) → MerlinGame (consomme buffer + genere on-demand)
```

**Quand on teste le LLM en mode autoplay:**
- Le buffer TransitionBiome est VIDE (pas de transition)
- Toutes les cartes sont generees on-demand (plus lent)
- C'est normal et attendu — le test mesure la generation, pas le prefetch

**Quand on teste en condition de jeu:**
- TransitionBiome pre-genere 5 cartes pendant l'animation
- Cartes 1-5 sont servies en ~2ms (buffer)
- Cartes 6+ sont generees on-demand ou par prefetch
- C'est le scenario reel joueur

---

### 8.3 Mode Headless — Regles Obligatoires

**Probleme:** Les scenes UI ont des animations bloquantes (tweens, typewriter, click-to-continue)
qui ne completent JAMAIS en headless car personne ne clique et certains tweens ne se resolvent pas.

**Points de blocage decouverts (2026-02-24):**

| Fonction | Blocage | Temps mort |
|----------|---------|------------|
| `show_narrator_intro()` | `_waiting_narrator_click` + 30s timeout/page | 30-90s |
| `show_dice_roll()` | Tween animation 3s + bounce | Hang infini |
| `show_result_text_transition()` | Tween fade + typewriter | Hang infini |
| `show_travel_animation()` | Fog overlay + tween fade | Hang infini |
| `show_opening_sequence()` | Layout + pixel animations | Variable |
| `show_scenario_intro()` | Click-to-continue 30s timeout | 30s |
| `show_progressive_indicators()` | Tween sequence | Variable |

**Solution implementee dans `merlin_game_controller.gd`:**
```gdscript
# Dans start_run():
if ui and is_instance_valid(ui) and not headless_mode:
    # ... toutes les animations UI bloquantes
elif headless_mode:
    _intro_shown = true
    print("[TRIADE] headless mode — skipped narrator intro")

# Dans _resolve_choice():
if headless_mode:
    dice_result = randi_range(1, 20)  # Instant dice, pas d'animation
# Skip: show_result_text_transition, show_travel_animation, timers 3s
```

**Race condition critique (decouverte 2026-02-24):**
```gdscript
# WRONG — _ready() → start_run() s'execute pendant add_child(), AVANT la ligne suivante
var game_instance = game_scene.instantiate()
add_child(game_instance)       # ← _ready() EXECUTE ICI
_controller.headless_mode = true  # TROP TARD

# CORRECT — set headless_mode AVANT add_child
var game_instance = game_scene.instantiate()
game_instance.headless_mode = true  # ← AVANT _ready()
game_instance.minigame_chance = 0.0
add_child(game_instance)
```

**Regle:** Toute propriete qui affecte `_ready()` ou `start_run()` doit etre definie
AVANT `add_child()`. L'ordre Godot est: `instantiate()` → proprietes → `add_child()` → `_ready()`.

---

### 8.4 Gestion CPU / Ollama / CPU Guardian

**Le hook `cpu_guardian.py` bloque les commandes Bash si CPU >= 90%.**

| Situation | Cause | Solution |
|-----------|-------|----------|
| CPU 100% apres test | Ollama genere encore | `taskkill //F //IM "ollama_llama_server.exe"` |
| CPU 100% pendant test | LLM generation active | Attendre ou kill Godot + Ollama |
| CPU bloque validation | Ollama en background | Kill Ollama, wait 10s, puis valider |
| CPU bloque apres kill | Windows lag de release | `sleep 20` puis reessayer |

**Sequence de cleanup:**
```bash
taskkill //F //IM "Godot_v4.5.1-stable_win64_console.exe" 2>/dev/null
taskkill //F //IM "ollama_llama_server.exe" 2>/dev/null
sleep 10  # Attendre release CPU
# Puis valider/relancer
```

**JAMAIS tuer `ollama.exe` (le serveur)** — seulement `ollama_llama_server.exe` (le worker LLM).
Ollama relancera le worker au prochain appel.

---

### 8.5 Validation Pipeline — Ordre Obligatoire

```
1. Editer le code
2. Kill Ollama worker si CPU > 80%
3. validate.bat (ou powershell -File tools/validate_editor_parse.ps1)
4. Corriger erreurs/warnings
5. Re-valider (0 errors, 0 warnings)
6. PUIS tester dans Godot (scene ou autoplay)
7. Analyser les logs (fichier, pas stdout)
8. Commit si OK
```

**Validation specifique aux fichiers .gd crees hors editeur:**
Godot ne genere pas les `.uid` ni le cache de types pour les fichiers crees par Claude Code.
L'Editor Parse Check (`--editor --headless --quit`) est OBLIGATOIRE apres creation de nouveaux scripts.

---

### 8.6 LLM Pipeline — Metriques et Seuils

**Metriques actuelles (Qwen 2.5-1.5B, CPU-only, 2026-02-24):**

| Metrique | Valeur observee | Seuil acceptable |
|----------|-----------------|------------------|
| gen_time/carte (warm) | 75-87s | < 10s (GPU) / < 90s (CPU) |
| Narrator text gen | 21-40s | — |
| GM effects gen | 7-11s | — |
| GM consequences gen | 4-7s | — |
| Quality judge rewrite | 20-25s | — |
| Fallback rate | 0% | 0% (zero fallback) |
| Labels extraits | 1-3/3 | 3/3 ideal |
| Labels fallback "VERBE" | 50% des cartes | < 20% |
| Text length | 236-306 chars | 30-800 chars |
| French output | ~80% | > 80% |

**Pipeline two-stage par carte:**
```
1. Narrator: free text (2400-3200 chars prompt, 120-160 max_tokens) → 21-40s
2. Label extraction: regex A)/B)/C) dans le texte → <1ms
3. GM effects: JSON structured (540-578 chars prompt, 80 max_tokens) → 7-11s
4. GM consequences: result_success/failure (430-620 chars, 40 max_tokens) → 4-7s
5. Quality judge: rewrite si score < 0.55 (1039-1100 chars, 200 max_tokens) → 20-25s
Total: ~75-87s/carte (CPU)
```

**Points de defaillance observes:**
- "Only 0 labels extracted" → Le Narrator n'inclut pas A)/B)/C) dans son texte → padding "VERBE"
- "Smart effects: GM failed" → Le GM genere du JSON invalide → heuristique fallback
- "Unreferenced static string" → Bug Godot interne (memory), pas notre code → ignore

---

### 8.7 Test LLM Standalone (hors Godot)

**Pour tester le modele sans lancer Godot:**
```bash
python tools/test_merlin_chat.py --mode perf --perf-runs 5
# Resultat: tmp/perf_results.json
```

**Pour tester un prompt specifique:**
```bash
python tools/test_merlin_chat.py --prompt "Tu es Merlin. Decris une foret celtique en 3 phrases."
```

**Verifier qu'Ollama tourne:**
```bash
curl -s http://localhost:11434/api/tags | head -5
# Ou: ollama list
```

---

### 8.8 Patterns de Debugging — Grep Logs

**Chercher les cartes:**
```bash
grep "=== CARD" "$LOG"           # Compter les cartes
grep "CHOSEN=" "$LOG"            # Choix effectues
grep "source=" "$LOG"            # Source (llm_native, fallback, etc.)
grep "D20=" "$LOG"               # Resultats de des
grep "text=" "$LOG"              # Textes generes
grep "ERROR\|SCRIPT ERROR" "$LOG"  # Erreurs runtime
```

**Diagnostiquer un blocage:**
```bash
tail -30 "$LOG"    # Voir ou c'est bloque
tasklist | grep -i Godot   # Verifier si le process tourne
wc -l "$LOG"       # Si le nombre de lignes ne bouge plus = bloque
```

---

### 8.9 Architecture de Test — 3 Niveaux

| Niveau | Quoi | Comment | Quand |
|--------|------|---------|-------|
| **Statique** | Syntaxe, types, parse | `validate.bat` / `validate_editor_parse.ps1` | Apres CHAQUE edit .gd |
| **LLM Standalone** | Qualite texte, latence | `test_merlin_chat.py --mode perf` | Apres changements prompts/params |
| **E2E Autoplay** | Pipeline complet in-engine | `scenes/TestAutoPlay.tscn` (headless) | Apres changements controller/UI/MOS |
| **Game context** | Experience joueur reelle | Full game (Manual play) | Avant release/milestone |

**Le test en condition de jeu (HubAntre → TransitionBiome → MerlinGame) est le seul qui teste:**
- Le buffer de cartes pre-generees (TransitionBiome)
- Le prefetch pendant la resolution joueur
- Les animations UI reelles
- L'experience timing percue par le joueur

---

---

## SECTION 9: Patterns UI Overlay Procédurale (2026-02-25)

### 9.1 Overlay Modal dans HubAntre (Pattern B.1)

**Contexte**: Ajouter une UI de sélection modale dans HubAntre sans créer de .tscn.

```gdscript
## Pattern: overlay Control créé à la demande, caché plutôt que supprimé
var _perk_overlay: Control = null

func _show_perk_overlay() -> void:
    if _perk_overlay != null and is_instance_valid(_perk_overlay):
        _perk_overlay.visible = true  # Réafficher sans recréer
        return
    # Créer l'overlay...
    _perk_overlay = Control.new()
    _perk_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(_perk_overlay)

func _on_confirmed() -> void:
    _perk_overlay.visible = false  # Masquer, pas queue_free()
```

**Règles**:
- `visible = false` pour fermer (réutilisable), jamais `queue_free()` si on veut rouvrir
- `PRESET_FULL_RECT` sur l'overlay = couvre toute la scène parente
- `set_meta("pending_perk", value)` pour passer des données via le noeud sans variables globales

### 9.2 Store State Extension — Champs Persistants vs Run

**Contexte**: B.1 — selected_perk doit persister entre runs, perk_used reset à chaque run.

```gdscript
# CORRECT: dans _init_triade_run() — preservation sélective
var prev_perks: Dictionary = run.get("perks", {})
run["perks"] = {
    "selected_perk": str(prev_perks.get("selected_perk", "")),  # persistant
    "perk_used": false,  # reset
}

# WRONG: reset complet qui efface la sélection inter-runs
run["perks"] = {"selected_perk": "", "perk_used": false}
```

**Règle**: Toujours vérifier quelles données doivent survivre au reset de run avant d'écraser.

### 9.3 Dispatch SELECT_PERK Pattern

**Validation dans le dispatch**:
```gdscript
"SELECT_PERK":
    var perk_id: String = str(action.get("perk_id", ""))
    if not perk_id.is_empty() and not MerlinConstants.SOUFFLE_PERK_TYPES.has(perk_id):
        return {"ok": false, "error": "unknown_perk: " + perk_id}
    # ... update state
```

**Règle**: Valider le `perk_id` contre `SOUFFLE_PERK_TYPES` AVANT d'écrire dans le state. Retourner `{"ok": false}` avec message d'erreur explicite.

---

*Last Updated: 2026-02-25 (Section 9: UI Overlay + Store State Patterns — B.1 Souffle Perk)*
*Maintained by: Debug Agent, Optimizer Agent & Task Dispatcher*

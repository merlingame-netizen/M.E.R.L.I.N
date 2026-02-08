extends CharacterBody3D
class_name PlayerFPS

## Vitesse de déplacement
@export var move_speed: float = 4.0
## Vitesse de sprint
@export var sprint_speed: float = 7.0
## Sensibilité de la souris
@export var mouse_sensitivity: float = 0.003
## Limite verticale du regard
@export var max_look_angle: float = 89.0

@onready var camera: Camera3D = $Camera3D

var current_speed: float = move_speed
var gravity: float = 12.0

func _ready() -> void:
	# Capturer la souris immédiatement pour le contrôle FPS
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Réinitialiser la rotation de la caméra
	if camera:
		camera.rotation = Vector3.ZERO

func _input(event: InputEvent) -> void:
	# Gestion de la souris pour regarder
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Rotation horizontale (sur le corps du joueur)
		rotate_y(-event.relative.x * mouse_sensitivity)
		
		# Rotation verticale (sur la caméra uniquement)
		if camera:
			camera.rotate_x(-event.relative.y * mouse_sensitivity)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-max_look_angle), deg_to_rad(max_look_angle))
	
	# Échap pour libérer/capturer la souris
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Clic gauche pour recapturer la souris si libérée
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	# Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Sprint avec Shift
	if Input.is_key_pressed(KEY_SHIFT):
		current_speed = sprint_speed
	else:
		current_speed = move_speed
	
	# Direction de mouvement (ZQSD et WASD)
	var input_dir := Vector2.ZERO
	
	# Avant
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
		input_dir.y -= 1
	# Arrière
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	# Gauche
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
		input_dir.x -= 1
	# Droite
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	# Calculer la direction de mouvement basée sur l'orientation du joueur
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		# Décélération
		velocity.x = move_toward(velocity.x, 0, current_speed * 5 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 5 * delta)
	
	move_and_slide()

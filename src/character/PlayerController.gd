class_name PlayerController
extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var dash_speed: float = 25.0
@export var jump_force: float = 5000.0
@export var dash_duration: float = 0.2

var mouse_sensitivity := 0.15

# Components
@onready var head : Node3D = $Head

#var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity: float = 300.0

var is_sprinting: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0


# https://www.youtube.com/watch?v=xIKErMgJ1Yk

func _ready() -> void:
	# Set the player as the center of the map generation
	MapGeneration.generation_center_node = self

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	print("Player Gravity: %f" % [gravity])

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		
		# Character rotation
		rotate_y(deg_to_rad(-e.relative.x * mouse_sensitivity))

		# Head rotation
		head.rotate_x(deg_to_rad(-e.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Movement input
	var input_dir := get_input_vector()
	input_dir = (transform.basis * input_dir).normalized()
	var target_speed := walk_speed
	
	# Sprinting
	if Input.is_action_pressed("sprint") and not is_dashing:
		target_speed = sprint_speed
		is_sprinting = true
	else:
		is_sprinting = false

	# Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_force

	# Dashing
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		if Input.is_action_just_pressed("dash"):
			is_dashing = true
			dash_timer = dash_duration

	velocity = velocity.normalized()
	if is_dashing:
		velocity = velocity * dash_speed
	else:
		var movement := input_dir * target_speed
		velocity.x = movement.x
		velocity.z = movement.z

	move_and_slide()	




func get_input_vector() -> Vector3:
	var inputDir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return Vector3(inputDir.x, 0.0, inputDir.y).normalized()


# Required for the MapGeneration.gd script
func get_map_generation_center_position() -> Vector3:
	return global_transform.origin

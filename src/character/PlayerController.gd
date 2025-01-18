class_name PlayerController
extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 10.0
@export var dash_speed: float = 25.0
@export var jump_force: float = 15.0
@export var gravity: float = -30.0
@export var dash_duration: float = 0.35

var is_sprinting: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0

# @onready var camera := $Target/Camera3D as Camera3D

# https://www.youtube.com/watch?v=C-1AerTEjFU&t=210s

func _ready() -> void:
	MapGeneration.generation_center_node = self

func get_map_generation_center_position() -> Vector3:
	return global_transform.origin

func get_input_vector() -> Vector3:
	var inputDir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var ret: Vector3 = Vector3(inputDir.x, 0, inputDir.y)
	return ret.normalized()

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	# Movement input
	var input_dir := get_input_vector()
	var target_speed := walk_speed
	
	# Sprinting
	if Input.is_action_pressed("sprint") and not is_dashing:
		target_speed = sprint_speed
		is_sprinting = true
	else:
		is_sprinting = false

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

	# Jumping
	if Input.is_action_just_pressed("move_upward") and is_on_floor():
		velocity.y = jump_force

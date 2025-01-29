class_name PlayerController
extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var dash_speed: float = 25.0
@export var dash_duration: float = 0.18

var mouse_sensitivity := 0.15

# Components
@onready var head : Node3D = $Head

# Gravity & Jumping
# See https://www.youtube.com/watch?v=IOe1aGY6hXA
# (0,0,0) is at the feet of the character, so this is the height of the feet at max jump height
var jump_height: float = 2.2
var jump_time_to_peak_sec: float = 0.65
var jump_time_to_descent_sec: float = 0.45

# TODO recalculate on change
@onready var jump_velocity: float = (2.0 * jump_height) / jump_time_to_peak_sec
@onready var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak_sec**2)
@onready var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_descent_sec**2)

var max_num_jumps: int = 3
var current_num_jumps: int = 0

# Terrible, implement a proper state machine
var is_sprinting: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0


# https://www.youtube.com/watch?v=xIKErMgJ1Yk

func _ready() -> void:
	# Set the player as the center of the map generation
	MapGeneration.generation_center_node = self

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_current_gravity() -> float:
	if velocity.y < 0.0:
		return jump_gravity
	else:
		return fall_gravity


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		
		# Character rotation
		rotate_y(deg_to_rad(-e.relative.x * mouse_sensitivity))

		# Head rotation
		head.rotate_x(deg_to_rad(-e.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
		

func jump() -> void:
	# Overwrite, this always gives the same impulse
	velocity.y = jump_velocity

func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity.y += get_current_gravity() * delta

	# Movement input
	var input_dir := get_input_vector()
	input_dir = (transform.basis * input_dir).normalized()

	# Speed
	var target_speed := walk_speed
	
	# Sprinting
	if Input.is_action_pressed("sprint") and not is_dashing:
		target_speed = sprint_speed
		is_sprinting = true
	else:
		is_sprinting = false

	if is_dashing:
		target_speed = dash_speed

	# Jumping
	if is_on_floor():
		current_num_jumps = 0

	if Input.is_action_just_pressed("jump") and current_num_jumps < max_num_jumps:
		jump()
		current_num_jumps += 1


	# Dashing
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		if Input.is_action_just_pressed("dash"):
			is_dashing = true
			dash_timer = dash_duration

	# Apply movement		
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

class_name PlayerController
extends CharacterBody3D

# Components
@onready var head: Node3D = $Head


var walk_speed: float = 5.0
var sprint_speed: float = 9.0
var dash_speed: float = 25.0
var dash_duration: float = 0.2

var air_control: float = 0.35
var dash_control: float = 0.5

var mouse_sensitivity := 0.15

# Gravity & Jumping
# See https://www.youtube.com/watch?v=IOe1aGY6hXA
# (0,0,0) is at the feet of the character, so this is the height of the feet at max jump height
var jump_height: float = 2.55
var jump_time_to_peak_sec: float = 1.65
var jump_time_to_descent_sec: float = 1.45

# Input buffering
var jump_input_buffer_time: float = 0.5
var jump_buffer_timer: float = 0.0


# Debugging
var print_timer: float = 0.0

# Multi-Jump
var max_num_jumps: int = 3
var currently_used_jumps: int = 0
var jump_strength_factors: Array[float] = [1.0, 0.8, 0.8]

# Terrible, implement a proper state machine
var is_sprinting: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0


# https://www.youtube.com/watch?v=xIKErMgJ1Yk
# TODO https://shaggydev.com/2022/02/13/advanced-state-machines-godot/

func _ready() -> void:
	# Set the player as the center of the map generation
	MapGeneration.generation_center_node = self

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_current_gravity() -> float:
	var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak_sec ** 2)
	var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_descent_sec ** 2)

	# Chose gravity based on current up vs downward velocity
	if velocity.y < 0.0:
		return jump_gravity
	else:
		return fall_gravity


func _input(event: InputEvent) -> void:
	###################
	### Mouse Input
	###################
	if event is InputEventMouseMotion:
		var e := event as InputEventMouseMotion
		
		# Character rotation
		rotate_y(deg_to_rad(-e.relative.x * mouse_sensitivity))

		# Head rotation
		head.rotate_x(deg_to_rad(-e.relative.y * mouse_sensitivity))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	###################
	### Keyboard Input
	###################
		

func jump() -> void:
	# Determine number of jump
	var jump_index: int = currently_used_jumps
	currently_used_jumps += 1

	# Calculate jump velocity
	var jump_velocity: float = (2.0 * jump_height) / jump_time_to_peak_sec
	velocity.y = jump_velocity * jump_strength_factors[jump_index]
	
	# Overwrite current vertical velocity => this always gives the same impulse
	velocity.y = jump_velocity

func _physics_process(delta: float) -> void:
	# Timers
	jump_buffer_timer -= delta
	dash_timer -= delta

	print_timer -= delta

	# Apply gravity
	if not is_on_floor():
		velocity.y += get_current_gravity() * delta

	# Movement input
	var input_dir := get_input_vector()
	input_dir = (transform.basis * input_dir).normalized()
	
	# Sprinting
	if Input.is_action_pressed("sprint") and not is_dashing:
		is_sprinting = true
	else:
		is_sprinting = false

	# Jumping
	if is_on_floor():
		currently_used_jumps = 0

	if Input.is_action_just_pressed("jump") and currently_used_jumps < max_num_jumps:
		jump()

	# Dashing
	if is_dashing:
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		if Input.is_action_just_pressed("dash"):
			is_dashing = true
			dash_timer = dash_duration

	# Determine desired speed
	var desired_horizontal_speed: float
	if is_dashing:
		desired_horizontal_speed = dash_speed
	elif is_sprinting:
		desired_horizontal_speed = sprint_speed
	else:
		desired_horizontal_speed = walk_speed

	# Determine control factor
	var control_factor: float
	if is_on_floor():
		control_factor = 1.0
	else:
		control_factor = air_control
	if is_dashing:
		# TODO this doesnt make sense.
		# We want limited player control but the previous direction should apply with full force
		# We need two variables for this
		control_factor = min(control_factor, dash_control)

	# Calculate desired velocity based on WASD input (horizontal)
	var desired_velocity_horizontal: Vector3 = input_dir * desired_horizontal_speed

	# Calculate velocity change based on desired velocity and input control factor
	var change_speed_factor: float = remap(control_factor, 0.0, 1.0, 1.0, 20.0)
	var curr_velocity_horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var new_velocity_horizontal: Vector3 = expchange_speedVec3(curr_velocity_horizontal, desired_velocity_horizontal, change_speed_factor, delta)

	# Limit velocity to desired speed
	# TODO this is broken as it only caps from fast -> slow.
	# var old_length: float = new_velocity_horizontal.length()
	# new_velocity_horizontal = new_velocity_horizontal.limit_length(desired_horizontal_speed)
	# # Debug print only
	# if old_length > new_velocity_horizontal.length():
	# 	print("Limiting speed from %f -> $%f" % [old_length, new_velocity_horizontal.length()])

	# Apply velocity (only horizontal)
	velocity.x = new_velocity_horizontal.x
	velocity.z = new_velocity_horizontal.z

	if print_timer <= 0.0:
		print_timer = 1.0 / 20.0
		print("Velocity: %6.2v , max_speed: %.1f , control: %.2f , change_speed: %.2f" % [velocity, desired_horizontal_speed, control_factor, change_speed_factor])

	move_and_slide()


func get_input_vector() -> Vector3:
	var inputDir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return Vector3(inputDir.x, 0.0, inputDir.y).normalized()


# Required for the MapGeneration.gd script
func get_map_generation_center_position() -> Vector3:
	return global_transform.origin


# See https://youtu.be/LSNQuFEDOyQ?si=pLfLIFVZXPFaMWlw&t=3010
# Exponential change_speed constant, usefull range approx. [1, 25], higher values change_speed faster
# Use as a = expchange_speed(a, b, change_speed, dt)
# With a = current value, b = target value, change_speed = change_speed constant, dt = delta time
func expchange_speed(a: float, b: float, change_speed: float, dt: float) -> float:
	return b + (a - b) * exp(-change_speed * dt)

func expchange_speedVec2(a: Vector2, b: Vector2, change_speed: float, dt: float) -> Vector2:
	return Vector2(expchange_speed(a.x, b.x, change_speed, dt), expchange_speed(a.y, b.y, change_speed, dt))

func expchange_speedVec3(a: Vector3, b: Vector3, change_speed: float, dt: float) -> Vector3:
	return Vector3(expchange_speed(a.x, b.x, change_speed, dt), expchange_speed(a.y, b.y, change_speed, dt), expchange_speed(a.z, b.z, change_speed, dt))

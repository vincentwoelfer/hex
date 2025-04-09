class_name PlayerController
extends CharacterBody3D

# Components
var walk_speed: float = 5.0
var sprint_speed: float = 9.0
var dash_speed: float = 25.0
var dash_duration: float = 0.2
var player_data: PlayerData

var time_to_max_acc: float = 0.085

# Computed once based on walk_speed / walk_acceleration
var deceleration: float

# var air_control: float = 0.35
# var dash_control: float = 0.5

# Gravity & Jumping
# For equations see: https://www.youtube.com/watch?v=IOe1aGY6hXA
# (0,0,0) is at the feet of the character, so this is the height of the feet at max jump height
var jump_height: float = 2.55
var jump_time_to_peak_sec: float = 0.65
var jump_time_to_descent_sec: float = 0.55
# todo apex time

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

var input: MovementInput

@onready var collision: CollisionShape3D = $Collision
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent

# First person youtube videos:
# https://www.youtube.com/watch?v=xIKErMgJ1Yk

var color: Color

func init(device: int, color_: Color) -> void:
	input = MovementInput.new(device)
	self.color = color_

	# Compute deceleration based on walk speed and time to max acc
	var walk_accel: float = _get_acc_for_target_vel_and_time(walk_speed, time_to_max_acc)
	self.deceleration = walk_accel


func _ready() -> void:
	path_finding_agent.init(color, collision.shape)
	path_finding_agent.show_path = DebugSettings.show_path_player_to_caravan
	path_finding_agent.set_track_target(GameStateManager.caravan)

	
func _get_current_gravity() -> float:
	var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak_sec ** 2)
	var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_descent_sec ** 2)

	# Chose gravity based on current up vs downward vel
	if velocity.y < 0.0:
		return fall_gravity
	else:
		return jump_gravity


func _input(event: InputEvent) -> void:
	input.handle_input_event(event)

	# Apply mouse movement: Character rotation
	# rotate_y(input.relative_rotation.y)

	# Apply mouse movement: Head rotation
	# head.rotate_x(input.relative_rotation.x)
	# head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	input.consume_mouse_input()


func _physics_process(delta: float) -> void:
	input.update_keys(delta)

	# Timers
	dash_timer -= delta

	# Movement input
	var input_dir := input.input_direction
	input_dir = (transform.basis * input_dir).normalized()

	# Sprinting
	if input.wants_sprint and not is_dashing:
		is_sprinting = true
	else:
		is_sprinting = false

	# Jumping
	if is_on_floor():
		currently_used_jumps = 0

	if input.jump_input.wants and currently_used_jumps < max_num_jumps:
		input.jump_input.consume()
		jump()

	# Dashing
	if is_dashing:
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		if input.dash_input.wants:
			input.dash_input.consume()
			is_dashing = true
			dash_timer = dash_duration
	
	# Test lightning
	if input.primary_input.wants:
		input.primary_input.consume()
		player_data.lightning_particles.show()

		var timer = get_tree().create_timer(3.0)
		timer.timeout.connect(func(): player_data.lightning_particles.hide())

	# Determine target vel based on state -> TODO rework into state machine
	var target_planar_speed: float
	if is_dashing:
		target_planar_speed = dash_speed
	elif is_sprinting:
		target_planar_speed = sprint_speed
	else:
		target_planar_speed = walk_speed
	target_planar_speed = target_planar_speed if input_dir.length() > 0.0 else 0.0

	# Acceleration & Deceleration
	var acceleration: float = _get_acc_for_target_vel_and_time(target_planar_speed, time_to_max_acc)
	var new_vel_horizontal: Vector2 = compute_planar_velocity(Vector2(velocity.x, velocity.z),
															  Vector2(input_dir.x, input_dir.z),
															  target_planar_speed, acceleration, deceleration, delta)

	# Only for debugging
	var delta_vel: float = new_vel_horizontal.length() - Vector2(velocity.x, velocity.z).length()

	# Apply vel (only horizontal)
	velocity.x = new_vel_horizontal.x
	velocity.z = new_vel_horizontal.y

	# Apply gravity
	if not is_on_floor():
		velocity.y += _get_current_gravity() * delta

	# print_timer -= delta
	# print_timer = -1.0
	# if print_timer <= 0.0:
	# 	print_timer = 1.0 / 30.0
	# 	var cur_vel := Vector2(velocity.x, velocity.z).length()
	# 	print("vel: %6.2f target_vel: %6.2f, delta_vel: %6.2f, accel: %.2f, decel: %.2f" % [cur_vel, target_planar_speed, delta_vel, acceleration, deceleration])

	move_and_slide()

	# Update path for visualization only
	

# Speed = float
# Velocity = Vector
func compute_planar_velocity(curr_vel: Vector2, input_dir: Vector2, target_speed: float, accel: float, decel: float, delta: float) -> Vector2:
	var current_speed: float = curr_vel.length()

	# Compute target velocity in the XZ plane
	var target_vel: Vector2 = input_dir * target_speed

	# Compute velocity difference
	var vel_delta: Vector2 = target_vel - curr_vel

	# Determine acceleration or deceleration
	var vel_change_strength: float = accel if vel_delta.dot(input_dir) > 0.0 else decel
	# if is_equal_approx(vel_change_strength, accel):
		# print("Accelerating")
	# elif is_equal_approx(vel_change_strength, decel):
		# print("Decelerating")
	# else:
		# print("No acceleration or deceleration")

	# Apply acceleration/deceleration
	var vel_change: Vector2 = vel_delta.normalized() * vel_change_strength * delta

	# Prevent overshooting (this also works for deceleration towards 0)
	if vel_change.length() > vel_delta.length():
		vel_change = vel_delta

	# Update velocity & limit to target speed
	var new_vel: Vector2 = curr_vel + vel_change
	curr_vel = curr_vel.limit_length(target_speed)
	return new_vel


func _get_acc_for_target_vel_and_time(target_vel: float, time_to_max: float) -> float:
	return target_vel / time_to_max


func jump() -> void:
	# Determine number of jump
	var jump_index: int = currently_used_jumps
	currently_used_jumps += 1

	# Calculate jump vel
	var jump_vel: float = (2.0 * jump_height) / jump_time_to_peak_sec
	jump_vel *= jump_strength_factors[jump_index]

	# Overwrite current vertical vel => this always gives the same impulse
	velocity.y = jump_vel

	# Vibration
	# Input.start_joy_vibration(0, 0.0, 1.0, 0.2 + 0.1 * jump_index)

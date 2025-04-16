class_name PlayerController
extends HexPhysicsCharacterBody3D

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
# (0,0,0) is at the feet of the character, so this is the height of the feet at max _jump height
var jump_height: float = 2.55
var jump_time_to_peak_sec: float = 0.65
var jump_time_to_descent_sec: float = 0.55
# todo apex time

# Debugging
var print_timer: float = 0.0

# Multi-Jump
var max_num_jumps: int = 2
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

# Carrying / Crystals
var is_carrying: bool = false

func init(device: int, color_: Color) -> void:
	input = MovementInput.new(device)
	self.color = color_

	# Compute deceleration based on walk speed and time to max acc
	# var walk_accel: float = _get_acc_for_target_vel_and_time(walk_speed, time_to_max_acc)
	# self.deceleration = walk_accel


func _ready() -> void:
	add_to_group(HexConst.GROUP_PLAYERS)

	# Only for visualization
	path_finding_agent.init(color, collision.shape, DebugSettings.show_path_player_to_caravan)
	path_finding_agent.set_track_target(GameStateManager.caravan)


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

	# GET DESIRED INPUT DIRECTION
	var input_dir: Vector3 = input.input_direction
	input_dir = (transform.basis * input_dir).normalized()

	# Sprinting
	if input.wants_sprint and not is_dashing:
		is_sprinting = true
	else:
		is_sprinting = false

	# Jumping
	if is_on_floor():
		currently_used_jumps = 0

	var jump_vel := 0.0
	if input.jump_input.wants and currently_used_jumps < max_num_jumps:
		input.jump_input.consume()
		jump_vel = _jump()

	# Dashing
	if is_dashing:
		if dash_timer <= 0.0:
			is_dashing = false
	else:
		if input.dash_input.wants:
			input.dash_input.consume()
			is_dashing = true
			dash_timer = dash_duration
	
	# Lightning
	if input.skill_primary_input.wants:
		input.skill_primary_input.consume()
		VisualLightningStrike.spawn(self.global_position)

	# Throw bomb
	if input.skill_secondary_input.wants:
		input.skill_secondary_input.consume()
		# TODO

	# Determine target vel based on state -> TODO rework into state machine
	var target_planar_speed: float
	if is_dashing:
		target_planar_speed = dash_speed
	elif is_sprinting:
		target_planar_speed = sprint_speed
	else:
		target_planar_speed = walk_speed

	var m: CharMovement = CharMovement.new()
	m.input_dir = Util.to_vec2(input_dir)
	m.input_speed = target_planar_speed
	
	m.accel_ramp_time = self.time_to_max_acc
	m.decel_ramp_time = self.time_to_max_acc
	m.max_possible_speed = self.walk_speed

	m.input_control_factor = 1.0
	m.vertical_override = jump_vel

	# Execute movement
	self._custom_physics_process(delta, m)

	
func _jump() -> float:
	# Determine number of _jump
	var jump_index: int = currently_used_jumps
	currently_used_jumps += 1

	# Calculate _jump vel
	var jump_vel: float = (2.0 * jump_height) / jump_time_to_peak_sec
	jump_vel *= jump_strength_factors[jump_index]

	# Overwrite current vertical vel => this always gives the same impulse
	# velocity.y = jump_vel

	# Vibration
	Input.start_joy_vibration(0, 0.0, 1.0, 0.2 + 0.1 * jump_index)

	return jump_vel


func _get_custom_gravity() -> float:
	var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak_sec ** 2)
	var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_descent_sec ** 2)

	# Chose gravity based on current up vs downward vel
	if velocity.y < 0.0:
		return fall_gravity
	else:
		return jump_gravity

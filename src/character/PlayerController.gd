class_name PlayerController
extends HexPhysicsCharacterBody3D

# Components
var walk_speed: float = 5.0
var sprint_speed: float = 9.0
var dash_speed: float = 28.0
var dash_duration: float = 0.05
var player_data: PlayerData

var time_to_max_acc: float = 0.085

# First person youtube videos: # https://www.youtube.com/watch?v=xIKErMgJ1Yk
# var air_control: float = 0.35
# var dash_control: float = 0.5

# Gravity & Jumping
# For equations see: https://www.youtube.com/watch?v=IOe1aGY6hXA
# (0,0,0) is at the feet of the character, so this is the height of the feet at max _jump height
var jump_height: float = 2.55
var jump_time_to_peak_sec: float = 0.65
var jump_time_to_descent_sec: float = 0.55
# todo apex time

# Multi-Jump
var max_num_jumps: int = 2
var currently_used_jumps: int = 0
var jump_strength_factors: Array[float] = [1.0, 0.8, 0.8]

# Terrible, implement a proper state machine
var is_sprinting: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0

var input: InputManager

@onready var collision: CollisionShape3D = $Collision
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var pick_up_manager: PickUpManager = $RotationAxis/PickUpManager
@onready var hex_character: HexPhysicsCharacterBody3D = $"."

var color: Color

func init(device: int, color_: Color) -> void:
	input = InputManager.new(device)
	self.color = color_
	self.mass = 10.0


func _ready() -> void:
	add_to_group(HexConst.GROUP_PLAYERS)

	hex_character.connect("Signal_huge_impulse_received", _huge_impulse_received)

	# Only for visualization
	path_finding_agent.init(color, collision.shape, DebugSettings.show_path_player_to_caravan)
	path_finding_agent.set_track_target(GameStateManager.caravan)


func _physics_process(delta: float) -> void:
	input.update_keys(delta)

	# Timers
	dash_timer -= delta

	# Sprinting
	# if input.wants_sprint and not is_dashing:
	# 	is_sprinting = true
	# else:
	# 	is_sprinting = false
	# TODO DISABLED for not
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
	# if input.skill_primary_input.wants:
		# input.skill_primary_input.consume()
		# VisualLightningStrike.spawn(self.global_position)

	# Throw bomb
	if input.skill_secondary_input.wants:
		input.skill_secondary_input.consume()
		throw_bomb()

	if input.pickup_drop_input.wants:
		input.pickup_drop_input.consume()
		pick_up_manager.perform_pickup_or_drop_action()

	var input_dir: Vector3 = (transform.basis * input.input_direction).normalized()

	var m: CharMovement = CharMovement.new()
	m.input_dir = Util.to_vec2(input_dir)
	m.input_speed = _get_current_speed()
	
	m.accel_ramp_time = self.time_to_max_acc
	m.decel_ramp_time = self.time_to_max_acc
	m.max_possible_speed = self.walk_speed

	m.input_control_factor = 1.0
	m.vertical_override = jump_vel

	# Execute movement
	self._custom_physics_process(delta, m)


func _get_current_speed() -> float:
	# Determine target vel based on state -> TODO rework into state machine
	var target_planar_speed: float
	if is_dashing:
		target_planar_speed = dash_speed
	elif is_sprinting:
		target_planar_speed = sprint_speed
	else:
		target_planar_speed = walk_speed
	return target_planar_speed
	
func _jump() -> float:
	# Determine number of _jump
	var jump_index: int = currently_used_jumps
	currently_used_jumps += 1

	# Calculate _jump vel
	var jump_vel: float = (2.0 * jump_height) / jump_time_to_peak_sec
	jump_vel *= jump_strength_factors[jump_index]

	# Vibration
	Input.start_joy_vibration(input.device_id, 0.0, 1.0, 0.2 + 0.15 * jump_index)

	return jump_vel


func _get_custom_gravity() -> float:
	var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak_sec ** 2)
	var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_descent_sec ** 2)

	# Chose gravity based on current up vs downward vel
	if velocity.y < 0.0:
		return fall_gravity
	else:
		return jump_gravity


func throw_bomb() -> void:
	Input.start_joy_vibration(input.device_id, 0.0, 0.3, 0.2)

	var bomb: ThrowableBomb = ResLoader.THROWABLE_BOMB_SCENE.instantiate()
	bomb.add_collision_exception_with(self)

	var hold_offset: Vector3 = Vector3.FORWARD * 0.5 + Vector3.UP * 0.8
	var throw_origin := global_transform.origin + rotation_axis.basis * hold_offset

	Util.spawn(bomb, throw_origin)

	# Apply torque (rotation)
	var torque_strength: float = 1.5
	var torque := Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)) * torque_strength
	bomb.apply_torque_impulse(torque)

	# Apply force
	var throw_dir: Vector3 = Vector3.FORWARD * 0.65 + Vector3.UP * 0.55
	throw_dir = throw_dir.normalized()
	var throw_force: float = 40.0
	var force: Vector3 = rotation_axis.basis * throw_dir * throw_force
	bomb.apply_central_impulse(force)

	# Hacky
	await Util.await_time(0.5)
	if bomb != null:	
		bomb.remove_collision_exception_with(self)


func _huge_impulse_received() -> void:
	Input.start_joy_vibration(input.device_id, 0.5, 0.0, 0.2)

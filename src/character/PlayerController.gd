class_name PlayerController
extends HexPhysicsCharacterBody3D

# Components
var walk_speed: float = 5.0
var sprint_speed: float = 9.0
var dash_speed: float = 25.0
var dash_duration: float = 0.04
var player_data: PlayerData

var time_to_max_acc: float = 0.085

# First person youtube videos: # https://www.youtube.com/watch?v=xIKErMgJ1Yk
# var air_control: float = 0.35
# var dash_control: float = 0.5

# Gravity & Jumping
# For equations see: https://www.youtube.com/watch?v=IOe1aGY6hXA
# (0,0,0) is at the feet of the character, so this is the height of the feet at max _jump height
var jump_height: float = 2.5
var jump_time_to_peak_sec: float = 0.55
var jump_time_to_descent_sec: float = 0.4
# todo apex time

# Multi-Jump
var max_num_jumps: int = 2
var currently_used_jumps: int = 0
var jump_strength_factors: Array[float] = [1.0, 0.95]

# Terrible, implement a proper state machine
var is_sprinting: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var is_slamming := false

var input: InputManager

# Components
@onready var collision: CollisionShape3D = $Collision
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var pick_up_manager: PickUpManager = $RotationAxis/PickUpManager

var current_gadget: AbstractGadget = null

var color: Color

func init(device: int, color_: Color) -> void:
	input = InputManager.new(device, self)
	self.color = color_


func _ready() -> void:
	Signal_huge_impulse_received.connect(self._on_huge_impulse_received)

	# Initalize components
	pick_up_manager.hex_character = self
	Signal_huge_impulse_received.connect(pick_up_manager.drop_to_ground_with_impulse)

	# Only for visualization
	path_finding_agent.init(color, collision.shape, DebugSettings.show_path_player_to_caravan)
	path_finding_agent.set_track_target(GameStateManager.caravan)


func _physics_process(delta: float) -> void:
	input.process(delta, self)

	# Timers
	dash_timer -= delta

	# Sprinting
	# if input.wants_sprint and not is_dashing:
	# 	is_sprinting = true
	# else:
	# 	is_sprinting = false
	# TODO DISABLED for not
	is_sprinting = false

	#################################################
	# Jumping / Slamming
	#################################################
	if is_on_floor():
		currently_used_jumps = 0

		# Slam check
		if is_slamming:
			is_slamming = false
			_slam_effect()

	var vertical_vel_override := 0.0
	if input.jump_input.wants:
		# Normal jump
		if currently_used_jumps < max_num_jumps:
			input.jump_input.consume()
			vertical_vel_override = _jump()
		# Slam (exactly once)
		elif currently_used_jumps == max_num_jumps and not is_on_floor():
			input.jump_input.consume()
			vertical_vel_override = _slam()
			is_slamming = true

	#################################################
	# Dashing
	#################################################
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
		# VFXLightningStrike.spawn(self.global_position)

	#################################################
	# Drop / Pickup
	#################################################
	if input.pickup_drop_input.wants:
		input.pickup_drop_input.consume()
		pick_up_manager.perform_pickup_or_drop_action()

	#################################################
	# Movement
	#################################################
	var input_dir: Vector3 = (transform.basis * input.input_direction).normalized()

	var m: HexCharMovementParams = HexCharMovementParams.new()
	m.input_dir = Util.to_vec2(input_dir)
	m.input_speed = _get_current_speed()
	m.has_looking_dir = true
	m.looking_dir = Util.to_vec2(input.looking_dir)
	m.accel_ramp_time = _get_time_to_max_acc()
	m.decel_ramp_time = _get_time_to_max_acc()
	m.max_possible_speed = _get_current_speed()
	m.input_control_factor = 1.0
	m.vertical_override = vertical_vel_override

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

func _get_time_to_max_acc() -> float:
	# Determine time to max acceleration based on state
	if is_dashing:
		return 0.0
	else:
		return time_to_max_acc

func _jump() -> float:
	# Determine number of _jump
	var jump_index: int = currently_used_jumps
	currently_used_jumps += 1

	# Calculate _jump vel
	var jump_vel: float = (2.0 * jump_height) / jump_time_to_peak_sec
	jump_vel *= jump_strength_factors[jump_index]

	# Vibration
	Input.start_joy_vibration(input.device_id, 0.0, 1.0, 0.1 + 0.1 * jump_index)

	return jump_vel

func _slam() -> float:
	currently_used_jumps += 1

	# TODO base slam vel on height (ray-cast) to get semi-consistent slam time
	var slam_vel := -45.0

	# Vibration
	Input.start_joy_vibration(input.device_id, 0.0, 1.0, 0.2)

	return slam_vel


func _get_custom_gravity() -> float:
	var jump_gravity: float = (-2.0 * jump_height) / (jump_time_to_peak_sec ** 2)
	var fall_gravity: float = (-2.0 * jump_height) / (jump_time_to_descent_sec ** 2)

	# Chose gravity based on current up vs downward vel
	if velocity.y < 0.0:
		return fall_gravity
	else:
		return jump_gravity


func pickup_gadget(gadget: AbstractGadget) -> void:
	if current_gadget:
		current_gadget.queue_free()

	current_gadget = gadget
	current_gadget.init(input)

	# Add to parent
	rotation_axis.add_child(current_gadget)

func drop_gadget() -> void:
	if current_gadget:
		current_gadget.queue_free()
		current_gadget = null

func _on_huge_impulse_received(impulse: Vector3) -> void:
	Input.start_joy_vibration(input.device_id, 0.0, 1.0, 0.05)


# Only executed once per slam
func _slam_effect() -> void:
	const slam_radius := 2.5
	const slam_height := 0.75
	const slam_force := 130.0

	# var effect := DebugVis3D.cylinder(slam_radius, slam_height, DebugVis3D.mat(Color(Color.RED.lightened(0.25), 0.15), false))
	# var effect_node := DebugVis3D.spawn(global_position + Vector3.UP * 0.5 * slam_height, effect)
	# Util.delete_after(0.25, effect_node)

	VFXFlameExplosionRadial.spawn_global_pos(global_position + Vector3.UP * 1.0)
	VFXAoeRangeIndicator.spawn_global_pos(global_position, slam_radius, 0.3)

	# Define area
	var area := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = slam_radius
	shape.height = slam_height
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.set_collision_mask_value(Layers.PHY.PLAYER_CHARACTERS, true)
	area.set_collision_mask_value(Layers.PHY.ENEMY_CHARACTERS, true)
	area.set_collision_mask_value(Layers.PHY.PICKABLE_OBJECTS, true)
	area.add_child(collision_shape)

	Util.spawn(area, global_position)

	# Required for the newly added area to work
	await get_tree().physics_frame
	await get_tree().physics_frame

	# APPLY
	var bodies := area.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue

		var impulse := Util.calculate_explosion_impulse(global_position, body.global_position, slam_force, slam_radius)

		if body is RigidBody3D:
			var rigid_body: RigidBody3D = body

			# Less impulse for bombs
			if body is ThrowableBomb:
				impulse *= 0.5
			rigid_body.apply_central_impulse(impulse)
			continue

		elif body is HexPhysicsCharacterBody3D:
			var hex_body: HexPhysicsCharacterBody3D = body

			# IMPULSE to players / Caravan
			if hex_body.is_in_group(HexConst.GROUP_PLAYERS) or (hex_body == GameStateManager.caravan):
				# TODO for now add additional force to the character to counteract the bug in its movement code
				impulse *= 2.0
				hex_body.apply_external_impulse(impulse)
				continue

			# Kill Enemies
			elif hex_body.is_in_group(HexConst.GROUP_ENEMIES):
				var enemy := hex_body as BasicEnemy
				enemy.pick_up_manager.drop_object()
				enemy.queue_free()
				continue


	await Util.await_time(0.15)
	area.queue_free()

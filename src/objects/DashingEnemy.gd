extends Node3D

@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var shape: CollisionShape3D = $CollisionShape3D

# Mesh rotation parameters
var current_rotation_speed_deg: float = 0.0
var max_rotation_speed_deg: float = 800.0

# Dashing parameters
var dash_speed_initial: float = 50.0
var dash_distance_max: float = 20.0

enum Mode {CHARGING, DASHING, COOLDOWN}
var mode: Mode = Mode.COOLDOWN

var cooldown_duration: float = 2.5
var charging_duration: float = 2.0

var cooldown_timestamp: float = 0.0
var charging_timestamp: float = 0.0

var tracked_player: Node3D = null
var target_position: Vector3 = Vector3.ZERO

# COLORS
var color_dashing: Color = Color.RED
var color_cooldown: Color = Color.RED.lerp(Color.BLACK, 0.7)


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	match mode:
		Mode.COOLDOWN:
			# Rotation speed
			current_rotation_speed_deg = 0.0

			# -> Charging
			if Util.has_time_passed(cooldown_timestamp, cooldown_duration):
				mode = Mode.CHARGING
				charging_timestamp = Util.now()
				tracked_player = get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS).pick_random()

		Mode.CHARGING:
			# Rotation speed
			var charge_complete_percentage: float = (Util.now() - charging_timestamp) / charging_duration
			current_rotation_speed_deg = lerpf(0.0, max_rotation_speed_deg, charge_complete_percentage)
			Util.change_material_color(mesh, color_cooldown.lerp(color_dashing, charge_complete_percentage))

			# Aim towards player
			_rotate_towards_player(delta)

			# -> Dashing
			if Util.has_time_passed(charging_timestamp, charging_duration):
				mode = Mode.DASHING
				target_position = _choose_target_position()
		
		Mode.DASHING:
			var to_target: Vector3 = target_position - global_position
			var distance: float = to_target.length()

			# Check how far we are from the target position
			const slow_after := 4.0
			var full_dash := clampf(distance / slow_after, 0.0, 1.0) # 1 = full dash, 0 = end of dash

			# Rotation & Movement speed
			current_rotation_speed_deg = max_rotation_speed_deg * full_dash
			var current_speed := lerpf(dash_speed_initial * 0.1, dash_speed_initial, full_dash)
			Util.change_material_color(mesh, color_cooldown.lerp(color_dashing, full_dash))
				
			# Move towards target
			if distance > current_speed * delta:
				global_position += to_target.normalized() * current_speed * delta
			else:
				global_position = target_position

				# -> Cooldown if target reached
				mode = Mode.COOLDOWN
				Util.change_material_color(mesh, color_cooldown)
				cooldown_timestamp = Util.now()
			
				
	# Rotate mesh - All modes
	var radians_per_frame: float = deg_to_rad(current_rotation_speed_deg) * delta
	mesh.rotate_object_local(Vector3.MODEL_TOP, radians_per_frame)


func _choose_target_position() -> Vector3:
	if tracked_player == null or tracked_player.is_queued_for_deletion():
		return global_position

	var current_facing: Vector3 = global_transform.basis.z
	current_facing.y = 0.0
	current_facing = current_facing.normalized()

	var target: Vector3 = global_position + current_facing * dash_distance_max
	target = PhysicUtil.get_raycast_height_on_map_surface(target, Layers.PHY.TERRAIN)

	# Shape collision test
	var shape_cast_height_offset: Vector3 = Vector3(0.0, 1.0 + 0.3, 0.0)

	var start := global_position + shape_cast_height_offset
	var end := target + shape_cast_height_offset

	var query := PhysicsShapeQueryParameters3D.new()
	query.set_shape(shape.shape)
	var basis_ := self.global_basis.rotated(Vector3.MODEL_LEFT, deg_to_rad(90)).rotated(Vector3.UP, self.rotation.y)
	query.transform = Transform3D(basis_, start)
	query.motion = end - start
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = Layers.PHY.TERRAIN

	var t := Util.get_space_state().cast_motion(query)[0]
	var final_target: Vector3 = global_position + query.motion * t
	final_target = PhysicUtil.get_raycast_height_on_map_surface(final_target, Layers.PHY.TERRAIN)

	# Visualize the target position
	# DebugVis3D.visualize_collision_shape_query_motion_with_hit(query, t, Color.GREEN, Color.RED, 3.0)

	return final_target

	
func _rotate_towards_player(delta: float) -> void:
	if tracked_player == null or tracked_player.is_queued_for_deletion():
		tracked_player = null
		return

	# Project the direction onto the XZ plane (ignore Y component)
	var to_target: Vector3 = tracked_player.global_position - self.global_position
	to_target.y = 0.0
	if to_target.length_squared() == 0.0:
		return
	to_target = to_target.normalized()

	var current_facing: Vector3 = global_transform.basis.z
	current_facing.y = 0.0
	current_facing = current_facing.normalized()

	# Compute the angle difference
	var angle_to_target: float = current_facing.signed_angle_to(to_target, Vector3.UP)
	var max_tracking_rotation_speed_deg: float = 180.0
	var max_step: float = deg_to_rad(max_tracking_rotation_speed_deg) * delta

	# Clamp rotation step to max allowed
	angle_to_target = clamp(angle_to_target, -max_step, max_step)
	self.rotate(Vector3.UP, angle_to_target)

class_name PathFindingAgent
extends Node3D

# Components
var debug_path: DebugPathInstance
var debug_path_2: DebugPathInstance

@onready var shape: CollisionShape3D = $Collision



func init(device: int, color: Color) -> void:
	debug_path = DebugPathInstance.new(Colors.set_alpha(color, 0.3), 0.05)
	debug_path_2 = DebugPathInstance.new(Colors.set_alpha(Color.DARK_BLUE, 0.3), 0.05)
	add_child(debug_path)
	add_child(debug_path_2)


func simplify_path(path: PackedVector3Array) -> PackedVector3Array:
	if path.size() < 3:
		return path # Nothing to simplify if path has less than 3 points

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var simplified_path := PackedVector3Array()

	var current_index := 0
	simplified_path.append(path[current_index])

	# Define the capsule shape for sweeping
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = (shape.shape as CapsuleShape3D).radius * 0.9
	capsule_shape.height = (shape.shape as CapsuleShape3D).height * 0.8
	var offset := Vector3(0, (shape.shape as CapsuleShape3D).height / 2.0, 0)

	const max_dist := 10.0
	const max_height_diff := 2.0

	# Iterate over path, try to connect current_index (from path start) with next_index, (from path end, moving backwards)
	while current_index < path.size() - 1:
		var next_index := path.size() - 1 # Try to jump directly to the end

		# Check if we can reach the furthest point directly
		while next_index > current_index + 1:
			# Only connect if
			# - path is clear
			# - distance is short enough
			# - low height difference
			# Check distance
			var distance := path[next_index].distance_to(path[current_index])
			if distance > max_dist:
				next_index -= 1
				continue

			# Check height difference
			var height_diff := absf(path[next_index].y - path[current_index].y)
			if height_diff > max_height_diff:
				next_index -= 1
				continue

			# Check path is clear
			var motion := path[next_index] - path[current_index]
			var query := PhysicsShapeQueryParameters3D.new()
			query.set_shape(capsule_shape)
			query.transform = Transform3D(Basis(), path[current_index] + offset)
			query.motion = motion
			query.collide_with_bodies = true
			query.collide_with_areas = false
			query.collision_mask = Layers.mask([Layers.L.TERRAIN, Layers.L.STATIC_GEOM])
			var result: PackedFloat32Array = space_state.cast_motion(query)

			if result[0] < 0.98:
				next_index -= 1
				continue

			# No issue -> Connect path points
			break

		# Move to the next reachable point
		current_index = next_index
		simplified_path.append(path[current_index])
	return simplified_path


func _update_path() -> void:
	var map: RID = get_world_3d().navigation_map
	# Do not query when the map has never synchronized and is empty.
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return

	var start_point: Vector3 = NavigationServer3D.map_get_closest_point(map, global_position)
	var origin_point: Vector3 = NavigationServer3D.map_get_closest_point(map, GameStateManager.caravan.get_global_transform().origin)
	var path := NavigationServer3D.map_get_path(map, start_point, origin_point, true)
	debug_path.update_path(path, global_position)

	var path_simplified := simplify_path(path)
	debug_path_2.update_path(path_simplified, global_position)


func _physics_process(delta: float) -> void:
	input.update_keys(delta)

	# Timers
	dash_timer -= delta

	# Apply gravity
	if not is_on_floor():
		velocity.y += _get_current_gravity() * delta

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

	# print_timer -= delta
	# print_timer = -1.0
	# if print_timer <= 0.0:
	# 	print_timer = 1.0 / 30.0
	# 	var cur_vel := Vector2(velocity.x, velocity.z).length()
	# 	print("vel: %6.2f target_vel: %6.2f, delta_vel: %6.2f, accel: %.2f, decel: %.2f" % [cur_vel, target_planar_speed, delta_vel, acceleration, deceleration])

	move_and_slide()

	_update_path()


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

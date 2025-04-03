class_name PathFindingAgent
extends Node3D

# Visualization
var visual_path_raw: DebugPathInstance
var visual_path: DebugPathInstance
var update_visual_path_start: bool = false
var update_visual_path_goal: bool = false

# Target & Tracking
var target: Vector3
var has_target: bool = false
var tracking_target: Node3D = null
var is_tracking_target: bool = false

# Path
var has_path: bool = false
var path_raw: PackedVector3Array
var path: PackedVector3Array

# Replanning
var last_target_replan_pos: Vector3
var last_target_replan_time: float

const replan_distance: float = 2.0
const replan_time_s: float = 1.5

# Simplify
const max_simplify_dist := 10.0
const max_simplify_height_diff := 2.0

# Define the shape for sweeping
var sweeping_shape: Shape3D
var height_offset: Vector3
var radius: float


func init(color: Color, sweeping_shape_: Shape3D) -> void:
	self.sweeping_shape = sweeping_shape_

	# Make shape smaller - depends on type
	var original_height: float = 0.0
	const height_factor: float = 0.8
	const radius_factor: float = 0.9
	
	if sweeping_shape is SphereShape3D:
		original_height = (sweeping_shape as SphereShape3D).radius * 2.0
		radius = (sweeping_shape as SphereShape3D).radius

		(sweeping_shape as SphereShape3D).radius *= radius_factor
	elif sweeping_shape is CapsuleShape3D:
		original_height = (sweeping_shape as CapsuleShape3D).height
		radius = (sweeping_shape as CapsuleShape3D).radius

		(sweeping_shape as CapsuleShape3D).radius *= radius_factor
		(sweeping_shape as CapsuleShape3D).height *= height_factor
	elif sweeping_shape is CylinderShape3D:
		original_height = (sweeping_shape as CylinderShape3D).height
		radius = (sweeping_shape as CylinderShape3D).radius

		(sweeping_shape as CylinderShape3D).radius *= radius_factor
		(sweeping_shape as CylinderShape3D).height *= height_factor
	else:
		push_error("Unsupported shape type")

	self.height_offset = Vector3(0, original_height / 2.0, 0)

	visual_path_raw = DebugPathInstance.new(Colors.set_alpha(color.lightened(0.4), 0.3), 0.05)
	visual_path = DebugPathInstance.new(Colors.set_alpha(color, 0.5), 0.05)
	add_child(visual_path_raw)
	add_child(visual_path)


func set_target(target_: Vector3) -> void:
	self.target = target_
	self.tracking_target = null
	self.has_target = true
	self.is_tracking_target = false


func set_track_target(track_target_: Node3D) -> void:
	if track_target_ == null:
		self.tracking_target = null
		self.is_tracking_target = false
		self.has_target = false
		return

	self.tracking_target = track_target_
	self.is_tracking_target = true
	self.has_target = true
	self.target = track_target_.global_position


func _physics_process(delta: float) -> void:
	_update_target_from_tracking()

	if !has_target:
		return

	# Check if we need to replan



func _process(delta: float) -> void:
	pass
	# TODO
	# Visually update path
	# if update_visual_path_start:
	# 	visual_path.update_path(path, global_position)
	# 	update_visual_path_start = false


func _update_target_from_tracking() -> void:
	# Check if tracking target became invalid
	if not is_tracking_target or tracking_target == null or !is_instance_valid(tracking_target):
		self.is_tracking_target = false
		self.tracking_target = null
		self.has_target = false
		return

	# Update target position
	self.target = tracking_target.global_position

# Called frequently, replans path
func _update_path() -> void:
	path_raw.clear()
	path.clear()
	has_path = false

	# Here we only plan to target, tracking has to be done separately
	if not has_target:
		return

	# Do not query when the map has never synchronized and is empty.
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	
	path_raw = NavigationServer3D.map_get_path(map, self.global_position, target, true)
	if path_raw.size() == 0:
		return

	has_path = true
	last_target_replan_pos = target
	last_target_replan_time = Time.get_unix_time_from_system()
	path = simplify_path(path_raw)

	# Update visuals here?
	visual_path_raw.update_path(path_raw, global_position)
	visual_path.update_path(path, global_position)


func simplify_path(p: PackedVector3Array) -> PackedVector3Array:
	# Nothing to simplify if p has less than 3 points
	if p.size() < 3:
		return p

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var simplified_p := PackedVector3Array()

	var current_index := 0
	simplified_p.append(p[current_index])
	
	# Iterate over p, try to connect current_index (from p start) with next_index, (from p end, moving backwards)
	while current_index < p.size() - 1:
		var next_index := p.size() - 1 # Try to jump directly to the end

		# Check if we can reach the furthest point directly
		while next_index > current_index + 1:
			# Only connect if
			# - p is clear
			# - distance is short enough
			# - low height difference
			# Check distance
			var distance := p[next_index].distance_to(p[current_index])
			if distance > max_simplify_dist:
				next_index -= 1
				continue

			# Check height difference
			var height_diff := absf(p[next_index].y - p[current_index].y)
			if height_diff > max_simplify_height_diff:
				next_index -= 1
				continue

			# Check p is clear
			var motion := p[next_index] - p[current_index]
			var query := PhysicsShapeQueryParameters3D.new()
			query.set_shape(sweeping_shape)
			query.transform = Transform3D(Basis(), p[current_index] + height_offset)
			query.motion = motion
			query.collide_with_bodies = true
			query.collide_with_areas = false
			query.collision_mask = Layers.mask([Layers.L.TERRAIN, Layers.L.STATIC_GEOM])
			var result: PackedFloat32Array = space_state.cast_motion(query)

			if result[0] < 0.98:
				next_index -= 1
				continue

			# No issue -> Connect p points
			break

		# Move to the next reachable point
		current_index = next_index
		simplified_p.append(p[current_index])
	return simplified_p

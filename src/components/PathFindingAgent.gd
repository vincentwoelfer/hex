class_name PathFindingAgent
extends Node3D

# Visualization
var visual_path_raw: DebugPathInstance
var visual_path: DebugPathInstance
var update_visual_path_start: bool = false
var update_visual_path_goal: bool = false
var show_path: bool = true

# Target & Tracking
var target: Vector3
var has_target: bool = false
var tracking_target: Node3D = null
var is_tracking_target: bool = false
var navigation_done: bool = false

# Path. The raw_path is only used for debug visualization.
# Coordinates are always in world space
# For visualization, we keep index 0 as the current agent position
# and try to follow/reach index 1
var has_path: bool = false
var path_raw: PackedVector3Array
var path: PackedVector3Array

# Replanning
var last_target_replan_pos: Vector3
var last_target_replan_time: float
const replan_distance: float = 1.0
const replan_interval_s: float = 1.0

# Simplify parameters
const max_simplify_dist := 10.0
const max_simplify_height_diff_upwards := 2.0
const max_simplify_slope_deg_upwards := HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG * 0.6

# Define the shape for sweeping
var sweeping_shape: Shape3D
var shape_cast_height_offset: Vector3
var radius: float

# TODO
# Mix these two. Write own agent class using NavServer API directly.
# https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_navigationagents.html#actor-as-characterbody3d
# https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_agent_avoidance.html
# https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_using_navigationservers.html#server-avoidance-callbacks

# => Use different nav-maps for pathfinding/querrying (depending on size, see below) but use one single map for avoidance-agents so they can all see each other.

# Different Nav-Mesh Maps/Sizes
# https://docs.godotengine.org/en/4.0/tutorials/navigation/navigation_different_actor_types.html


func init(color: Color, sweeping_shape_reference: Shape3D) -> void:
	self.sweeping_shape = sweeping_shape_reference.duplicate(false)

	# Make shape smaller - depends on type
	var original_height: float = 0.0
	const height_factor: float = 0.9
	const radius_factor: float = 1.0
	
	if sweeping_shape is SphereShape3D:
		var s := sweeping_shape as SphereShape3D
		original_height = s.radius * 2.0
		radius = s.radius
		s.radius *= radius_factor

	elif sweeping_shape is CapsuleShape3D:
		var s := sweeping_shape as CapsuleShape3D

		original_height = s.height
		radius = s.radius
		s.radius *= radius_factor
		s.height *= height_factor

	elif sweeping_shape is CylinderShape3D:
		var s := sweeping_shape as CylinderShape3D

		original_height = s.height
		radius = s.radius
		s.radius *= radius_factor
		s.height *= height_factor
	else:
		push_error("Unsupported shape type")

	self.shape_cast_height_offset = Vector3(0, original_height / 2.0, 0)

	const width := 0.06
	visual_path = DebugPathInstance.new(color, width)
	add_child(visual_path)

	if DebugSettings.show_raw_debug_path:
		var debug_color := Colors.set_alpha(Colors.mod_sat_val_hue(color, -0.4, 0.0, 0.05), color.a * 0.75)
		visual_path_raw = DebugPathInstance.new(debug_color, width * 0.75)
		add_child(visual_path_raw)
	

 # ==================== PUBLIC API ========================
# Set target/tracking target
func set_target(target_: Vector3) -> void:
	self.navigation_done = false

	self.target = target_
	self.tracking_target = null
	self.has_target = true
	self.is_tracking_target = false

func set_track_target(track_target_: Node3D) -> void:
	self.navigation_done = false
	
	if track_target_ == null:
		self.tracking_target = null
		self.is_tracking_target = false
		self.has_target = false
		return

	self.tracking_target = track_target_
	self.is_tracking_target = true
	self.has_target = true
	self.target = track_target_.global_position

func is_navigation_done() -> bool:
	return navigation_done

func get_target() -> Vector3:
	if not has_target:
		return Vector3.ZERO
	return target

func get_direction() -> Vector3:
	if not has_path or path.size() <= 1:
		return Vector3.ZERO

	# We try to reach index 1, 0 is current position (in visualization)
	var direction: Vector3 = path[1] - global_position
	direction.y = 0.0
	return direction.normalized()


# ===================== PRIVATE =========================
# Main process loop
func _physics_process(delta: float) -> void:
	_update_target_from_tracking()

	if not has_target:
		return

	_check_for_replan()

	if not has_path:
		return

	_update_path_progress()
	

func _check_for_replan() -> void:
	var now := Time.get_unix_time_from_system()
	if last_target_replan_pos.distance_to(target) > replan_distance or now - last_target_replan_time > replan_interval_s:
		_plan_new_path()
		last_target_replan_pos = target
		last_target_replan_time = now
	# TODO also replan if distance to large from path (eg by being pushed, avoidance, etc.)


func _update_path_progress() -> void:
	# We try to reach index 1, 0 is current position (in visualization)
	if path.size() <= 1:
		# Goal reached
		navigation_done = true
		has_path = false
		path_raw.clear()
		path.clear()
		has_target = false
		self.is_tracking_target = false
		self.tracking_target = null
		return

	var dist_next_waypoint: float = path[1].distance_to(global_position)
	if dist_next_waypoint <= radius * 0.5:
		path.remove_at(1)
			
		# Indices are not the same, this is only a workaround. But raw_path has same or more so this kinda works.
		# Just wait for replanning to solve this.
		if DebugSettings.show_raw_debug_path and path_raw.size() > 1:
			path_raw.remove_at(1)

	pass


func _process(delta: float) -> void:
	# Update visual path
	visual_path.update_path(path, global_position)
	visual_path.enabled = show_path

	if DebugSettings.show_raw_debug_path:
		visual_path_raw.update_path(path_raw, global_position)
		visual_path_raw.enabled = show_path
	
		 
func _update_target_from_tracking() -> void:
	if not is_tracking_target:
		return

	# Check if tracking target became invalid
	if tracking_target == null or !is_instance_valid(tracking_target):
		self.is_tracking_target = false
		self.tracking_target = null
		self.has_target = false
		return

	# Update target position
	self.target = tracking_target.global_position


# Called frequently, replans path
func _plan_new_path() -> void:
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
	
	# TODO this plans towards the nearest point on the map, not the target. Maybe manually add target to path.
	path_raw = NavigationServer3D.map_get_path(map, self.global_position, target, true)
	if path_raw.size() == 0:
		return

	has_path = true
	last_target_replan_pos = target
	last_target_replan_time = Time.get_unix_time_from_system()
	path = simplify_path(path_raw)


func simplify_path(p: PackedVector3Array) -> PackedVector3Array:
	# Nothing to simplify if p has less than 3 points
	if p.size() < 3:
		return p

	# Check if we can reach the end directly	
	var simplified_p := PackedVector3Array()
	var current_index := 0
	simplified_p.append(p[current_index])
	
	# Iterate over p, try to connect current_index (from p start) with next_index, (from p end, moving backwards)
	while current_index < p.size() - 1:
		var next_index := p.size() - 1 # Try to jump directly to the end

		# Check if we can reach the furthest point directly
		while next_index > current_index + 1:
			# Check if we can connect current_index with next_index
			if can_connect_points(p[current_index], p[next_index]):
				break
			else:
				next_index -= 1

		# Move to the next reachable point
		current_index = next_index
		simplified_p.append(p[current_index])
	return simplified_p


func can_connect_points(curr: Vector3, next: Vector3) -> bool:
	# Only connect if
	# - path is clear
	# - distance is short enough
	# - low height difference
	# - low slope
	# Check distance
	var distance := curr.distance_to(next)
	if distance > max_simplify_dist:
		return false

	# Check height difference
	var height_diff := next.y - curr.y
	if height_diff > max_simplify_height_diff_upwards:
		return false

	# Check slope
	var slope_deg := rad_to_deg(atan(height_diff / distance))
	if slope_deg > max_simplify_slope_deg_upwards:
		return false

	# Check if path sweep is clear
	var query := PhysicsShapeQueryParameters3D.new()
	query.set_shape(sweeping_shape)
	query.transform = Transform3D(Basis(), curr + self.shape_cast_height_offset)
	query.motion = next - curr
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.collision_mask = Layers.mask([Layers.L.TERRAIN, Layers.L.STATIC_GEOM])

	var result: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	if result[0] < 1.0:
		return false

	# Everything is fine -> can connect
	return true

# TODO optimioze by creating shape once and use rid
# Example code:

# var shape_rid = PhysicsServer3D.shape_create(PhysicsServer3D.SHAPE_SPHERE)
# var radius = 2.0
# PhysicsServer3D.shape_set_data(shape_rid, radius)

# var params = PhysicsShapeQueryParameters3D.new()
# params.shape_rid = shape_rid

# # Execute physics queries here...

# # Release the shape when done with physics queries.
# PhysicsServer3D.free_rid(shape_rid)

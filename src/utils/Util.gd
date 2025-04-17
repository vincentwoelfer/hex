@tool
class_name Util

########################################################################
# Randomness
########################################################################
## Gives a random offset in a circle with radius r_max
static func rand_circular_offset(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := randf_range(0.0, r_max)
	return vec3_from_radius_angle(r, angle)

## Gives a random offset in a circle betwee radius r_min and r_max
static func rand_circular_offset_range(r_min: float, r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := randf_range(r_min, r_max)
	return vec3_from_radius_angle(r, angle)


static func rand_circular_offset_normal_dist(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := clampf(randfn(r_max, 1.0), 0.0, r_max)
	return vec3_from_radius_angle(r, angle)


static func rand_sign() -> float:
	return 1.0 if randf() > 0.5 else -1.0


########################################################################
# ANGLES + VECTORS (Geometry)
########################################################################

# Ensures value is always [0, 5], even if suplying negative number
static func as_dir(dir: int) -> int:
	return (dir + 6) % 6

# Orientation 0 = 0 = Forward -Z
static var HEX_ANGLES: Array[float] = [0.0, PI / 3.0, 2.0 * PI / 3.0, PI, 4.0 * PI / 3.0, 5.0 * PI / 3.0, 6.0 * PI / 3.0]
static func get_six_hex_angles() -> Array[float]:
	return HEX_ANGLES

## Returns the angle of a hexagon side in radians
static func get_hex_angle(dir: int) -> float:
	return HEX_ANGLES[as_dir(dir)]

static func get_hex_angle_interpolated(orientation: float) -> float:
	return PI / 3.0 * orientation


static func vec3_from_radius_angle(r: float, angle: float) -> Vector3:
	return Vector3(r * cos(angle), 0.0, r * sin(angle))


static func get_angle_to_vec3(v: Vector3) -> float:
	return to_vec2(v).angle()


# Returns difference v1 -> v2
static func get_angle_diff(v1: Vector3, v2: Vector3) -> float:
	return to_vec2(v1).angle_to(to_vec2(v2))


# True if v1 -> v2 is clockwise
static func is_clockwise_order(v1: Vector3, v2: Vector3) -> bool:
	return get_angle_diff(v1, v2) > 0.0

## Converts vec3 -> vec2, y is ignored
static func to_vec2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Convert vec2 -> vec3, y is set to 0
static func to_vec3(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y)


static func get_dist_planar(a: Vector3, b: Vector3) -> float:
	return to_vec2(b - a).length()


########################################################################
# Misc
########################################################################
# Like clamp but ensures values is between [a,b] , even if a > b
static func clampf(val: float, a: float, b: float) -> float:
	return clampf(val, minf(a, b), maxf(a, b))

static func spread_values(a: float, b: float, n: int) -> Array[float]:
	assert(n >= 0)
	if n == 0:
		return []
	if n == 1 or a == b:
		return [a]

	# General case
	var step: float = (b - a) / float(n - 1)
	var values: Array[float] = []
	for i: int in range(n):
		values.append(a + i * step)
	return values

static func spread_vec3(a: Vector3, b: Vector3, n: int) -> Array[Vector3]:
	assert(n >= 0)
	if n == 0:
		return []
	if n == 1 or a == b:
		return [a]

	var step: Vector3 = (b - a) / float(n - 1)
	var values: Array[Vector3] = []
	for i: int in range(n):
		values.append(a + step * float(i))
	return values

########################################################################
# Timing & Waiting
########################################################################
static func wait_until(node: Node3D, condition: Callable) -> void:
	while not condition.call():
		await node.get_tree().physics_frame


static func delete_after(time: float, node: Node3D) -> void:
	if node == null:
		return
	node.add_child(timer(time, Callable(node, "queue_free"), true))


static func timer(wait_time: float, timeout_callable: Callable, one_shot: bool = false) -> Timer:
	var t := Timer.new()
	t.wait_time = wait_time
	t.one_shot = one_shot
	t.autostart = true
	t.timeout.connect(timeout_callable)
	return t

static func await_time(time: float) -> void:
	await get_scene_root().get_tree().create_timer(time).timeout

########################################################################
# 3D Vector Math
########################################################################
static func transform_from_point_and_normal(point: Vector3, normal: Vector3) -> Transform3D:
	var transform := Transform3D()
	transform.origin = point
	transform.basis.y = normal
	transform.basis.x = - transform.basis.z.cross(normal)
	transform.basis = transform.basis.orthonormalized()
	return transform


static func get_total_path_length(points: PackedVector3Array) -> float:
	if points.size() <= 1:
		return 0.0

	var total_length: float = 0.0
	for i in range(1, points.size()):
		total_length += points[i - 1].distance_to(points[i])
	return total_length

########################################################################
# Geometry Stuff
########################################################################
# 0 = on a, 1 = on b
static func compute_t_on_line_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	return ap.dot(ab) / ab.dot(ab)


static func is_point_near_line_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	const epsilon: float = 0.001
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var ab_len: float = ab.length()
	var cross_product: float = ab.cross(ap)
	var distance: float = abs(cross_product) / ab_len
	return distance <= epsilon * ab_len


static func cotangent(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ba := a - b
	var bc := c - b
	return bc.dot(ba) / abs(bc.cross(ba))


static func is_point_on_edge(point: Vector2, p1: Vector2, p2: Vector2) -> bool:
	# Check if point lies on the line segment (p1, p2)
	if is_equal_approx(point.distance_to(p1) + point.distance_to(p2), p1.distance_to(p2)):
		return true
	return false


static func is_point_outside_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	# First, check if the point lies on any of the polygon's edges
	for i in range(polygon.size()):
		var p1 := polygon[i]
		var p2 := polygon[(i + 1) % polygon.size()]
		if is_point_on_edge(point, p1, p2):
			return false # The point is on the polygon outline -> counts as inside

	# Ray-casting method for point containment
	var num_intersections := 0
	
	for i in range(polygon.size()):
		var p1 := polygon[i]
		var p2 := polygon[(i + 1) % polygon.size()]
		
		# Check if the ray from 'point' to the right intersects the edge (p1, p2)
		if ((p1.y > point.y) != (p2.y > point.y)):
			var x_intersection := (p2.x - p1.x) * (point.y - p1.y) / (p2.y - p1.y) + p1.x
			if point.x < x_intersection:
				num_intersections += 1
	
	# If the number of intersections is odd, the point is inside; if even, it's outside
	return num_intersections % 2 == 0


static func is_triangle_outside_of_polygon(tri: Array[Vector3], polygon: PackedVector2Array) -> bool:
	# Check if any of the three midpoints is outside of the polygon
	var midpoints: Array[Vector3] = [(tri[0] + tri[1]) / 2.0, (tri[0] + tri[2]) / 2.0, (tri[1] + tri[2]) / 2.0]
	for m in midpoints:
		if Util.is_point_outside_polygon(Util.to_vec2(m), polygon):
			return true
	return false


########################################################################
# LERP
########################################################################
const EPSILON: float = 0.001
static func lerp_towards_f(curr: float, goal: float, speed: float, delta: float) -> float:
	if abs(goal - curr) < EPSILON:
		return goal
	return lerp(curr, goal, 1.0 - exp(-speed * delta))


static func lerp_towards_angle(curr: float, goal: float, speed: float, delta: float) -> float:
	if abs(goal - curr) < EPSILON:
		return goal
	return lerp_angle(curr, goal, 1.0 - exp(-speed * delta))


static func lerp_towards_vec3(curr: Vector3, goal: Vector3, speed: float, delta: float) -> Vector3:
	if curr.distance_to(goal) < EPSILON:
		return goal
	return lerp(curr, goal, 1.0 - exp(-speed * delta))

########################################################################
# HEXAGON
########################################################################
# smooth_strength = 0 = Perfect Hexagon
# smooth_strength = 1 = Perfect Circle
static func get_hex_radius(r: float, angle: float, smooth_strength: float = 0.0) -> float:
	# Limit to range [0, 60]deg aka one hex segment
	angle = fmod(angle, PI / 3.0)
	var r_hex: float = sqrt(3) * r / (sqrt(3) * cos(angle) + sin(angle))
	return lerp(r_hex, r, smooth_strength)


static func get_hex_vertex(r: float, angle: float, smooth_strength: float = 0.0) -> Vector3:
	return vec3_from_radius_angle(get_hex_radius(r, angle, smooth_strength), angle)


########################################################################
# Physics stuff
########################################################################
static func get_scene_root() -> Node3D:
	if Engine.is_editor_hint():
		# TODO In editor mode, we need to get the root of the edited scene
		# This is not ready instantly upon startup, so we need to wait a bit
		return EditorInterface.get_edited_scene_root() as Node3D
	else:
		return (Engine.get_main_loop() as SceneTree).current_scene

static func get_world() -> World3D:
	var scene_root: Node3D = get_scene_root()
	if scene_root == null:
		return null
	return scene_root.get_world_3d()

static func get_space_state() -> PhysicsDirectSpaceState3D:
	return get_world().direct_space_state

# TODO: Change for multipe navigation maps
static func get_map() -> RID:
	return get_world().navigation_map

## If parent is null the instance will be added to the scene root, use global_pos.
## If parent is not null the instance will be added to the parent, use local_pos.
static func spawn(instance: Node3D, pos: Vector3, parent: Node3D = null) -> void:
	if parent != null:
		parent.add_child(instance)
		instance.position = pos
	else:
		Util.get_scene_root().add_child(instance)
		instance.global_position = pos
	instance.reset_physics_interpolation()


########################################################################
# Camera access
########################################################################

# Get global camera works in game and editor
static func get_global_cam(reference_node: Node) -> Camera3D:
	var cam: Camera3D
	if Engine.is_editor_hint():
		cam = EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	else:
		cam = reference_node.get_viewport().get_camera_3d()
	return cam


# Get global camera pos, works in game and editor
static func get_global_cam_pos(reference_node: Node) -> Vector3:
	var cam := get_global_cam(reference_node)
		
	if cam != null:
		return cam.global_position
	else:
		return Vector3.ZERO


########################################################################
# Materials
########################################################################
static func duplicate_material_new_color(mesh_instance: MeshInstance3D, new_color: Color) -> void:
	var new_mesh: Mesh = mesh_instance.mesh.duplicate(true)
	var new_mat: StandardMaterial3D = new_mesh.surface_get_material(0)

	new_mat.albedo_color = new_color
	new_mesh.surface_set_material(0, new_mat)
	mesh_instance.mesh = new_mesh


########################################################################
# Gameplay Effects
########################################################################
## Apply a radial impulse from an explosion centered at 'origin'.
static func calculate_explosion_impulse(origin: Vector3, target_pos: Vector3, explosion_strength: float, explosion_radius: float) -> Vector3:
	var to_target: Vector3 = target_pos - origin
	to_target.y = 0.0 # Ignore height difference

	var dist: float = to_target.length()

	# Create fake upward component
	to_target.y = dist * 0.2
	to_target = to_target.normalized()

	# out of range, no effect
	if dist > explosion_radius:
		return Vector3.ZERO

	# Impulse diminishes with distance from the origin
	var force_factor: float = 1.0 - (dist / explosion_radius)

	# Change from [1, 0] to [1, 0.5]
	force_factor = remap(force_factor, 1.0, 0.0, 1.0, 0.5)
	return to_target * explosion_strength * force_factor

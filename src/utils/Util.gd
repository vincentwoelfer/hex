@tool
class_name Util

######################################################
# Randomness
######################################################
## Gives a random offset in a circle with radius r_max
static func randCircularOffset(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := randf_range(0.0, r_max)
	return vec3FromRadiusAngle(r, angle)

## Gives a random offset in a circle betwee radius r_min and r_max
static func randCircularOffsetRange(r_min: float, r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := randf_range(r_min, r_max)
	return vec3FromRadiusAngle(r, angle)


static func randCircularOffsetNormalDist(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := clampf(randfn(r_max, 1.0), 0.0, r_max)
	return vec3FromRadiusAngle(r, angle)


######################################################
# ANGLES + VECTORS (Geometry)
######################################################

# Ensures value is always [0, 5], even if suplying negative number
static func as_dir(dir: int) -> int:
	return (dir + 6) % 6

# Orientation 0 = 0 = Forward -Z
static var HEX_ANGLES: Array[float] = [0.0, PI / 3.0, 2.0 * PI / 3.0, PI, 4.0 * PI / 3.0, 5.0 * PI / 3.0, 6.0 * PI / 3.0]
static func getSixHexAngles() -> Array[float]:
	return HEX_ANGLES

## Returns the angle of a hexagon side in radians
static func getHexAngle(dir: int) -> float:
	return HEX_ANGLES[as_dir(dir)]

static func getHexAngleInterpolated(orientation: float) -> float:
	return PI / 3.0 * orientation


static func vec3FromRadiusAngle(r: float, angle: float) -> Vector3:
	return Vector3(r * cos(angle), 0.0, r * sin(angle))


static func getAngleToVec3(v: Vector3) -> float:
	return toVec2(v).angle()


# Returns difference v1 -> v2
static func getAngleDiff(v1: Vector3, v2: Vector3) -> float:
	return toVec2(v1).angle_to(toVec2(v2))


# True if v1 -> v2 is clockwise
static func isClockwiseOrder(v1: Vector3, v2: Vector3) -> bool:
	return getAngleDiff(v1, v2) > 0.0


static func toVec2(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Convert 2D vector to 3D vector, y is set to 0
static func toVec3(v: Vector2) -> Vector3:
	return Vector3(v.x, 0.0, v.y)


# More advanced angle stuff
static func sortVecAccordingToAngles(vecs: Array[Vector3]) -> Array[Vector3]:
	# TODO this does not work correclty for cases >180 deg
	# => Correctly check that all vectors lie in a 180deg segment. Currently this assert cant trigger since the angle between any two points is at most exactly 180deg.
	var max_angle_diff := 0.0

	# Compare every pair of vectors
	for i in range(vecs.size()):
		for j in range(i + 1, vecs.size()):
			max_angle_diff = max(max_angle_diff, getAngleDiff(vecs[i], vecs[j]))

	var all_in_segment := max_angle_diff < PI
	assert(all_in_segment, "Angles must be within an 180deg sector, max angle diff is %f" % rad_to_deg(max_angle_diff))

	# Need to invert the result to have the vectors in ascending angle-order 
	vecs.sort_custom(func(a: Vector3, b: Vector3) -> bool: return !isClockwiseOrder(a, b))
	return vecs


######################################################
# Misc
######################################################
# Like clamp but ensures values is between a,b , even if a > b
static func clampf(val: float, a: float, b: float) -> float:
	return clampf(val, minf(a, b), maxf(a, b))


######################################################
# Timing & Waiting
######################################################
static func wait_until(node: Node3D, condition: Callable) -> void:
	while not condition.call():
		await node.get_tree().process_frame

######################################################
# Camera access
######################################################

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


######################################################
# Printing / Logging
######################################################
const BANNER_WIDTH: int = 64
const BANNER_CHAR: String = "="

static func print_only_banner() -> void:
	print(BANNER_CHAR.repeat(BANNER_WIDTH))

static func print_banner(string: String) -> void:
	# Souround string with spaces
	string = " " + string + " "

	print(center_text(string, BANNER_WIDTH, BANNER_CHAR))

static func print_multiline_banner(string: String) -> void:
	# Souround string with spaces
	string = " " + string + " "

	var banner_line: String = BANNER_CHAR.repeat(BANNER_WIDTH)
	print(banner_line, "\n", center_text(string, BANNER_WIDTH, BANNER_CHAR), "\n", banner_line)

static func center_text(text: String, width: int, filler: String) -> String:
	var pad_size_total: int = max(0, (width - text.length()))

	var pad_size_left: int
	var pad_size_right: int
	if pad_size_total % 2 == 0:
		var pad_size: int = int(pad_size_total / 2.0)
		pad_size_left = pad_size
		pad_size_right = pad_size
	else:
		pad_size_left = floori(pad_size_total / 2.0)
		pad_size_right = pad_size_left + 1

	return filler.repeat(pad_size_left) + text + filler.repeat(pad_size_right)

######################################################
# 3D Vector Math
######################################################
static func transformFromPointAndNormal(point: Vector3, normal: Vector3) -> Transform3D:
	var transform := Transform3D()
	transform.origin = point
	transform.basis.y = normal
	transform.basis.x = - transform.basis.z.cross(normal)
	transform.basis = transform.basis.orthonormalized()
	return transform


######################################################
# Mesh manipulation / merging
######################################################
static func create_mesh_from_triangles(triangles: Array[Triangle]) -> Mesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)

	for tri in triangles:
		tri.addToSurfaceTool(st)

	# Removes duplicates and actually create mesh
	st.index()
	st.optimize_indices_for_cache()
	st.generate_normals()
	return st.commit()


######################################################
# Stuff
######################################################
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


######################################################
# LERP
######################################################
const EPSILON: float = 0.001
static func lerp_towards_f(curr: float, goal: float, speed: float, delta: float) -> float:
	if abs(goal - curr) < EPSILON:
		return goal
	return lerp(curr, goal, 1.0 - exp(- speed * delta))


static func lerp_towards_angle(curr: float, goal: float, speed: float, delta: float) -> float:
	if abs(goal - curr) < EPSILON:
		return goal
	return lerp_angle(curr, goal, 1.0 - exp(- speed * delta))


static func lerp_towards_vec3(curr: Vector3, goal: Vector3, speed: float, delta: float) -> Vector3:
	if curr.distance_to(goal) < EPSILON:
		return goal
	return lerp(curr, goal, 1.0 - exp(- speed * delta))

######################################################
# HEXAGON
######################################################

# smooth_strength = 0 = Perfect Hexagon
# smooth_strength = 1 = Perfect Circle
static func getHexRadius(r: float, angle: float, smooth_strength: float = 0.0) -> float:
	# Limit to range [0, 60]deg aka one hex segment
	angle = fmod(angle, PI / 3.0)
	var r_hex: float = sqrt(3) * r / (sqrt(3) * cos(angle) + sin(angle))
	return lerp(r_hex, r, smooth_strength)


static func getHexVertex(r: float, angle: float, smooth_strength: float = 0.0) -> Vector3:
	return vec3FromRadiusAngle(getHexRadius(r, angle, smooth_strength), angle)


######################################################
# Array stuff
######################################################
static func isPointOnEdge(point: Vector2, p1: Vector2, p2: Vector2) -> bool:
	# Check if point lies on the line segment (p1, p2)
	if is_equal_approx(point.distance_to(p1) + point.distance_to(p2), p1.distance_to(p2)):
		return true
	return false


static func isPointOutsidePolygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	# First, check if the point lies on any of the polygon's edges
	for i in range(polygon.size()):
		var p1 := polygon[i]
		var p2 := polygon[(i + 1) % polygon.size()]
		if isPointOnEdge(point, p1, p2):
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


static func isTriangleOutsideOfPolygon(tri: Array[Vector3], polygon: PackedVector2Array) -> bool:
	# Check if any of the three midpoints is outside of the polygon
	var midpoints: Array[Vector3] = [(tri[0] + tri[1]) / 2.0, (tri[0] + tri[2]) / 2.0, (tri[1] + tri[2]) / 2.0]
	for m in midpoints:
		if Util.isPointOutsidePolygon(Util.toVec2(m), polygon):
			return true
	return false

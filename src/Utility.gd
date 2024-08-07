class_name Utility

static func randColor() -> Color:
	return Color(randf_range(0.1, 0.9), randf_range(0.1, 0.9), randf_range(0.1, 0.9), 1.0)


static func vec3FromRadiusAngle(r: float, angle: float) -> Vector3:
	return Vector3(r * cos(angle), 0.0, r * sin(angle))


static func randCircularOffset(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := randf_range(0.0, r_max)
	return vec3FromRadiusAngle(r, angle)


static func randCircularOffsetNormalDist(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := clampf(randfn(r_max, 1.0), 0.0, r_max)
	return vec3FromRadiusAngle(r, angle)


# smooth_strength = 0 = Perfect Hexagon
# smooth_strength = 1 = Perfect Circle
static func getHexRadius(r: float, angle: float, smooth_strength: float = 0.0) -> float:
	# Limit to range [0, 60]deg aka one hex segment
	angle = fmod(angle, PI / 3.0)
	var r_hex: float = sqrt(3) * r / (sqrt(3) * cos(angle) + sin(angle))
	return lerp(r_hex, r, smooth_strength)


static func getHexVertex(r: float, angle: float, smooth_strength: float = 0.0) -> Vector3:
	return vec3FromRadiusAngle(getHexRadius(r, angle, smooth_strength), angle)
	

static func generateHexagonVertices(r: float, extra_verts_per_side: int, smooth_strength: float) -> Array[Vector3]:
	var total_verts: int = 6 * (1 + extra_verts_per_side)
	var angle_step: float = 2.0 * PI / total_verts
	var array: Array[Vector3] = []

	for i in range(total_verts):
		var angle := i * angle_step
		array.append(getHexVertex(r, angle))
	return array


# ToDo: 
# - generate 6x 3 corner vertices
# - fill array with 3 corner vertices, generate extra_verts_per_side verts and append next corner
# - repeat
# static func generateHexVerticesWithCorners(r: float, extra_verts_per_side: int) -> Array[Vector3]:
	# var total_verts: int = 6 * (1 + extra_verts_per_side)
	# var angle_step: float = 2.0 * PI / total_verts
	# var array: Array[Vector3] = []

	# for i in range(total_verts):
	# 	var angle := i * angle_step
	# 	array.append(vec3FromRadiusAngle(getHexRadius(r, angle, smooth_strength), angle))
	# return array


# Compute the 3 Vector3 points for one hex corner
static func getThreeHexCornerVertices(r_inner: float, r_outer: float, angle: float) -> Array[Vector3]:
	assert(fmod(angle, PI / 3.0) == 0.0, "Angle must be a multiple of PI/3!")

	# No smooth strength since corner
	var inner_corner := getHexVertex(r_inner, angle)
	var outer_corner := getHexVertex(r_outer, angle)

	# Distance between the two interior circles of the inner and outer radius of the hex
	var dist := r_outer - r_inner
	
	# 30deg = PI/6.0 = one half of a hexagon segment
	var left_angle := angle - PI / 6.0
	var right_angle := angle + PI / 6.0
	var left := inner_corner + vec3FromRadiusAngle(dist, left_angle)
	var right := inner_corner + vec3FromRadiusAngle(dist, right_angle)

	return [left, outer_corner, right]


###############################
class Triangle:
	var a: Vector3
	var b: Vector3
	var c: Vector3

	func _init(a_: Vector3, b_: Vector3, c_: Vector3) -> void:
		self.a = a
		self.b = b
		self.c = c

		assert(a != b and a != c and b != c, "Triangle points must be different")
		assert(Geometry2D.is_polygon_clockwise(PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])), "Triangle points must be clockwise!")

	func getArea() -> float:
		return 0.5 * (b - a).cross(c - a).length()

	func getRandPoint() -> Vector3:
		var u: float = randf()
		var v: float = randf()
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		var w: float = 1.0 - u - v
		return a * u + b * v + c * w

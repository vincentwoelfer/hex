class_name Utility

static func randColor() -> Color:
	return Color(0.5, randf(), randf(), 1.0)

# Compute one Vector3 point in direction dir with radius r
static func getHexCorner(r: float, dir: int) -> Vector3:
	var angle := deg_to_rad(60.0 * dir)
	return Vector3(r * cos(angle), 0.0, r * sin(angle))

# Compute 6 Vector3 points in each direction with radius r
static func getRegularHexCornerArray(r: float) -> Array[Vector3]:
	var array : Array[Vector3] = []
	for dir in HexDir.values():
		array.append(getHexCorner(r, dir))
	return array

class TransitionHexCorners:
	var left: Vector3
	var center: Vector3
	var right: Vector3

	func _init(left_: Vector3, center_: Vector3, right_: Vector3) -> void:
		self.left = left_
		self.center = center_
		self.right = right_

# Compute the 3 Vector3 points for one hex corner
static func getTransitionHexCorners(r_inner: float, r_outer: float, dir: int) -> TransitionHexCorners:
	var inner_reference_corner := getHexCorner(r_inner, dir)
	var outer_center_corner := getHexCorner(r_outer, dir)

	# distance between the two interior circles of the inner and outer radius of the hex
	var dist := HexConst.outer_radius_interior_circle() - HexConst.inner_radius_interior_circle()
	
	var left_angle := deg_to_rad(60.0 * dir - 30.0)
	var outer_left_corner := inner_reference_corner + Vector3(dist * cos(left_angle), 0.0, dist * sin(left_angle))

	var right_angle := deg_to_rad(60.0 * dir + 30.0)
	var outer_right_corner := inner_reference_corner + Vector3(dist * cos(right_angle), 0.0, dist * sin(right_angle))

	return TransitionHexCorners.new(outer_left_corner, outer_center_corner, outer_right_corner)

# Returns a nested array with 6 x 3 Vector points for the outer transition points
static func getTransitionHexCornersArray(r_inner: float, r_outer: float) -> Array[TransitionHexCorners]:
	var array : Array[TransitionHexCorners] = []
	for dir in HexDir.values():
		array.append(getTransitionHexCorners(r_inner, r_outer, dir))
	return array

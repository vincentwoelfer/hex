class_name Utility

######################################################
# COLORS
######################################################
static func randColor() -> Color:
	return Color(randf_range(0.1, 0.9), randf_range(0.1, 0.9), randf_range(0.1, 0.9), 1.0)


static func randColorVariation(color: Color, variation: float = 0.2) -> Color:
	return color + Color(randf_range(-variation, variation), randf_range(-variation, variation), randf_range(-variation, variation), 0.0)


static func getDistincHexColor(i: int) -> Color:
	assert(i >= 0 and i <= 5)
	if i == 0: return Color.RED
	if i == 1: return Color.MEDIUM_BLUE
	if i == 2: return Color.ORANGE
	if i == 3: return Color.DARK_MAGENTA
	if i == 4: return Color.DARK_GREEN
	if i == 5: return Color.AQUA
	return Color.BLACK


######################################################
# Randomness
######################################################

static func randCircularOffset(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := randf_range(0.0, r_max)
	return vec3FromRadiusAngle(r, angle)


static func randCircularOffsetNormalDist(r_max: float) -> Vector3:
	var angle := randf_range(0.0, 2.0 * PI)
	var r := clampf(randfn(r_max, 1.0), 0.0, r_max)
	return vec3FromRadiusAngle(r, angle)

######################################################
# ANGLES + VECTORS (Geometry)
######################################################
static func getSixHexAngles() -> Array[float]:
	var pi_third := PI / 3.0
	return [0.0, pi_third, 2.0 * pi_third, PI, 4.0 * pi_third, 5.0 * pi_third, 6.0 * pi_third]


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


static func generateFullHexagonNoCorners(r: float, extra_verts_per_side: int, smooth_strength: float) -> Array[Vector3]:
	var total_verts: int = 6 * (1 + extra_verts_per_side)
	var angle_step: float = 2.0 * PI / total_verts
	var vertices: Array[Vector3] = []

	for i in range(total_verts):
		var angle := i * angle_step
		vertices.append(getHexVertex(r, angle, smooth_strength))

	assert(vertices.size() == total_verts)
	return vertices


# Compute the 3 Vector3 points for one hex corner
static func getThreeHexCornerVertices(r_inner: float, r_outer: float, angle: float) -> Array[Vector3]:
	#assert(is_zero_approx(fmod(angle, PI / 3.0)), "Angle must be a multiple of PI/3!")
	#assert(r_outer > r_inner)

	# No smooth strength since corner
	var inner_corner := getHexVertex(r_inner, angle)
	var outer_corner := getHexVertex(r_outer, angle)

	# Distance between the two interior circles of the inner and outer radius of the hex
	var dist := (r_outer * sqrt(3.0) / 2.0) - (r_inner * sqrt(3.0) / 2.0)

	# 30deg = PI/6.0 = one half of a hexagon segment
	var left_angle := angle - PI / 6.0
	var right_angle := angle + PI / 6.0
	var left := inner_corner + vec3FromRadiusAngle(dist, left_angle)
	var right := inner_corner + vec3FromRadiusAngle(dist, right_angle)

	return [left, outer_corner, right]


static func generateFullHexagonWithCorners(r_inner: float, r_outer: float, extra_verts_per_side: int) -> Array[Vector3]:
	var corners: Array = []
	for angle in getSixHexAngles():
		corners.append(getThreeHexCornerVertices(r_inner, r_outer, angle))

	# Determine angle difference (from hex center) between the corners and their neighbours
	var corner: Vector3 = corners[0][1]
	var corner_neighbour: Vector3 = corners[0][2]
	var corner_angle_offset: float = abs(toVec2(corner).angle_to(toVec2(corner_neighbour)))

	# Compute how many additional vertices per side and at which angles.
	# Basically we reduce the 60deg hex-segment on both sides by corner_angle_offset
	# to get the center part of the side which is the same as the inner hexagon.
	var side_angle_range := (PI / 3.0 - 2.0 * corner_angle_offset)
	var side_angle_step := side_angle_range / (extra_verts_per_side + 1)

	# Put everything together
	var vertices: Array[Vector3] = []
	for i in range(6):
		# Append corner points. For first, ommit the first one because its actually the last one of the whole hexagon
		if i == 0:
			vertices.append(corners[i][1])
			vertices.append(corners[i][2])
		else:
			vertices.append(corners[i][0])
			vertices.append(corners[i][1])
			vertices.append(corners[i][2])

		# Add additional vertices per side
		var side_angle_start := (i * PI / 3.0) + corner_angle_offset
		for j in range(1, extra_verts_per_side + 1):
			var angle := side_angle_start + (j * side_angle_step)
			vertices.append(getHexVertex(r_outer, angle))

	# Append first(left) corner vertex of first corner at the end
	vertices.append(corners[0][0])

	assert(vertices.size() == 6 * (3 + extra_verts_per_side))
	return vertices

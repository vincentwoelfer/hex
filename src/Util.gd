class_name Util

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



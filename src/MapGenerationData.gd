@tool # Must be tool because static variables are used in editor
class_name MapGenerationData

# HEIGHT GENERATION
static var height_noise: Noise = preload("res://assets/noise/TerrainHeightNoiseGenerator.tres")
static var height_noise_scale: float = 0.1
static var continentalness_curve: Curve = preload("res://assets/noise/continentalness_curve.tres")

# Only for testing (im high af)
static var height_map: Dictionary[int, int] = {}

# Globally pure (= indepentend of anything else), this is the ground truth.
# Does NOT require any prior info in map / geometry_inputs
static func determine_height(hex_pos: HexPos) -> int:
	var pos2D: Vector2 = HexPos.hexpos_to_xy(hex_pos)

	# Get continentalness
	var continentalness: float = 1.0 - clampf(hex_pos.magnitude() / (HexConst.MAP_MAX_SIZE as float), 0.0, 1.0)
	var continentalness_height := continentalness_curve.sample(continentalness)
	continentalness_height = remap(continentalness_height, 0.0, 1.0, HexConst.MAP_MIN_HEIGHT, HexConst.MAP_MAX_HEIGHT)

	# Get random height noise
	#var noise: float = remap(height_noise.get_noise_2d(pos2D.x, pos2D.y), -1.0, 1.0, 0.0, 1.0) # Remap noise to [0, 1]
	var noise: float = height_noise.get_noise_2d(pos2D.x, pos2D.y)
	var noise_height: float = remap(noise * height_noise_scale, -1.0, 1.0, -HexConst.MAP_MAX_HEIGHT, HexConst.MAP_MAX_HEIGHT)

	# Combine
	var height: float = continentalness_height + noise_height
	var height_int: int = clampi(roundi(height), HexConst.MAP_MIN_HEIGHT, HexConst.MAP_MAX_HEIGHT)

	# Border
	if hex_pos.magnitude() >= HexConst.MAP_MAX_SIZE:
		height_int = HexConst.MAP_OCEAN_HEIGHT

	return height_int

# Only here to have this class actually decide all the relevant information for map generation
# THIS must be bidirectional, the type must be the same for for both hex-tiles it connects!
static func determine_transition_type(from_hex_pos: HexPos, from_height: int, to_hex_pos: HexPos, to_height: int) -> HexGeometryInput.TransitionType:
	# TODO this adds randomness as some steep connections are suddenly smooth
	var rand_cond: bool = not (from_hex_pos.r == from_hex_pos.q or to_hex_pos.r == to_hex_pos.q)

	# Make map much smoother in one direction
	if from_hex_pos.r >= 5 or to_hex_pos.r >= 5:
		return HexGeometryInput.TransitionType.SMOOTH

	else:
		if abs(to_height - from_height) == 12 and rand_cond:
			return HexGeometryInput.TransitionType.SMOOTH


	# Normal cases
	if abs(to_height - from_height) >= HexConst.trans_type_max_height_diff:
		return HexGeometryInput.TransitionType.SHARP
	else:
		return HexGeometryInput.TransitionType.SMOOTH

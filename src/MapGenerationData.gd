@tool
class_name MapGenerationData

# HEIGHT GENERATION
static var height_noise: Noise = preload("res://assets/noise/TerrainHeightNoiseGenerator.tres")

# Globally pure (= indepentend of anything else), this is the ground truth.
# Does NOT require any prior info in map / geometry_inputs
static func determine_height(hex_pos: HexPos) -> int:
	var max_height := HexConst.MAP_MAX_HEIGHT

	# Add randomness
	if hex_pos.q < 0:
		max_height += 16


	var pos2D: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	var noise: float = height_noise.get_noise_2d(pos2D.x, pos2D.y)
	noise = remap(noise, -1.0, 1.0, 0.0, 1.0)

	var height_f: float = remap(noise, 0.0, 1.0, HexConst.MAP_MIN_HEIGHT, max_height)
	var height: int = roundf(height_f) as int

	# Modify further (away from noise map)	
	height = clampi(height, HexConst.MAP_MIN_HEIGHT + 4, max_height) + 1

	if height > max_height * 0.85:
		height += 6

	# Border
	# if hex_pos.magnitude() >= HexConst.MAP_SIZE:
	# 	height = HexConst.MAP_OCEAN_HEIGHT

	return height

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

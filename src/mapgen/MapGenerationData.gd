@tool # Must be tool because static variables are used in editor
class_name MapGenerationData

# HEIGHT GENERATION
static var height_noise: Noise = preload("res://assets/noise/TerrainHeightNoiseGenerator.tres")

# Globally pure (= indepentend of anything else), this is the ground truth.
# Does NOT require any prior info in map / geometry_inputs
static func determine_height(hex_pos: HexPos) -> int:
	var max_height := HexConst.MAP_HEIGHT_MAX

	# Add randomness based on map region	
	if hex_pos.s < 0:
		max_height += 8

	if cos(hex_pos.q / (PI * 30)) < 0:
		max_height += 16
	if cos(hex_pos.r / (PI * 10)) < 0:
		max_height += 8


	var pos2D: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	var noise: float = height_noise.get_noise_2d(pos2D.x, pos2D.y)
	noise = remap(noise, -1.0, 1.0, 0.0, 1.0)

	var height_f: float = remap(noise, 0.0, 1.0, HexConst.MAP_HEIGHT_MIN, max_height)
	var height: int = roundf(height_f) as int

	# Modify further (compared to noise map)	
	height = clampi(height, HexConst.MAP_HEIGHT_MIN + 4, max_height) + 1

	# Add cliff-tops
	if height > max_height * 0.88:
		height += 6

	return height

# Only here to have this class actually decide all the relevant information for map generation
# THIS must be bidirectional, the type must be the same for for both hex-tiles it connects!
static func determine_transition_type(from_hex_pos: HexPos, from_height: int, to_hex_pos: HexPos, to_height: int) -> HexGeometryInput.TransitionType:
	# This adds randomness as some steep connections are suddenly smooth
	var rand_cond: bool = not (from_hex_pos.r == from_hex_pos.q or to_hex_pos.r == to_hex_pos.q)

	var height_diff: int = abs(to_height - from_height)

	# Make some connections smoother
	if rand_cond and height_diff in [14, 15, 16]:
		return HexGeometryInput.TransitionType.SMOOTH

	# Normal cases
	if height_diff <= HexConst.trans_type_max_height_diff:
		return HexGeometryInput.TransitionType.SMOOTH
	else:
		return HexGeometryInput.TransitionType.SHARP

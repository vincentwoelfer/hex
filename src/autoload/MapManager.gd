# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

const MIN_HEIGHT: int = 1
const MAX_HEIGHT: int = 20

const OCEAN_HEIGHT: int = 0
const INVALID_HEIGHT: int = -1

# Includes one circle of ocean
# Size = n means n circles around the map origin. So n=1 means 7 tiles (one origin tile and 6 additional tiles)
const MAP_SIZE: int = 5
# 12 for most performance tests in the past

var map: HexMap = HexMap.new()
	

# Requires the heights of the adjacent hex to be added to the map already
func create_hex_geometry_input(hex_pos: HexPos) -> HexGeometryInput:
	var tile := map.get_hex(hex_pos)
	assert(tile != null)

	# Height
	var input := HexGeometryInput.new()
	input.height = tile.height

	# Neighbours
	var neighbours: Array[HexTile] = []
	neighbours.resize(6)
	for dir in range(6):
		neighbours[dir] = map.get_hex(hex_pos.get_neighbor(dir))

	# Transitions
	for dir in range(6):
		input.transitions[dir] = create_transition_between_tiles(tile, neighbours[dir])
		
	# Corner vertices
	for dir in range(6):
		var angle := Util.getHexAngle(dir)
		var vec: Vector3 = Util.getHexVertex(HexConst.outer_radius, angle) # X/Z
		var both_neighbours: Array[HexTile] = [neighbours[Util.as_dir(dir - 1)], neighbours[dir]]
		vec.y = determine_corner_vertex_height(input.height, both_neighbours)
		input.corner_vertices[dir] = vec

	# Corner vertices smoothing
	for dir in range(6):
		# Use normal corner_vertex as base
		var vec: Vector3 = input.corner_vertices[dir]

		var both_transitions: Array[HexGeometryInput.Transition] = [input.transitions[Util.as_dir(dir - 1)], input.transitions[Util.as_dir(dir)]]
		vec.y = determine_corner_vertex_smoothing_height(input.height, vec.y, both_transitions)
		input.corner_vertices_smoothing[dir] = vec
	
	return input


func determine_corner_vertex_smoothing_height(own_height: int, strict_corner_height: float, trans: Array[HexGeometryInput.Transition]) -> float:
	# BOTH THE SAME
	if trans[0].type == trans[1].type:
		# Both SMOOTH
		if trans[0].type == HexGeometryInput.TransitionType.SMOOTH:
			# Use normal (strict) corner vertex
			return strict_corner_height # Already global height

		# BOTH SHARP
		elif trans[0].type == HexGeometryInput.TransitionType.SHARP:
			# Use own height
			return 0.0

		# BOTH INVALID
		elif trans[0].type == HexGeometryInput.TransitionType.INVALID:
			# Use own height
			return 0.0
		
		# Should never happen
		assert(false)
		return 0.0

	# BOTH DIFFERENT
	else:
		# Different or one invalid -> take the smooth one and average
		var height_other: int
		if trans[0].type == HexGeometryInput.TransitionType.SMOOTH:
			height_other = trans[0].height_other
		else:
			height_other = trans[1].height_other

		var avg := (height_other + own_height) / 2.0
		return (avg - own_height) * HexConst.height
		

# Computes the height of the corner vertex bordering these two transitions.
# Relative = already as float and minus own height -> as vertex coordinates
func determine_corner_vertex_height(own_height: int, neighbours: Array[HexTile]) -> float:
	var heights: Array[int] = [own_height]
	for n in neighbours:
		if n != null:
			heights.append(n.height)

	# No valid neighbours -> use own height
	if heights.size() == 1:
		return own_height * HexConst.height

	# One valid neighbour -> average heights
	if heights.size() == 2:
		var avg := (heights[0] + heights[1]) / 2.0
		return (avg - own_height) * HexConst.height

	# Two valid neighbours -> per-transition average -> use median
	else:
		var averages: Array[float] = []
		averages.push_back((heights[0] + heights[1]) / 2.0)
		averages.push_back((heights[1] + heights[2]) / 2.0)
		averages.push_back((heights[2] + heights[0]) / 2.0)

		# median
		averages.sort()
		var median := averages[1]
		return (median - own_height) * HexConst.height


func create_transition_between_tiles(from: HexTile, to: HexTile) -> HexGeometryInput.Transition:
	assert(from != null)
	var t := HexGeometryInput.Transition.new()

	if to != null:
		t.height_other = to.height
		if abs(t.height_other - from.height) >= HexConst.trans_type_max_height_diff:
			t.type = HexGeometryInput.TransitionType.SHARP
		else:
			t.type = HexGeometryInput.TransitionType.SMOOTH
	else:
		# If neighbour does not exists set height to same as from tile and mark transition invalid
		t.height_other = from.height
		t.type = HexGeometryInput.TransitionType.INVALID
	return t


func get_all_hex_coordinates(N: int) -> Array[HexPos]:
	var num := compute_total_num_tiles_for_map_size(N)
	var coordinates: Array[HexPos] = []
	coordinates.resize(num)
	var i := 0

	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N)
		var r2: int = min(N, -q + N)
		for r in range(r1, r2 + 1):
			var s := -q - r
			coordinates[i] = HexPos.new(q, r, s)
			i += 1

	return coordinates


func compute_total_num_tiles_for_map_size(N: int) -> int:
	# Only origin tile	
	if N == 0:
		return 1

	# per layer: 6 * (layer_size)
	# Runs for [1, ..., N] 
	var num := 0
	for n in range(0, N + 1):
		if n == 0:
			num += 1
		else:
			num += 6 * n
	return num

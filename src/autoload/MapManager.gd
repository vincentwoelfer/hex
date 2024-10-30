# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

var map: HexMap = HexMap.new()


func create_basic_hex_geometry_input(hex_pos: HexPos) -> HexGeometryInput:
	# Fetch or create own new geometry input
	var own_info := map.fetch_or_create_geometry_input(hex_pos)

	# NEW -> BASIC
	if own_info.generation_stage == HexGeometryInput.GenerationStage.NEW:
		# Required: Neighbours heights
		var neighbours_height: Array[int] = []
		neighbours_height.resize(6)
		for dir in range(6):
			# This creates a new enty if not existing yet!
			neighbours_height[dir] = map.fetch_or_create_geometry_input(hex_pos.get_neighbour(dir)).height

		# Finally genereate own
		own_info.generate_basic(neighbours_height)

	return own_info


func create_complete_hex_geometry_input(hex_pos: HexPos) -> HexGeometryInput:
	# Fetch or create own basic geometry input
	var own_info := create_basic_hex_geometry_input(hex_pos)

	# BASIC -> COMPLETE
	if own_info.generation_stage == HexGeometryInput.GenerationStage.BASIC:
		# Required: Neighbours with BASIC
		var neighbours_info: Array[HexGeometryInput] = []
		neighbours_info.resize(6)
		for dir in range(6):
			neighbours_info[dir] = create_basic_hex_geometry_input(hex_pos.get_neighbour(dir))

		# Finally genereate own
		own_info.generate_complete(neighbours_info)
	
	return own_info


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

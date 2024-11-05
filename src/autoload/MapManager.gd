# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

var map: HexMap = HexMap.new()

# Called from HexTile.generate()
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


# Only called from the above function create_complete_hex_geometry_input()
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







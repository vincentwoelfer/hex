@tool # Must be tool because static variables are used in editor
class_name HexGeometryInputMap

# Member variables
static var geometry_inputs: Dictionary[int, HexGeometryInput] = {}
static var mutex: Mutex = Mutex.new()


#################################################################
# Generate Data
#################################################################

############################# PUBLIC ############################
# Called from Generating Thread -> protect with mutexes
static func create_complete_hex_geometry_input(hex_pos: HexPos) -> HexGeometryInput:
	mutex.lock()

	# Fetch or create own basic geometry input
	var own_info := _create_basic_hex_geometry_input(hex_pos)

	# BASIC -> COMPLETE
	if own_info.generation_stage == HexGeometryInput.GenerationStage.BASIC:
		# Required: Neighbours with BASIC
		var neighbours_info: Array[HexGeometryInput] = []
		neighbours_info.resize(6)
		for dir in range(6):
			neighbours_info[dir] = _create_basic_hex_geometry_input(hex_pos.get_neighbour(dir))

		mutex.unlock()

		# Finally genereate own -> mutex not needed anymore
		own_info.generate_complete(neighbours_info)
	
	# Free mutex if not done so already
	else:
		mutex.unlock()

	return own_info

############################# PRIVATE ############################
# Only called from the above function create_complete_hex_geometry_input() -> no mutxes needed
static func _create_basic_hex_geometry_input(hex_pos: HexPos) -> HexGeometryInput:
	# Fetch or create own new geometry input
	var own_info := _fetch_or_create_geometry_input(hex_pos)

	# NEW -> BASIC
	if own_info.generation_stage == HexGeometryInput.GenerationStage.NEW:
		# Required: Neighbours heights
		var neighbours_height: Array[int] = []
		neighbours_height.resize(6)
		for dir in range(6):
			# This creates a new enty if not existing yet!
			neighbours_height[dir] = _fetch_or_create_geometry_input(hex_pos.get_neighbour(dir)).height

		# Finally genereate own
		own_info.generate_basic(neighbours_height)

	return own_info

############################# PRIVATE ############################
# Only called from the above function _create_basic_hex_geometry_input() -> no mutxes needed
# Access to actual dictionary -> Only place where new keys are created
static func _fetch_or_create_geometry_input(hex_pos: HexPos) -> HexGeometryInput:
	var key: int = hex_pos.hash()

	# Search for key or create new entry if not existing. This is the ONLY place HexGeometryInput is ever created
	if geometry_inputs.has(key):
		return geometry_inputs[key]

	var geometry_input: HexGeometryInput = HexGeometryInput.new(hex_pos, MapGenerationData.determine_height(hex_pos))
	geometry_inputs[key] = geometry_input
	return geometry_input

#################################################################
# DELETE
#################################################################
# PUBLIC
static func clear_all() -> void:
	mutex.lock()

	for i: int in geometry_inputs:
		if geometry_inputs[i] != null:
			geometry_inputs[i].free()
	geometry_inputs.clear()

	mutex.unlock()


#################################################################
# DEBUG helper
#################################################################
# Requires mutex lock -> actual performance impact
static func print_debug_stats() -> void:
	var num_new: int = 0
	var num_basic: int = 0
	var num_complete: int = 0

	mutex.lock()

	for val: HexGeometryInput in geometry_inputs.values():
		if val.generation_stage == HexGeometryInput.GenerationStage.NEW:
			num_new += 1
		elif val.generation_stage == HexGeometryInput.GenerationStage.BASIC:
			num_basic += 1
		elif val.generation_stage == HexGeometryInput.GenerationStage.COMPLETE:
			num_complete += 1

	mutex.unlock()

	print("Map Geometry Info | new: %d\t basic: %d\t complete: %d\t total: %d" % [num_new, num_basic, num_complete, num_new + num_basic + num_complete])

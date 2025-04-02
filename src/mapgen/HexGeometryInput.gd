class_name HexGeometryInput
extends Node

# Variables
var height: int
var corner_vertices: Array[Vector3]
var corner_vertices_smoothing: Array[Vector3]
var transitions: Array[Transition]

var hex_pos: HexPos

# Track progess
var generation_stage: GenerationStage

# Transitions
enum TransitionType {INVALID, SHARP, SMOOTH}
class Transition:
	var type: TransitionType
	var height_other: int
	var smoothing_start_height: float
	var smoothing_end_height: float

# NEW      = Only height
# BASIC    = + transition-types, corner vertices (strict & smoothed)
# COMPLETE = + transition start/end smothing height
enum GenerationStage {NEW = 0, BASIC = 1, COMPLETE = 2}


func _init(hex_pos_: HexPos, height_: int) -> void:
	self.hex_pos = hex_pos_
	self.height = height_

	self.transitions.resize(6)
	self.corner_vertices.resize(6)
	self.corner_vertices_smoothing.resize(6)

	self.generation_stage = GenerationStage.NEW


# Only uses height information. Neighbour invalid -> null
# DETERMINES the transition-type based on HexConst.trans_type_max_height_diff
func generate_basic(neighbours_height: Array[int]) -> void:
	assert(neighbours_height.size() == 6)
	assert(self.generation_stage == GenerationStage.NEW)
	self.generation_stage = GenerationStage.BASIC

	# Transitions
	for dir in range(6):
		transitions[dir] = create_transition_between_tiles(height, neighbours_height[dir], dir)

	# Corner vertices
	for dir in range(6):
		var angle := Util.getHexAngle(dir)
		var vec: Vector3 = Util.getHexVertex(HexConst.outer_radius, angle) # X/Z
		var both_neighbours: Array[int] = [neighbours_height[Util.as_dir(dir - 1)], neighbours_height[dir]]
		vec.y = determine_corner_vertex_height(height, both_neighbours)
		corner_vertices[dir] = vec

	# Corner vertices smoothing
	for dir in range(6):
		# Use normal corner_vertex as base
		var vec: Vector3 = corner_vertices[dir]
		var both_transitions: Array[Transition] = [transitions[Util.as_dir(dir - 1)], transitions[Util.as_dir(dir)]]
		vec.y = determine_corner_vertex_smoothing_height(height, vec.y, both_transitions)
		corner_vertices_smoothing[dir] = vec


# Requires neighbouring HexGeometryInput cells in BASIC stage
func generate_complete(neighbour_input: Array[HexGeometryInput]) -> void:
	assert(neighbour_input.size() == 6)
	assert(self.generation_stage == GenerationStage.BASIC)
	self.generation_stage = GenerationStage.COMPLETE

	for dir in range(6):
		compute_smoothed_transition_vertices(dir, neighbour_input[dir])


func compute_smoothed_transition_vertices(dir: int, n: HexGeometryInput) -> void:
	assert(n.generation_stage >= GenerationStage.BASIC)

	# Shortcuts
	var type := transitions[dir].type
	var start: float
	var end: float

	# Get neighbour corner_vertices_smoothing heights and make them relative to ours:
	var n_start_height: float = n.corner_vertices_smoothing[get_neighbour_corner_idx(dir, true)].y
	var n_end_height: float = n.corner_vertices_smoothing[get_neighbour_corner_idx(dir, false)].y
	n_start_height = relativize_height(n_start_height, n.height)
	n_end_height = relativize_height(n_end_height, n.height)

	# SHARP or INVALID
	# Use strict corner vertex height for SHARP transitions, clamp prevent breaks in geometry
	if type == TransitionType.SHARP or type == TransitionType.INVALID:
		start = corner_vertices[dir].y
		end = corner_vertices[Util.as_dir(dir + 1)].y

		# Clamp height between smoothed vertex corners heights
		start = Util.clampf(start, corner_vertices_smoothing[dir].y, n_start_height)
		end = Util.clampf(end, corner_vertices_smoothing[Util.as_dir(dir + 1)].y, n_end_height)

	# SMOOTH
	# Use average of own smoothed corner vertex height and that of the neighbour
	elif type == TransitionType.SMOOTH:
		start = (corner_vertices_smoothing[dir].y + n_start_height) / 2.0
		end = (corner_vertices_smoothing[Util.as_dir(dir + 1)].y + n_end_height) / 2.0

	transitions[dir].smoothing_start_height = start
	transitions[dir].smoothing_end_height = end


func relativize_height(value: float, n_height: int) -> float:
	return value + (n_height * HexConst.height) - height * HexConst.height


func determine_corner_vertex_smoothing_height(own_height: int, own_strict_corner_height: float, trans: Array[Transition]) -> float:
	assert(trans.size() == 2)

	# BOTH THE SAME
	if trans[0].type == trans[1].type:
		# Both SMOOTH
		if trans[0].type == TransitionType.SMOOTH:
			# Use normal (strict) corner vertex
			return own_strict_corner_height # Already global height

		# BOTH SHARP
		elif trans[0].type == TransitionType.SHARP:
			return 0.0

		# BOTH INVALID
		elif trans[0].type == TransitionType.INVALID:
			# Use normal (strict) corner vertex
			return own_strict_corner_height # Already global height

		# Should never happen
		assert(false)
		return 0.0

	# BOTH DIFFERENT
	else:
		# Different or one invalid -> take the smooth one and average
		var height_other: int
		if trans[0].type == TransitionType.SMOOTH:
			height_other = trans[0].height_other
		else:
			height_other = trans[1].height_other

		var avg := (height_other + own_height) / 2.0
		return (avg - own_height) * HexConst.height


# Computes the height of the corner vertex bordering these two transitions.
# Relative = already as float and minus own height -> as vertex coordinates
func determine_corner_vertex_height(own_height: int, neighbours_height: Array[int]) -> float:
	assert(neighbours_height.size() == 2)

	var heights: Array[int] = [own_height]
	for n in neighbours_height:
		if n != HexConst.MAP_HEIGHT_INVALID:
			heights.append(n)

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


func create_transition_between_tiles(from_height: int, to_height: int, dir: int) -> Transition:
	assert(from_height != HexConst.MAP_HEIGHT_INVALID)
	var t := Transition.new()

	if to_height != HexConst.MAP_HEIGHT_INVALID:
		t.height_other = to_height
		t.type = MapGenerationData.determine_transition_type(hex_pos, from_height, hex_pos.get_neighbour(dir), to_height)
	else:
		# If neighbour does not exists set height to same as from tile and mark transition invalid
		t.height_other = from_height
		t.type = TransitionType.INVALID
	return t


static func get_neighbour_corner_idx(dir: int, start: bool) -> int:
	# dir += 4 for first (start) one. Second one (end) is always -1
	var start_idx := Util.as_dir(dir + 4)
	if not start:
		start_idx = Util.as_dir(start_idx - 1)

	return start_idx


########################################################################
func create_debug_visualization(parent: Node3D) -> void:
	# Corner vertices
	for i in range(6):
		var instance := MeshInstance3D.new()
		var color := Colors.getDistincHexColor(i).darkened(0.5)
		instance.mesh = DebugShapes3D.sphere_mesh(0.15 - i * 0.005, DebugShapes3D.material(color))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.position = corner_vertices[i]
		parent.add_child(instance)

	# Smoothed corner vertices
	for i in range(6):
		var instance := MeshInstance3D.new()
		var color := Colors.getDistincHexColor(i).lightened(0.3)
		instance.mesh = DebugShapes3D.sphere_mesh(0.15 - i * 0.005, DebugShapes3D.material(color))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pos: Vector3 = corner_vertices_smoothing[i]
		var inwards_factor := HexConst.inner_radius / HexConst.outer_radius
		pos.x *= inwards_factor
		pos.z *= inwards_factor
		pos.y *= inwards_factor
		instance.position = pos
		parent.add_child(instance)

	# transition vertices
	# for i in range(6):
	# 	var trans := transitions[i].sta

	# 	var instance := MeshInstance3D.new()
	# 	var color := Colors.getDistincHexColor(i).lightened(0.3)
	# 	instance.mesh = DebugShapes3D.create_sphere(0.15 - i * 0.01, DebugShapes3D.create_mat(color))
	# 	var pos: Vector3 = corner_vertices_smoothing[i]
	# 	var inwards_factor := HexConst.inner_radius / HexConst.outer_radius
	# 	pos.x *= inwards_factor
	# 	pos.z *= inwards_factor
	# 	#pos.y *= inwards_factor
	# 	instance.position = pos
	# 	parent.add_child(instance)

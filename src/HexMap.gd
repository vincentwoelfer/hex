@tool
class_name HexMap

# Hash-Map of Hexes. Key = int (HexPos.has()), Value = HexTile
var tiles: Dictionary[int, HexTile] = {}

var geometry_inputs: Dictionary[int, HexGeometryInput] = {}


#################################################
# Hex Geometry Inputs
#################################################
# TODO add mutex here for multithreading!!!
func fetch_or_create_geometry_input(hex_pos: HexPos) -> HexGeometryInput:
	var key: int = hex_pos.hash()
	if not geometry_inputs.has(key):
		# Create new entry if not existing. This is the ONLY place HexGeometryInput is ever created
		geometry_inputs[key] = HexGeometryInput.new(hex_pos, MapGenerationData.determine_height(hex_pos))

	return geometry_inputs[key]


func print_debug_stats() -> void:
	var num_new: int = 0
	var num_basic: int = 0
	var num_complete: int = 0

	for val: HexGeometryInput in geometry_inputs.values():
		if val.generation_stage == HexGeometryInput.GenerationStage.NEW:
			num_new += 1
		elif val.generation_stage == HexGeometryInput.GenerationStage.BASIC:
			num_basic += 1
		elif val.generation_stage == HexGeometryInput.GenerationStage.COMPLETE:
			num_complete += 1

	print("Map Geometry Info | new: %d\t basic: %d\t complete: %d\t total: %d" % [num_new, num_basic, num_complete, num_new + num_basic + num_complete])


#################################################
# Hex Tiles
#################################################
func add_hex_tile_hash(key: int, height: int) -> HexTile:
	var hex_pos: HexPos = HexPos.unhash(key)
	if tiles.has(hash):
		print("Map already has tile at r: %d, q: %d, s:%d!" % [hex_pos.r, hex_pos.q, hex_pos.s])
	else:
		tiles[key] = HexTile.new(hex_pos, height)
	return tiles[key]

func add_hex_tile(hex_pos: HexPos, height: int) -> HexTile:
	var key := hex_pos.hash()
	if tiles.has(key):
		print("Map already has tile at r: %d, q: %d, s:%d!" % [hex_pos.r, hex_pos.q, hex_pos.s])
	else:
		tiles[key] = HexTile.new(hex_pos, height)
	return tiles[key]


func get_hex_tile_hash(key: int) -> HexTile:
	if not tiles.has(key):
		return null
	return tiles[key]

func get_hex_tile(hex_pos: HexPos) -> HexTile:
	var key: int = hex_pos.hash()
	if not tiles.has(key):
		return null
	return tiles[key]


func is_empty() -> bool:
	return tiles.is_empty()


func free_all_hex_tiles() -> void:
	for i: int in tiles:
		if tiles[i] != null:
			tiles[i].free()
	tiles.clear()


func free_all_geometry_inputs() -> void:
	for i: int in geometry_inputs:
		if geometry_inputs[i] != null:
			geometry_inputs[i].free()
	geometry_inputs.clear()

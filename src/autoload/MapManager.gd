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
const MAP_SIZE: int = 4
# 12 for most performance tests in the past

var map: HexMap = HexMap.new()


func free_all() -> void:
	if not map.is_empty():
		# Delete from hexmap
		var coordinates := get_all_hex_coordinates(MAP_SIZE)

		for hex_pos in coordinates:
			var tile : HexTile = map.get_hex(hex_pos)
			if tile != null:
				tile.free()
		map.clear_all()
	

func get_all_hex_coordinates(N: int) -> Array[HexPos]:
	var num := compute_num_tiles_for_map_size(N)
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


func compute_num_tiles_for_map_size(N: int) -> int:
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

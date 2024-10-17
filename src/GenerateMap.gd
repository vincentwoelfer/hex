@tool
extends Node3D

var height_noise: Noise = preload("res://assets/noise/TerrainHeightNoiseGenerator.tres")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_complete_map()

	# Signals
	EventBus.Signal_HexConstChanged.connect(generate_all_hex_tile_geometry)


func generate_complete_map() -> void:
	# Delete from hexmap
	MapManager.map.clear_all()

	var coordinates := get_all_hex_coordinates(MapManager.MAP_SIZE)
	for hex_pos in coordinates:
		var height: int = determine_height(hex_pos)
		create_empty_hex_tile(hex_pos, height)


	generate_all_hex_tile_geometry()

# MAP GENERATION STEP 1
# Create and instantiate empty hex-tiles, add as child and set world position
# Only done ONCE and expects map to be empty
func create_empty_hex_tile(hex_pos: HexPos, height: int) -> void:
	# Verify that this hex_pos does not contain a tile yet
	assert(!MapManager.map.get_hex(hex_pos).is_valid())

	var hex_tile := MapManager.map.add_hex(hex_pos, height)

	# Add to Screne tree at correct position
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	hex_tile.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)

	# Add to the current scene
	add_child(hex_tile, true)


# MAP GENERATION STEP 2
# Generate hex-tiles (= Geometry, Plants...). This is done by the hex tile and we only call it for every tile
# This allows this to be parallelized later on
func generate_all_hex_tile_geometry() -> void:
	var t_start := Time.get_ticks_msec()

	var coordinates := get_all_hex_coordinates(MapManager.MAP_SIZE)
	for hex_pos in coordinates:
		MapManager.map.get_hex(hex_pos).generate()

	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	print("Regenerated map tiles in %.3f sec" % [t])


func determine_height(hex_pos: HexPos) -> int:
	var pos2D: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	var noise: float = height_noise.get_noise_2d(pos2D.x, pos2D.y)
	noise = remap(noise, -1.0, 1.0, 0.0, 1.0)

	var height_f: float = remap(noise, 0.0, 1.0, MapManager.MIN_HEIGHT, MapManager.MAX_HEIGHT)
	var height: int = roundf(height_f) as int

	# Modify further (away from noise map)	
	height = clampi(height, MapManager.MIN_HEIGHT + 4, MapManager.MAX_HEIGHT) + 1

	if height > MapManager.MAX_HEIGHT * 0.85:
		height += 5

	# Border
	if hex_pos.magnitude() == MapManager.MAP_SIZE:
		height = MapManager.OCEAN_HEIGHT

	return height


func get_all_hex_coordinates(N: int) -> Array[HexPos]:
	var coordinates: Array[HexPos] = []

	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N)
		var r2: int = min(N, -q + N)
		for r in range(r1, r2 + 1):
			var s := -q - r
			var hex_pos := HexPos.new(q, r, s)
			coordinates.push_back(hex_pos)

	return coordinates

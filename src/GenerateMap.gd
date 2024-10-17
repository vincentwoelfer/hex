@tool
extends Node3D

var height_noise: Noise = preload("res://assets/noise/TerrainHeightNoiseGenerator.tres")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_complete_map()

	# Signals
	EventBus.Signal_HexConstChanged.connect(generate_complete_map)


func generate_complete_map() -> void:
	# MAP GENERATION STEP 1
	# Create and instantiate empty hex-tiles, add as child and set world position
	# Only done ONCE and expects map to be empty
	var t_start := Time.get_ticks_msec()

	# Delete from hexmap
	MapManager.map.clear_all()

	var coordinates := get_all_hex_coordinates(MapManager.MAP_SIZE)
	for hex_pos in coordinates:
		var height: int = determine_height(hex_pos)
		create_empty_hex_tile(hex_pos, height)

	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	print("Created %d empty hex tiles in %.3f sec" % [coordinates.size(), t])

	# MAP GENERATION STEP 2
	# Generate hex-tiles (= Geometry, Plants...). This is done by the hex tile and we only call it for every tile
	# This allows this to be parallelized later on
	generate_all_hex_tile_geometry()


# STEP 2
func generate_all_hex_tile_geometry() -> void:
	var t_start := Time.get_ticks_msec()

	# Get coordinates
	var coordinates := get_all_hex_coordinates(MapManager.MAP_SIZE)

	# Create and run threads
	var num_threads := 1
	var threads: Array[Thread] = []
	for i in range(num_threads):
		threads.append(Thread.new())

	# Split coordinates
	var part_size: int = ceil(float(coordinates.size()) / float(num_threads))

	# Start threads
	for i in range(num_threads):
		var start_index: int = i * part_size
		var end_index: int = min((i + 1) * part_size, coordinates.size() - 1)
		var slice := coordinates.slice(start_index, end_index)
		print("Starting thread %d with slice [%d, %d]" % [i, start_index, end_index])
		threads[i].start(thread_function.bind(slice))

	# Join threads
	for i in range(num_threads):
		threads[i].wait_to_finish()

	# Finish
	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	print("Populated %d hex tiles in %.3f sec (%d threads)" % [coordinates.size(), t, num_threads])


# STEP 2 Thread function
func thread_function(hex_poses: Array[HexPos]) -> void:
	for hex_pos in hex_poses:
		#print(hex_pos)
		MapManager.map.get_hex(hex_pos).generate()
		pass


# For STEP 1
func create_empty_hex_tile(hex_pos: HexPos, height: int) -> void:
	# Verify that this hex_pos does not contain a tile yet
	assert(!MapManager.map.get_hex(hex_pos).is_valid())

	var hex_tile := MapManager.map.add_hex(hex_pos, height)

	# Add to Screne tree at correct position
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	hex_tile.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)

	# Add to the current scene
	add_child.call_deferred(hex_tile, true)


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
	var num := compute_num_tiles_for_map_size(N)
	var coordinates: Array[HexPos] = []
	coordinates.resize(num)
	var i := 0

	print("N=", N, " num=", num)

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

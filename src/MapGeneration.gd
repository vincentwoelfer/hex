@tool
extends Node3D

# Regeneration
var regenerate: bool = false
var last_regeneration_timestamp := 0.0
var max_regeneration_delay := 1.0

# Queues
var to_generate_queue: Array[int] = []
var to_generate_mutex: Mutex = Mutex.new()
var to_generate_semaphore: Semaphore = Semaphore.new()

var generated_queue: Array[HexTile] = []
var generated_mutex: Mutex = Mutex.new()

# Threads
var thread: Thread
var is_running: bool = true


# Misc
var generation_dist_hex_tiles := 3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#delete_everything()

	# Create thread
	thread = Thread.new()
	thread.start(thread_generation_func)

	# Signals
	EventBus.Signal_HexConstChanged.connect(set_regenerate)


func _exit_tree() -> void:
	print("MAIN: Waiting for thread to finish")
	is_running = false

	# Post to the semaphore to unblock any waiting threads so they can exit
	to_generate_semaphore.post()
	thread.wait_to_finish()
	print("MAIN: Thread finished")


func _process(delta: float) -> void:
	# Check regeneration
	if self.regenerate and (Time.get_unix_time_from_system() - last_regeneration_timestamp) > max_regeneration_delay:
		last_regeneration_timestamp = Time.get_unix_time_from_system()
		self.regenerate = false
		delete_everything()

	# Empty generated queue and add to scene
	add_generated_tiles()

	# Add tiles near player to queue
	queue_new_tiles()

	
func add_generated_tiles() -> void:
	var t_start := Time.get_ticks_msec()

	# TODO might stall if tiles are being generated right now
	# -> use semaphore or similar
	generated_mutex.lock()
	
	var num_added := 0
	var last_added: String = ""
	for tile: HexTile in generated_queue:
		add_child(tile, false)
		num_added += 1
		last_added = tile.hex_pos._to_string()

	generated_queue.clear()

	generated_mutex.unlock()

	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	if num_added > 1:
		print("MAIN: Added %d tiles in %.3f sec , last one: %s" % [num_added, t, last_added])
		
		# TODO This crashes since geometry-input is not mutex-protected!!!!!
		#MapManager.map.print_debug_stats()
	
	
func queue_new_tiles() -> void:
	var t_start := Time.get_ticks_msec()

	var camera_position: Vector3 = get_viewport().get_camera_3d().global_transform.origin
	var camera_hex_pos: HexPos = HexPos.xyz_to_hexpos_frac(camera_position).round()

	var coords_in_range := camera_hex_pos.get_all_coordinates_in_range(generation_dist_hex_tiles, true)
	var num_queued := 0

	to_generate_mutex.lock()
	for hex_pos in coords_in_range:
		var key: int = hex_pos.hash()

		# Check if hextile is either existing or queued 
		if to_generate_queue.has(key):
			continue

		var tile: HexTile = MapManager.map.get_hex_tile_hash(key)
		if tile == null:
			to_generate_queue.append(key)
			num_queued += 1

			# create_empty_hex_tile(hex_pos)
			# tile = MapManager.map.get_hex_tile(hex_pos)
			# tile.generate()
			# num_generated += 1

	to_generate_mutex.unlock()

	if num_queued > 0:
		# Notify thread
		to_generate_semaphore.post(num_queued)

	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	if num_queued > 0:
		print("MAIN: Queued %d tiles in %.3f sec" % [num_queued, t])


func thread_generation_func() -> void:
	while is_running:
		to_generate_semaphore.wait()

		if not is_running:
			print("THREAD: Exiting")
			break

		var t_start := Time.get_ticks_msec()

		to_generate_mutex.lock()
		var has_key: bool = not to_generate_queue.is_empty()
		var key: int = 0
		if has_key:
			key = to_generate_queue[0]
		to_generate_mutex.unlock()

		if not has_key:
			# print("THREAD: Queue empty")
			continue

		# Generate tile for this hex_pos
		var hex_pos: HexPos = HexPos.unhash(key)
		create_empty_hex_tile(hex_pos)
		var tile: HexTile = MapManager.map.get_hex_tile(hex_pos)

		if tile != null:
			tile.generate()

			generated_mutex.lock()
			generated_queue.append(tile)
			generated_mutex.unlock()

			# Only now remove this key from the to_generate_queue
			to_generate_mutex.lock()
			to_generate_queue.erase(key)
			to_generate_mutex.unlock()

			var t := (Time.get_ticks_msec() - t_start) / 1000.0
			print("THREAD: Generated 1 tile in %.3f sec (incl. mutex wait time) : %s" % [t, hex_pos._to_string()])
		else:
			# WTF
			print("THREAD: Tile is null after generation: %s" % hex_pos._to_string())


# For STEP 1
func create_empty_hex_tile(hex_pos: HexPos) -> void:
	# Verify that this hex_pos does not contain a tile yet
	assert(MapManager.map.get_hex_tile(hex_pos) == null)

	var height: int = MapGenerationData.determine_height(hex_pos)
	var hex_tile := MapManager.map.add_hex_tile(hex_pos, height)

	# # Add to Scene tree at correct position
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	hex_tile.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)

	# Add to the current scene
	# add_child(hex_tile, false)


##############################
# Regeneration
##############################
func set_regenerate() -> void:
	self.regenerate = true


func delete_everything() -> void:
	print("Deleting everything")
	MapManager.map.free_all_hex_tiles()
	MapManager.map.free_all_geometry_inputs()


########################################################
########################################################
########################################################
# TESTING - STEP 3 MERGE ALL TERRAIN
# var instance := MeshInstance3D.new()
# var st_combined: SurfaceTool = SurfaceTool.new()

# for hex_pos in coordinates:
# 	var tile: HexTile = MapManager.map.get_hex_tile(hex_pos)
# 	st_combined.append_from(tile.geometry.mesh, 0, tile.global_transform)

# instance.set_mesh(st_combined.commit())
# const DEFAULT_GEOM_MATERIAL: Material = preload('res://assets/materials/default_geom_material.tres')
# const HIGHLIGHT_MAT: ShaderMaterial = preload('res://assets/materials/highlight_material.tres')
# instance.material_override = DEFAULT_GEOM_MATERIAL
# instance.material_overlay = HIGHLIGHT_MAT
# add_child(instance, false)

# # ROCKS
# var instance_rocks := MeshInstance3D.new()
# st_combined = SurfaceTool.new()

# for hex_pos in coordinates:
# 	var tile: HexTile = MapManager.map.get_hex_tile(hex_pos)
# 	st_combined.append_from(tile.rocksMesh, 0, tile.global_transform)

# instance_rocks.set_mesh(st_combined.commit())
# const ROCKS_MATERIAL: Material = preload('res://assets/materials/rocks_material.tres')
# instance_rocks.material_override = ROCKS_MATERIAL
# add_child(instance_rocks, false)

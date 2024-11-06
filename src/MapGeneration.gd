@tool # No static vars but actually runs in editor
extends Node3D
class_name MapGeneration

# Regeneration
var regenerate: bool = false
var last_regeneration_timestamp := 0.0
var max_regeneration_delay := 1.0

# Queues
var to_generate_queue: Array[int] = []
var to_generate_mutex: Mutex = Mutex.new()
var to_generate_semaphore: Semaphore = Semaphore.new()

var generated_queue: Array[int] = []
var generated_mutex: Mutex = Mutex.new()

# Threads
var threads: Array[Thread] = []
var num_threads: int = 2
var is_running: bool = true

# Misc
var generation_dist_hex_tiles := 8
@onready var camera_controller: CameraController = %Camera3D as CameraController


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#delete_everything()

	# Create thread
	print("Starting %d threads" % num_threads)
	for i in range(num_threads):
		threads.append(Thread.new())
		threads[i].start(thread_generation_func.bind(i))

	# Signals
	EventBus.Signal_HexConstChanged.connect(set_regenerate)


func _process(delta: float) -> void:
	# Check regeneration
	if self.regenerate and (Time.get_unix_time_from_system() - last_regeneration_timestamp) > max_regeneration_delay:
		last_regeneration_timestamp = Time.get_unix_time_from_system()
		self.regenerate = false
		delete_everything()

	# Empty generated queue and add to scene
	fetch_and_add_all_generated_tiles()

	# Add tiles near player to queue
	queue_new_tiles_for_generation()


# Fetch all generated tile hashes, get the tile from the HexTileMap and add them to the scene
func fetch_and_add_all_generated_tiles() -> void:
	var t_start := Time.get_ticks_usec()

	generated_mutex.lock()
	
	var num_added := 0
	for key: int in generated_queue:
		var tile: HexTile = HexTileMap.get_by_hash(key)
		add_child(tile, false)
		num_added += 1

	generated_queue.clear()

	generated_mutex.unlock()

	var t := (Time.get_ticks_usec() - t_start) / 1000.0

	if num_added > 1:
		print("MAIN: Added %d tiles in %4.0f ms" % [num_added, t])
		HexGeometryInputMap.print_debug_stats()
	
	
func queue_new_tiles_for_generation() -> void:
	var t_start := Time.get_ticks_usec()

	var generation_position: Vector3 = Vector3.ZERO
	if not Engine.is_editor_hint() and camera_controller != null:
		generation_position = camera_controller.get_follow_point()


	var camera_hex_pos: HexPos = HexPos.xyz_to_hexpos_frac(generation_position).round()
	var hashes_in_range: PackedInt32Array = camera_hex_pos.get_all_coordinates_in_range_hash(generation_dist_hex_tiles, true)

	# Remove any hashes which are already presend in the map. No mutex needed here
	var hashes_filtered: PackedInt32Array
	for key in hashes_in_range:
		if HexTileMap.get_by_hash(key) == null:
			hashes_filtered.push_back(key)

	var num_queued := 0

	# MUTEX LOCK
	to_generate_mutex.lock()
	for key in hashes_filtered:
		# Check if hextile is not already queued
		if to_generate_queue.has(key):
			continue

		# Add to queue
		to_generate_queue.push_back(key)
		num_queued += 1

	to_generate_mutex.unlock()
	# MUTEX UNLOCK

	if num_queued > 0:
		# Notify threads
		to_generate_semaphore.post(num_queued)

	var t := (Time.get_ticks_usec() - t_start) / 1000.0
	if num_queued > 0:
		print("MAIN: Queued %d tiles in %4.0f ms" % [num_queued, t])


func thread_generation_func(thread_id: int) -> void:
	while is_running:
		to_generate_semaphore.wait()

		if not is_running:

			print("THREAD %d: Exiting" % thread_id)
			break

		var t_start := Time.get_ticks_usec()

		var key: int = 0
		var hex_pos: HexPos
		var tile: HexTile

		# Fetch tile hash to generate, remove from queue and already add to HexTileMap to prevent re-queueing
		# MUTEX LOCK
		to_generate_mutex.lock()

		var has_key: bool = not to_generate_queue.is_empty()
		if has_key:
			key = to_generate_queue.pop_back()
			hex_pos = HexPos.unhash(key)

			# Generate empty tile in HexTileMap
			# -> TODO maybe this results in a deadlock since we need both mutexes at the same time?
			tile = create_empty_hex_tile(hex_pos)
			assert(tile != null)

		to_generate_mutex.unlock()
		# MUTEX UNLOCK

		if not has_key:
			continue

		# Generate geometry input (kinda cheap)
		var geometry_input := HexGeometryInputMap.create_complete_hex_geometry_input(hex_pos)

		# Generate HexGeometry itself (very expensive)
		tile.generate(geometry_input)

		generated_mutex.lock()
		generated_queue.push_back(key)
		generated_mutex.unlock()

		var t := (Time.get_ticks_usec() - t_start) / 1000.0
		print("THREAD %d: Generated 1 tile in %4.0f ms (incl. mutex wait time)" % [thread_id, t])


func create_empty_hex_tile(hex_pos: HexPos) -> HexTile:
	# Verify that this hex_pos does not contain a tile yet
	# assert(HexTileMap.get_by_pos(hex_pos) == null)

	var height: int = MapGenerationData.determine_height(hex_pos)
	var hex_tile := HexTileMap.add_by_pos(hex_pos, height)

	# Set global world position of tile -> TODO move this elsewhere ?
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	hex_tile.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)

	return hex_tile


##############################
# Regeneration
##############################
func set_regenerate() -> void:
	self.regenerate = true


func delete_everything() -> void:
	print("Deleting everything")

	generated_mutex.lock()
	generated_queue.clear()
	generated_mutex.unlock()

	to_generate_mutex.lock()
	to_generate_queue.clear()
	to_generate_mutex.unlock()

	HexTileMap.free_all()
	HexGeometryInputMap.free_all()


##############################
# Cleanup
##############################
func _exit_tree() -> void:
	print("MAIN: Waiting for %d threads to finish" % num_threads)
	is_running = false

	# Empty queue
	to_generate_mutex.lock()
	to_generate_queue.clear()
	to_generate_mutex.unlock()

	# Post to the semaphore to unblock any waiting threads so they can exit
	to_generate_semaphore.post(num_threads * 10)

	for thread in threads:
		thread.wait_to_finish()
	print("MAIN: %d threads finished" % num_threads)


########################################################
########################################################
########################################################
# TESTING - STEP 3 MERGE ALL TERRAIN
# var instance := MeshInstance3D.new()
# var st_combined: SurfaceTool = SurfaceTool.new()

# for hex_pos in coordinates:
# 	var tile: HexTile = MapManager.map.get_by_pos(hex_pos)
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
# 	var tile: HexTile = MapManager.map.get_by_pos(hex_pos)
# 	st_combined.append_from(tile.rocksMesh, 0, tile.global_transform)

# instance_rocks.set_mesh(st_combined.commit())
# const ROCKS_MATERIAL: Material = preload('res://assets/materials/rocks_material.tres')
# instance_rocks.material_override = ROCKS_MATERIAL
# add_child(instance_rocks, false)

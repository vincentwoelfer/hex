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
# 3-4 is sweet spot on my machine
var num_threads: int = 3
var threads_running: bool = true
var fetch_tiles_count := 4

# Misc
var tile_generation_distance := 8
var tile_deletion_distance := 35
@onready var camera_controller: CameraController = %Camera3D as CameraController
var generation_position: HexPos = HexPos.invalid()

# Testing
var t_start_: int
var testing_complete: bool = false

# TODO:
# Find our why sometimes tiles are missing. Happens more with more threads

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This is required for the LSP to work (since this script is a tool script)
	if OS.has_feature("Server"):
		print("Detected headless, not starting map generation!")
		num_threads = 0
		return

	# Create thread
	print("MAIN: Starting %d threads with %d fetch_tiles_count" % [num_threads, fetch_tiles_count])
	for i in range(num_threads):
		threads.append(Thread.new())
		threads[i].start(thread_generation_loop.bind(i))

	# Signals
	EventBus.Signal_HexConstChanged.connect(set_regenerate)

	# Start testing timer
	t_start_ = Time.get_ticks_usec()


func _process(delta: float) -> void:
	# Check regeneration
	if self.regenerate and (Time.get_unix_time_from_system() - last_regeneration_timestamp) > max_regeneration_delay:
		last_regeneration_timestamp = Time.get_unix_time_from_system()
		self.regenerate = false
		delete_everything()

	# Empty generated queue and add to scene, regardless of player position
	fetch_and_add_all_generated_tiles()

	# Add tiles near player to queue and delete far away
	var generation_position_changed := update_generation_position()
	if generation_position_changed:
		queue_new_tiles_for_generation()
		remove_far_away_tiles()

	# Testing
	if not testing_complete:
		var expected := HexPos.compute_num_tiles_in_range(tile_generation_distance, true)
		if HexTileMap.tiles.size() >= expected:
			var t := (Time.get_ticks_usec() - t_start_) / 1000.0
			print("=======================================================")
			print("MAIN: Process took %4.0f ms to generate %d tiles (N=%d)" % [t, expected, tile_generation_distance])
			print("MAIN: Thread count: %d, fetch_tiles_count: %d" % [num_threads, fetch_tiles_count])
			print("=======================================================")
			testing_complete = true


# Returns true if the player has moved and we need to regenerate
func update_generation_position() -> bool:
	# Default to ZERO if camera not existing/found
	var new_generation_position_world: Vector3 = Util.get_global_cam_pos(self)
	var new_generation_position_hexpos: HexPos = HexPos.xyz_to_hexpos_frac(new_generation_position_world).round()

	# Abort if fiels has not changed
	if new_generation_position_hexpos.equals(generation_position):
		return false

	# Update pos and return true
	generation_position = new_generation_position_hexpos
	return true


# Fetch all generated tile hashes, get the tile from the HexTileMap and add them to the scene
func fetch_and_add_all_generated_tiles() -> void:
	# MUTEX LOCK
	generated_mutex.lock()
	var generated_queue_copy: Array[int] = generated_queue.duplicate()
	generated_queue.clear()
	generated_mutex.unlock()
	# MUTEX UNLOCK

	for key: int in generated_queue_copy:
		var tile: HexTile = HexTileMap.get_by_hash(key)
		assert(tile != null)
		# Only place where tiles are added to the scene
		add_child(tile, false)


func remove_far_away_tiles() -> void:
	# No mutex needed here
	var child_count := get_child_count()

	for i in range(child_count - 1, -1, -1):
		var node: Node = get_child(i)
		if node is HexTile and is_instance_valid(node) and not node.is_queued_for_deletion() and (node as HexTile).is_valid():
			var tile: HexTile = node as HexTile
			var distance := generation_position.distance_to(tile.hex_pos)
			if distance > tile_deletion_distance:
				# This is the only place where tiles are removed
				HexTileMap.delete_by_hash(tile.hex_pos.hash())
				node.queue_free()


func queue_new_tiles_for_generation() -> void:
	var hashes_in_range: PackedInt32Array = generation_position.get_neighbours_in_range_as_hash(tile_generation_distance, true)

	# Remove any hashes which are already presend in the map. No mutex needed here.
	# THIS MIGHT MISS SOME TILES SINCE THEY ARE ADDED TO THE MAP AFTER THIS CHECK -> filter again after mutex lock
	var hashes_filtered: PackedInt32Array
	for key in hashes_in_range:
		if HexTileMap.get_by_hash(key) == null:
			hashes_filtered.push_back(key)

	var num_queued := 0

	# MUTEX LOCK
	to_generate_mutex.lock()
	for key in hashes_filtered:
		# Filter again, this time in to_generate_mutex
		if HexTileMap.get_by_hash(key) != null:
			continue

		# Queue if hex-tile is not already queued
		if not to_generate_queue.has(key):
			# Push front is less effective BUT preserves order. Godot has no fast FIFO container :(
			to_generate_queue.push_front(key)
			# print("Queuing: ", HexPos.unhash(key)._to_string())
			num_queued += 1

	to_generate_mutex.unlock()
	# MUTEX UNLOCK

	if num_queued > 0:
		# Notify threads
		to_generate_semaphore.post(num_queued)


func thread_generation_loop(thread_id: int) -> void:
	while threads_running:
		to_generate_semaphore.wait()

		if not threads_running:
			print("THREAD %d: Exiting" % thread_id)
			break

		# var t_start := Time.get_ticks_usec()

		var keys: Array[int] = []
		var hex_poses: Array[HexPos] = []
		var tiles: Array[HexTile] = []

		# Fetch tile hash to generate, remove from queue and already add to HexTileMap to prevent re-queueing
		# MUTEX LOCK
		to_generate_mutex.lock()

		# Fetch keys
		for i in range(fetch_tiles_count):
			# Fetch and pop key, save hex_pos and create empty tile for it
			var k: Variant = to_generate_queue.pop_back()
			if k == null:
				break

			keys.push_back(k)
			hex_poses.push_back(HexPos.unhash(keys[i]))

			# Create HexTile here already to prevent re-queueing
			tiles.push_back(create_empty_hex_tile(hex_poses[i]))

		to_generate_mutex.unlock()
		# MUTEX UNLOCK

		# Abort if no keys
		if keys.is_empty():
			continue

		# Generate geometry input (dirt cheap ~ < 1ms) and HexGeometry itself (expensive ~ 50ms per tile)
		for i in range(keys.size()):
			var geometry_input := HexGeometryInputMap.create_complete_hex_geometry_input(hex_poses[i])
			tiles[i].generate(geometry_input)

		# Add to generated queue
		generated_mutex.lock()
		for i in range(keys.size()):
			generated_queue.push_back(keys[i])
		generated_mutex.unlock()

		# var t := (Time.get_ticks_usec() - t_start) / 1000.0
		# print("THREAD %d: Generated %d tile(s) in %4.0f ms" % [thread_id, keys.size(), t])


func create_empty_hex_tile(hex_pos: HexPos) -> HexTile:
	assert(hex_pos != null)
	var height: int = MapGenerationData.determine_height(hex_pos)
	var hex_tile := HexTileMap.add_by_pos(hex_pos, height)
	assert(hex_tile != null)

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
	print("Deleting everything!")

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
	threads_running = false

	# Empty queue
	to_generate_mutex.lock()
	to_generate_queue.clear()
	to_generate_mutex.unlock()

	# Post to the semaphore to unblock any waiting threads so they can exit
	to_generate_semaphore.post(num_threads * 10)

	for thread in threads:
		thread.wait_to_finish()
	print("MAIN: %d threads finished" % num_threads)

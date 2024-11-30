@tool # No static vars but actually runs in editor
extends Node3D
class_name MapGeneration

# Regeneration
var regenerate: bool = false
var last_regeneration_timestamp := 0.0
var max_regeneration_delay := 1.0

# Queues
var to_generate_queue: Array[int] = []
var to_generate_mutex: Mutex
var to_generate_semaphore: Semaphore

var generated_queue: Array[int] = []
var generated_queue_mutex: Mutex

# Threads
var threads: Array[Thread] = []
# 3-4 is sweet spot on my machine
var num_threads: int = 4
var threads_running: bool = true
var threads_running_mutex: Mutex
# Seems to make almost no difference in performance
var fetch_tiles_count := 1

# Generation Data. Distances are in tile-sizes, the formula takes in meters to convert
var tile_generation_distance_hex := HexConst.distance_m_to_hex(70)
var tile_deletion_distance_hex := HexConst.distance_m_to_hex(250)
@onready var camera_controller: CameraController = %Camera3D as CameraController
var generation_position: HexPos = HexPos.invalid()

# Testing
var t_start_benchmark: int
var benchmark_complete: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This is required for the headless LSP to work (since this script is a tool script)
	if OS.has_feature("Server"):
		num_threads = 0
		return

	# Init stuff
	to_generate_mutex = Mutex.new()
	to_generate_semaphore = Semaphore.new()
	generated_queue_mutex = Mutex.new()
	threads_running_mutex = Mutex.new()

	# Create thread
	print("MAIN: Starting %d threads with %d fetch_tiles_count" % [num_threads, fetch_tiles_count])
	threads.clear()
	for i in range(num_threads):
		threads.append(Thread.new())
		threads[i].start(thread_generation_loop_function)

	# Signals
	EventBus.Signal_HexConstChanged.connect(set_regenerate)

	# Start benchmark timer
	t_start_benchmark = Time.get_ticks_usec()


func _process(delta: float) -> void:
	# This is required for the headless LSP to work (since this script is a tool script)
	if OS.has_feature("Server"): return

	# Check if shutdown in process -> Dont queue anything new and join threads
	threads_running_mutex.lock()
	var should_exit: bool = !threads_running
	threads_running_mutex.unlock()

	if should_exit:
		if threads.is_empty():
			Util.print_multiline_banner("All threads finished, exiting game")
			get_tree().quit()
		else:
			join_threads()
		return # Dont queue anything new

	# Check map regeneration
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

	# Only for Testing / benchmarking
	if not benchmark_complete:
		var expected := HexPos.compute_num_tiles_in_range(tile_generation_distance_hex, true)
		if HexTileMap.get_size() >= expected:
			var t := (Time.get_ticks_usec() - t_start_benchmark) / 1000.0
			Util.print_only_banner()
			print("MAIN: Process took %4.0f ms to generate %d tiles (N=%d)" % [t, expected, tile_generation_distance_hex])
			print("MAIN: Thread count: %d, fetch_tiles_count: %d" % [num_threads, fetch_tiles_count])
			Util.print_only_banner()
			benchmark_complete = true


# Returns true if the player has moved and we need to regenerate
func update_generation_position() -> bool:
	# Base generation pos on player or camera if in editor
	var world_pos: Vector3

	if camera_controller != null and not Engine.is_editor_hint():
		world_pos = camera_controller.get_follow_point()
	else:
		world_pos = Util.get_global_cam_pos(self)

	# Transform to hexpos
	var hex_pos: HexPos = HexPos.xyz_to_hexpos_frac(world_pos).round()

	# Abort if hex-tile / field has not changed
	if hex_pos.equals(generation_position):
		return false

	# Update pos and return true
	generation_position = hex_pos
	return true


# Fetch all generated tile hashes, get the tile from the HexTileMap and add them to the scene
func fetch_and_add_all_generated_tiles() -> void:
	# MUTEX LOCK
	generated_queue_mutex.lock()
	var generated_queue_copy: Array[int] = generated_queue.duplicate()
	generated_queue.clear()
	generated_queue_mutex.unlock()
	# MUTEX UNLOCK

	for key: int in generated_queue_copy:
		var tile: HexTile = HexTileMap.get_by_hash(key)
		assert(tile != null)
		# Only place where tiles are added to the scene
		add_child(tile)


func remove_far_away_tiles() -> void:
	# No mutex needed here
	var child_count := get_child_count()

 	# Loop over all children in reverse order (to be able to modify the array)
	for i in range(child_count - 1, -1, -1):
		var tile: HexTile = get_child(i) as HexTile
		if is_instance_valid(tile) and not tile.is_queued_for_deletion():
			var distance := generation_position.distance_to(tile.hex_pos)
			if distance > tile_deletion_distance_hex:
				# This is the only place where tiles are removed
				HexTileMap.delete_by_pos(tile.hex_pos)
				tile.queue_free()


func queue_new_tiles_for_generation() -> void:
	var hashes_in_range: PackedInt32Array = generation_position.get_neighbours_in_range_as_hash(tile_generation_distance_hex, true)

	# Remove any hashes which are already presend in the map. No mutex needed here.
	# This might miss some tiles since they are added to the map after this check -> filter again after mutex lock
	var hashes_filtered: PackedInt32Array
	for key in hashes_in_range:
		if HexTileMap.get_by_hash(key) == null:
			hashes_filtered.push_back(key)

	# Early return if empty to avoid mutex lock completely
	if hashes_filtered.is_empty():
		return

	# MUTEX LOCK
	to_generate_mutex.lock()

	var num_queued := 0
	for key in hashes_filtered:
		# Filter again, this time with locked to_generate_mutex
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

	# Notify threads
	if num_queued > 0:
		to_generate_semaphore.post(num_queued)

####################################################################################################
# THREAD FUNCTION
####################################################################################################
func thread_generation_loop_function() -> void:
	# Overwrite thread_id (number from 0) with actual thread id
	var thread_id := OS.get_thread_caller_id()

	while true:
		# Wait for new data (also posted on exit signal)
		to_generate_semaphore.wait()

		# Exit if requested
		threads_running_mutex.lock()
		var should_exit: bool = not threads_running
		threads_running_mutex.unlock()
		if should_exit:
			print("THREAD %d: Exiting thread function" % thread_id)
			return

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
		generated_queue_mutex.lock()
		for i in range(keys.size()):
			generated_queue.push_back(keys[i])
		generated_queue_mutex.unlock()


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
	Util.print_multiline_banner("Regenerating map")
	self.regenerate = true

##############################
# Cleanup
##############################
func delete_everything() -> void:
	print("Deleting everything!")

	generated_queue_mutex.lock()
	generated_queue.clear()
	generated_queue_mutex.unlock()

	to_generate_mutex.lock()
	to_generate_queue.clear()
	to_generate_mutex.unlock()

	HexTileMap.clear_all()
	HexGeometryInputMap.clear_all()


##############################
# Shutdown
##############################
func shutdown_threads() -> void:
	# Signal exit
	threads_running_mutex.lock()
	threads_running = false
	threads_running_mutex.unlock()

	# Delete queue
	to_generate_mutex.lock()
	to_generate_queue.clear()
	to_generate_mutex.unlock()

	print("MAIN: Waiting for %d threads to finish..." % num_threads)


# Called repeatedly in _process to check if threads are finished
func join_threads() -> bool:
	if threads.size() == 0:
		print("MAIN: All %d threads finished" % num_threads)
		return true

	# Post to the semaphore to unblock any waiting threads so they can exit
	to_generate_semaphore.post(threads.size() * 10)

	var to_delete_idx: int = -1
	for i in range(threads.size()):
		# is_alive == false -> joins immediately
		if not threads[i].is_alive():
			threads[i].wait_to_finish()
			to_delete_idx = i
			break # delete only one per iteration

	# Actually delete finished
	if to_delete_idx != -1:
		var deleted_num: int = num_threads - threads.size()
		print("MAIN: Joined thead %d / %d" % [deleted_num, num_threads])
		threads.remove_at(to_delete_idx)

	return false


func _exit_tree() -> void:
	if not threads.is_empty():
		# This is only for when exiting through the editor
		Util.print_multiline_banner("MapGeneration cleaning up on _exit_tree")
		shutdown_threads()

		while not threads.is_empty():
			join_threads()
			await get_tree().create_timer(0.01).timeout

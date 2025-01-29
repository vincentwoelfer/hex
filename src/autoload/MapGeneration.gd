# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# Complete Map Regeneration
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
var fetch_chunks_count := 1

# Generation Data. Distances are in tile-sizes, the formula takes in meters to convert
var tile_generation_distance_hex := HexConst.distance_m_to_hex(50)
var tile_deletion_distance_hex := HexConst.distance_m_to_hex(100)
var generation_position: HexPos = HexPos.invalid()

# Testing
var t_start_benchmark: int
var benchmark_complete: bool = false

# Map generation happens arround this node. Must have function "get_map_generation_center_position() -> Vector3"
var generation_center_node: Node3D = null

# Called when the node enters the scene tree. Node, all children and parent (SceneTree) are ready at this point
func _ready() -> void:
	var active: bool = true
	# This is required for the headless LSP to work (since this script is a tool script)
	if OS.has_feature("Server"): active = false

	# Prevent map-generation in editor in other scenes
	# var scene: = get_tree().edited_scene_root
	# print(get_tree())
	# print(get_tree().current_scene)
	# print(get_tree().edited_scene_root)
	# print(scene)
	# print(scene.scene_file_path)
	# if scene and scene.scene_file_path != "res://scenes/MapGeneration.tscn":
	# 	active = false

	# Dont start threads if not active
	if not active:
		num_threads = 0
		return

	# Init stuff
	to_generate_mutex = Mutex.new()
	to_generate_semaphore = Semaphore.new()
	generated_queue_mutex = Mutex.new()
	threads_running_mutex = Mutex.new()

	# Create thread
	print("MAIN: Starting %d threads with %d fetch_chunks_count, chunk_size: %d" % [num_threads, fetch_chunks_count, HexConst.chunk_size])
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

	self.tick_check_map_regeneration()

	# Empty generated queue and add to scene, regardless of player position
	fetch_and_add_generated_tiles()

	# Add tiles near player to queue and delete far away
	var generation_position_changed := update_generation_position()
	if generation_position_changed:
		queue_new_tiles_for_generation()
		remove_far_away_tiles()

	# Only for Testing / benchmarking
	if not benchmark_complete:
		var expected_tiles := HexPos.compute_num_tiles_in_range(tile_generation_distance_hex, true)
		if HexTileMap.get_size() >= expected_tiles:
			var num_chunks := HexChunkMap.get_size()
			var t := (Time.get_ticks_usec() - t_start_benchmark) / 1000.0
			Util.print_only_banner()
			print("MAIN: Process took %4.0f ms to generate %d tiles in %d chunks (N=%d)" % [t, expected_tiles, num_chunks, tile_generation_distance_hex])
			print("MAIN: Thread count: %d, fetch_chunks_count: %d, chunk_size=%d" % [num_threads, fetch_chunks_count, HexConst.chunk_size])
			Util.print_only_banner()
			benchmark_complete = true


# Returns true if the player has moved and we need to regenerate
func update_generation_position() -> bool:
	# Base generation pos on player or camera if in editor
	var world_pos: Vector3

	if generation_center_node != null and generation_center_node.has_method("get_map_generation_center_position") and not Engine.is_editor_hint():
		@warning_ignore("UNSAFE_METHOD_ACCESS")
		world_pos = generation_center_node.get_map_generation_center_position()
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
func fetch_and_add_generated_tiles() -> void:
	# OLD code before chunking
	# MUTEX LOCK
	# Fetch ALL
	# generated_queue_mutex.lock()
	# var generated_queue_copy: Array[int] = generated_queue.duplicate()
	# generated_queue.clear()
	# generated_queue_mutex.unlock()

	# Fetch only one (because we have chunks now)
	generated_queue_mutex.lock()
	var generated_queue_copy: Array[int]
	if generated_queue.size() > 0:
		generated_queue_copy = [generated_queue.pop_front()]
	generated_queue_mutex.unlock()
	# MUTEX UNLOCK

	for key: int in generated_queue_copy:
		var chunk: HexChunk = HexChunkMap.get_by_hash(key)
		assert(chunk != null) # This should never happen
		if chunk != null:
			# Only place where tiles are added to the scene
			add_child(chunk)


func remove_far_away_tiles() -> void:
	# No mutex needed here
	var child_count := get_child_count()

 	# Loop over all children in reverse order (to be able to modify the array)
	for i in range(child_count - 1, -1, -1):
		var chunk: HexChunk = get_child(i) as HexChunk
		if is_instance_valid(chunk) and not chunk.is_queued_for_deletion():
			var distance := generation_position.distance_to(chunk.get_hex_pos_center())
			if distance > tile_deletion_distance_hex:
				# This is the only place where tiles are removed
				HexChunkMap.delete_by_pos(chunk.hex_pos_base)
				HexTileMap.delete_batch_by_poses(chunk.tile_poses)
				# This will also free the children of the chunk
				chunk.queue_free()


func queue_new_tiles_for_generation() -> void:
	var hashes_in_range_tiles: PackedInt32Array = generation_position.get_neighbours_in_range_as_hash(tile_generation_distance_hex, true)

	# TODO optimize this
	# Filter to only get hexposes which are chunk bases
	var hashes_in_range: PackedInt32Array
	for i in range(hashes_in_range_tiles.size()):
		var hex_pos: HexPos = HexPos.unhash(hashes_in_range_tiles[i])
		if hex_pos.is_chunk_base():
			hashes_in_range.push_back(hashes_in_range_tiles[i])

	# Remove any hashes which are already presend in the map. No mutex needed here.
	# This might miss some chunks since they are added to the map after this check -> filter again after mutex lock
	var hashes_filtered: PackedInt32Array
	for key in hashes_in_range:
		if HexChunkMap.get_by_hash(key) == null:
			hashes_filtered.push_back(key)

	# Early return if empty to avoid mutex lock completely
	if hashes_filtered.is_empty():
		return

	# MUTEX LOCK
	to_generate_mutex.lock()

	var num_queued := 0
	for key in hashes_filtered:
		# Filter again, this time with locked to_generate_mutex
		if HexChunkMap.get_by_hash(key) == null:
			# Queue if chunk is not already queued
			if not to_generate_queue.has(key):
				# Push front is less effective BUT preserves order. Godot has no fast FIFO container :(
				to_generate_queue.push_front(key)
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
	# Get actual thread id
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
		var chunk_positions: Array[HexPos] = []
		var chunks: Array[HexChunk] = []

		# Fetch tile hash to generate, remove from queue and already add to HexTileMap to prevent re-queueing
		# MUTEX LOCK
		to_generate_mutex.lock()

		# Fetch keys
		for i in range(fetch_chunks_count):
			# Fetch and pop key, save hex_pos and create empty tile for it
			var k: Variant = to_generate_queue.pop_back()
			if k == null:
				break

			keys.push_back(k)
			chunk_positions.push_back(HexPos.unhash(keys[i]))

			# Create chunk and add to map here already to prevent the main thread from re-queueing it again
			var new_chunk: HexChunk = HexChunkMap.add_by_pos(chunk_positions[i])
			chunks.push_back(new_chunk)

		to_generate_mutex.unlock()
		# MUTEX UNLOCK

		# Abort if no keys
		if keys.is_empty():
			continue

		# Generate chunks. This will generate the tiles itself which is the expensive part
		for i in range(keys.size()):
			chunks[i].generate()

		# Add to generated queue
		generated_queue_mutex.lock()
		for i in range(keys.size()):
			generated_queue.push_back(keys[i])
		generated_queue_mutex.unlock()


##############################
# Regeneration
##############################
func set_regenerate() -> void:
	self.regenerate = true


func tick_check_map_regeneration() -> void:
	var now := Time.get_unix_time_from_system()
	if self.regenerate and (now - last_regeneration_timestamp) > max_regeneration_delay:
		last_regeneration_timestamp = now
		self.regenerate = false
		Util.print_multiline_banner("Regenerating map")
		delete_everything()

##############################
# Cleanup
##############################
func delete_everything() -> void:
	print("Deleting everything!")

	generated_queue_mutex.lock()
	to_generate_mutex.lock()
	generated_queue.clear()
	
	HexTileMap.clear_all()
	HexChunkMap.clear_all()
	HexGeometryInputMap.clear_all()
	
	to_generate_queue.clear()
	to_generate_mutex.unlock()
	generated_queue_mutex.unlock()

	print('Done deleting everything!')
	
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


# This is only for when exiting through the editor
func _exit_tree() -> void:
	# This is only for in-editor -> return if not in editor.
	if not Engine.is_editor_hint():
		return

	delete_everything()

	if not threads.is_empty():
		Util.print_multiline_banner("MapGeneration cleaning up on _exit_tree")
		shutdown_threads()

		while not threads.is_empty():
			join_threads()
			# This fails if node not in tree (if scene was not opened on startup)
			await get_tree().create_timer(0.01).timeout

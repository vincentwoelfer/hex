@tool
extends Node3D

# Regeneration
var regenerate: bool = false
var last_regeneration_timestamp := 0.0
var max_regeneration_delay := 1.0

# Queues
# var to_generate_queue: Array[HexPos] = []
# var to_generate_mutex: Mutex = Mutex.new()
# var to_generate_semaphore: Semaphore = Semaphore.new()


# Threads
# ....


# Misc
var generation_dist_hex_tiles := 3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#delete_everything()

	# Signals
	EventBus.Signal_HexConstChanged.connect(set_regenerate)


func _process(delta: float) -> void:
	# Check regeneration
	if self.regenerate and (Time.get_unix_time_from_system() - last_regeneration_timestamp) > max_regeneration_delay:
		last_regeneration_timestamp = Time.get_unix_time_from_system()
		self.regenerate = false
		delete_everything()

	# Add tiles near player to queue
	var t_start := Time.get_ticks_msec()

	var camera_position: Vector3 = get_viewport().get_camera_3d().global_transform.origin
	var camera_hex_pos: HexPos = HexPos.xyz_to_hexpos_frac(camera_position).round()

	var coords_in_range := camera_hex_pos.get_all_coordinates_in_range(generation_dist_hex_tiles, true)
	var num_generated := 0
	for hex_pos in coords_in_range:
		# Add HexTile if missing
		var tile: HexTile = MapManager.map.get_hex_tile(hex_pos)
		if tile == null:
			create_empty_hex_tile(hex_pos)
			tile = MapManager.map.get_hex_tile(hex_pos)
			tile.generate()
			num_generated += 1

	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	if num_generated > 0:
		print("Generated %d tiles in %.3f sec" % [num_generated, t])
		MapManager.map.print_debug_stats()


# For STEP 1
func create_empty_hex_tile(hex_pos: HexPos) -> void:
	# Verify that this hex_pos does not contain a tile yet
	assert(MapManager.map.get_hex_tile(hex_pos) == null)

	var height: int = MapGenerationData.determine_height(hex_pos)
	var hex_tile := MapManager.map.add_hex_tile(hex_pos, height)

	# Add to Scene tree at correct position
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	hex_tile.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)

	# Add to the current scene
	add_child(hex_tile, true)


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
# add_child(instance, true)

# # ROCKS
# var instance_rocks := MeshInstance3D.new()
# st_combined = SurfaceTool.new()

# for hex_pos in coordinates:
# 	var tile: HexTile = MapManager.map.get_hex_tile(hex_pos)
# 	st_combined.append_from(tile.rocksMesh, 0, tile.global_transform)

# instance_rocks.set_mesh(st_combined.commit())
# const ROCKS_MATERIAL: Material = preload('res://assets/materials/rocks_material.tres')
# instance_rocks.material_override = ROCKS_MATERIAL
# add_child(instance_rocks, true)

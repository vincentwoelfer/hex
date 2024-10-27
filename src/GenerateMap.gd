@tool
extends Node3D

var height_noise: Noise = preload("res://assets/noise/TerrainHeightNoiseGenerator.tres")
var generate: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	generate_complete_map()

	# Signals
	EventBus.Signal_HexConstChanged.connect(set_generate)


func set_generate() -> void:
	self.generate = true


func _process(delta: float) -> void:
	if self.generate:
		self.generate = false
		generate_complete_map()


func generate_complete_map() -> void:
	# MAP GENERATION STEP 1
	# Create and instantiate empty hex-tiles, add as child and set world position
	# Only done ONCE and expects map to be empty
	MapManager.map.free_all()
	
	var coordinates := MapManager.get_all_hex_coordinates(MapManager.MAP_SIZE)
	for hex_pos in coordinates:
		var height: int = determine_height(hex_pos)
		create_empty_hex_tile(hex_pos, height)

	# MAP GENERATION STEP 2
	# Generate hex-tiles (= Geometry, Plants...). This is done by the hex tile and we only call it for every tile
	# This allows this to be parallelized later on
	generate_all_hex_tile_geometry()

	########################################################
	########################################################
	########################################################
	# TESTING - STEP 3 MERGE ALL TERRAIN
	# var instance := MeshInstance3D.new()
	# var st_combined: SurfaceTool = SurfaceTool.new()

	# for hex_pos in coordinates:
	# 	var tile :HexTile = MapManager.map.get_hex(hex_pos)
	# 	st_combined.append_from(tile.geometry.mesh, 0, tile.global_transform)

	# instance.set_mesh(st_combined.commit())
	# const DEFAULT_GEOM_MATERIAL: Material = preload('res://assets/materials/default_geom_material.tres')
	# instance.material_override = DEFAULT_GEOM_MATERIAL
	# add_child(instance, true)


# For STEP 1
func create_empty_hex_tile(hex_pos: HexPos, height: int) -> void:
	# Verify that this hex_pos does not contain a tile yet
	assert(MapManager.map.get_hex(hex_pos) == null)

	var hex_tile := MapManager.map.add_hex(hex_pos, height)

	# Add to Scene tree at correct position
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	hex_tile.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)

	# Add to the current scene
	add_child(hex_tile, true)


# STEP 2
func generate_all_hex_tile_geometry() -> void:
	var t_start := Time.get_ticks_msec()

	# Get coordinates
	var coordinates := MapManager.get_all_hex_coordinates(MapManager.MAP_SIZE)
	for hex_pos in coordinates:
		MapManager.map.get_hex(hex_pos).generate()

	# Finish
	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	print("Generated %d hex tiles in %.3f sec" % [coordinates.size(), t])


func determine_height(hex_pos: HexPos) -> int:
	var pos2D: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	var noise: float = height_noise.get_noise_2d(pos2D.x, pos2D.y)
	noise = remap(noise, -1.0, 1.0, 0.0, 1.0)

	var height_f: float = remap(noise, 0.0, 1.0, MapManager.MIN_HEIGHT, MapManager.MAX_HEIGHT)
	var height: int = roundf(height_f) as int

	# Modify further (away from noise map)	
	height = clampi(height, MapManager.MIN_HEIGHT + 4, MapManager.MAX_HEIGHT) + 1

	if height > MapManager.MAX_HEIGHT * 0.85:
		height += 6

	# Border
	if hex_pos.magnitude() == MapManager.MAP_SIZE:
		height = MapManager.OCEAN_HEIGHT

	return height

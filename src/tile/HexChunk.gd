@tool
class_name HexChunk
extends Node3D

######################################################
# Parent / Struct class holding everything a hex tile can be/posess
######################################################

# Core Variables
var hex_pos_base: HexPos

# Visual Representation
# var terrainMesh: MeshInstance3D
# var terrainOccluderInstance: OccluderInstance3D
# var plant: SurfacePlant
# var rocks: MeshInstance3D

# Collision
# var collisionBody: StaticBody3D

# Model here or through children???
var tiles: Array[HexTile] = []

# Does not much, only actual constructor
func _init(hex_pos_: HexPos) -> void:
	assert(hex_pos_.is_chunk_base())
	self.hex_pos_base = hex_pos_
	if self.hex_pos_base != null:
		self.name = 'HexChunk' + hex_pos_base._to_string()
	else:
		self.name = 'HexChunk-Invalid'

	# Set position of chunk in world
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos_base)
	self.position = Vector3(world_pos.x, 0.0, world_pos.y)

	# self.terrainMesh = null
	# self.terrainOccluderInstance = null
	# self.plant = null
	# self.rocks = null
	# self.collisionBody = null

func generate() -> void:
	# Free previous tiles
	for c in self.get_children():
		c.free()

	# Generate new tiles
	var tile_poses: Array[HexPos] = self.hex_pos_base.get_chunk_tiles()
	for hex_pos_tile in tile_poses:
		# Create new tile
		var height: int = MapGenerationData.determine_height(hex_pos_tile)
		var tile := HexTile.new(hex_pos_tile, height)
		tiles.append(tile)

		# Generate tile
		var geometry_input := HexGeometryInputMap.create_complete_hex_geometry_input(hex_pos_tile)
		tile.generate(geometry_input)
		add_child(tile)

	# Add tiles to map as batch
	HexTileMap.add_initialized_tiles_batch(tiles)

	# Color Chunk in same color for debugging

	# Add debug color overlay for tiles
	if DebugSettings.use_chunk_colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = Colors.randColorNoExtreme()
		for tile in tiles:
			tile.terrainMesh.material_override = material
		

func _ready() -> void:
	pass
	# Signals
	# EventBus.Signal_TooglePerTileUi.connect(toogleTileUi)
	# EventBus.Signal_WorldStep.connect(processWorldStep)
		

# func addRocks(sampler: PolygonSurfaceSampler) -> ArrayMesh:
# 	if not sampler.is_valid():
# 		return null

# 	var rock_density_per_square_meter: float = 0.25
# 	# Standard deviation = x means:
# 	# 66% of samples are within [-x, x] of the mean
# 	# 96% of samples are within [-2x, 2x] of the mean
# 	var num_rocks: int = round(randfn(rock_density_per_square_meter, rock_density_per_square_meter)) * sampler.get_total_area()

# 	if num_rocks <= 0:
# 		return null

# 	var st_combined: SurfaceTool = SurfaceTool.new()
# 	for i in range(num_rocks):
# 		var t: Transform3D = sampler.get_random_point_transform()
# 		t = t.rotated_local(Vector3.UP, randf_range(0.0, TAU))

# 		# Random huge rock
# 		if randf() <= 0.05:
# 			t = t.scaled_local(Vector3.ONE * randf_range(6.0, 8.0))
# 			t = t.translated_local(Vector3.UP * -0.1) # Move down a bit

# 		var mesh: Mesh = ResLoader.basic_rocks_meshes.pick_random()
# 		st_combined.append_from(mesh, 0, t)
# 	return st_combined.commit()


# func _process(delta: float) -> void:
# 	if label != null:
# 		label.update_label_position()


func get_hex_pos_center() -> HexPos:
	if tiles.is_empty():
		return hex_pos_base

	# TODO test this
	var front_frac: HexPosFrac = tiles[0].hex_pos.as_frac()
	var back_frac: HexPosFrac = tiles[tiles.size() - 1].hex_pos.as_frac()
	var center_frac: HexPosFrac = front_frac.add(back_frac).scale(0.5)
	return center_frac.round()


func is_valid() -> bool:
	return hex_pos_base != null

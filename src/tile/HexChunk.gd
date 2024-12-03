@tool
class_name HexChunk
extends Node3D

######################################################
# Parent / Struct class holding everything a hex chunk can be/posess
######################################################

# Core Variables
var hex_pos_base: HexPos

# Visual Representation
var terrainMesh: MeshInstance3D
# var terrainOccluderInstance: OccluderInstance3D
# var plant: SurfacePlant
# var rocks: MeshInstance3D

# Collision
# var collisionBody: StaticBody3D


# Tiles
var tile_poses: Array[HexPos] = []
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


func generate() -> void:
	# Free previous tiles
	tiles.clear()
	tile_poses.clear()
	for c in self.get_children():
		c.free()

	# Generate new tiles
	tile_poses = hex_pos_base.get_chunk_tile_positions()
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
	assert(tiles.size() == pow(HexConst.chunk_size, 2))
	HexTileMap.add_initialized_tiles_batch(tiles)

	##############################
	# Merge components from tiles
	##############################

	# Terrain Mesh
	var triangle_mesh_tool := TriangleMeshTool.new()
	# TODO THIs modifies the triangles so the modification does not need to happen again below. Fix this?
	for tile: HexTile in tiles:
		triangle_mesh_tool.add_triangle_list(tile.geometry.triangles, tile.position)

	terrainMesh = MeshInstance3D.new()
	terrainMesh.name = "terrain"
	terrainMesh.mesh = triangle_mesh_tool.commit()
	terrainMesh.material_override = ResLoader.DEFAULT_TERRAIN_MAT
	add_child(terrainMesh)

	# TODO this is only a quick version
	#  surface samplers
	var triangles: Array[Triangle] = []
	for tile: HexTile in tiles:
		for tri: Triangle in tile.geometry.triangles:
			#triangles.append(Triangle.new(tri.a + tile.position, tri.b + tile.position, tri.c + tile.position))
			triangles.append(tri)

	var sampler := PolygonSurfaceSampler.new(triangles).filter_max_incline(40).finalize()

	if sampler.is_valid():
		# GRASS
		if DebugSettings.enable_grass:
			var plant := SurfacePlant.new()
			plant.name = "Grass"
			plant.populate_multimesh(sampler)
			add_child(plant)

	# Add debug color overlay for tiles
	if DebugSettings.use_chunk_colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = Colors.randColorNoExtreme()
		terrainMesh.material_override = material
		

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

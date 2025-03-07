@tool
class_name HexChunk
extends Node3D

######################################################
# Parent / Struct class holding everything a hex chunk can be/posess
######################################################

# Core Variables
var chunk_hex_pos: HexPos

var tile_poses: Array[HexPos] = []
var tiles: Array[HexTile] = []

# Visual/Phyiscal Components
var terrain_mesh: MeshInstance3D
var collision_static_body: StaticBody3D

var samplerAll: PolygonSurfaceSampler
var samplerHorizontal: PolygonSurfaceSampler
var samplerVertical: PolygonSurfaceSampler

var grass: SurfacePlant
var rocks: MeshInstance3D


# Does not much, only actual constructor
func _init(chunk_hex_pos_: HexPos) -> void:
	assert(chunk_hex_pos_.is_chunk_base())
	self.chunk_hex_pos = chunk_hex_pos_
	if self.chunk_hex_pos != null:
		self.name = 'HexChunk' + chunk_hex_pos._to_string()
	else:
		self.name = 'HexChunk-Invalid'

	# Set position of chunk in world
	var world_pos: Vector2 = HexPos.hexpos_to_xy(chunk_hex_pos)
	self.position = Vector3(world_pos.x, 0.0, world_pos.y)


func generate() -> void:
	#########################################
	# Free previous tiles
	#########################################
	tiles.clear()
	tile_poses.clear()
	for c in self.get_children():
		c.free()

	#########################################
	# Generate new tiles
	#########################################
	tile_poses = chunk_hex_pos.get_chunk_tile_positions()
	for tile_hex_pos in tile_poses:
		# Create new tile
		var height: int = MapGenerationData.determine_height(tile_hex_pos)
		var tile := HexTile.new(tile_hex_pos, height)
		tiles.append(tile)

		# Generate tile
		var geometry_input := HexGeometryInputMap.create_complete_hex_geometry_input(tile_hex_pos)
		tile.generate(geometry_input)

	# Verify
	assert(tiles.size() == pow(HexConst.CHUNK_SIZE, 2))
	assert(tiles.size() == tile_poses.size())

	# Add tiles to map as batch
	HexTileMap.add_initialized_tiles_batch(tiles)

	#########################################
	# Merge triangles and faces from all tiles
	#########################################
	var geometry_merger := HexGeometryMerger.new()
	for tile: HexTile in tiles:
		geometry_merger.add_triangles(tile.geometry.triangles, tile.position)

	#########################################
	# Terrain
	#########################################
	terrain_mesh = MeshInstance3D.new()
	terrain_mesh.name = "terrain"
	terrain_mesh.mesh = geometry_merger.generate_mesh()
	terrain_mesh.material_override = ResLoader.DEFAULT_TERRAIN_MAT
	add_child(terrain_mesh)

	# Add debug color overlay for tiles
	if DebugSettings.use_chunk_colors:
		var material := StandardMaterial3D.new()
		material.albedo_color = Colors.randColorNoExtreme()
		terrain_mesh.material_override = material

	#########################################
	# Polygon Surface Samplers
	#########################################
	self.samplerAll = PolygonSurfaceSampler.new(geometry_merger.triangles).finalize()
	self.samplerHorizontal = PolygonSurfaceSampler.new(geometry_merger.triangles).filter_max_incline(45).finalize()
	self.samplerVertical = PolygonSurfaceSampler.new(geometry_merger.triangles).filter_min_incline(45).finalize()

	#########################################
	# Collision
	#########################################
	var polygon_shape := ConcavePolygonShape3D.new()
	polygon_shape.set_faces(geometry_merger.generate_faces())

	# Generate static body
	collision_static_body = StaticBody3D.new()

	if DebugSettings.enable_terrain_collision_visualizations:
		# Create propper collision shape with visualizations
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = polygon_shape
		collision_shape.debug_fill = false
		collision_static_body.add_child(collision_shape)
	else:
		# Use physics server / shape owner api
		var owner_id := collision_static_body.create_shape_owner(self)
		collision_static_body.shape_owner_add_shape(owner_id, polygon_shape)

	add_child(collision_static_body)

	#########################################
	# Grass / Rocks
	#########################################
	if samplerHorizontal.is_valid():
		# GRASS
		if DebugSettings.enable_grass:
			grass = SurfacePlant.new()
			grass.name = "Grass"
			grass.populate_multimesh(samplerHorizontal)
			add_child(grass)

		# ROCKS
		if DebugSettings.enable_rocks:
			var rocksMesh := generate_rocks_mesh(samplerHorizontal)
			if rocksMesh != null:
				rocks = MeshInstance3D.new()
				rocks.name = "Rocks"
				rocks.material_override = ResLoader.ROCKS_MAT
				rocks.mesh = rocksMesh
				add_child(rocks)


func get_hex_pos_center() -> HexPos:
	if tiles.is_empty():
		return chunk_hex_pos

	var front_frac: HexPosFrac = tiles[0].hex_pos.as_frac()
	var back_frac: HexPosFrac = tiles[tiles.size() - 1].hex_pos.as_frac()
	var center_frac: HexPosFrac = front_frac.add(back_frac).scale(0.5)
	return center_frac.round()


func is_valid() -> bool:
	return chunk_hex_pos != null


func generate_rocks_mesh(sampler: PolygonSurfaceSampler) -> ArrayMesh:
	if not sampler.is_valid():
		return null

	var rock_density_per_square_meter: float = 0.15
	# Standard deviation = x means:
	# 66% of samples are within [-x, x] of the mean
	# 96% of samples are within [-2x, 2x] of the mean
	var num_rocks: int = round(randfn(rock_density_per_square_meter, rock_density_per_square_meter) * sampler.get_total_area())

	if num_rocks <= 0 or randf() <= 0.3:
		return null

	var st_combined: SurfaceTool = SurfaceTool.new()
	for i in range(num_rocks):
		var t: Transform3D = sampler.get_random_point_transform()
		t = t.rotated_local(Vector3.UP, randf_range(0.0, TAU))

		# Random huge rock
		if randf() <= 0.05:
			t = t.scaled_local(Vector3.ONE * randf_range(5.0, 7.0))
			t = t.translated_local(Vector3.UP * -0.1) # Move down a bit

		var mesh: Mesh = ResLoader.basic_rocks_meshes.pick_random()
		st_combined.append_from(mesh, 0, t)
	return st_combined.commit()

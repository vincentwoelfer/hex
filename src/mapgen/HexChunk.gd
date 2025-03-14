@tool
class_name HexChunk
extends Node3D

######################################################
# Parent / Struct class holding everything a hex chunk can be/posess
######################################################

# Core Variables
var chunk_hex_pos: HexPos
var chunk_aabb: AABB

var tile_poses: Array[HexPos] = []
var tiles: Array[HexTile] = []

# Visual/Phyiscal Components
var terrain_mesh: MeshInstance3D
var terrain_collision: StaticBody3D

var samplerAll: PolygonSurfaceSampler
var samplerHorizontal: PolygonSurfaceSampler
var samplerVertical: PolygonSurfaceSampler

var grass: SurfacePlant
var rocks: MeshInstance3D
var rocks_collision: StaticBody3D

# Navigation
var nav_source_geometry_data: NavigationMeshSourceGeometryData3D
var nav_mesh: NavigationMesh
var nav_region: NavigationRegion3D


# Does not much, only actual constructor
func _init(chunk_hex_pos_: HexPos) -> void:
	assert(chunk_hex_pos_.is_chunk_base())
	self.chunk_hex_pos = chunk_hex_pos_
	if self.chunk_hex_pos != null:
		self.name = 'HexChunk' + chunk_hex_pos._to_string()
	else:
		self.name = 'HexChunk-Invalid'

	# Set position of chunk in world. y = 0 because height is contained in tile positions
	var world_pos: Vector2 = HexPos.hexpos_to_xy(chunk_hex_pos)
	self.position = Vector3(world_pos.x, 0.0, world_pos.y)
	add_to_group("chunks")


func _enter_tree() -> void:
	self.chunk_aabb = calculate_aabb()
	# var col: Color = Colors.randColorNoExtreme()
	# col.a = 0.3
	# DebugShapes3D.spawn_visible_aabb(chunk_aabb, col, self)

	# TODO wait efficiently until all neighbouring chunks are loaded
	await get_tree().create_timer(3.0).timeout
	parse_source_geometry_data.call_deferred()


func parse_source_geometry_data() -> void:
	nav_source_geometry_data = NavigationMeshSourceGeometryData3D.new()

	var parse_settings: NavigationMesh = NavigationMesh.new()
	parse_settings.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	parse_settings.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	parse_settings.geometry_source_group_name = "chunks"

	# TODO include colliders from 6 neighbouring chunks

	NavigationServer3D.parse_source_geometry_data(parse_settings, nav_source_geometry_data, self, on_parsing_done)


func on_parsing_done() -> void:
	# Create new nav-mesh with parameters
	nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.cell_size = HexConst.nav_cell_size
	nav_mesh.cell_height = HexConst.nav_cell_size
	nav_mesh.agent_radius = HexConst.nav_agent_radius

	# Nav-Mesh baking settings regardin geometry
	var baking_border := 1.5
	nav_mesh.filter_baking_aabb = self.chunk_aabb.grow(baking_border)
	nav_mesh.border_size = baking_border

	# nav_mesh.edge_max_length = 1.0
	# nav_mesh.filter_ledge_spans = false
	# nav_mesh.edge_max_error = 1.0


	# Bake the navigation mesh on a thread with the source geometry data.
	NavigationServer3D.bake_from_source_geometry_data_async(
		nav_mesh,
		nav_source_geometry_data,
		on_baking_done
	)


func on_baking_done() -> void:
	# Snap vertex positions to avoid most rasterization issues with float precision.
	# var navmesh_vertices: PackedVector3Array = nav_mesh.vertices
	# for i in navmesh_vertices.size():
	# 	var vertex: Vector3 = navmesh_vertices[i]
	# 	navmesh_vertices[i] = vertex.snappedf(HexConst.nav_cell_size)
	# nav_mesh.vertices = navmesh_vertices

	# Create a new navigation region for the navigation mesh.
	nav_region = NavigationRegion3D.new()

	nav_region.navigation_mesh = nav_mesh
	nav_region.enabled = true
	add_child(nav_region)

	# Update the region with the updated navigation mesh.
	# NavigationServer3D.region_set_navigation_mesh(nav_region_rid, self.nav_mesh)
	# Enable the region and set it to the default navigation map.
	# NavigationServer3D.region_set_enabled(nav_region_rid, true)
	# NavigationServer3D.region_set_map(nav_region_rid, get_world_3d().get_navigation_map())

	# 
	
################################################################################
################################################################################
################################################################################

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
	terrain_collision = StaticBody3D.new()

	if DebugSettings.enable_terrain_collision_visualizations:
		# Create propper collision shape with visualizations
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = polygon_shape
		collision_shape.debug_fill = false
		terrain_collision.add_child(collision_shape)
	else:
		# Use physics server / shape owner api
		var owner_id := terrain_collision.create_shape_owner(self)
		terrain_collision.shape_owner_add_shape(owner_id, polygon_shape)

	add_child(terrain_collision)

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

				# Collision
				rocks_collision = StaticBody3D.new()
				var rocks_collision_shape := CollisionShape3D.new()
				rocks_collision_shape.shape = generate_collision_shape_from_array_mesh(rocksMesh)
				rocks_collision_shape.debug_fill = false
				terrain_collision.add_child(rocks_collision_shape)
				add_child(rocks_collision)


func get_hex_pos_center() -> HexPos:
	if tiles.is_empty():
		return chunk_hex_pos

	var front_frac: HexPosFrac = tiles[0].hex_pos.as_frac()
	var back_frac: HexPosFrac = tiles[tiles.size() - 1].hex_pos.as_frac()
	var center_frac: HexPosFrac = front_frac.add(back_frac).scale(0.5)
	return center_frac.round()


func is_valid() -> bool:
	return chunk_hex_pos != null


func generate_collision_shape_from_array_mesh(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var polygon_shape := ConcavePolygonShape3D.new()
	polygon_shape.set_faces(mesh.get_faces())
	return polygon_shape


enum RockType {SMALL, MEDIUM, LARGE}
func generate_rocks_mesh(sampler: PolygonSurfaceSampler) -> ArrayMesh:
	if not sampler.is_valid():
		return null

	# Standard deviation = x means:
	# 66% of samples are within [-x, x] of the mean
	# 96% of samples are within [-2x, 2x] of the mean
	var avg_rock_density_per_square_meter: float = 0.011
	var num_rocks: int = round(randfn(avg_rock_density_per_square_meter, avg_rock_density_per_square_meter) * sampler.get_total_area())

	if num_rocks <= 0 or randf() <= 0.35:
		return null

	var st_combined: SurfaceTool = SurfaceTool.new()
	for i in range(num_rocks):
		var t: Transform3D = sampler.get_random_point_transform()
		t = t.rotated_local(Vector3.UP, randf_range(0.0, TAU))

		var mesh: Mesh = ResLoader.basic_rocks_meshes.pick_random()
		var size: Vector3 = mesh.get_aabb().size
		var max_mesh_dim: float = max(size.x, size.y, size.z)

		var rock_type: RockType = RockType.MEDIUM
		var r := randf()
		if r <= 0.07:
			rock_type = RockType.LARGE

		if rock_type == RockType.LARGE:
			var height := randf_range(5.0, 10.0)
			t = t.scaled_local(Vector3.ONE * (height / max_mesh_dim))

		elif rock_type == RockType.MEDIUM:
			var height := randf_range(1.0, 2.5)
			t = t.scaled_local(Vector3.ONE * (height / max_mesh_dim))

		# elif rock_type == RockType.SMALL:
		# 	var max_height := randf_range(0.1, 0.15)
		# 	t = t.scaled_local(Vector3.ONE * (max_height / mesh_height))

		st_combined.append_from(mesh, 0, t)
	return st_combined.commit()


## Returns [average_height, height_range]
func find_height_min_max_for_tiles() -> Array[float]:
	var min_height: float = 1000
	var max_height: float = -1000
	for tile: HexTile in tiles:
		min_height = min(min_height, tile.height * HexConst.height)
		max_height = max(max_height, tile.height * HexConst.height)

	var avg := (min_height + max_height) / 2.0
	var span := max_height - min_height
	return [avg - 0.5, span + 1.0]


func calculate_aabb() -> AABB:
	var height_info := find_height_min_max_for_tiles()

	var first_tile_pos := tiles[0].position
	var last_tile_pos := tiles[tiles.size() - 1].position

	var center: Vector3 = (first_tile_pos + last_tile_pos) / 2.0
	center.y = height_info[0]

	var dimensions: Vector3 = (last_tile_pos - first_tile_pos).abs()
	dimensions.y = height_info[1]

	# Exctend dimensions to match rectangular grid
	# X is indepentent of chunk size
	dimensions.x += (HexConst.outer_radius * 0.75) * 2.0
	# Z is dependent on chunk size (TODO fix for chunk-size != 4)
	dimensions.z -= (HexConst.outer_radius_interior_circle() * 0.5) * 2.0

	return AABB(center - dimensions / 2.0, dimensions)

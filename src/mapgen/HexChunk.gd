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
var rocks: ScatteredRocks

# Navigation
var nav_source_geometry_data: NavigationMeshSourceGeometryData3D
var nav_mesh: NavigationMesh
var nav_region: NavigationRegion3D

# Logic to wait for all neighbours to be loaded
var missing_nav_chunk_neighbours: Array[HexPos] = []
var missing_nav_chunk_timer: Timer


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
	
	# On start all are missing
	missing_nav_chunk_neighbours = self.chunk_hex_pos.get_chunk_navigation_neighbours()


func _ready() -> void:
	# Add to group for navigation mesh parsing - This also communicates to other chunks that
	# this chunk is loaded and neighbouring chunks can use it for generating nav-mesh collision data.
	add_to_group(HexConst.NAV_CHUNKS_GROUP_NAME)

	self.chunk_aabb = calculate_chunk_navigation_aabb()

	# Start neighour check timer
	missing_nav_chunk_timer = Timer.new()
	missing_nav_chunk_timer.set_wait_time(0.5)
	missing_nav_chunk_timer.set_one_shot(false)
	missing_nav_chunk_timer.autostart = true
	missing_nav_chunk_timer.timeout.connect(_update_missing_nav_chunk_neighbours)
	add_child(missing_nav_chunk_timer)


func _update_missing_nav_chunk_neighbours() -> void:
	var all_chunks: Array[Node] = get_tree().get_nodes_in_group(HexConst.NAV_CHUNKS_GROUP_NAME)
	var all_chunks_poses: Array[HexPos] = []
	all_chunks_poses.assign(all_chunks.map(func(chunk: Node) -> HexPos: return (chunk as HexChunk).chunk_hex_pos))
	missing_nav_chunk_neighbours = missing_nav_chunk_neighbours.filter(
		func(hex_pos: HexPos) -> bool:
			return not all_chunks_poses.any(func(p: HexPos) -> bool: return p.equals(hex_pos))
	)

	if missing_nav_chunk_neighbours.is_empty():
		missing_nav_chunk_timer.queue_free()
		missing_nav_chunk_timer = null
		parse_source_geometry_data.call_deferred()


func parse_source_geometry_data() -> void:
	nav_source_geometry_data = NavigationMeshSourceGeometryData3D.new()

	var parse_settings: NavigationMesh = NavigationMesh.new()
	parse_settings.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	parse_settings.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	parse_settings.geometry_source_group_name = HexConst.NAV_CHUNKS_GROUP_NAME

	# TODO Optimization: Maybe create groups and only include colliders from 6 neighbouring chunks.
	# Using whole tree works fine for now
	NavigationServer3D.parse_source_geometry_data(parse_settings, nav_source_geometry_data, self, on_parsing_done)


func on_parsing_done() -> void:
	# Create new nav-mesh with parameters
	nav_mesh = NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.sample_partition_type = NavigationMesh.SAMPLE_PARTITION_MONOTONE
	nav_mesh.cell_size = HexConst.nav_cell_size
	nav_mesh.cell_height = HexConst.nav_cell_size
	nav_mesh.agent_radius = HexConst.nav_agent_radius

	nav_mesh.agent_max_slope = 50.0 # default 45
	nav_mesh.agent_max_climb = snappedf(0.125, HexConst.nav_cell_size) # default = 0.25

	# Nav-Mesh baking settings regardin geometry
	var baking_border := snappedf(1.5, HexConst.nav_cell_size)
	nav_mesh.filter_baking_aabb = self.chunk_aabb.grow(baking_border)

	# Keep nav-meshes smaller than the actual geometry by having an artificial border of one cell size
	nav_mesh.border_size = baking_border + HexConst.nav_cell_size

	nav_mesh.detail_sample_distance = 6.0 # default = 6.0
	nav_mesh.detail_sample_max_error = 1.0 # default = 1.0

	nav_mesh.edge_max_error = 1.5 # default = 1.3

	nav_mesh.region_min_size = 40.0 # The minimum size of a region for it to be created, default = 2
	nav_mesh.region_merge_size = 100.0 # smaller than this will be merged, default = 20


	# Bake the navigation mesh on a thread with the source geometry data.
	NavigationServer3D.bake_from_source_geometry_data_async(
		nav_mesh,
		nav_source_geometry_data,
		on_baking_done
	)


func is_outlier_vertex(v: Vector3, eps: float = 0.1) -> bool:
	# forumlar x: -1.875 + n * 15.0
	# forumlar z: 1.08253192901611 + n * 17.3749990463
	var snapped_x := -1.875 + snappedf(v.x, 15.0)
	var snapped_z := 1.08253192901611 + snappedf(v.z, 17.3749990463)

	return (abs(v.x - snapped_x) <= eps and not is_equal_approx(v.x, snapped_x)) or \
		   (abs(v.z - snapped_z) <= eps and not is_equal_approx(v.z, snapped_z))

func correct_outliert_vertex(v: Vector3, eps: float = 0.1) -> Vector3:
	var old := v
	var snapped_x := -1.875 + snappedf(v.x, 15.0)
	var snapped_z := 1.08253192901611 + snappedf(v.z, 17.3749990463)

	if abs(v.x - snapped_x) <= eps:
		v.x = snapped_x
	if abs(v.z - snapped_z) <= eps:
		v.z = snapped_z

	print("Corrected: ", old, " -> ", v)
	return v


func on_baking_done() -> void:
	nav_region = NavigationRegion3D.new()

	# Post-process vertices	
	# var verts := nav_mesh.get_vertices()
	# for i in range(verts.size()):
	# 	if is_outlier_vertex(verts[i]):
	# 		# MODIFY
	# 		verts[i] = correct_outliert_vertex(verts[i])

	# 		# spawn debug sphere
	# 		var instance := MeshInstance3D.new()
	# 		instance.mesh = DebugShapes3D.create_sphere_mesh(0.25, Color.PURPLE)
	# 		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 		instance.position = verts[i] + Vector3(0, 0.8, 0)
	# 		self.add_child(instance)
	
	# for v in verts:
	# 	if is_outlier_vertex(v):
	# 		print("DSFSÄDPÖFJÄSLÖDF ", v)
	# nav_mesh.set_vertices(verts)
	
	nav_region.navigation_mesh = nav_mesh
	nav_region.enabled = true
	add_child(nav_region)


## Generates the chunk, calls generate on all tiles. This is called in a separate thread
## and only constructs the chunk as a sub-scene, it doesnt access the main scene tree.
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
			rocks = ScatteredRocks.new(samplerHorizontal)
			rocks.name = "Rocks"
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


## Returns [average_height, height_range]
func find_height_min_max_for_tiles() -> Array[float]:
	var min_height: float = 1000
	var max_height: float = -1000
	for tile: HexTile in tiles:
		min_height = min(min_height, tile.height * HexConst.height)
		max_height = max(max_height, tile.height * HexConst.height)

	var avg := (min_height + max_height) / 2.0
	var span := max_height - min_height
	return [avg, span]


func calculate_chunk_navigation_aabb() -> AABB:
	var height_info := find_height_min_max_for_tiles()

	# Enlargen aabb on y-axis
	height_info[0] -= 1.0
	height_info[1] += 2.0

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

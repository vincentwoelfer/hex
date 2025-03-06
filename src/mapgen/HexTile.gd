@tool
class_name HexTile
extends Node3D

######################################################
# Parent / Struct class holding everything a hex tile can be/posess
######################################################

# Core Variables
var hex_pos: HexPos
var height: int

var geometry: HexGeometry


# Visual Representation
# var terrainMesh: MeshInstance3D = null
var terrainOccluderInstance: OccluderInstance3D = null
var plant: SurfacePlant = null # TODO must stay here for tick() (i guess).
var rocks: MeshInstance3D = null

# Collision
var collisionBody: StaticBody3D

# Does not much, only actual constructor
# Order is init() -> generate() -> ready()
func _init(hex_pos_: HexPos, height_: int) -> void:
	self.hex_pos = hex_pos_
	self.height = height_
	if self.hex_pos != null and self.hex_pos.is_valid():
		self.name = 'HexTile' + hex_pos._to_string()
	else:
		self.name = 'HexTile-Invalid'

	# Set position of tile (relative to parent chunk)
	var hex_pos_local := hex_pos.subtract(hex_pos.to_chunk_base())
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos_local)
	self.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)


func generate(geometry_input: HexGeometryInput) -> void:
	assert(geometry_input != null)
	assert(geometry_input.generation_stage == HexGeometryInput.GenerationStage.COMPLETE)
	
	# Delete old stuff
	for c in self.get_children():
		c.free()

	# Create geometry from geometry input
	geometry = HexGeometry.new(geometry_input)

	#########################################
	# Add / generate new stuff baes on new geometry
	#########################################	
	# Terrain mesh is created in chunk

	if DebugSettings.visualize_hex_input:
		geometry_input.create_debug_visualization(self)

	if self.height > 0:
		collisionBody = StaticBody3D.new()

		if DebugSettings.enable_terrain_collision_visualizations:
			# Create propper collision shape with visualizations
			var collision_shape := CollisionShape3D.new()
			collision_shape.shape = geometry.collision_shape
			collision_shape.debug_fill = false
			collisionBody.add_child(collision_shape)
		else:
			# Use physics server / shape owner api
			var owner_id := collisionBody.create_shape_owner(self)
			collisionBody.shape_owner_add_shape(owner_id, geometry.collision_shape)

		add_child(collisionBody)

		
	# Remaining steps (=placing stuff on tile) only if tile is a valid non-ocean tile with a horizontal sampler
	if self.height > 0 and geometry.samplerHorizontal.is_valid():
		# Add plants
		# if DebugSettings.enable_grass:
		# 	plant = SurfacePlant.new()
		# 	plant.name = "Grass"
		# 	plant.populate_multimesh(geometry.samplerHorizontal)
		# 	add_child(plant)
		# Add rocks
		if DebugSettings.enable_rocks:
			var rocksMesh := addRocks(geometry.samplerHorizontal)
			if rocksMesh != null:
				rocks = MeshInstance3D.new()
				rocks.name = "Rocks"
				rocks.material_override = ResLoader.ROCKS_MAT
				rocks.mesh = rocksMesh
				add_child(rocks)


func addRocks(sampler: PolygonSurfaceSampler) -> ArrayMesh:
	if not sampler.is_valid():
		return null

	var rock_density_per_square_meter: float = 0.25
	# Standard deviation = x means:
	# 66% of samples are within [-x, x] of the mean
	# 96% of samples are within [-2x, 2x] of the mean
	var num_rocks: int = round(randfn(rock_density_per_square_meter, rock_density_per_square_meter)) * sampler.get_total_area()

	if num_rocks <= 0:
		return null

	var st_combined: SurfaceTool = SurfaceTool.new()
	for i in range(num_rocks):
		var t: Transform3D = sampler.get_random_point_transform()
		t = t.rotated_local(Vector3.UP, randf_range(0.0, TAU))

		# Random huge rock
		if randf() <= 0.05:
			t = t.scaled_local(Vector3.ONE * randf_range(6.0, 8.0))
			t = t.translated_local(Vector3.UP * -0.1) # Move down a bit

		var mesh: Mesh = ResLoader.basic_rocks_meshes.pick_random()
		st_combined.append_from(mesh, 0, t)
	return st_combined.commit()


func is_valid() -> bool:
	return hex_pos != null

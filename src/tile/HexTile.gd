@tool
class_name HexTile
extends Node3D

######################################################
# Parent / Struct class holding everything a hex tile can be/posess
######################################################

const DEFAULT_TERRAIN_MAT: Material = preload('res://assets/materials/default_geom_material.tres')
const HIGHLIGHT_MAT: ShaderMaterial = preload('res://assets/materials/highlight_material.tres')
const ROCKS_MATERIAL: Material = preload('res://assets/materials/rocks_material.tres')

# Core Variables
var hex_pos: HexPos
var height: int

var params: HexTileParams
var label: HexTileLabel

# Visual Representation
var terrainMesh: MeshInstance3D
var terrainOccluderInstance: OccluderInstance3D
var plant: SurfacePlant
var rocks: MeshInstance3D

# Does not much, only actual constructor
func _init(hex_pos_: HexPos, height_: int) -> void:
	self.hex_pos = hex_pos_
	self.height = height_
	if self.hex_pos != null:
		self.name = 'HexTile' + hex_pos._to_string()
	else:
		self.name = 'HexTile-Invalid'

	self.plant = null
	self.rocks = null
	self.terrainMesh = null
	self.label = null
	self.params = HexTileParams.new() # Randomizes everything

	# TODO move to static place
	# Load Rocks - hardcoded numbers for now
	# for i in range(1, 10):
		# allAvailRockMeshes.append(load('res://assets/blender/objects/rock_collection_1_' + str(i) + '.res') as Mesh)
	

func _ready() -> void:
	if height > 0:
		label = HexTileLabel.new(params)
		label.set_label_world_pos(global_position)
		add_child(label)

	# Signals
	EventBus.Signal_TooglePerTileUi.connect(toogleTileUi)
	EventBus.Signal_WorldStep.connect(processWorldStep)
		

func generate(geometry_input: HexGeometryInput) -> void:
	assert(geometry_input != null)
	assert(geometry_input.generation_stage == HexGeometryInput.GenerationStage.COMPLETE)
	
	# Delete old stuff
	if terrainMesh != null:
		terrainMesh.free()
	if plant != null:
		plant.free()
	if rocks != null:
		rocks.free()

	# Does this solve everything?
	# For now, it deletes debug visuals
	for c in self.get_children():
		c.free()

	print("THREAD %d: XXX after free" % OS.get_thread_caller_id())

	# Create geometry from geometry input
	var geometry := HexGeometry.new(geometry_input)

	terrainMesh = MeshInstance3D.new()
	terrainMesh.name = "terrain"
	terrainMesh.mesh = geometry.mesh
	terrainMesh.material_override = DEFAULT_TERRAIN_MAT
	terrainMesh.material_overlay = HIGHLIGHT_MAT
	add_child(terrainMesh)

	print("THREAD %d: XXX after mesh" % OS.get_thread_caller_id())

	# Occluder
	if DebugSettings.generate_terrain_occluder:
		terrainOccluderInstance = OccluderInstance3D.new()
		terrainOccluderInstance.occluder = geometry.occluder
		add_child(terrainOccluderInstance)

	print("THREAD %d: XXX after occluder" % OS.get_thread_caller_id())

	if DebugSettings.visualize_hex_input:
		geometry_input.create_debug_visualization(self)

	print("THREAD %d: XXX after debug" % OS.get_thread_caller_id())

	# if DebugSettings.generate_collision and self.height > 0:
		#terrainMesh.create_convex_collision(true, false)
		#terrainMesh.create_multiple_convex_collisions(null)

		# TODO most accurate but slowest. Maybe manually simplify mesh beforehand?
		# terrainMesh.create_trimesh_collision()

	print("THREAD %d: XXX after collision" % OS.get_thread_caller_id())

	if self.height > 0 and geometry.samplerHorizontal.is_valid():
		# Add plants
		if DebugSettings.enable_grass:
			plant = SurfacePlant.new()
			plant.name = "Grass"
			plant.populate_multimesh(geometry.samplerHorizontal)
			add_child(plant)

		print("THREAD %d: XXX after grass" % OS.get_thread_caller_id())

		# Add rocks
		if DebugSettings.enable_rocks:
			var rocksMesh := addRocks(geometry.samplerHorizontal)
			if rocksMesh != null:
				rocks = MeshInstance3D.new()
				rocks.name = "Rocks"
				rocks.material_override = ROCKS_MATERIAL
				rocks.mesh = rocksMesh
				add_child(rocks)

	print("THREAD %d: XXX after rocks" % OS.get_thread_caller_id())


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


func processWorldStep() -> void:
	# For now just end data here, this is not good!
	if plant != null:
		plant.processWorldStep(params.humidity, params.shade, params.nutrition)


func toogleTileUi() -> void:
	if label != null:
		label.is_label_visible = !label.is_label_visible


func _process(delta: float) -> void:
	if label != null:
		label.update_label_position()


func is_valid() -> bool:
	return hex_pos != null

@tool
class_name HexTile
extends Node3D

######################################################
# Parent / Struct class holding everything a hex tile can be/posess
######################################################

const DEFAULT_TERRAIN_MAT: Material = preload('res://assets/materials/default_geom_material.tres')
const HIGHLIGHT_MAT: ShaderMaterial = preload('res://assets/materials/highlight_material.tres')
const ROCKS_MATERIAL: Material = preload('res://assets/materials/rocks_material.tres')

var allAvailRockMeshes: Array[ArrayMesh]

# Core Variables
var hex_pos: HexPos
var height: int

var params: HexTileParams
var label: HexTileLabel

# Visual Representation
var geometry: HexGeometry
var terrainMesh: MeshInstance3D
var terrainOccluderInstance: OccluderInstance3D
var plant: SurfacePlant
var rocks: MeshInstance3D

var rocksMesh: Mesh

# Does not much, only actual constructor
func _init(hex_pos_: HexPos, height_: int) -> void:
	self.hex_pos = hex_pos_
	self.height = height_
	if self.hex_pos != null:
		self.name = 'HexTile' + hex_pos._to_string()
	else:
		self.name = 'HexTile-Invalid'

	self.geometry = null
	self.plant = null
	self.rocks = null
	self.terrainMesh = null

	# Load Rocks - hardcoded numbers for now
	for i in range(1, 10):
		allAvailRockMeshes.append(load('res://assets/blender/objects/rock_collection_1_' + str(i) + '.res') as Mesh)

	self.params = HexTileParams.new() # Randomizes everything

	if height > 0:
		label = HexTileLabel.new(params)
		add_child(label)

	# Signals
	EventBus.Signal_TooglePerTileUi.connect(toogleTileUi)
	EventBus.Signal_WorldStep.connect(processWorldStep)


func _ready() -> void:
	if label != null:
		label.set_label_world_pos(global_position)


func generate() -> void:
	# Delete old stuff
	if geometry != null:
		geometry.free()
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

	# Add geometry - Get relevant parameters from Map (read-only)
	var hex_input := MapManager.create_complete_hex_geometry_input(hex_pos)
	geometry = HexGeometry.new(hex_input)
	terrainMesh = MeshInstance3D.new()
	terrainMesh.name = "terrain"
	terrainMesh.mesh = geometry.mesh
	terrainMesh.material_override = DEFAULT_TERRAIN_MAT
	terrainMesh.material_overlay = HIGHLIGHT_MAT
	#terrainMesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# terrainMesh.visibility_range_end = 100
	# terrainMesh.visibility_range_end_margin = 20
	add_child(terrainMesh, true)

	# Occluder
	terrainOccluderInstance = OccluderInstance3D.new()
	terrainOccluderInstance.occluder = geometry.occluder
	add_child(terrainOccluderInstance, true)

	if DebugSettings.visualize_hex_input:
		hex_input.create_debug_visualization(self)

	if DebugSettings.generate_collision and self.height > 0:
		terrainMesh.create_convex_collision(true, true)

	if self.height > 0 and geometry.samplerHorizontal.is_valid():
		# Add plants
		if DebugSettings.enable_grass:
			plant = SurfacePlant.new()
			plant.name = "Grass"
			plant.populate_multimesh(geometry.samplerHorizontal)
			add_child(plant, true)

		# Add rocks
		if DebugSettings.enable_rocks:
			rocksMesh = addRocks(geometry.samplerHorizontal)
			if rocksMesh != null:
				rocks = MeshInstance3D.new()
				rocks.name = "Rocks"
				rocks.material_override = ROCKS_MATERIAL
				rocks.mesh = rocksMesh
				add_child(rocks, true)


func addRocks(sampler: PolygonSurfaceSampler) -> ArrayMesh:
	if not sampler.is_valid():
		return null

	var st_combined: SurfaceTool = SurfaceTool.new()
	for i in range(1, 8):
		var t: Transform3D = sampler.get_random_point_transform()
		t = t.rotated_local(Vector3.UP, randf_range(0.0, TAU))

		# Random large rocks
		if randf() <= 0.05:
			t = t.scaled_local(Vector3.ONE * randf_range(6.0, 8.0))
			t = t.translated_local(Vector3.UP * -0.1) # Move down a bit

		var mesh: ArrayMesh = self.allAvailRockMeshes.pick_random()
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

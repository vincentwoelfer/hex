@tool
class_name HexTile
extends Node3D

######################################################
# Parent / Struct class holding everything a hex tile can be/posess
######################################################

#######################
####################### Feld:
# klima-bedingungen
# humidity
# Schatten  (wie viele Bäume)
# nutrition = wie gut wachsen sachen, erde vs sand/stein

# Was da drauf ist.
#

# Derived
# => aktuellen lichteinfall = Sonne - Schatten

#######################
####################### Allgemeint Wetter:
# Temperatur
# Aktueller Regenfall -> mehr wasser
# Aktuelle Sonne -> weniger wasser, mehr licht

const ROCKS_MATERIAL: Material = preload('res://assets/materials/rocks_material.tres')
var allAvailRockMeshes: Array[ArrayMesh]

# Core Variables
var hexpos: HexPos
var height: int

var params: HexTileParams
var label: HexTileLabel

# Visual Representation
var geometry: HexGeometry
var plant: SurfacePlant
var rocks: MeshInstance3D

# Does not much, only actual constructor
func _init(hexpos_: HexPos, height_: int) -> void:
	self.hexpos = hexpos_
	self.height = height_
	if self.hexpos != null:
		self.name = 'HexTile' + hexpos._to_string()
	else:
		self.name = 'HexTile-Invalid'

	self.geometry = null
	self.plant = null
	self.rocks = null

	# Load Rocks - hardcoded numbers for now
	for i in range(1, 10):
		allAvailRockMeshes.append(load('res://assets/blender/objects/rock_collection_1_' + str(i) + '.res') as ArrayMesh)

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
		#remove_child(geometry)
		geometry.free()
	if plant != null:
		#remove_child(plant)
		plant.free()
	if rocks != null:
		#remove_child(rocks)
		rocks.free()

	# Add geometry - Get relevant parameters from Map (read-only)
	geometry = HexGeometry.new(self.height, get_adjacent_hex())
	geometry.generate()
	add_child(geometry, true)

	if height > 0 and geometry.samplerHorizontal.is_valid():
		# Add plants
		if DebugSettings.enable_grass:
			plant = SurfacePlant.new()
			plant.name = "Grass"
			plant.populate_multimesh(geometry.samplerHorizontal)
			add_child(plant, true)

		# Add rocks
		if DebugSettings.enable_rocks:
			var rocksMesh := addRocks(geometry.samplerHorizontal)
			if rocksMesh != null:
				rocks = MeshInstance3D.new()
				rocks.name = "Rocks"
				rocks.material_override = ROCKS_MATERIAL
				rocks.mesh = rocksMesh
				add_child(rocks, true)


func get_adjacent_hex() -> Array[HexGeometry.AdjacentHex]:
	var adjacent_hex: Array[HexGeometry.AdjacentHex] = []
	for dir in range(6):
		var adjacent_tile := MapManager.map.get_hex(self.hexpos.get_neighbor(dir))
		var adjacent_height: int
		var adjacent_descr := ""

		if adjacent_tile != null:
			adjacent_height = adjacent_tile.height
			adjacent_descr = ""

		else:
			# If neighbour does not exists set height to same as own tile and mark transition
			adjacent_height = self.height
			adjacent_descr = 'invalid'

		adjacent_hex.push_back(HexGeometry.AdjacentHex.new(adjacent_height, adjacent_descr))
	return adjacent_hex
		

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
	return hexpos != null

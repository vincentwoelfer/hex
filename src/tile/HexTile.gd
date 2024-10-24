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

# Core Variables
var hexpos: HexPos
var height: int

var params: HexTileParams
var label: HexTileLabel

# Visual Representation
var geometry: HexGeometry
var plant: SurfacePlant

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
		remove_child(geometry)
		geometry.free()
	if plant != null:
		remove_child(plant)
		plant.free()

	# Get relevant parameters from Map (read-only)
	var adjacent_hex: Array[HexGeometry.AdjacentHex] = []
	for dir in range(6):
		var adjacent_height: int = MapManager.map.get_hex(self.hexpos.get_neighbor(dir)).height
		var adjacent_descr := ""

		# If neighbour does not exists set height to same as own tile and mark transition
		if adjacent_height == MapManager.INVALID_HEIGHT:
			adjacent_height = self.height
			adjacent_descr = 'invalid'

		adjacent_hex.push_back(HexGeometry.AdjacentHex.new(adjacent_height, adjacent_descr))

	# Add geometry
	geometry = HexGeometry.new(height, adjacent_hex)
	geometry.generate()
	add_child(geometry, true)

	# Add plants
	if height > 0 and geometry.samplerHorizontal.is_valid():
		plant = SurfacePlant.new()
		plant.populate_multimesh(geometry.samplerHorizontal)
		add_child(plant, true)


func processWorldStep() -> void:
	# For now just end data here, this is not good!
	if plant != null:
		plant.processWorldStep(params.humidity, params.shade, params.nutrition)


func toogleTileUi(is_label_visible: bool) -> void:
	if label != null:
		label.is_label_visible = is_label_visible


func _process(delta: float) -> void:
	if label != null:
		label.update_label_position()


func is_valid() -> bool:
	return hexpos != null

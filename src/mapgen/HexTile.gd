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
	
	# Create geometry from geometry input
	geometry = HexGeometry.new(geometry_input)

	if DebugSettings.visualize_hex_input:
		geometry_input.create_debug_visualization(self)


func is_valid() -> bool:
	return hex_pos != null

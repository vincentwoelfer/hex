extends Node
class_name PlayerData

# On Construction
var id: int
var display_name: String
var color: Color
var input_device: int

# On Runtime
var player_node: Node3D


# Called when initializing a new player
func _init(id_: int, display_name_: String, color_: Color, input_device_: int) -> void:
	id = id_
	display_name = display_name_
	color = color_
	input_device = input_device_

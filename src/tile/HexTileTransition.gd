@tool
class_name HexTileTransition

var height_other: int
var type: String # unused for now

func _init(height_other_: int, type_: String) -> void:
    self.height_other = height_other_
    self.type = type_

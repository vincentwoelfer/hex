@tool
class_name HexTileTransition

var height_other: int
var type: Type

enum Type {INVALID, SHARP, SMOOTH}

func _init(height_other_: int, type_: Type) -> void:
    self.height_other = height_other_
    self.type = type_


func get_weight() -> float:
    match type:
        Type.SHARP:
            return 0.0
        Type.SMOOTH:
            return 1.0
        _:
            return 0.0

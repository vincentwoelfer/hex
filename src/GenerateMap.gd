@tool
extends Node3D

var hex_geometry := preload("res://scenes/HexGeometry.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for x in range(0, 4):
		for z in range(0, 4):
			var isEven: bool = z % 2 == 0
			var height: int = 0
			var pos := Vector3.ZERO
			pos.x = (x * HexConst.horizontal_size() * 2.0) + (HexConst.horizontal_size() / 2.0 if !isEven else 0.0)
			pos.z = z * HexConst.vertical_size() * 1.0
			pos.y = height

			# Instantiate
			var tile: HexGeometry = hex_geometry.instantiate()
		
			var adjacent_hex: Array[HexGeometry.AdjacentHex] = [HexGeometry.AdjacentHex.new(0, ""), HexGeometry.AdjacentHex.new(0, ""), HexGeometry.AdjacentHex.new(1, ""), HexGeometry.AdjacentHex.new(2, ""), HexGeometry.AdjacentHex.new(0, ""), HexGeometry.AdjacentHex.new(-1, "")]
			
			# Set parameters
			tile.height = height
			tile.adjacent_hex = adjacent_hex
			tile.position = pos

			# Add to the current scene
			add_child(tile)
			#tile.owner = self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

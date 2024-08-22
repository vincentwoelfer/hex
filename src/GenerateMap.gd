@tool
extends Node3D

var hex_geometry := preload("res://scenes/HexGeometry.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var map: HexMap = HexMap.new()

	var N: int = 2

	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N);
		var r2: int = min(N, -q + N);
		for r in range(r1, r2 + 1):
			var hex := HexMap.Hex.new(q, r, -q - r)
			create_hex(hex)

func create_hex(hex: HexMap.Hex) -> void:
	#print("Creating Hex at q=", hex.q, ", r=", hex.r, ", s=", hex.s)
	var pos: Vector2 = HexMap.hex_to_pixel(hex)

	var height: int = hex.r

	# Instantiate
	var tile: HexGeometry = hex_geometry.instantiate()

	#var adjacent_hex: Array[HexGeometry.AdjacentHex] = [HexGeometry.AdjacentHex.new(0, ""), HexGeometry.AdjacentHex.new(0, ""), HexGeometry.AdjacentHex.new(1, ""), HexGeometry.AdjacentHex.new(2, ""), HexGeometry.AdjacentHex.new(0, ""), HexGeometry.AdjacentHex.new(-1, "")]	
	var adjacent_hex: Array[HexGeometry.AdjacentHex] = [
		HexGeometry.AdjacentHex.new(HexMap.hex_neighbor(hex, 0).r, ""),
		HexGeometry.AdjacentHex.new(HexMap.hex_neighbor(hex, 1).r, ""),
		HexGeometry.AdjacentHex.new(HexMap.hex_neighbor(hex, 2).r, ""),
		HexGeometry.AdjacentHex.new(HexMap.hex_neighbor(hex, 3).r, ""),
		HexGeometry.AdjacentHex.new(HexMap.hex_neighbor(hex, 4).r, ""),
		HexGeometry.AdjacentHex.new(HexMap.hex_neighbor(hex, 5).r, "")]

	print(adjacent_hex[0].to_string())

	# Set parameters
	tile.height = height
	tile.adjacent_hex = adjacent_hex
	tile.position = Vector3(pos.x, height * HexConst.height, pos.y)

	# Add to the current scene
	add_child(tile)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

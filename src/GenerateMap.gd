@tool
extends Node3D

var hex_geometry := preload("res://scenes/HexGeometry.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var map: HexMap = HexMap.new()

	var N: int = 2

	# Create Map
	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N);
		var r2: int = min(N, -q + N);
		for r in range(r1, r2 + 1):
			var hex := HexPos.new(q, r, -q - r)
			map.add_hex(hex, r)


	# Create Geometry
	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N);
		var r2: int = min(N, -q + N);
		for r in range(r1, r2 + 1):
			var hex := HexPos.new(q, r, -q - r)
			create_hex(hex, map)

func create_hex(hex: HexPos, map: HexMap) -> void:
	#print("Creating Hex at q=", hex.q, ", r=", hex.r, ", s=", hex.s)
	var pos: Vector2 = HexPos.hexpos_to_pixel(hex)

	# Lookup in map and get own height
	var t := map.get_hex(hex)
	var height: int = t.height

	# Get adjacent from map
	var adjacent_hex: Array[HexGeometry.AdjacentHex] = []

	for i in range(6):
		var h := map.get_hex(HexPos.hexpos_neighbor(hex, i)).height

		# If neighbour does not exists set height to same as own tile
		if h == -1:
			h = height

		adjacent_hex.append(HexGeometry.AdjacentHex.new(h, ""))

	# Instantiate & Set parameters
	var tile: HexGeometry = hex_geometry.instantiate()
	tile.height = height
	tile.adjacent_hex = adjacent_hex
	tile.position = Vector3(pos.x, height * HexConst.height, pos.y)

	# Add to the current scene
	add_child(tile)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

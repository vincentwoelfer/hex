@tool
extends Node3D

var hex_geometry := preload("res://scenes/HexGeometry.tscn")

var N: int = 2
var map: HexMap = HexMap.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create Map
	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N)
		var r2: int = min(N, -q + N)
		for r in range(r1, r2 + 1):
			var s := -q - r

			# var north: int = ceilf((s - r)) as int
			# var h: int = maxi(0, north)
			var f2: float = sqrt(3.0) / 2.0
			var f3: float = sqrt(3.0)
			var north: float = -(f2 * q + f3 * r)
			var h: int = maxi(0, roundf(north+1) as int)

			var hex := HexPos.new(q, r, s)
			var x := HexPos.hexpos_to_xyz(hex).x
			var y := HexPos.hexpos_to_xyz(hex).y
			var hash_: int = hex.hash()

			print("Adding with x/y= %5.2f / %5.2f| q=%d r=%d s=%d hash=%d \t| north= %3.1f | height= %d" % [x, y, hex.q, hex.r, hex.s, hash_, north, h])
			map.add_hex(hex, h)

	EventBus.Signal_HexConstChanged.connect(generate_geometry)
	generate_geometry()


func generate_geometry() -> void:
	# Remove previous tiles
	for n in get_children():
		remove_child(n)
		n.queue_free()

	# Create Geometry
	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N)
		var r2: int = min(N, -q + N)
		for r in range(r1, r2 + 1):
			var s := -q - r
			var hex := HexPos.new(q, r, s)
			create_hex(hex)

	print("Regenerated map tiles!")

func create_hex(hex: HexPos) -> void:
	#print("Creating Hex at q=", hex.q, ", r=", hex.r, ", s=", hex.s)
	var pos: Vector2 = HexPos.hexpos_to_xyz(hex)

	# Lookup in map and get own height
	var height: int = map.get_hex(hex).height

	# Get adjacent from map
	var adjacent_hex: Array[HexGeometry.AdjacentHex] = []

	for dir in range(6):
		var h := map.get_hex(hex.get_neighbor(dir)).height
		var descr := ""

		# If neighbour does not exists set height to same as own tile and mark transition
		if h == -1:
			h = height
			descr = 'invalid'

		adjacent_hex.push_back(HexGeometry.AdjacentHex.new(h, descr))

	# Instantiate & Set parameters
	var tile: HexGeometry = hex_geometry.instantiate()
	tile.height = height
	tile.adjacent_hex = adjacent_hex
	tile.position = Vector3(pos.x, height * HexConst.height, pos.y)

	# Add to the current scene
	add_child(tile, true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

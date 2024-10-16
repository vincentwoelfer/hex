@tool
extends Node3D

var HEX_GEOMETRY_SCENE := preload("res://scenes/HexGeometry.tscn")
var height_noise: Noise = preload("res://assets/TerrainHeightNoise.tres")

var min_height := 1
var max_height := 20

const OCEAN_HEIGHT = 0
const INVALID_HEIGHT = -1

var N: int = 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Delete from hexmap
	MapManager.map.clear_all()

	# Create Map
	for q in range(-N, N + 1):
		var r1: int = max(-N, -q - N)
		var r2: int = min(N, -q + N)
		for r in range(r1, r2 + 1):
			var s := -q - r
			var hex_pos := HexPos.new(q, r, s)

			#var height: int = abs(N - hex_pos.magnitude()) * 2 + randi_range(-1, 1) * 3
			#height = clampi(height, 0, 30)

			var pos2D: Vector2 = HexPos.hexpos_to_xy(hex_pos)
			var noise: float = height_noise.get_noise_2d(pos2D.x, pos2D.y)
			noise = remap(noise, -1.0, 1.0, 0.0, 1.0)

			var height_f: float = remap(noise, 0.0, 1.0, min_height, max_height)
			var height: int = clampi(roundf(height_f) as int, min_height + 4, max_height)

			# Border
			if hex_pos.magnitude() == N:
				height = OCEAN_HEIGHT

			# For debug printing only
			# var x := HexPos.hexpos_to_xy(hex_pos).x
			# var y := HexPos.hexpos_to_xy(hex_pos).y
			# var hash_: int = hex_pos.hash()
			#print("Adding with x/y= %5.2f / %5.2f| q=%d r=%d s=%d hash=%d \t| north= %3.1f | height= %d" % [x, y, hex_pos.q, hex_pos.r, hex_pos.s, hash_, north, height])

			MapManager.map.add_hex(hex_pos, height)

	EventBus.Signal_HexConstChanged.connect(generate_geometry)
	generate_geometry()


func generate_geometry() -> void:
	var t_start := Time.get_ticks_msec()

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
			var hex_pos := HexPos.new(q, r, s)
			create_hex(hex_pos)

	var t := (Time.get_ticks_msec() - t_start) / 1000.0
	print("Regenerated map tiles in %.3f sec" % [t])


func create_hex(hex_pos: HexPos) -> void:
	var world_pos: Vector2 = HexPos.hexpos_to_xy(hex_pos)
	var hex_tile: HexTile = MapManager.map.get_hex(hex_pos)

	# Lookup in map and get own height
	var height: int = hex_tile.height

	# Get adjacent from map
	var adjacent_hex: Array[HexGeometry.AdjacentHex] = []

	for dir in range(6):
		var h := MapManager.map.get_hex(hex_pos.get_neighbor(dir)).height
		var descr := ""

		# If neighbour does not exists set height to same as own tile and mark transition
		if h == -1:
			h = INVALID_HEIGHT
			descr = 'invalid'

		adjacent_hex.push_back(HexGeometry.AdjacentHex.new(h, descr))

	# Instantiate & Set parameters
	var hex_geometry: HexGeometry = HEX_GEOMETRY_SCENE.instantiate()
	hex_geometry.height = height
	hex_geometry.adjacent_hex = adjacent_hex

	# Add to tile	
	hex_tile.position = Vector3(world_pos.x, height * HexConst.height, world_pos.y)
	hex_tile.assign_geometry(hex_geometry)

	# Add to the current scene
	add_child(hex_tile, true)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

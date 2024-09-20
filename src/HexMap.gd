class_name HexMap

# Hash-Map of Hexes. Key = int (HexPos.has()), Value = HexTile
#var tiles: Dictionary[int, HexTile] = {}
var tiles: Dictionary = {}

func add_hex(hex: HexPos, height: int) -> HexTile:
	var key: int = hex.hash()
	if tiles.has(key):
		print("Map already has tile at r: %d, q: %d, s:%d!" % [hex.r, hex.q, hex.s])
		return
	tiles[key] = HexTile.new(hex, height)
	return tiles[key]


func get_hex(hex: HexPos) -> HexTile:
	var key: int = hex.hash()
	if not tiles.has(key):
		#print("Map has no tile at r: %d, q: %d, s:%d!" % [hex.r, hex.q, hex.s])
		return HexTile.new(null, -1)
	return tiles[key]

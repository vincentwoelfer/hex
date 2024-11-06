@tool # Must be tool because static variables are used in editor
class_name HexTileMap

# Hash-Map of Hexes. Key = int (HexPos.has()), Value = HexTile
static var tiles: Dictionary[int, HexTile] = {}
static var mutex: Mutex = Mutex.new()

#################################################################
# ADD -> does nothing if already existing, returns the tile in all cases
#################################################################
static func add_by_hash(key: int, height: int) -> HexTile:
	var hex_pos: HexPos = HexPos.unhash(key)
	return _add(hex_pos, key, height)


static func add_by_pos(hex_pos: HexPos, height: int) -> HexTile:
	var key := hex_pos.hash()
	return _add(hex_pos, key, height)

	
static func _add(hex_pos: HexPos, key: int, height: int) -> HexTile:
	mutex.lock()

	# Create var
	var tile: HexTile

	# Existing
	if tiles.has(key):
		tile = tiles.get(key)
		mutex.unlock()
		return tile

	# Add new
	tiles[key] = HexTile.new(hex_pos, height)
	tile = tiles.get(key)

	mutex.unlock()
	return tile

#################################################################
# GET -> returns null if not existing
#################################################################
static func get_by_hash(key: int) -> HexTile:
	mutex.lock()
	var tile: HexTile = tiles.get(key)
	mutex.unlock()
	return tile


static func get_by_pos(hex_pos: HexPos) -> HexTile:
	return get_by_hash(hex_pos.hash())


#################################################################
# CHECK
#################################################################
static func is_empty() -> bool:
	mutex.lock()
	var ret: bool = tiles.is_empty()
	mutex.unlock()
	return ret


#################################################################
# DELETE
#################################################################
static func free_all() -> void:
	mutex.lock()
	for i: int in tiles:
		if tiles[i] != null:
			tiles[i].free()
	tiles.clear()
	mutex.unlock()

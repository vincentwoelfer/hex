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

	mutex.lock()
	var tile: HexTile = tiles.get_or_add(key, HexTile.new(hex_pos, height))
	mutex.unlock()

	return tile


static func add_by_pos(hex_pos: HexPos, height: int) -> HexTile:
	var key := hex_pos.hash()

	mutex.lock()
	var tile: HexTile = tiles.get_or_add(key, HexTile.new(hex_pos, height))
	mutex.unlock()
	
	return tile

#################################################################
# GET -> returns null if not existing
#################################################################
static func get_by_hash(key: int) -> HexTile:
	mutex.lock()
	if not tiles.has(key):
		mutex.unlock()
		return null

	var tile: HexTile = tiles[key]
	mutex.unlock()
	return tile


static func get_by_pos(hex_pos: HexPos) -> HexTile:
	var key: int = hex_pos.hash()

	mutex.lock()
	if not tiles.has(key):
		mutex.unlock()
		return null

	var tile: HexTile = tiles[key]
	mutex.unlock()
	return tile


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

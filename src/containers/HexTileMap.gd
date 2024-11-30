@tool # Must be tool because static variables are used in editor
class_name HexTileMap

# Hash-Map of Hexes. Key = int (HexPos.hash()), Value = HexTile
static var tiles: Dictionary[int, HexTile] = {}
static var mutex: Mutex = Mutex.new()

#################################################################
# ADD -> does nothing if already existing, returns the tile in all cases
#################################################################
static func add_by_hash(key: int, height: int) -> HexTile:
	var hex_pos: HexPos = HexPos.unhash(key)
	# -> Requires mutex
	return _add(hex_pos, key, height)


static func add_by_pos(hex_pos: HexPos, height: int) -> HexTile:
	var key := hex_pos.hash()
	# -> Requires mutex
	return _add(hex_pos, key, height)

	
static func _add(hex_pos: HexPos, key: int, height: int) -> HexTile:
	# Create var
	var tile: HexTile

	mutex.lock()

	# Existing
	if tiles.has(key):
		tile = tiles.get(key)
		mutex.unlock()
		return tile

	# Add new
	tile = HexTile.new(hex_pos, height)
	tiles.set(key, tile)

	mutex.unlock()
	return tile


#################################################################
# BATCHED ADD - for adding all tiles of a chunk
# DIFFERENT FROM HexChunkMap
#################################################################
static func add_initialized_tiles_batch(new_tiles: Array[HexTile]) -> void:
	mutex.lock()

	for i in range(new_tiles.size()):
		var key: int = new_tiles[i].hex_pos.hash()
		assert(not tiles.has(key))
		tiles.set(key, new_tiles[i])

	mutex.unlock()

#################################################################
# GET -> returns null if not existing
#################################################################
static func get_by_hash(key: int) -> HexTile:
	mutex.lock()
	var tile: HexTile = tiles.get(key)
	mutex.unlock()
	return tile


static func get_by_pos(hex_pos: HexPos) -> HexTile:
	# -> Requires mutex
	return get_by_hash(hex_pos.hash())


#################################################################
# CHECK
#################################################################
static func is_empty() -> bool:
	mutex.lock()
	var ret: bool = tiles.is_empty()
	mutex.unlock()
	return ret


static func get_size() -> int:
	mutex.lock()
	var ret: int = tiles.size()
	mutex.unlock()
	return ret


#################################################################
# DELETE
#################################################################
# DOES NOT FREE
static func delete_by_hash(key: int) -> void:
	mutex.lock()
	tiles.erase(key)
	mutex.unlock()

static func delete_by_pos(hex_pos: HexPos) -> void:
	# -> Requires mutex
	delete_by_hash(hex_pos.hash())


# DIFFERENT FROM HexChunkMap
static func delete_batch_by_poses(hex_poses: Array[HexPos]) -> void:
	mutex.lock()
	for i in range(hex_poses.size()):
		tiles.erase(hex_poses[i].hash())
	mutex.unlock()


static func clear_all() -> void:
	mutex.lock()
	# IS THIS REQUIRED ???
	# for i: int in tiles:
	# 	if tiles[i] != null:
	# 		tiles[i].free()
	tiles.clear()
	mutex.unlock()

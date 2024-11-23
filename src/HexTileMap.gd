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
	print("THREAD %d: _add before new." % OS.get_thread_caller_id())
	print("hex_pos: ", hex_pos)
	print("height: ", height)
	var t: HexTile = HexTile.new(hex_pos, height)
	print("THREAD %d: _add after new" % OS.get_thread_caller_id())
	tiles.set(key, t)
	print("THREAD %d: _add after set" % OS.get_thread_caller_id())
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
	if tiles.has(key):
		#tiles[key].free()
		tiles.erase(key)
	mutex.unlock()


static func delete_by_pos(hex_pos: HexPos) -> void:
	# -> Requires mutex
	delete_by_hash(hex_pos.hash())


static func free_all() -> void:
	mutex.lock()
	# IS THIS REQUIRED ???
	# for i: int in tiles:
	# 	if tiles[i] != null:
	# 		tiles[i].free()
	tiles.clear()
	mutex.unlock()

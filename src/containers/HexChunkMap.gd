@tool # Must be tool because static variables are used in editor
class_name HexChunkMap

# Hash-Map of Hexes. Key = int (HexPos.hash()), Value = HexChunk
static var chunks: Dictionary[int, HexChunk] = {}
static var mutex: Mutex = Mutex.new()

#################################################################
# ADD -> does nothing if already existing, returns the chunk in all cases
#################################################################
static func add_by_hash(key: int) -> HexChunk:
	var hex_pos: HexPos = HexPos.unhash(key)
	# -> Requires mutex
	return _add(hex_pos, key)


static func add_by_pos(hex_pos: HexPos) -> HexChunk:
	var key := hex_pos.hash()
	# -> Requires mutex
	return _add(hex_pos, key)

	
static func _add(hex_pos: HexPos, key: int) -> HexChunk:
	assert(hex_pos.is_chunk_base()) # DIFFERENT FROM HexTileMap

	# Create var
	var chunk: HexChunk

	mutex.lock()

	# Existing
	if chunks.has(key):
		chunk = chunks.get(key)
		mutex.unlock()
		return chunk

	# Add new
	chunk = HexChunk.new(hex_pos)
	chunks.set(key, chunk)

	mutex.unlock()
	return chunk

#################################################################
# GET -> returns null if not existing
#################################################################
static func get_by_hash(key: int) -> HexChunk:
	assert(HexPos.unhash(key).is_chunk_base()) # DIFFERENT FROM HexTileMap

	mutex.lock()
	var chunk: HexChunk = chunks.get(key)
	mutex.unlock()
	return chunk


static func get_by_pos(hex_pos: HexPos) -> HexChunk:
	# -> Requires mutex
	return get_by_hash(hex_pos.hash())


#################################################################
# CHECK
#################################################################
static func is_empty() -> bool:
	mutex.lock()
	var ret: bool = chunks.is_empty()
	mutex.unlock()
	return ret


static func get_size() -> int:
	mutex.lock()
	var ret: int = chunks.size()
	mutex.unlock()
	return ret


#################################################################
# DELETE
#################################################################

# DOES NOT FREE
static func delete_by_hash(key: int) -> void:
	assert(HexPos.unhash(key).is_chunk_base()) # DIFFERENT FROM HexTileMap

	mutex.lock()
	chunks.erase(key)
	mutex.unlock()


static func delete_by_pos(hex_pos: HexPos) -> void:
	# -> Requires mutex
	delete_by_hash(hex_pos.hash())


static func clear_all() -> void:
	mutex.lock()
	# IS THIS REQUIRED ???
	# for i: int in chunks:
	# 	if chunks[i] != null:
	# 		chunks[i].free()
	chunks.clear()
	mutex.unlock()

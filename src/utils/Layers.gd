@tool
class_name Layers
extends Node

enum L {
	ALL = 1,
	# Only the generated hex-floor
	TERRAIN = 2,
	# Rocks, trees, etc.
	STATIC_GEOM = 3,
	PLAYER_CHARACTERS = 4,
	ENEMY_CHARACTERS = 5,
	PICKABLE_OBJECTS = 6,
}

# Handy Shortcuts
const TERRAIN_AND_STATIC = L.TERRAIN | L.STATIC_GEOM

static func mask(layers: Array[int]) -> int:
	var result: int = 0
	for layer in layers:
		result += (1 << (layer - 1))
	return result

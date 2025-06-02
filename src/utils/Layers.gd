@tool
class_name Layers
extends Node

enum PHY {
	ALL = 1,
	# Only the generated hex-floor
	TERRAIN = 2,
	# Rocks, trees, etc.
	STATIC_GEOM = 3,
	PLAYER_CHARACTERS = 4,
	ENEMY_CHARACTERS = 5,
	PICKABLE_OBJECTS = 6,
	CARAVAN = 7,
}

enum VIS {
	ALL = 1,
	# Only the generated hex-floor
	TERRAIN = 2,
	# Rocks, trees, etc.
	STATIC_GEOM = 3,
}

# Handy Shortcuts
static var PHY_TERRAIN_AND_STATIC := mask([PHY.TERRAIN, PHY.STATIC_GEOM])

static func mask(layers: Array[int]) -> int:
	var result: int = 0
	for layer in layers:
		result += (1 << (layer - 1))
	return result

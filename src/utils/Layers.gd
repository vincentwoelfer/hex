@tool
class_name Layers
extends Node

enum L {
	ALL = 1,
	TERRAIN = 2,
	STATIC_GEOM = 3,
	PLAYER_CHARACTERS = 4,
	ENEMY_CHARACTERS = 5,
}

static func mask(layers: Array[int]) -> int:
	var result: int = 0
	for layer in layers:
		result += (1 << (layer - 1))
	return result

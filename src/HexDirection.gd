class_name HexDirection

enum {	
	NE = 0,
	SE = 1,
	S = 2,
	SW = 3,
	NW = 4,
	N = 5
}

# Next = Right = Clockwise
static func next(dir : int) -> int:
	return (dir + 1) % 6

# Prev = Left = Counter-Clockwise
static func prev(dir : int) -> int:
	return (dir - 1) % 6

static func opposite(dir : int) -> int:
	return (dir + 3) % 6

static func values() -> Array:
	return [NE, SE, S, SW, NW, N]

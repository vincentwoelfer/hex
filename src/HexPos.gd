@tool
class_name HexPos

# Class variables
var q: int
var r: int
var s: int

func _init(q_: int, r_: int, s_: int) -> void:
	q = q_
	r = r_
	s = s_
	if q + r + s != 0:
		push_error("q + r + s must be 0")


func _to_string() -> String:
	return '(' + str(q) + ', ' + str(r) + ', ' + str(s) + ')'


func hash() -> int:
	# Maps [q,r] -> N, works bidirectionally and for signed integers
	# Based on signed Szudzik pairing but without /2 in the end (no "improved packing")
	# https://www.vertexfragment.com/ramblings/cantor-szudzik-pairing-functions/#signed-szudzik
	var a: int = 2 * q if q >= 0 else (-2 * q) - 1
	var b: int = 2 * r if r >= 0 else (-2 * r) - 1
	var result: int = (a * a) + a + b if a >= b else (b * b) + a
	return result


static func unhash(z: int) -> HexPos:
	# Inverse of hash()
	# https://gist.github.com/TheGreatRambler/048f4b38ca561e6566e0e0f6e71b7739	
	var sqrtz: int = floori(sqrt(z))
	var sqz: int = sqrtz * sqrtz;
	var a: int
	var b: int
	if ((z - sqz) >= sqrtz):
		a = sqrtz
		b = z - sqz - sqrtz
	else:
		a = z - sqz
		b = sqrtz
	@warning_ignore("integer_division")
	var q_: int = a / 2 if a % 2 == 0 else (a + 1) / -2
	@warning_ignore("integer_division")
	var r_: int = b / 2 if b % 2 == 0 else (b + 1) / -2
	return HexPos.new(q_, r_, -q_ - r_)


func add(other: HexPos) -> HexPos:
	return HexPos.new(q + other.q, r + other.r, s + other.s)

func subtract(other: HexPos) -> HexPos:
	return HexPos.new(q - other.q, r - other.r, s - other.s)


# Distance to (0,0,0) aka "length"
func magnitude() -> int:
	return roundi((absi(q) + absi(r) + absi(s)) / 2.0)


# Actual distance function (in hex tiles)
func distance_to(other: HexPos) -> int:
	return (subtract(other)).magnitude()


func get_neighbour(dir: int) -> HexPos:
	return add(hexpos_direction(dir))


func get_all_coordinates_in_range(N: int, include_self: bool = false) -> Array[HexPos]:
	assert(N >= 0)
	
	var num := compute_num_tiles_in_range(N, include_self)

	var coordinates: Array[HexPos] = []
	coordinates.resize(num)
	var i := 0

	for q_ in range(-N, N + 1):
		var r1: int = max(-N, -q_ - N)
		var r2: int = min(N, -q_ + N)
		for r_ in range(r1, r2 + 1):
			var s_ := -q_ - r_
			if include_self or (q != q_ or r != r_ or s != s_):
				coordinates[i] = HexPos.new(q + q_, r + r_, s + s_)
			i += 1

	return coordinates


#########################################
# Static functions
#########################################
# +X = right = 0
static var hexpos_directions: Array[HexPos] = [
	HexPos.new(1, 0, -1), # 0: +X, bot-right   | r=0
	HexPos.new(0, 1, -1), # 1: +Z, bot         | q=0
	HexPos.new(-1, 1, 0), # 2: +X, bot-left    | s=0
	HexPos.new(-1, 0, 1), # 3: -X, top-left    | r=0
	HexPos.new(0, -1, 1), # 4: -Z, top         | q=0
	HexPos.new(1, -1, 0), # 5: -X, top-right   | s=0
]

# static var hexpos_diagonals: Array[HexPos] = [
#     # TODO anpassen
#     HexPos.new(2, -1, -1), HexPos.new(1, -2, 1), HexPos.new(-1, -1, 2),
#     HexPos.new(-2, 1, 1), HexPos.new(-1, 2, -1), HexPos.new(1, 1, -2)
# ]

static func hexpos_direction(direction: int) -> HexPos:
	return hexpos_directions[Util.as_dir(direction)]


# static func hexpos_direction_diagonal(direction: int) -> HexPos:
#     assert(direction >= 0)
	# return hexpos_diagonals[direction % 6]


# static func hexpos_diagonal_neighbour(hex: HexPos, direction: int) -> HexPos:
#     return hexpos_add(hex, hexpos_direction_diagonal(direction))


# static func hexpos_distance(a: HexPos, b: HexPos) -> int:
	# return hexpos_length(hexpos_subtract(a, b))


# static func hexpos_rotate_left(a: HexPos) -> HexPos:
#     return HexPos.new(-a.s, -a.q, -a.r)
# static func hexpos_rotate_right(a: HexPos) -> HexPos:
#     return HexPos.new(-a.r, -a.s, -a.q)


# N = range/radius with 0 being the origin tile
static func compute_num_tiles_in_range(N: int, include_self: bool) -> int:
	# Only origin tile. Necessary for range 0 because of how range() works
	var self_count: int = 1 if include_self else 0
	if N == 0:
		return self_count

	# per layer: 6 * (layer_size)
	# Runs for [1, ..., N] 
	var num := 0
	for n in range(0, N + 1):
		if n == 0:
			num += self_count
		else:
			num += 6 * n
	return num


static func hexpos_to_xy(hex_pos: HexPos) -> Vector2:
	var size: Vector2 = Vector2(HexConst.outer_radius, HexConst.outer_radius)
	var origin: Vector2 = Vector2(0, 0)

	var f0: float = 3.0 / 2.0
	#var f1: float = 0.0
	var f2: float = sqrt(3.0) / 2.0
	var f3: float = sqrt(3.0)
	
	var x: float = (f0 * hex_pos.q) * size.x
	var y: float = (f2 * hex_pos.q + f3 * hex_pos.r) * size.y

	return Vector2(x + origin.x, y + origin.y)


static func xyz_to_hexpos_frac(world_pos: Vector3) -> HexPosFrac:
	return xy_to_hexpos_frac(Vector2(world_pos.x, world_pos.z))


static func xy_to_hexpos_frac(world_pos: Vector2) -> HexPosFrac:
	var size: Vector2 = Vector2(HexConst.outer_radius, HexConst.outer_radius)
	var origin: Vector2 = Vector2(0, 0)

	var b0: float = 2.0 / 3.0
	var b1: float = 0.0
	var b2: float = -1.0 / 3.0
	var b3: float = sqrt(3.0) / 3.0

	var pt: Vector2 = Vector2((world_pos.x - origin.x) / size.x, (world_pos.y - origin.y) / size.y)
	var q_: float = b0 * pt.x + b1 * pt.y
	var r_: float = b2 * pt.x + b3 * pt.y

	return HexPosFrac.new(q_, r_, -q_ - r_)

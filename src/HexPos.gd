@tool
class_name HexPos

var q: int
var r: int
var s: int

static var hexpos_directions: Array[HexPos] = [
    HexPos.new(1, 0, -1), HexPos.new(1, -1, 0), HexPos.new(0, -1, 1),
    HexPos.new(-1, 0, 1), HexPos.new(-1, 1, 0), HexPos.new(0, 1, -1)
]

static var hexpos_diagonals: Array[HexPos] = [
    HexPos.new(2, -1, -1), HexPos.new(1, -2, 1), HexPos.new(-1, -1, 2),
    HexPos.new(-2, 1, 1), HexPos.new(-1, 2, -1), HexPos.new(1, 1, -2)
]

func _init(q_: int, r_: int, s_: int) -> void:
    q = q_
    r = r_
    s = s_
    if q + r + s != 0:
        push_error("q + r + s must be 0")

# Based on Cantors enumeration of pairs, also see https://stackoverflow.com/a/682617/7721704
func hash() -> int:
    @warning_ignore("integer_division")
    return ((q + r) * (q + r + 1) / 2) + r


static func hexpos_direction(direction: int) -> HexPos:
    assert(direction >= 0)
    return hexpos_directions[direction % 6]


static func hexpos_direction_diagonal(direction: int) -> HexPos:
    assert(direction >= 0)
    return hexpos_diagonals[direction % 6]


static func hexpos_add(a: HexPos, b: HexPos) -> HexPos:
    return HexPos.new(a.q + b.q, a.r + b.r, a.s + b.s)


static func hexpos_subtract(a: HexPos, b: HexPos) -> HexPos:
    return HexPos.new(a.q - b.q, a.r - b.r, a.s - b.s)


static func hexpos_scale(a: HexPos, k: int) -> HexPos:
    return HexPos.new(a.q * k, a.r * k, a.s * k)


static func hexpos_rotate_left(a: HexPos) -> HexPos:
    return HexPos.new(-a.s, -a.q, -a.r)


static func hexpos_rotate_right(a: HexPos) -> HexPos:
    return HexPos.new(-a.r, -a.s, -a.q)


static func hexpos_neighbor(hex: HexPos, direction: int) -> HexPos:
    return hexpos_add(hex, hexpos_direction(direction))


static func hexpos_diagonal_neighbor(hex: HexPos, direction: int) -> HexPos:
    return hexpos_add(hex, hexpos_direction_diagonal(direction))


static func hexpos_length(hex: HexPos) -> int:
    # TODO Changed rounding behaviour, maybe this is buggy
    return roundi((absi(hex.q) + absi(hex.r) + absi(hex.s)) / 2.0)


static func hexpos_distance(a: HexPos, b: HexPos) -> int:
    return hexpos_length(hexpos_subtract(a, b))


static func hexpos_round(h: HexPosFrac) -> HexPos:
    var qi: int = roundi(h.q)
    var ri: int = roundi(h.r)
    var si: int = roundi(h.s)
    var q_diff: float = abs(qi - h.q)
    var r_diff: float = abs(ri - h.r)
    var s_diff: float = abs(si - h.s)
    if q_diff > r_diff and q_diff > s_diff:
        qi = -ri - si
    elif r_diff > s_diff:
        ri = -qi - si
    else:
        si = -qi - ri
    return HexPos.new(qi, ri, si)


static func hexpos_lerp(a: HexPosFrac, b: HexPosFrac, t: float) -> HexPosFrac:
    return HexPosFrac.new(a.q * (1.0 - t) + b.q * t, a.r * (1.0 - t) + b.r * t, a.s * (1.0 - t) + b.s * t)


static func hexpos_linedraw(a: HexPos, b: HexPos) -> Array[HexPos]:
    var N: int = hexpos_distance(a, b)
    const eps := 0.000001
    var a_nudge: HexPosFrac = HexPosFrac.new(a.q + eps, a.r + eps, a.s - 2.0 * eps)
    var b_nudge: HexPosFrac = HexPosFrac.new(b.q + eps, b.r + eps, b.s - 2.0 * eps)
    var results: Array[HexPos] = []
    var step: float = 1.0 / max(N, 1)
    for i in range(N + 1):
        results.append(hexpos_round(hexpos_lerp(a_nudge, b_nudge, step * i)))
    return results


static func hexpos_to_pixel(h: HexPos) -> Vector2:
    var size: Vector2 = Vector2(HexConst.outer_radius, HexConst.outer_radius)
    var origin: Vector2 = Vector2(0, 0)

    var f0: float = 3.0 / 2.0
    var f1: float = 0.0
    var f2: float = sqrt(3.0) / 2.0
    var f3: float = sqrt(3.0)
    
    var x: float = (f0 * h.q + f1 * h.r) * size.x
    var y: float = (f2 * h.q + f3 * h.r) * size.y

    return Vector2(x + origin.x, y + origin.y)


static func pixel_to_hexpos(p: Vector2) -> HexPosFrac:
    var size: Vector2 = Vector2(HexConst.outer_radius, HexConst.outer_radius)
    var origin: Vector2 = Vector2(0, 0)

    var b0: float = 2.0 / 3.0
    var b1: float = 0.0
    var b2: float = -1.0 / 3.0
    var b3: float = sqrt(3.0) / 3.0

    var pt: Vector2 = Vector2((p.x - origin.x) / size.x, (p.y - origin.y) / size.y)
    var q_: float = b0 * pt.x + b1 * pt.y
    var r_: float = b2 * pt.x + b3 * pt.y

    return HexPosFrac.new(q_, r_, -q_ - r_)

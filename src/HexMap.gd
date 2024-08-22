class_name HexMap

# Hash-Map of Hexes. Key = int, Value = Hex
var _storage: Dictionary = {}

#static func getHex(Hex)


class Hex:
    var q: int
    var r: int
    var s: int
    
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

    # func to_string() -> String:
    #     return "q: %d | r: %d | s: %d" % [q, r, s]


class FractionalHex:
    var q: float
    var r: float
    var s: float
    
    func _init(q_: float, r_: float, s_: float) -> void:
        q = q_
        r = r_
        s = s_
        if round(q + r + s) != 0:
            push_error("q + r + s must be 0")


static var hex_directions: Array[Hex] = [
    Hex.new(1, 0, -1), Hex.new(1, -1, 0), Hex.new(0, -1, 1),
    Hex.new(-1, 0, 1), Hex.new(-1, 1, 0), Hex.new(0, 1, -1)
]

static var hex_diagonals: Array[Hex] = [
    Hex.new(2, -1, -1), Hex.new(1, -2, 1), Hex.new(-1, -1, 2),
    Hex.new(-2, 1, 1), Hex.new(-1, 2, -1), Hex.new(1, 1, -2)
]


static func hex_add(a: Hex, b: Hex) -> Hex:
    return Hex.new(a.q + b.q, a.r + b.r, a.s + b.s)


static func hex_subtract(a: Hex, b: Hex) -> Hex:
    return Hex.new(a.q - b.q, a.r - b.r, a.s - b.s)


static func hex_scale(a: Hex, k: int) -> Hex:
    return Hex.new(a.q * k, a.r * k, a.s * k)


static func hex_rotate_left(a: Hex) -> Hex:
    return Hex.new(-a.s, -a.q, -a.r)


static func hex_rotate_right(a: Hex) -> Hex:
    return Hex.new(-a.r, -a.s, -a.q)


static func hex_direction(direction: int) -> Hex:
    return hex_directions[direction]


static func hex_neighbor(hex: Hex, direction: int) -> Hex:
    return hex_add(hex, hex_direction(direction))


static func hex_diagonal_neighbor(hex: Hex, direction: int) -> Hex:
    return hex_add(hex, hex_diagonals[direction])


static func hex_length(hex: Hex) -> int:
    # TODO Changed rounding behaviour, maybe this is buggy
    return roundi((absi(hex.q) + absi(hex.r) + absi(hex.s)) / 2.0)


static func hex_distance(a: Hex, b: Hex) -> int:
    return hex_length(hex_subtract(a, b))


static func hex_round(h: FractionalHex) -> Hex:
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
    return Hex.new(qi, ri, si)


static func hex_lerp(a: FractionalHex, b: FractionalHex, t: float) -> FractionalHex:
    return FractionalHex.new(a.q * (1.0 - t) + b.q * t, a.r * (1.0 - t) + b.r * t, a.s * (1.0 - t) + b.s * t)


static func hex_linedraw(a: Hex, b: Hex) -> Array[Hex]:
    var N: int = hex_distance(a, b)
    const eps := 0.000001
    var a_nudge: FractionalHex = FractionalHex.new(a.q + eps, a.r + eps, a.s - 2.0 * eps)
    var b_nudge: FractionalHex = FractionalHex.new(b.q + eps, b.r + eps, b.s - 2.0 * eps)
    var results: Array[Hex] = []
    var step: float = 1.0 / max(N, 1)
    for i in range(N + 1):
        results.append(hex_round(hex_lerp(a_nudge, b_nudge, step * i)))
    return results


static func hex_to_pixel(h: Hex) -> Vector2:
    var size: Vector2 = Vector2(HexConst.outer_radius, HexConst.outer_radius)
    var origin: Vector2 = Vector2(0, 0)

    var f0: float = 3.0 / 2.0
    var f1: float = 0.0
    var f2: float = sqrt(3.0) / 2.0
    var f3: float = sqrt(3.0)
    
    var x: float = (f0 * h.q + f1 * h.r) * size.x
    var y: float = (f2 * h.q + f3 * h.r) * size.y

    return Vector2(x + origin.x, y + origin.y)


static func pixel_to_hex(p: Vector2) -> FractionalHex:
    var size: Vector2 = Vector2(HexConst.outer_radius, HexConst.outer_radius)
    var origin: Vector2 = Vector2(0, 0)

    var b0: float = 2.0 / 3.0
    var b1: float = 0.0
    var b2: float = -1.0 / 3.0
    var b3: float = sqrt(3.0) / 3.0

    var pt: Vector2 = Vector2((p.x - origin.x) / size.x, (p.y - origin.y) / size.y)
    var q: float = b0 * pt.x + b1 * pt.y
    var r: float = b2 * pt.x + b3 * pt.y

    return FractionalHex.new(q, r, -q - r)

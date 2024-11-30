class_name HexPosFrac

var q: float
var r: float
var s: float

func _init(q_: float, r_: float, s_: float) -> void:
	q = q_
	r = r_
	s = s_
	if round(q + r + s) != 0:
		push_error("q + r + s must be 0")

func round() -> HexPos:
	var qi: int = roundi(q)
	var ri: int = roundi(r)
	var si: int = roundi(s)
	var q_diff: float = abs(qi - q)
	var r_diff: float = abs(ri - r)
	var s_diff: float = abs(si - s)
	if q_diff > r_diff and q_diff > s_diff:
		qi = -ri - si
	elif r_diff > s_diff:
		ri = -qi - si
	else:
		si = -qi - ri
	return HexPos.new(qi, ri, si)


func add(other: HexPosFrac) -> HexPosFrac:
	return HexPosFrac.new(q + other.q, r + other.r, s + other.s)

func subtract(other: HexPosFrac) -> HexPosFrac:
	return HexPosFrac.new(q - other.q, r - other.r, s - other.s)

# Only makes sense if HexPosFrac represents a distance/direction
func scale(factor: float) -> HexPosFrac:
	return HexPosFrac.new(q * factor, r * factor, s * factor)


# static func hexpos_lerp(a: HexPosFrac, b: HexPosFrac, t: float) -> HexPosFrac:
#     return HexPosFrac.new(a.q * (1.0 - t) + b.q * t, a.r * (1.0 - t) + b.r * t, a.s * (1.0 - t) + b.s * t)


# static func hexpos_linedraw(a: HexPos, b: HexPos) -> Array[HexPos]:
#     var N: int = hexpos_distance(a, b)
#     const eps := 0.000001
#     var a_nudge: HexPosFrac = HexPosFrac.new(a.q + eps, a.r + eps, a.s - 2.0 * eps)
#     var b_nudge: HexPosFrac = HexPosFrac.new(b.q + eps, b.r + eps, b.s - 2.0 * eps)
#     var results: Array[HexPos] = []
#     var step: float = 1.0 / max(N, 1)
#     for i in range(N + 1):
#         results.append(hexpos_round(hexpos_lerp(a_nudge, b_nudge, step * i)))
#     return results

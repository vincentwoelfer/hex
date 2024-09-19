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

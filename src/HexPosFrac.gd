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

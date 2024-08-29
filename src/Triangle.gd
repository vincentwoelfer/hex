class_name Triangle

var a: Vector3
var b: Vector3
var c: Vector3
var color: Color

func _init(a_: Vector3, b_: Vector3, c_: Vector3, color_: Color = Color()) -> void:
    if not Geometry2D.is_polygon_clockwise(PackedVector2Array([Util.toVec2(a_), Util.toVec2(b_), Util.toVec2(c_)])):
        self.a = a_
        self.b = b_
        self.c = c_
    else:
        self.a = a_
        self.b = c_
        self.c = b_
    self.color = color_
    assert(a != b and a != c and b != c, "Triangle points must be different")

func getArea() -> float:
    return 0.5 * (b - a).cross(c - a).length()

func getRandPoint() -> Vector3:
    var u: float = randf()
    var v: float = randf()
    if u + v > 1.0:
        u = 1.0 - u
        v = 1.0 - v
    var w: float = 1.0 - u - v
    return a * u + b * v + c * w

func addToSurfaceTool(st: SurfaceTool) -> void:
    st.set_color(color)
    st.set_smooth_group(-1)
    st.add_vertex(a)
    st.set_smooth_group(-1)
    st.add_vertex(b)
    st.set_smooth_group(-1)
    st.add_vertex(c)

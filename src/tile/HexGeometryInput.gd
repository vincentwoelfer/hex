@tool
class_name HexGeometryInput

var height: int
var corner_vertices: Array[Vector3]
var corner_vertices_smoothing: Array[Vector3]

# Transitions
enum TransitionType {INVALID, SHARP, SMOOTH}

class Transition:
    var type: TransitionType
    var height_other: int

var transitions: Array[Transition]

func _init() -> void:
    self.transitions.resize(6)
    self.corner_vertices.resize(6)
    self.corner_vertices_smoothing.resize(6)

func create_debug_visualization(parent: Node3D) -> void:
    for i in range(6):
        var instance := MeshInstance3D.new()
        var color := Colors.getDistincHexColor(i).darkened(0.6)
        instance.mesh = DebugShapes3D.create_sphere(0.15 - i * 0.01, color)
        instance.position = corner_vertices[i]
        parent.add_child(instance)

    for i in range(6):
        var instance := MeshInstance3D.new()
        var color := Colors.getDistincHexColor(i).lightened(0.3)
        instance.mesh = DebugShapes3D.create_sphere(0.15 - i * 0.01, color)
        var pos: Vector3 = corner_vertices_smoothing[i]
        var inwards_factor := HexConst.inner_radius / HexConst.outer_radius
        pos.x *= inwards_factor
        pos.z *= inwards_factor
        pos.y *= inwards_factor
        instance.position = pos
        parent.add_child(instance)

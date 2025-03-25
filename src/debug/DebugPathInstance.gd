class_name DebugPathInstance
extends MeshInstance3D

var color: Color = Color(1, 0, 0, 0.8)
var width: float = 0.1
var height_offset: float = 0.2


func _init(color_: Color, width_: float = 0.1) -> void:
	color = color_
	width = width_
	self.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	self.global_position = Vector3.ZERO + Vector3(0, height_offset, 0)


func update_path(path: PackedVector3Array) -> void:
	if path.size() < 2:
		visible = false
		return

	mesh = DebugShapes3D.create_path_mesh(path, width)
	mesh.surface_set_material(0, DebugShapes3D.create_debug_material(color))
	visible = true

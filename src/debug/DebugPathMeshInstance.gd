class_name DebugPathMeshInstance
extends MeshInstance3D

var color: Color = Color(1, 0, 0, 0.8)


func _init(color_: Color) -> void:
	color = color_
	self.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func update_path(path: PackedVector3Array) -> void:
	if path.size() < 2:
		visible = false
		return

	mesh = DebugShapes3D.create_path_mesh(path, 0.1)
	mesh.surface_set_material(0, DebugShapes3D.create_debug_material(color))
	visible = true

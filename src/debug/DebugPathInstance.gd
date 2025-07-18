class_name DebugPathInstance
extends MeshInstance3D

var color: Color = Color(1, 0, 0, 0.8)
var width: float = 0.05
var enabled: bool = true
var height_offset: float = 0.35
var mat: StandardMaterial3D

func _init(color_: Color, width_: float = 0.1, enabled_: bool = true) -> void:
	color = color_
	width = width_
	enabled = enabled_

	self.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	self.physics_interpolation_mode = PhysicsBody3D.PHYSICS_INTERPOLATION_MODE_OFF

	mat = DebugVis3D.mat(color, false, false, true)


func _physics_process(delta: float) -> void:
	# Counteract parents movement
	self.global_position = Vector3.ZERO + Vector3(0, height_offset, 0)


func update_path(path: PackedVector3Array, start_pos_override: Vector3 = Vector3.INF) -> void:
	if path.size() < 2:
		visible = false
		return

	if start_pos_override != Vector3.INF:
		path[0] = start_pos_override

	mesh = DebugVis3D.path_mesh(path, width, mat)
	visible = enabled

extends Node3D
class_name SurfacePlant

# TODO make this extend ressource ????

var multiMesh: MultiMeshInstance3D = MultiMeshInstance3D.new()

const GRASS_MESH_HIGH := preload('res://assets/grass/grass_high.obj')
const GRASS_MESH_LOW := preload('res://assets/grass/grass_low.obj')
const GRASS_MAT: ShaderMaterial = preload('res://assets/grass/mat_grass.tres')

func _init() -> void:
	multiMesh = MultiMeshInstance3D.new()
	multiMesh.name = 'GrassMultiMesh'
	multiMesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multiMesh.material_override = GRASS_MAT
	multiMesh.extra_cull_margin = 1.0
	add_child(multiMesh, true)

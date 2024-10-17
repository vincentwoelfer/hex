extends Node3D
class_name Arrow3D

var arrow_length: float = 1.0
var arrow_radius: float = 0.1

func _ready() -> void:
	var immediate_mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.RED

	var arrow := create_arrow()

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for v in arrow:
		immediate_mesh.surface_add_vertex(v[0])
		immediate_mesh.surface_add_vertex(v[1])
	immediate_mesh.surface_end()
	immediate_mesh.surface_set_material(0, material)
	
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = immediate_mesh
	add_child.call_deferred(mesh_instance)


# Function to create an arrow geometry using ImmediateGeometry
func create_arrow() -> Array[PackedVector3Array]:
	var array: Array[PackedVector3Array] = []
	
	var origin: Vector3 = Vector3(0, 0, 0)
	var end: Vector3 = Vector3(0, 0, arrow_length)
	
	# Line (arrow body)
	array.append(PackedVector3Array([origin, end]))
	
	# Cone (arrowhead)
	var cone_base_radius: float = arrow_radius
	var cone_height: float = 0.2
	var cone_tip: Vector3 = Vector3(0, 0, arrow_length + cone_height)
	
	for i in range(12): # 12 points around the cone base
		var angle: float = i * PI * 2.0 / 12.0
		var x: float = cos(angle) * cone_base_radius
		var y: float = sin(angle) * cone_base_radius
		array.append(PackedVector3Array([end, Vector3(x, y, arrow_length)]))
	
	return array

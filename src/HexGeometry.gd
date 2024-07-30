@tool
class_name HexGeometry
extends Node3D

# @export_range(0.5, 5, 0.5) var width: float = 1.0:
# 	set(value):
# 		regenerate = true
# 		width = value
# @export_range(0.5, 5, 0.5) var height: float = 1.0:
# 	set(value):
# 		regenerate = true
# 		height = value

# Class variables
#var regenerate: bool = false
var terrainMesh: MeshInstance3D

func _init() -> void:
	terrainMesh = MeshInstance3D.new()
	terrainMesh.name = "TerrainMesh"
	add_child(terrainMesh, true)
	#terrainMesh.owner = self

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	HexConstants.regenerate = true
	
func create_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	#st.set_normal(Vector3.UP)
	st.set_color(Color(1, 0, 0, 1))

	# Face 1
	st.add_vertex(Vector3(-HexConstants.width, 0.0, 0.0))
	st.add_vertex(Vector3(HexConstants.width, 0.0, -HexConstants.height))
	st.add_vertex(Vector3(0.0, 0.0, HexConstants.height))

	# Removes duplicates -> may mess up colors by merging vertices
	#st.index()

	st.generate_normals()
	var mesh := st.commit()

	# Only for statistics output
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(mesh, 0)
	print("Generated HexGeometry: ", mdt.get_vertex_count(), " vertices, ", mdt.get_face_count(), " faces")

	return mesh

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and HexConstants.regenerate:
		HexConstants.regenerate = false
		terrainMesh.mesh = create_mesh()

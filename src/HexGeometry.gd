@tool
class_name HexGeometry
extends Node3D

# Class variables
var terrainMesh: MeshInstance3D

func _init() -> void:
	terrainMesh = MeshInstance3D.new()
	terrainMesh.name = "TerrainMesh"
	add_child(terrainMesh, true)
	#terrainMesh.owner = self

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.Signal_HexConstantsChanged.connect(generate)

	generate()

func generate() -> void:
	var st : SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	st.set_color(Color(1, 0, 0, 1))

	# Face 1
	st.add_vertex(Vector3(-HexConstants.width, 0.0, 0.0))
	st.add_vertex(Vector3(HexConstants.width, 0.0, -HexConstants.height))
	st.add_vertex(Vector3(0.0, 0.0, HexConstants.height))

	# Removes duplicates -> may mess up colors by merging vertices
	#st.index()

	st.generate_normals()
	terrainMesh.mesh = st.commit()

	# Only for statistics output
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(terrainMesh.mesh as ArrayMesh, 0)
	print("Generated HexGeometry: ", mdt.get_vertex_count(), " vertices, ", mdt.get_face_count(), " faces")


func _process(delta: float) -> void:
	pass

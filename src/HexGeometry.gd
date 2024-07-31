@tool
class_name HexGeometry
extends Node3D

# Class variables
var terrainMesh: MeshInstance3D

# Input
@export var adjacent: Array[int] = [1, 1, 0, 0, -1, -1]

func _init() -> void:
	terrainMesh = MeshInstance3D.new()
	terrainMesh.name = "TerrainMesh"
	terrainMesh.material_override = load("res://DefaultMaterial.tres")

	add_child(terrainMesh, true)
	#terrainMesh.owner = self

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.Signal_HexConstantsChanged.connect(generate)

	generate()

func generate() -> void:
	#assert(adjacent.size() == 6)
	#adjacent.resize(6)
	#adjacent.assign(range(7).filter(func(item: int) -> int: return item if item != null else 0))
	#adjacent = adjacent.map(func(item: int) -> int: return item if item != null else 0)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	#########################################

	var vertsInner := Utility.getHexCornerArray3(HexConstants.inner_radius)
	var vertsOuter := Utility.getHexCornerArray3(HexConstants.outer_radius)

	# Adjust height of outer vertices according do adjacent tiles
	for corner_dir in HexDirection.values():
		var a:= HexConstants.transition_height(adjacent[HexDirection.prev(corner_dir)])
		var b:= HexConstants.transition_height(adjacent[corner_dir])
		vertsOuter[corner_dir].y = (a + b) / 2.0

	# Inner Hex Surface
	var c := Utility.randColor()
	addTri(st, vertsInner[0], vertsInner[1], vertsInner[5], c.darkened(0.0))
	addTri(st, vertsInner[1], vertsInner[2], vertsInner[5], c.darkened(0.1))
	addTri(st, vertsInner[2], vertsInner[4], vertsInner[5], c.darkened(0.2))
	addTri(st, vertsInner[2], vertsInner[3], vertsInner[4], c.darkened(0.3))

	# Connection Inner <-> Outer
	for curr in HexDirection.values():
		var next := HexDirection.next(curr)
		c = Utility.randColor().darkened(0.2)
		addTri(st, vertsOuter[next], vertsInner[next], vertsInner[curr], c)
		addTri(st, vertsOuter[next], vertsInner[curr], vertsOuter[curr], c.darkened(0.3))

	#########################################
	# Removes duplicates -> may mess up colors by merging vertices
	#st.index()

	st.generate_normals()
	terrainMesh.mesh = st.commit()
	terrainMesh.create_debug_tangents()

	# Only for statistics output
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(terrainMesh.mesh as ArrayMesh, 0)
	print("Generated HexGeometry: ", mdt.get_vertex_count(), " vertices, ", mdt.get_face_count(), " faces")


func addTri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)


func _process(delta: float) -> void:
	pass

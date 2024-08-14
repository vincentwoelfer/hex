@tool
class_name HexGeometry
extends Node3D

# Class variables
var terrainMesh: MeshInstance3D
var triangles: Array[Triangle]

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
	EventBus.Signal_HexConstChanged.connect(generate)
	generate()

func generate() -> void:
	generateTriangles()

	# Build Mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for tri in triangles:
		tri.addToSurfaceTool(st)

	#########################################
	# Removes duplicates. Only use later to not mask real number of vertices
	#st.index()

	st.generate_normals()
	terrainMesh.mesh = st.commit()
	terrainMesh.create_debug_tangents()

	# Only for statistics output
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(terrainMesh.mesh as ArrayMesh, 0)
	print("Generated HexGeometry: ", mdt.get_vertex_count(), " vertices, ", mdt.get_face_count(), " faces")

func generateTriangles() -> void:
	triangles.clear()

	var verts_inner := Utility.generateFullHexagonNoCorners(HexConst.inner_radius, HexConst.extra_verts_per_side, HexConst.core_circle_smooth_strength)
	var verts_outer := Utility.generateFullHexagonWithCorners(HexConst.inner_radius, HexConst.outer_radius, HexConst.extra_verts_per_side)

	# Adjust height of inner ring
	for i in range(verts_inner.size()):
		var h_var := 0.00 # 0.05
		verts_inner[i].y += clamp(randfn(0.0, HexConst.height * h_var), HexConst.height * -h_var, HexConst.height * h_var)
		verts_inner[i] += Utility.randCircularOffset(HexConst.inner_radius * 0.04)
		
	# Adjust height of outer vertices according do adjacent tiles
	# We do this per corner!
	for i in range(verts_outer.size()):
		verts_outer[i].y -= HexConst.height

	#########################################
	# Triangles for inner Hex Surface
	#########################################
	var col := Utility.randColor()
	#var col := Color.FOREST_GREEN

	# Generate PackedVec2Array
	var verts_inner_packed: PackedVector2Array = []
	for v in verts_inner:
		verts_inner_packed.append(Utility.toVec2(v))
	var indices: PackedInt32Array = Geometry2D.triangulate_delaunay(verts_inner_packed)

	for i in range(0, indices.size(), 3):
		var i1 := indices[i]
		var i2 := indices[i + 1]
		var i3 := indices[i + 2]
		triangles.append(Triangle.new(verts_inner[i1], verts_inner[i2], verts_inner[i3], Utility.randColorVariation(col)))

	#########################################
	# Triangles for outer Hex Surface
	#########################################
	var i := 0
	var j := 0
	var n1 := verts_inner.size()
	var n2 := verts_outer.size()

	col = Utility.randColor()
	while i < n1 or j < n2:
		if j == n2 or (i < n1 and (i + 1) % n1 <= (j + 1) % n2):
			triangles.append(Triangle.new(verts_inner[i % n1], verts_outer[j % n2], verts_inner[(i + 1) % n1], Utility.randColorVariation(col)))
			i += 1
		else:
			triangles.append(Triangle.new(verts_inner[i % n1], verts_outer[j % n2], verts_outer[(j + 1) % n2], Utility.randColorVariation(col)))
			j += 1

	# # Connection Inner <-> Outer for each HexDirection
	# for curr in HexDir.values():
	# 	var next := HexDir.next(curr)
	# 	#c = Utility.randColor().darkened(0.2)
	# 	c = Color.WEB_GRAY
	# 	# Two triangles directly between hexes
	# 	addTri(st, verts_outer[next].left, verts_inner[next], verts_inner[curr], c)
	# 	addTri(st, verts_outer[next].left, verts_inner[curr], verts_outer[curr].right, c.darkened(0.3))

	# # Connection for corner area for each hex corner direction
	# for corner_dir in HexDir.values():
	# 	#c = Utility.randColor().darkened(0.2)
	# 	c = Color.DARK_GRAY
	# 	# Two triangles between inner point, outer center point and outer left/right
	# 	addTri(st, verts_inner[corner_dir], verts_outer[corner_dir].left, verts_outer[corner_dir].center, c)
	# 	addTri(st, verts_inner[corner_dir], verts_outer[corner_dir].center, verts_outer[corner_dir].right, c.darkened(0.3))

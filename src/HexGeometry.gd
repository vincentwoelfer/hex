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
	st.set_normal(Vector3.UP)

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
	var verts_center := generateCenterPoints(HexConst.extra_verts_per_center)

	# Adjust height of inner ring
	for i in range(verts_inner.size()):
		var h_var := 0.05
		verts_inner[i] += Utility.randCircularOffset(HexConst.inner_radius * 0.04)
		verts_inner[i].y += clamp(randfn(0.0, h_var), -h_var, h_var)

	# Adjust center vertices
	for i in range(verts_center.size()):
		var h_var := 0.07
		verts_center[i] += Utility.randCircularOffset(HexConst.inner_radius * 0.1)
		verts_center[i].y += clamp(randfn(0.0, h_var), -h_var, h_var)
	
	# Adjust height of outer vertices according do adjacent tiles
	# We do this per corner!
	for i in range(verts_outer.size()):
		verts_outer[i].y -= HexConst.height

	#########################################
	# Triangles for inner Hex Surface
	#########################################
	var col := Color.FOREST_GREEN

	# Generate PackedVec2Array
	var verts_center_packed: PackedVector2Array = []
	for v in verts_inner:
		verts_center_packed.append(Utility.toVec2(v))
	for v in verts_center:
		verts_center_packed.append(Utility.toVec2(v))

	var indices: PackedInt32Array = Geometry2D.triangulate_delaunay(verts_center_packed)

	var n_inner := verts_inner.size()

	for i in range(0, indices.size(), 3):
		var i1 := indices[i]
		var i2 := indices[i + 1]
		var i3 := indices[i + 2]

		var p1 := verts_inner[i1] if i1 < n_inner else verts_center[i1 - n_inner]
		var p2 := verts_inner[i2] if i2 < n_inner else verts_center[i2 - n_inner]
		var p3 := verts_inner[i3] if i3 < n_inner else verts_center[i3 - n_inner]

		# Check if triangle is valid and skip if not. Invalid if:
		# - Triangle consists of only circle-edge (certs_inner) points
		# - Triangle points "inwards". e.g. the covered area lies outside of the circle
		var all_vertices_on_circle := i1 < n_inner and i2 < n_inner and i3 < n_inner
		if all_vertices_on_circle and triangle_points_inwards(verts_inner, i1, i2, i3):
			continue

		triangles.append(Triangle.new(p1, p2, p3, Utility.randColorVariation(col, 0.05)))

	#########################################
	# Triangles for outer Hex Surface
	#########################################
	var size_inner := verts_inner.size()
	var size_outer := verts_outer.size()

	# Per Side
	for x in range(6):
		col = Utility.getDistincHexColor(x)

		# start inner
		var i := x * (1 + HexConst.extra_verts_per_side)
		# start outer
		var j := x * (3 + HexConst.extra_verts_per_side)

		# end inner
		var n1 := i + 1 + HexConst.extra_verts_per_side
		# end outer
		var n2 := j + 3 + HexConst.extra_verts_per_side
		
		while i < n1 or j < n2:
			var outer_is_clockwise_further := Utility.isClockwiseOrder(verts_inner[i % size_inner], verts_outer[j % size_outer])

			if j == n2 or (i < n1 and outer_is_clockwise_further):
				triangles.append(Triangle.new(verts_inner[i % size_inner], verts_outer[j % size_outer], verts_inner[(i + 1) % size_inner], Utility.randColorVariation(col)))
				i += 1
			else:
				triangles.append(Triangle.new(verts_inner[i % size_inner], verts_outer[j % size_outer], verts_outer[(j + 1) % size_outer], Utility.randColorVariation(col)))
				j += 1
				

func generateCenterPoints(num: int) -> Array[Vector3]:
	var points: Array[Vector3] = []

	# Adjust to ensure points stay within the hexagon
	var ring_radius := HexConst.inner_radius * 0.6

	# Distribute along the first ring
	for i in range(num):
		var angle := TAU * i / num
		points.append(Utility.vec3FromRadiusAngle(ring_radius, angle))

	return points


func triangle_points_inwards(verts_inner: Array[Vector3], i1: int, i2: int, i3: int) -> bool:
	var size := verts_inner.size()
	var indices: Array[int] = [i1, i2, i3]
	indices.sort()

	# Triangle can only point inwards if i1-i3 are consecutive
	if not ((indices[0] + 1) % size == indices[1] and (indices[1] + 1) % size == indices[2]):
		return false

	# => vertices are consecutive
	# Check that center-Vertex must be further from circle-center (ZERO) than only one of the others
	var dist_left := Utility.toVec2(verts_inner[indices[0]]).distance_to(Vector2.ZERO)
	var dist_center := Utility.toVec2(verts_inner[indices[1]]).distance_to(Vector2.ZERO)
	var dist_right := Utility.toVec2(verts_inner[indices[2]]).distance_to(Vector2.ZERO)
	
	# Inwards if center is smaller than both other vertices
	return dist_center <= dist_left and dist_center <= dist_right

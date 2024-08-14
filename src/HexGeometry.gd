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
	EventBus.Signal_HexConstChanged.connect(generate)
	generate()

func generate() -> void:
	#assert(adjacent.size() == 6)
	#adjacent.resize(6)
	#adjacent.assign(range(7).filter(func(item: int) -> int: return item if item != null else 0))
	#adjacent = adjacent.map(func(item: int) -> int: return item if item != null else 0)

	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	#########################################

	var verts_inner := Utility.generateFullHexagonNoCorners(HexConst.inner_radius, HexConst.extra_verts_per_side, HexConst.core_circle_smooth_strength)
	var verts_outer := Utility.generateFullHexagonWithCorners(HexConst.inner_radius, HexConst.outer_radius, HexConst.extra_verts_per_side)

	for i in range(verts_inner.size()):
		var h_var := 0.05
		verts_inner[i].y += clamp(randfn(0.0, HexConst.height * h_var), HexConst.height * -h_var, HexConst.height * h_var)
		verts_inner[i] += Utility.randCircularOffset(HexConst.inner_radius * 0.04)
		

	# Adjust height of outer vertices according do adjacent tiles.
	# We do this per corner!
	for i in range(verts_outer.size()):
		verts_outer[i].y -= HexConst.height

	# for corner_dir in HexDir.values():
	# 	var left_adjacent := adjacent[HexDir.prev(corner_dir)]
	# 	var right_adjacent := adjacent[corner_dir]
	# 	var height_left := HexConst.transition_height(left_adjacent)
	# 	var height_right := HexConst.transition_height(right_adjacent)

	# 	# Take left as reference and compute from that perspective
	# 	var left_to_right_adjacent := right_adjacent - left_adjacent
	# 	var height_from_left_to_right := HexConst.transition_height(left_to_right_adjacent)

	# 	# Adjust height by difference from our perspective to left
	# 	var height_left_hex := left_adjacent * HexConst.height
	# 	var height_opposite := height_left_hex + height_from_left_to_right

	# 	# Now center height is simply those 3 weighted
	# 	var height_center := (height_left + height_right + height_opposite) / 3.0

	# 	verts_outer[corner_dir].left.y = height_left
	# 	verts_outer[corner_dir].right.y = height_right
	# 	verts_outer[corner_dir].center.y = height_center

	#########################################
	# Inner Hex Surface
	#########################################
	#var c := Utility.randColor()
	var col := Color.FOREST_GREEN

	# # Generate PackedVec2Array
	# var verts_inner_packed: PackedVector2Array = []
	# for v in verts_inner:
	# 	verts_inner_packed.append(Utility.toVec2(v))
	# var indices: PackedInt32Array = Geometry2D.triangulate_delaunay(verts_inner_packed)

	# for i in range(0, indices.size(), 3):
	# 	var i1 := indices[i]
	# 	var i2 := indices[i + 1]
	# 	var i3 := indices[i + 2]
	# 	addTri(st, verts_inner[i1], verts_inner[i2], verts_inner[i3], Utility.randColorVariation(col))

	#########################################
	# Outer Hex Surface
	#########################################
	col = Color.WEB_GRAY

	var verts_combined_packed: PackedVector2Array = []
	for v in verts_inner:
		verts_combined_packed.append(Utility.toVec2(v))
	for v in verts_outer:
		verts_combined_packed.append(Utility.toVec2(v))
	var indices := Geometry2D.triangulate_delaunay(verts_combined_packed)

	for i in range(0, indices.size(), 3):
		# var i1 := verts_inner[indices[i]] if i <= verts_inner.size() else verts_outer[indices[i - verts_inner.size()]]
		# var i2 := indices[i+1]
		# var i3 := indices[i+2]
		var a: Vector3
		var b: Vector3
		var c: Vector3

		var all_inner := true

		if indices[i] < verts_inner.size():
			a = verts_inner[indices[i]]
		else:
			all_inner = false
			a = verts_outer[indices[i] - verts_inner.size()]

		if indices[i + 1] < verts_inner.size():
			b = verts_inner[indices[i + 1]]
		else:
			all_inner = false
			b = verts_outer[indices[i + 1] - verts_inner.size()]

		if indices[i + 2] < verts_inner.size():
			c = verts_inner[indices[i + 2]]
		else:
			all_inner = false
			c = verts_outer[indices[i + 2] - verts_inner.size()]

		if all_inner:
			addTri(st, a, b, c, Color.FOREST_GREEN)
		else:
			addTri(st, a, b, c, Utility.randColorVariation(Color.ORCHID))

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


func addTri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	if not Geometry2D.is_polygon_clockwise(PackedVector2Array([Utility.toVec2(a), Utility.toVec2(b), Utility.toVec2(c)])):
		st.set_color(color)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)
	else:
		st.set_color(color)
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)

func addQuad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, darken: float = 0.0) -> void:
	addTri(st, a, b, c, color)
	addTri(st, a, c, d, color.darkened(darken))

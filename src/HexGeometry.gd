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

	var vertsInner := Utility.getRegularHexCornerArray(HexConst.inner_radius)
	var vertsOuter := Utility.getTransitionHexCornersArray(HexConst.inner_radius, HexConst.outer_radius)

	# Adjust height of outer vertices according do adjacent tiles.
	# We do this per corner!
	for corner_dir in HexDir.values():
		var left_adjacent := adjacent[HexDir.prev(corner_dir)]
		var right_adjacent := adjacent[corner_dir]
		var height_left := HexConst.transition_height(left_adjacent)
		var height_right := HexConst.transition_height(right_adjacent)

		# Lake left as reference and compute from that perspective
		var left_to_right_adjacent := right_adjacent - left_adjacent
		var height_from_left_to_right := HexConst.transition_height(left_to_right_adjacent)
		
		# Adjust height by difference from our perspective to left
		var height_left_hex := left_adjacent * HexConst.height
		var height_opposite := height_left_hex + height_from_left_to_right
		
		# Now center height is simply those 3 weighted
		var height_center := (height_left + height_right + height_opposite) / 3.0

		vertsOuter[corner_dir].left.y = height_left
		vertsOuter[corner_dir].right.y = height_right
		vertsOuter[corner_dir].center.y = height_center

	# Inner Hex Surface
	#var c := Utility.randColor()
	var c := Color.FOREST_GREEN
	addTri(st, vertsInner[0], vertsInner[1], vertsInner[5], c.darkened(0.0))
	addTri(st, vertsInner[1], vertsInner[2], vertsInner[5], c.darkened(0.0))
	addTri(st, vertsInner[2], vertsInner[4], vertsInner[5], c.darkened(0.0))
	addTri(st, vertsInner[2], vertsInner[3], vertsInner[4], c.darkened(0.0))

	# Connection Inner <-> Outer for each HexDirection
	for curr in HexDir.values():
		var next := HexDir.next(curr)
		#c = Utility.randColor().darkened(0.2)
		c = Color.WEB_GRAY
		# Two triangles directly between hexes
		addTri(st, vertsOuter[next].left, vertsInner[next], vertsInner[curr], c)
		addTri(st, vertsOuter[next].left, vertsInner[curr], vertsOuter[curr].right, c.darkened(0.3))

	# Connection for corner area for each hex corner direction
	for corner_dir in HexDir.values():
		#c = Utility.randColor().darkened(0.2)
		c = Color.DARK_GRAY
		# Two triangles between inner point, outer center point and outer left/right
		addTri(st, vertsInner[corner_dir], vertsOuter[corner_dir].left, vertsOuter[corner_dir].center, c)

		addTri(st, vertsInner[corner_dir], vertsOuter[corner_dir].center, vertsOuter[corner_dir].right, c.darkened(0.3))

		
	#########################################
	# Removes duplicates. Use later to not mask real number of vertices
	#st.index()

	st.generate_normals()
	terrainMesh.mesh = st.commit()
	#terrainMesh.create_debug_tangents()

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

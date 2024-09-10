@tool
class_name HexGeometry
extends Node3D

# Class variables
var terrainMesh: MeshInstance3D
var triangles: Array[Triangle]
var sampler: PolygonSurfaceSampler


class AdjacentHex:
	var height: int
	var type: String # unused for now

	func _init(height_: int, type_: String) -> void:
		self.height = height_
		self.type = type_

	
# Input Variables
var adjacent_hex: Array[AdjacentHex] = [AdjacentHex.new(3, ""), AdjacentHex.new(3, ""), AdjacentHex.new(1, ""), AdjacentHex.new(1, ""), AdjacentHex.new(0, ""), AdjacentHex.new(-1, "")]
var height: int = 1


func _init() -> void:
	terrainMesh = MeshInstance3D.new()
	terrainMesh.name = "TerrainMesh"
	terrainMesh.material_override = load("res://DefaultMaterial.tres")

	add_child(terrainMesh, true)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	EventBus.Signal_HexConstChanged.connect(generate)
	generate()


func _process(delta: float) -> void:
	pass
	#DebugDraw3D.draw_arrowhead(transform, Color.RED, 99999)


func generate() -> void:
	var verts_inner := generateFullHexagonNoCorners(HexConst.inner_radius, HexConst.extra_verts_per_side, HexConst.core_circle_smooth_strength)
	var verts_outer := generateFullHexagonWithCorners(HexConst.inner_radius, HexConst.outer_radius, HexConst.extra_verts_per_side)
	var verts_center := generateCenterPoints(HexConst.extra_verts_per_center)

	#########################################
	# Adjust vertex heights
	#########################################
	# Adjust height of inner ring
	for i in range(verts_inner.size()):
		var h_var := 0.05
		verts_inner[i] += Util.randCircularOffset(HexConst.inner_radius * 0.04)
		verts_inner[i].y += clamp(randfn(0.0, h_var), -h_var, h_var)

	# Adjust center vertices
	for i in range(verts_center.size()):
		var h_var := 0.07
		verts_center[i] += Util.randCircularOffset(HexConst.inner_radius * 0.1)
		verts_center[i].y += clamp(randfn(0.0, h_var), -h_var, h_var)
	
	# Adjust outer/transitional vertex heights
	modifyOuterVertexHeights(verts_outer, adjacent_hex, height)

	#########################################
	# Triangulate
	#########################################
	self.triangles.clear()
	self.triangles += triangulateCenter(verts_center, verts_inner)
	self.triangles += triangulateOuter(verts_inner, verts_outer)

	# Add triangles to mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)

	for tri in triangles:
		tri.addToSurfaceTool(st)

	# Removes duplicates and actually create mesh
	st.index()
	st.generate_normals()
	terrainMesh.mesh = st.commit()

	# Recreate triangle sampler
	self.sampler = PolygonSurfaceSampler.new(self.triangles)

	#for i in range(50):
	#	addSphere(self.sampler.get_random_point())
	addRocks(self.sampler.get_random_point_transform())
	
	# Only for debugging
	#terrainMesh.create_debug_tangents()

	# Only for statistics output-
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(terrainMesh.mesh as ArrayMesh, 0)
	#print("Generated HexGeometry: ", mdt.get_vertex_count(), " vertices, ", mdt.get_face_count(), " faces")


func addRocks(transform_: Transform3D) -> void:
	var mesh_scene: PackedScene
	mesh_scene = load("res://assets/meshes/rocks1/scene.gltf") # Load the specific mesh scene

	var mesh_instance := mesh_scene.instantiate() as Node3D
	add_child(mesh_instance)
	mesh_instance.transform = transform_

	#var arrow_instance := Arrow3D.new()
	#arrow_instance.transform = transform_
	#add_child(arrow_instance)
	

func addSphere(pos: Vector3) -> void:
	 # Create a new MeshInstance3D
	var sphere_instance := MeshInstance3D.new()

	# Create a SphereMesh
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.07 # Set radius of the sphere
	sphere_mesh.height = 0.07 # Adjust height if needed
	sphere_mesh.radial_segments = 4 # Number of radial segments (more = smoother)
	sphere_mesh.rings = 4 # Number of rings (more = smoother)
	
	# Bright red material (unshaded).
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0)
	sphere_mesh.surface_set_material(0, material)

	sphere_instance.mesh = sphere_mesh

	# Add the sphere to the current scene
	add_child(sphere_instance)
	# Optionally, you can adjust its position
	sphere_instance.position = pos


static func modifyOuterVertexHeights(verts_outer: Array[Vector3], adjacent: Array[AdjacentHex], own_height: int) -> void:
	# Adjust CORNER vertices according to both adjacent tiles
	for i in range(6):
		var corner_height: int = 0
		var corner_vertex_index := i * (3 + HexConst.extra_verts_per_side)

		# Get adjacent and create sorted heights array
		var adj: Array[AdjacentHex] = [adjacent[(i - 1 + 6) % 6], adjacent[i]]
		var h: Array[int] = [own_height, adj[0].height, adj[1].height]
		h.sort()

		# Check for special case where one adjacent is not valid (map border).
		# If two are not valid all are set to own height and this is handled by the default case
		var num_invalid: int = adj.reduce(func(accum: int, elem: AdjacentHex, ) -> int: return accum + 1 if elem.type == 'invalid' else accum, 0)
		#var num_invalid: int = 0
		if num_invalid == 1:
			var adj_height := 0
			if adj[0].type != 'invalid':
				adj_height = adj[0].height
			else:
				adj_height = adj[1].height

			var y: float = HexConst.transition_height(adj_height - own_height)
			verts_outer[corner_vertex_index].y = y
		else:
			# All three same
			if h[0] == h[1] and h[1] == h[2]:
				corner_height = h[0]
			# Two are same -> use the two
			elif h[0] == h[1] or h[0] == h[2] or h[1] == h[2]:
				if h[0] == h[1]:
					corner_height = h[0]
				else:
					corner_height = h[2]
			# All different -> use middle one
			else:
				corner_height = h[1]

			# Normalize relative to own height. Dont use transition_height here, directly compute height of the neighbouring cell (or own if h=0)
			var y: float = (corner_height - own_height) * HexConst.height
			verts_outer[corner_vertex_index].y = y


	# For each DIRECTION: Adjust height of outer vertices according do adjacent tiles.
	# This does not modify the corner vertices
	for i in range(6):
		# Determine height (normalize relative to own height)
		var y: float = HexConst.transition_height(adjacent[i].height - own_height)

		# +1 to ommit corners
		var start := i * (3 + HexConst.extra_verts_per_side) + 1
		var end := (i + 1) * (3 + HexConst.extra_verts_per_side)

		for x in range(start, end):
			verts_outer[x].y = y


static func triangulateCenter(verts_center: Array[Vector3], verts_inner: Array[Vector3], ) -> Array[Triangle]:
	var tris: Array[Triangle] = []
	var col := Color.FOREST_GREEN

	# Generate PackedVec2Array
	var verts_center_packed: PackedVector2Array = []
	var verts_polygon_packed: PackedVector2Array = []
	for v in verts_inner:
		verts_center_packed.append(Util.toVec2(v))
		verts_polygon_packed.append(Util.toVec2(v))
	for v in verts_center:
		verts_center_packed.append(Util.toVec2(v))

	var indices: PackedInt32Array = Geometry2D.triangulate_delaunay(verts_center_packed)

	var s_in := verts_inner.size()

	for i in range(0, indices.size(), 3):
		# Conevert result-indices (i) into original vertex-array indices
		var i1 := indices[i]
		var i2 := indices[i + 1]
		var i3 := indices[i + 2]

		var p1 := verts_inner[i1] if i1 < s_in else verts_center[i1 - s_in]
		var p2 := verts_inner[i2] if i2 < s_in else verts_center[i2 - s_in]
		var p3 := verts_inner[i3] if i3 < s_in else verts_center[i3 - s_in]

		# Check if triangle is valid and skip if not. Invalid if one midpoint is outside of polygon formed by inner_verts
		var all_vertices_on_circle := i1 < s_in and i2 < s_in and i3 < s_in
		if all_vertices_on_circle and Util.isTriangleOutsideOfPolygon([p1, p2, p3], verts_polygon_packed):
			continue
			
		tris.append(Triangle.new(p1, p2, p3, Util.randColorVariation(col, 0.05)))
	
	return tris


static func triangulateOuter(verts_inner: Array[Vector3], verts_outer: Array[Vector3]) -> Array[Triangle]:
	var tris: Array[Triangle] = []
	var s_in := verts_inner.size()
	var s_out := verts_outer.size()

	# Per Side
	for x in range(6):
		var col := Util.getDistincHexColor(x)

		# start inner
		var i := x * (1 + HexConst.extra_verts_per_side)
		# start outer
		var j := x * (3 + HexConst.extra_verts_per_side)

		# end inner
		var n1 := (x + 1) * (1 + HexConst.extra_verts_per_side)
		# end outer
		var n2 := (x + 1) * (3 + HexConst.extra_verts_per_side) - 1

		# Triangulate start-corner manually here
		tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], Util.randColorVariation(col)))
		j += 1
		
		# Only transition area between hexes, without corners!
		while i < n1 or j < n2:
			var c := Util.randColorVariation(col)
			var outer_is_clockwise_further := Util.isClockwiseOrder(verts_inner[i % s_in], verts_outer[j % s_out])

			if j == n2 or (i < n1 and outer_is_clockwise_further):
				tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_inner[(i + 1) % s_in], c))
				i += 1
			else:
				tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], c))
				j += 1

		# Triangulate end-corner manually here
		tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], Util.randColorVariation(col)))

	return tris
				

static func generateCenterPoints(num: int) -> Array[Vector3]:
	var points: Array[Vector3] = []

	# Adjust to ensure points stay within the hexagon
	var ring_radius := HexConst.inner_radius * 0.6

	# Distribute along the first ring
	for i in range(num):
		var angle := TAU * i / num
		points.append(Util.vec3FromRadiusAngle(ring_radius, angle))

	return points


static func doesTrianglePointsInwards(verts_inner: Array[Vector3], i1: int, i2: int, i3: int) -> bool:
	var size := verts_inner.size()
	var indices: Array[int] = [i1, i2, i3]
	indices.sort()

	# Triangle can only point inwards if i1-i3 are consecutive
	if not ((indices[0] + 1) % size == indices[1] and (indices[1] + 1) % size == indices[2]):
		return false

	# => vertices are consecutive
	# Check that center-Vertex must be further from circle-center (ZERO) than only one of the others
	var dist_left := Util.toVec2(verts_inner[indices[0]]).distance_to(Vector2.ZERO)
	var dist_center := Util.toVec2(verts_inner[indices[1]]).distance_to(Vector2.ZERO)
	var dist_right := Util.toVec2(verts_inner[indices[2]]).distance_to(Vector2.ZERO)
	
	# Inwards if center is smaller than both other vertices
	return dist_center <= dist_left and dist_center <= dist_right


static func generateFullHexagonNoCorners(r: float, extra_verts_per_side: int, smooth_strength: float) -> Array[Vector3]:
	var total_verts: int = 6 * (1 + extra_verts_per_side)
	var angle_step: float = 2.0 * PI / total_verts
	var vertices: Array[Vector3] = []

	for i in range(total_verts):
		var angle := i * angle_step
		vertices.append(Util.getHexVertex(r, angle, smooth_strength))

	assert(vertices.size() == total_verts)
	return vertices


# Compute the 3 Vector3 points for one hex corner
static func getThreeHexCornerVertices(r_inner: float, r_outer: float, angle: float) -> Array[Vector3]:
	#assert(is_zero_approx(fmod(angle, PI / 3.0)), "Angle must be a multiple of PI/3!")
	#assert(r_outer > r_inner)

	# No smooth strength since corner
	var inner_corner := Util.getHexVertex(r_inner, angle)
	var outer_corner := Util.getHexVertex(r_outer, angle)

	# Distance between the two interior circles of the inner and outer radius of the hex
	var dist := (r_outer * sqrt(3.0) / 2.0) - (r_inner * sqrt(3.0) / 2.0)

	# 30deg = PI/6.0 = one half of a hexagon segment
	var left_angle := angle - PI / 6.0
	var right_angle := angle + PI / 6.0
	var left := inner_corner + Util.vec3FromRadiusAngle(dist, left_angle)
	var right := inner_corner + Util.vec3FromRadiusAngle(dist, right_angle)

	return [left, outer_corner, right]


static func generateFullHexagonWithCorners(r_inner: float, r_outer: float, extra_verts_per_side: int) -> Array[Vector3]:
	var corners: Array = []
	for angle in Util.getSixHexAngles():
		corners.append(getThreeHexCornerVertices(r_inner, r_outer, angle))

	# Determine angle difference (from hex center) between the corners and their neighbours
	var corner: Vector3 = corners[0][1]
	var corner_neighbour: Vector3 = corners[0][2]
	var corner_angle_offset: float = abs(Util.toVec2(corner).angle_to(Util.toVec2(corner_neighbour)))

	# Compute how many additional vertices per side and at which angles.
	# Basically we reduce the 60deg hex-segment on both sides by corner_angle_offset
	# to get the center part of the side which is the same as the inner hexagon.
	var side_angle_range := (PI / 3.0 - 2.0 * corner_angle_offset)
	var side_angle_step := side_angle_range / (extra_verts_per_side + 1)

	# Put everything together
	var vertices: Array[Vector3] = []
	for i in range(6):
		# Append corner points. For first, ommit the first one because its actually the last one of the whole hexagon
		if i == 0:
			vertices.append(corners[i][1])
			vertices.append(corners[i][2])
		else:
			vertices.append(corners[i][0])
			vertices.append(corners[i][1])
			vertices.append(corners[i][2])

		# Add additional vertices per side
		var side_angle_start := (i * PI / 3.0) + corner_angle_offset
		for j in range(1, extra_verts_per_side + 1):
			var angle := side_angle_start + (j * side_angle_step)
			vertices.append(Util.getHexVertex(r_outer, angle))

	# Append first(left) corner vertex of first corner at the end
	vertices.append(corners[0][0])

	assert(vertices.size() == 6 * (3 + extra_verts_per_side))
	return vertices

@tool
class_name HexGeometry
extends Node3D

# Class variables
var mesh: Mesh
var triangles: Array[Triangle]
var samplerAll: PolygonSurfaceSampler
var samplerHorizontal: PolygonSurfaceSampler
var samplerVertical: PolygonSurfaceSampler

# Input Variables. The height is absolute!
var transitions: Array[HexTileTransition]
var height: int

# Intermediate variables
var verts_center: Array[Vector3]
var verts_inner: Array[Vector3]
var verts_outer: Array[Vector3]


func _init(height_: int, transitions_: Array[HexTileTransition]) -> void:
	self.height = height_
	self.transitions = transitions_


func get_corner_vertex(i: int) -> Vector3:
	return verts_outer[get_corner_index(i)]

func get_corner_index(i: int) -> int:
	return i * HexConst.total_verts_per_side()


func generate() -> void:
	verts_center = generateCenterPoints(HexConst.extra_verts_per_center)
	verts_inner = generateInnerHexagonNoCorners(HexConst.inner_radius, HexConst.extra_verts_per_side, HexConst.core_circle_smooth_strength)
	verts_outer = generateOuterHexagonWithCorners(HexConst.inner_radius, HexConst.outer_radius, HexConst.extra_verts_per_side)

	#########################################
	# Adjust vertex heights
	#########################################
	# Adjust outer/transitional vertex heights
	modifyOuterVertexHeights()
	modifyInnerAndCenterVertexHeights()
	modifyOuterVertexHeightsAgain()

	#########################################
	# Triangulate
	#########################################
	triangles.clear()
	triangles += triangulateCenter()
	triangles += triangulateOuter()

	# Add triangles to mesh
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)

	for tri in triangles:
		tri.addToSurfaceTool(st)

	# Removes duplicates and actually create mesh
	st.index()
	st.generate_normals()
	mesh = st.commit()

	# Recreate triangle samplerAll
	self.samplerAll = PolygonSurfaceSampler.new(self.triangles)
	self.samplerHorizontal = PolygonSurfaceSampler.new(self.triangles)
	self.samplerHorizontal.filter_max_incline(45)

	self.samplerVertical = PolygonSurfaceSampler.new(self.triangles)
	self.samplerVertical.filter_min_incline(45)


func modifyInnerAndCenterVertexHeights() -> void:
	# Set height according to weightes average of hex corners
	for i in range(verts_center.size()):
		verts_center[i].y = lerpf(verts_center[i].y, getInterpolatedHeightInside(verts_center[i]), HexConst.smooth_height_factor)

	for i in range(verts_inner.size()):
		verts_inner[i].y = lerpf(verts_inner[i].y, getInterpolatedHeightInside(verts_inner[i]), HexConst.smooth_height_factor)


func modifyOuterVertexHeightsAgain() -> void:
	for i in range(verts_outer.size()):
		var is_corner: bool = i % HexConst.total_verts_per_side() == 0
		
		if not is_corner:
			var prev_corner: int = i - (i % HexConst.total_verts_per_side())
			var next_corner: int = (prev_corner + HexConst.total_verts_per_side()) % verts_outer.size()

			var t := compute_t_on_line_segment(Util.toVec2(verts_outer[i]), Util.toVec2(verts_outer[prev_corner]), Util.toVec2(verts_outer[next_corner]))
			var h := (1.0 - t) * verts_outer[prev_corner].y + t * verts_outer[next_corner].y

			verts_outer[i].y = lerpf(verts_outer[i].y, h, HexConst.smooth_height_factor)


func getInterpolatedHeightInside(p: Vector3) -> float:
	var weights := computeBarycentricWeightsForInsidePoint(p)
	var h: float = 0.0
	for i in range(6):
		h += weights[i] * get_corner_vertex(i).y * getCornerWeightsAccordingToTransitionTypes(i)

	return h


func getCornerWeightsAccordingToTransitionTypes(corner_index: int) -> float:
	# Get both transitions
	var trans: Array[HexTileTransition] = [transitions[(corner_index - 1 + 6) % 6], transitions[corner_index]]

	# Average transition types
	return (trans[0].get_weight() + trans[1].get_weight()) / 2.0


# Computes the height of the corner vertex bordering these two transitions.
# Relative = already as float and minus own height -> as vertex coordinates
func getCornerVertexHeight(trans: Array[HexTileTransition]) -> float:
	# Add transitions to array
	var heights: Array[int] = [self.height]
	for t in trans:
		if t.type != HexTileTransition.Type.INVALID:
			heights.append(t.height_other)

	var accum := 0.0

	for h in heights:
		accum += h
	var avg := accum / heights.size()

	var final_height := (avg - self.height) * HexConst.height
	
	#var final_height := HexConst.transition_height(avg - self.height)

	return final_height


func modifyOuterVertexHeights() -> void:
	# For each CORNER: Adjust vertices according to both adjacent tiles
	for i in range(6):
		# Get both transitions and create sorted heights array
		var trans: Array[HexTileTransition] = [transitions[(i - 1 + 6) % 6], transitions[i]]

		# Actually set height
		verts_outer[get_corner_index(i)].y = getCornerVertexHeight(trans)


	# For each DIRECTION: Adjust height of outer vertices according do adjacent tiles.
	# This does not modify the corner vertices
	for i in range(6):
		# Determine height (normalize relative to own height)
		var y: float = HexConst.transition_height(transitions[i].height_other - self.height)

		# +1 to ommit corners
		var start := get_corner_index(i) + 1
		var end := get_corner_index(i + 1)

		for x in range(start, end):
			verts_outer[x].y = y


func triangulateCenter() -> Array[Triangle]:
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

		tris.append(Triangle.new(p1, p2, p3, Colors.randColorVariation(col, 0.05)))

	return tris


func triangulateOuter() -> Array[Triangle]:
	var tris: Array[Triangle] = []
	var s_in := verts_inner.size()
	var s_out := verts_outer.size()

	# Per Side
	for x in range(6):
		var col := Colors.getDistincHexColor(x)

		# start inner & outer
		var i := x * (1 + HexConst.extra_verts_per_side)
		var j := x * HexConst.total_verts_per_side()

		# end inner & outer
		var n1 := (x + 1) * (1 + HexConst.extra_verts_per_side)
		var n2 := (x + 1) * HexConst.total_verts_per_side() - 1

		# Triangulate start-corner manually here
		tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], Colors.randColorVariation(col)))
		j += 1

		# Only transition area between hexes, without corners!
		while i < n1 or j < n2:
			var c := Colors.randColorVariation(col)
			var outer_is_clockwise_further := Util.isClockwiseOrder(verts_inner[i % s_in], verts_outer[j % s_out])

			if j == n2 or (i < n1 and outer_is_clockwise_further):
				tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_inner[(i + 1) % s_in], c))
				i += 1
			else:
				tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], c))
				j += 1

		# Triangulate end-corner manually here
		tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], Colors.randColorVariation(col)))

	return tris


func computeBarycentricWeightsForInsidePoint(p_3d: Vector3) -> Array[float]:
	# See http://www.geometry.caltech.edu/pubs/MHBD02.pdf

	var p := Util.toVec2(p_3d)
	var weights: Array[float]
	var weight_sum: float = 0
	var on_border := false

	for i in range(6):
		var w: float
		var prev := (i - 1 + 6) % 6
		var next := (i + 1) % 6
		var corner_i := Util.toVec2(get_corner_vertex(i))
		var corner_prev := Util.toVec2(get_corner_vertex(prev))
		var corner_next := Util.toVec2(get_corner_vertex(next))

		# TODO maybe remove this code if its slow and not needed!
		# Check if p is very close to one of the hexagon border segments for this corner i
		if is_point_near_line_segment(p, corner_prev, corner_i):
			var t := compute_t_on_line_segment(p, corner_prev, corner_i)
			w = t * 100
			on_border = true

		elif is_point_near_line_segment(p, corner_i, corner_next):
			var t := compute_t_on_line_segment(p, corner_next, corner_i)
			w = t * 100
			on_border = true

		else:
			var tan1 := cotangent(p, corner_i, corner_prev)
			var tan2 := cotangent(p, corner_i, corner_next)
			w = (tan1 + tan2) / (p - corner_i).length_squared()

		weights.push_back(w)
		weight_sum += w

	# Normalize weights
	for i in range(6):
		if on_border and weights[i] < 0.5:
			weight_sum -= weights[i]
			weights[i] = 0.0

		weights[i] /= weight_sum
	
	return weights


func doesVertsInnerTrianglePointsInwards(i1: int, i2: int, i3: int) -> bool:
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


static func generateInnerHexagonNoCorners(r: float, extra_verts_per_side: int, smooth_strength: float) -> Array[Vector3]:
	var total_verts: int = 6 * (1 + extra_verts_per_side)
	var angle_step: float = 2.0 * PI / total_verts
	var vertices: Array[Vector3] = []

	for i in range(total_verts):
		var angle := i * angle_step
		vertices.append(Util.getHexVertex(r, angle, smooth_strength))

	assert(vertices.size() == total_verts)
	return vertices


static func generateOuterHexagonWithCorners(r_inner: float, r_outer: float, extra_verts_per_side: int) -> Array[Vector3]:
	var corner_verts: Array = []
	for angle in Util.getSixHexAngles():
		corner_verts.append(getThreeHexCornerVertices(r_inner, r_outer, angle))

	# Determine angle difference (from hex center) between the corner_verts and their neighbours
	var corner: Vector3 = corner_verts[0][1]
	var corner_neighbour: Vector3 = corner_verts[0][2]
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
			vertices.append(corner_verts[i][1])
			vertices.append(corner_verts[i][2])
		else:
			vertices.append(corner_verts[i][0])
			vertices.append(corner_verts[i][1])
			vertices.append(corner_verts[i][2])

		# Add additional vertices per side
		var side_angle_start := (i * PI / 3.0) + corner_angle_offset
		for j in range(1, extra_verts_per_side + 1):
			var angle := side_angle_start + (j * side_angle_step)
			vertices.append(Util.getHexVertex(r_outer, angle))

	# Append first(left) corner vertex of first corner at the end
	vertices.append(corner_verts[0][0])

	assert(vertices.size() == 6 * (3 + extra_verts_per_side))
	return vertices


#########################################################################################
# Actual static functions
#########################################################################################
# Compute the 3 Vector3 points for one hex corner
static func getThreeHexCornerVertices(r_inner: float, r_outer: float, angle: float) -> Array[Vector3]:
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


static func generateCenterPoints(num: int) -> Array[Vector3]:
	var points: Array[Vector3] = []

	# Generate first point in center
	points.append(Vector3.ZERO)
	num -= 1

	# Adjust to ensure points stay within the hexagon
	var ring_radius := HexConst.inner_radius * 0.5

	# Distribute along the first ring
	for i in range(num):
		var angle := TAU * i / num
		points.append(Util.vec3FromRadiusAngle(ring_radius, angle))

	return points

# 0 = on a, 1 = on b
static func compute_t_on_line_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	return ap.dot(ab) / ab.dot(ab)


static func is_point_near_line_segment(p: Vector2, a: Vector2, b: Vector2) -> bool:
	const epsilon: float = 0.001
	var ab: Vector2 = b - a
	var ap: Vector2 = p - a
	var ab_len: float = ab.length()
	var cross_product: float = ab.cross(ap)
	var distance: float = abs(cross_product) / ab_len
	return distance <= epsilon * ab_len


static func cotangent(a: Vector2, b: Vector2, c: Vector2) -> float:
	var ba := a - b
	var bc := c - b
	return bc.dot(ba) / abs(bc.cross(ba))

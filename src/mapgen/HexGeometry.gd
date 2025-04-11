@tool
class_name HexGeometry
extends Node3D

# Class variables
var triangles: Array[Triangle]

# Input Variables. The height is absolute!
var input: HexGeometryInput

# Intermediate variables
var verts_center: PackedVector3Array
var verts_inner: PackedVector3Array
var verts_outer: PackedVector3Array


func _init(input_: HexGeometryInput) -> void:
	assert(input_ != null)
	assert(input_.generation_stage == HexGeometryInput.GenerationStage.COMPLETE)
	self.input = input_
	generate()


func generate() -> void:
	#########################################
	# Generate flat vertices (no height information)
	#########################################
	verts_center = generateCenterPoints(HexConst.extra_verts_per_center)
	verts_inner = generateInnerHexagonNoCorners(HexConst.inner_radius, HexConst.extra_verts_per_side, HexConst.core_circle_smooth_strength)
	verts_outer = generateOuterHexagonWithCorners(HexConst.inner_radius, HexConst.outer_radius, HexConst.extra_verts_per_side)

	#########################################
	# Set vertex heights
	#########################################
	setOuterVertexHeights()
	setInnerAndCenterVertexHeights()

	#########################################
	# Triangulate
	#########################################	
	triangles.clear()
	triangles += triangulateCenter()
	triangles += triangulateOuter()

	
func setInnerAndCenterVertexHeights() -> void:
	if HexConst.smooth_height_factor_inner == 0.0:
		return

	# Set height according to weighted average of hex corners
	for i in range(verts_center.size()):
		verts_center[i].y = lerpf(0.0, getInterpolatedHeightInside(verts_center[i]), HexConst.smooth_height_factor_inner)

	for i in range(verts_inner.size()):
		verts_inner[i].y = lerpf(0.0, getInterpolatedHeightInside(verts_inner[i]), HexConst.smooth_height_factor_inner)


func getInterpolatedHeightInside(p: Vector3) -> float:
	var weights := computeBarycentricWeightsForInsidePoint(p)
	var h: float = 0.0
	for dir in range(6):
		h += weights[dir] * input.corner_vertices_smoothing[dir].y
	return h


func setOuterVertexHeights() -> void:
	# For each CORNER: Take corner vertex height from input. No transition height here, corner_vertices[].height is already final height
	for dir in range(6):
		verts_outer[HexConst.dir_to_corner_index(dir)].y = input.corner_vertices[dir].y

	# For each DIRECTION: Adjust height of outer vertices according do adjacent tiles.
	# This does not modify the corner vertices
	for dir in range(6):
		# Determine height (normalize relative to own height)
		var base_height: float = HexConst.transition_height(input.transitions[dir].height_other - input.height)
		
		# +1 to ommit corners
		var start_idx := HexConst.dir_to_corner_index(dir) + 1
		var end_idx := HexConst.dir_to_corner_index(Util.as_dir(dir + 1))

		# Here we only need 2d x/z information so we can always use strict corner vertices
		var start_corner: Vector2 = Util.to_vec2(input.corner_vertices[dir])
		var end_corner: Vector2 = Util.to_vec2(input.corner_vertices[Util.as_dir(dir + 1)])

		# Loop over side vertices excluding actual corner vertices (these are set above)
		var x: int = start_idx
		while x != end_idx:
			var t := Util.compute_t_on_line_segment(Util.to_vec2(verts_outer[x]), start_corner, end_corner)
			var smoothed_height: float = (1.0 - t) * input.transitions[dir].smoothing_start_height + t * input.transitions[dir].smoothing_end_height
			verts_outer[x].y = lerpf(base_height, smoothed_height, HexConst.smooth_height_factor_outer)

			# Increment with wrap-around
			x = (x + 1) % verts_outer.size()


func triangulateCenter() -> Array[Triangle]:
	var tris: Array[Triangle] = []
	var col := Colors.get_distinct_hex_color_top_side()

	# Generate PackedVec2Array
	var verts_center_packed: PackedVector2Array = []
	var verts_polygon_packed: PackedVector2Array = []
	for v in verts_inner:
		verts_center_packed.append(Util.to_vec2(v))
		verts_polygon_packed.append(Util.to_vec2(v))
	for v in verts_center:
		verts_center_packed.append(Util.to_vec2(v))

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
		if all_vertices_on_circle and Util.is_triangle_outside_of_polygon([p1, p2, p3], verts_polygon_packed):
			continue

		tris.append(Triangle.new(p1, p2, p3, Colors.rand_variation(col)))

	return tris


func triangulateOuter() -> Array[Triangle]:
	var tris: Array[Triangle] = []
	var s_in := verts_inner.size()
	var s_out := verts_outer.size()

	# Per Side
	for dir in range(6):
		var sideColor := Colors.get_distinct_hex_color(dir)
		var corner_color := Colors.modify_color_for_corner_area(sideColor)
		sideColor = Colors.modify_color_for_transition_type(sideColor, input.transitions[dir].type)

		# start inner & outer
		var i := dir * (1 + HexConst.extra_verts_per_side)
		var j := dir * HexConst.total_verts_per_side()

		# end inner & outer
		var n1 := (dir + 1) * (1 + HexConst.extra_verts_per_side)
		var n2 := (dir + 1) * HexConst.total_verts_per_side() - 1

		# Triangulate start-corner manually here		
		tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], corner_color))
		j += 1

		# Only transition area between hexes, without corners!
		while i < n1 or j < n2:
			var col := Colors.rand_variation(sideColor)
			var outer_is_clockwise_further := Util.is_clockwise_order(verts_inner[i % s_in], verts_outer[j % s_out])

			if j == n2 or (i < n1 and outer_is_clockwise_further):
				tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_inner[(i + 1) % s_in], col))
				i += 1
			else:
				tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], col))
				j += 1

		# Triangulate end-corner manually here
		tris.append(Triangle.new(verts_inner[i % s_in], verts_outer[j % s_out], verts_outer[(j + 1) % s_out], corner_color))

	return tris
	

# Point must be strictly inside hexagon (not on borders)!
func computeBarycentricWeightsForInsidePoint(p_3d: Vector3) -> PackedFloat32Array:
	# See http://www.geometry.caltech.edu/pubs/MHBD02.pdf
	var p := Util.to_vec2(p_3d)
	var weights: PackedFloat32Array = []
	weights.resize(6)

	var weight_sum: float = 0.0
	var on_border := false

	for i in range(6):
		var w: float
		# Get corners as 2D
		var corner_i := Util.to_vec2(input.corner_vertices[i])
		var corner_prev := Util.to_vec2(input.corner_vertices[Util.as_dir(i - 1)])
		var corner_next := Util.to_vec2(input.corner_vertices[Util.as_dir(i + 1)])

		# TODO maybe remove this code if its slow and not needed!
		# Check if p is very close to one of the hexagon border segments for this corner i
		# if is_point_near_line_segment(p, corner_prev, corner_i):
		# 	var t := compute_t_on_line_segment(p, corner_prev, corner_i)
		# 	w = t * 100
		# 	on_border = true

		# elif is_point_near_line_segment(p, corner_i, corner_next):
		# 	var t := compute_t_on_line_segment(p, corner_next, corner_i)
		# 	w = t * 100
		# 	on_border = true

		# else:
		var tan1 := Util.cotangent(p, corner_i, corner_prev)
		var tan2 := Util.cotangent(p, corner_i, corner_next)
		w = (tan1 + tan2) / (p - corner_i).length_squared()

		weights[i] = w
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
	var dist_left := Util.to_vec2(verts_inner[indices[0]]).distance_to(Vector2.ZERO)
	var dist_center := Util.to_vec2(verts_inner[indices[1]]).distance_to(Vector2.ZERO)
	var dist_right := Util.to_vec2(verts_inner[indices[2]]).distance_to(Vector2.ZERO)

	# Inwards if center is smaller than both other vertices
	return dist_center <= dist_left and dist_center <= dist_right


func get_corner_vertex(i: int) -> Vector3:
	return verts_outer[HexConst.dir_to_corner_index(i)]


#########################################################################################
#########################################################################################
# Static functions
#########################################################################################
#########################################################################################
static func generateInnerHexagonNoCorners(r: float, extra_verts_per_side: int, smooth_strength: float) -> PackedVector3Array:
	var total_verts: int = 6 * (1 + extra_verts_per_side)
	var angle_step: float = 2.0 * PI / total_verts
	var vertices: PackedVector3Array = []

	for i in range(total_verts):
		var angle := i * angle_step
		vertices.append(Util.get_hex_vertex(r, angle, smooth_strength))

	assert(vertices.size() == total_verts)
	return vertices


static func generateOuterHexagonWithCorners(r_inner: float, r_outer: float, extra_verts_per_side: int) -> PackedVector3Array:
	var corner_verts: Array[PackedVector3Array] = []
	for angle in Util.get_six_hex_angles():
		corner_verts.append(getThreeHexCornerVertices(r_inner, r_outer, angle))

	# Determine angle difference (from hex center) between the corner_verts and their neighbours
	var corner: Vector3 = corner_verts[0][1]
	var corner_neighbour: Vector3 = corner_verts[0][2]
	var corner_angle_offset: float = abs(Util.to_vec2(corner).angle_to(Util.to_vec2(corner_neighbour)))

	# Compute how many additional vertices per side and at which angles.
	# Basically we reduce the 60deg hex-segment on both sides by corner_angle_offset
	# to get the center part of the side which is the same as the inner hexagon.
	var side_angle_range := (PI / 3.0 - 2.0 * corner_angle_offset)
	var side_angle_step := side_angle_range / (extra_verts_per_side + 1)

	# Put everything together
	var vertices: PackedVector3Array
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
			vertices.append(Util.get_hex_vertex(r_outer, angle))

	# Append first(left) corner vertex of first corner at the end
	vertices.append(corner_verts[0][0])

	assert(vertices.size() == 6 * (3 + extra_verts_per_side))
	return vertices


# Compute the 3 Vector3 points for one hex corner
static func getThreeHexCornerVertices(r_inner: float, r_outer: float, angle: float) -> PackedVector3Array:
	# No smooth strength since corner
	var inner_corner := Util.get_hex_vertex(r_inner, angle)
	var outer_corner := Util.get_hex_vertex(r_outer, angle)

	# Distance between the two interior circles of the inner and outer radius of the hex
	var dist := HexConst.outer_radius_interior_circle() - HexConst.inner_radius_interior_circle()

	# 30deg = PI/6.0 = one half of a hexagon segment
	var left_angle := angle - PI / 6.0
	var right_angle := angle + PI / 6.0
	var left := inner_corner + Util.vec3_from_radius_angle(dist, left_angle)
	var right := inner_corner + Util.vec3_from_radius_angle(dist, right_angle)

	return [left, outer_corner, right]


static func generateCenterPoints(num: int) -> PackedVector3Array:
	var points: PackedVector3Array = []

	# Generate first point in center
	points.append(Vector3.ZERO)
	num -= 1

	# Adjust to ensure points stay within the hexagon
	var ring_radius := HexConst.inner_radius * 0.5

	# Distribute along the first ring
	for i in range(num):
		var angle := TAU * i / num
		points.append(Util.vec3_from_radius_angle(ring_radius, angle))

	return points

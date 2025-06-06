class_name PolygonSurfaceSampler


var triangles: Array[Triangle]

# Percentage of the total area each triangle covers
var area_weights: Array[float]
var total_area: float
var total_weight: float


func _init(triangles_: Array[Triangle]) -> void:
	self.triangles = triangles_
	#self._calculate_area_weights()	


func finalize() -> PolygonSurfaceSampler:
	self._calculate_area_weights()
	return self


func is_valid() -> bool:
	return !self.triangles.is_empty()


func get_total_area() -> float:
	return total_area


func filter_max_incline(max_incline_deg: float) -> PolygonSurfaceSampler:
	self.triangles = triangles.filter(func(tri: Triangle) -> bool:
		# Return true to keep triangle
		return tri.calculateInclineDeg() <= max_incline_deg
	)
	# if self.triangles.is_empty():
	# 	print("Triangle list in PolygonSurfaceSampler is empty after filtering for max_incline <= %f" % [max_incline_deg])
	#self._calculate_area_weights()
	return self


func filter_min_incline(min_incline_deg: float) -> PolygonSurfaceSampler:
	self.triangles = triangles.filter(func(tri: Triangle) -> bool:
		# Return true to keep triangle
		return tri.calculateInclineDeg() >= min_incline_deg
	)
	# if self.triangles.is_empty():
	# 	print("Triangle list in PolygonSurfaceSampler is empty after filtering for min_incline >= %f" % [min_incline_deg])
	#self._calculate_area_weights()
	return self


func get_random_point() -> Vector3:
	# if not is_valid():
	# 	push_warning("Tried to get point from PolygonSurfaceSampler but triangle list is empty!")
	# 	return Vector3.ZERO

	var tri_idx: int = _weighted_random_choice()
	return self.triangles[tri_idx].getRandPoint()


func get_random_point_transform() -> Transform3D:
	# if not is_valid():
	# 	push_warning("Tried to get transform from PolygonSurfaceSampler but triangle list is empty!")
	# 	return Transform3D.IDENTITY

	var tri_idx: int = _weighted_random_choice()
	var tri: Triangle = self.triangles[tri_idx]
	return Util.transform_from_point_and_normal(tri.getRandPoint(), tri.getNormal())


func _calculate_area_weights() -> PolygonSurfaceSampler:
	var areas: Array[float] = []
	total_area = 0.0
	total_weight = 0.0
	for tri in self.triangles:
		var area: float = tri.getArea()
		areas.append(area)
		total_area += area

	self.area_weights.clear()
	for area in areas:
		var weight: float = area / total_area
		# We already include the weights of the previous triangles to make the lookup faster
		area_weights.append(weight + total_weight)
		total_weight += weight

	return self


func _weighted_random_choice() -> int:
	# ChatGPT magic
	var rand: float = randf() * total_weight
	var index: int = area_weights.bsearch(rand)
	if index < 0:
		index = ~index # Convert the negative insertion point to the actual index
	return index


# Expensive, only use for debugging
func compute_custom_aabb(object_height: float) -> AABB:
	if not is_valid():
		return AABB()

	var aabb := AABB(triangles[0].a, Vector3.ZERO)

	for tri: Triangle in triangles:
		aabb = aabb.expand(tri.a)
		aabb = aabb.expand(tri.b)
		aabb = aabb.expand(tri.c)

	# Expand aabb upwards by object height
	aabb = aabb.expand(aabb.get_support(Vector3.UP) + Vector3(0, object_height, 0))

	return aabb

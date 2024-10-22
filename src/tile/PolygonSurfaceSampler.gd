class_name PolygonSurfaceSampler

var area_weights: Array[float]
var triangles: Array[Triangle]


func _init(triangles_: Array[Triangle]) -> void:
	self.triangles = triangles_
	self._calculate_area_weights()


func is_valid() -> bool:
	return !self.triangles.is_empty()


func filter_max_incline(max_incline_deg: float) -> void:
	self.triangles = triangles.filter(func(tri: Triangle) -> bool:
		# Return true to keep triangle
		return tri.calculateInclineDeg() <= max_incline_deg
	)
	self._calculate_area_weights()
	if self.triangles.is_empty():
		print("Triangle list in PolygonSurfaceSampler is empty after filtering for max_incline <= %f" % [max_incline_deg])


func filter_min_incline(min_incline_deg: float) -> void:
	self.triangles = triangles.filter(func(tri: Triangle) -> bool:
		# Return true to keep triangle
		return tri.calculateInclineDeg() >= min_incline_deg
	)
	self._calculate_area_weights()
	if self.triangles.is_empty():
		print("Triangle list in PolygonSurfaceSampler is empty after filtering for min_incline >= %f" % [min_incline_deg])


func get_random_point() -> Vector3:
	if not is_valid():
		push_warning("Tried to get point from PolygonSurfaceSampler but triangle list is empty!")
		return Vector3.ZERO

	var tri_idx: int = _weighted_random_choice()
	return self.triangles[tri_idx].getRandPoint()


func get_random_point_transform() -> Transform3D:
	if not is_valid():
		push_warning("Tried to get transform from PolygonSurfaceSampler but triangle list is empty!")
		return Transform3D.IDENTITY

	var tri_idx: int = _weighted_random_choice()
	var tri: Triangle = self.triangles[tri_idx]
	return Util.transformFromPointAndNormal(tri.getRandPoint(), tri.getNormal())


func _calculate_area_weights() -> void:
	var areas: Array[float] = []
	var total_area: float = 0.0
	for tri in self.triangles:
		var area: float = tri.getArea()
		areas.append(area)
		total_area += area

	self.area_weights.clear()
	for area in areas:
		area_weights.append(area / total_area)


func _weighted_random_choice() -> int:
	var total_weight: float = 0.0
	for weight in area_weights:
		total_weight += weight

	var rand: float = randf() * total_weight
	for i in range(area_weights.size()):
		if rand < area_weights[i]:
			return i
		rand -= area_weights[i]

	# Fallback in case of rounding errors
	return area_weights.size() - 1

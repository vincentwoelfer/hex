class_name PolygonSurfaceSampler

var area_weights: Array[float]
var triangles: Array[Triangle]


func _init(triangles_: Array[Triangle]) -> void:
	self.triangles = triangles_
	self._calculate_area_weights()


func filter_max_incline(max_incline_deg: float) -> void:
	self.triangles = triangles.filter(func(tri: Triangle) -> bool:
		# Return true to keep triangle
		return tri.calculateInclineDeg() <= max_incline_deg
	)
	self._calculate_area_weights()


func filter_min_incline(min_incline_deg: float) -> void:
	self.triangles = triangles.filter(func(tri: Triangle) -> bool:
		# Return true to keep triangle
		return tri.calculateInclineDeg() >= min_incline_deg
	)
	self._calculate_area_weights()


func get_random_point() -> Vector3:
	var tri_idx: int = _weighted_random_choice(self.area_weights)
	return self.triangles[tri_idx].getRandPoint()


func get_random_point_transform() -> Transform3D:
	var tri_idx: int = _weighted_random_choice(self.area_weights)
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


func _weighted_random_choice(weights: Array[float]) -> int:
	var total_weight: float = 0.0
	for weight in weights:
		total_weight += weight
	
	var rand: float = randf() * total_weight
	for i in range(weights.size()):
		if rand < weights[i]:
			return i
		rand -= weights[i]
	
	# Fallback in case of rounding errors
	return weights.size() - 1

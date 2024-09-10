class_name PolygonSurfaceSampler

var area_weights: Array[float]
var triangles: Array[Triangle]


func _init(triangles_: Array[Triangle]) -> void:
	self.triangles = triangles_
	_calculate_area_weights()


func get_random_points(num_points: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	points.resize(num_points)
	for i in range(num_points):
		points[i] = self.get_random_point()
	return points


func get_random_point() -> Vector3:
	var tri_idx: int = _weighted_random_choice(self.area_weights)
	var tri: Triangle = self.triangles[tri_idx]
	return tri.getRandPoint()


func get_random_point_transform() -> Transform3D:
	var tri_idx: int = _weighted_random_choice(self.area_weights)
	var tri: Triangle = self.triangles[tri_idx]

	var transform: Transform3D = Transform3D()
	transform.origin = tri.getRandPoint()
	var normal := tri.getNormal()
	# Set the orientation (normal as the z-axis direction)
	transform.basis = Basis(normal.cross(Vector3(1, 0, 0)), normal.cross(Vector3(0, 1, 0)), normal).orthonormalized()

	return transform


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

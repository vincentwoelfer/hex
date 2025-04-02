extends Object
class_name NavMeshAnalyzer

# Internal class to represent a cluster of polygons
class Cluster:
	var polygon_indices: PackedInt32Array
	var vertex_indices: PackedInt32Array
	# var area: float
	var has_external_edge: bool
	var is_inside_geometry: bool

	func _init(polygon_indices_: PackedInt32Array, vertex_indices_: PackedInt32Array, has_external_edge_: bool, is_inside_geometry_: bool) -> void:
		self.polygon_indices = polygon_indices_
		self.vertex_indices = vertex_indices_
		# self.area = area_
		self.has_external_edge = has_external_edge_
		self.is_inside_geometry = is_inside_geometry_

# Input - these are in local space of the nav mesh
var nav_mesh: NavigationMesh
var nav_mesh_aabb: AABB
var world_pos: Vector3

# Intermediate
var clusters: Array[Cluster] = []

func _init(nav_mesh_: NavigationMesh, nav_mesh_aabb_: AABB, world_pos_: Vector3) -> void:
	self.nav_mesh = nav_mesh_
	self.nav_mesh_aabb = nav_mesh_aabb_
	self.world_pos = world_pos_


func analyze() -> void:
	assert(clusters.is_empty())

	var vertices: PackedVector3Array = nav_mesh.get_vertices()
	var polygon_count: int = nav_mesh.get_polygon_count()

	var visited: Array[int] = []

	for i in range(polygon_count):
		if visited.has(i):
			continue

		var cluster_polygon_indices := PackedInt32Array()
		var cluster_vertex_indices := PackedInt32Array()
		var to_visit: Array[int] = [i]

		while to_visit.size() > 0:
			var current: int = to_visit.pop_back()
			if visited.has(current):
				continue

			visited.append(current)
			cluster_polygon_indices.append(current)

			var poly_indices := nav_mesh.get_polygon(current)
			for idx in poly_indices:
				if not cluster_vertex_indices.has(idx):
					cluster_vertex_indices.append(idx)

				# Check adjacency to other polygons
				for j in range(polygon_count):
					if visited.has(j):
						continue
					var other_indices := nav_mesh.get_polygon(j)
					if _polygons_are_adjacent(poly_indices, other_indices):
						to_visit.append(j)

		# var area := _calculate_polygon_area(cluster_vertex_indices, vertices)
		var has_external_edge := _has_external_edge(cluster_vertex_indices, vertices)

		var collision_point := vertices[cluster_vertex_indices[0]] + Vector3(0, 0.2, 0) + self.world_pos
		var is_inside_geometry := Util.perform_static_collision_point_test(collision_point)
		clusters.append(Cluster.new(cluster_polygon_indices, cluster_vertex_indices, has_external_edge, is_inside_geometry))


func _polygons_are_adjacent(poly_a: PackedInt32Array, poly_b: PackedInt32Array) -> bool:
	var shared := 0
	for i in poly_a:
		if poly_b.has(i):
			shared += 1
			if shared >= 2:
				return true
	return false


# func _calculate_polygon_area(vertex_indices: PackedInt32Array, vertices: PackedVector3Array) -> float:
# 	var area: float = 0.0
	
# 	if vertex_indices.size() < 3:
# 		return 0.0 # Not a polygon
	
# 	# Use the first vertex as the anchor point for triangle fan
# 	var anchor: Vector3 = vertices[vertex_indices[0]]
	
# 	for i in range(1, vertex_indices.size() - 1):
# 		var v1: Vector3 = vertices[vertex_indices[i]] - anchor
# 		var v2: Vector3 = vertices[vertex_indices[i + 1]] - anchor
# 		area += 0.5 * v1.cross(v2).length()
	
# 	return area


func _has_external_edge(vertex_indices: PackedInt32Array, vertices: PackedVector3Array) -> bool:
	for idx in vertex_indices:
		var v := vertices[idx]
		if is_equal_approx(v.x, nav_mesh_aabb.position.x) or is_equal_approx(v.x, nav_mesh_aabb.position.x + nav_mesh_aabb.size.x):
			return true
		if is_equal_approx(v.z, nav_mesh_aabb.position.z) or is_equal_approx(v.z, nav_mesh_aabb.position.z + nav_mesh_aabb.size.z):
			return true
	return false


func build_clean_nav_mesh() -> NavigationMesh:
	# Example filtering logic
	clusters = clusters.filter(func(cluster: Cluster) -> bool:
		# True = keep the cluster, false = discard it
		if cluster.is_inside_geometry:
			return false
		
		if cluster.has_external_edge:
			return true

		return true
	)

	# Build new mesh data
	var new_vertices := PackedVector3Array()
	var new_polygons: Array[PackedInt32Array] = []
	var vertex_map: Dictionary[Vector3, int] = {}

	for cluster in clusters:
		for poly_idx in cluster.polygon_indices:
			var old_poly := nav_mesh.get_polygon(poly_idx)
			var new_poly := PackedInt32Array()
			for idx in old_poly:
				var vertex: Vector3 = nav_mesh.get_vertices()[idx]
				if not vertex_map.has(vertex):
					vertex_map[vertex] = new_vertices.size()
					new_vertices.append(vertex)
				new_poly.append(vertex_map[vertex])
			new_polygons.append(new_poly)

	var new_nav_mesh := NavigationMesh.new()
	new_nav_mesh.set_vertices(new_vertices)
	for poly in new_polygons:
		new_nav_mesh.add_polygon(poly)

	return new_nav_mesh

extends Object
class_name NavMeshAnalyzer

# Internal class to represent a cluster of polygons
class Cluster:
	var polygon_indices: PackedInt32Array
	var vertex_indices: PackedInt32Array
	var has_external_edge: bool
	var is_inside_geometry: bool
	var is_on_terrain: bool

	func _init(polygon_indices_: PackedInt32Array, vertex_indices_: PackedInt32Array, has_external_edge_: bool, is_inside_geometry_: bool, is_on_terrain_: bool) -> void:
		self.polygon_indices = polygon_indices_
		self.vertex_indices = vertex_indices_
		self.has_external_edge = has_external_edge_
		self.is_inside_geometry = is_inside_geometry_
		self.is_on_terrain = is_on_terrain_

# Input - these are in local space of the nav mesh
var nav_mesh: NavigationMesh
var nav_mesh_aabb: AABB
var world_pos: Vector3

# Intermediate
var vertices: PackedVector3Array = []
var clusters: Array[Cluster] = []

func _init(nav_mesh_: NavigationMesh, nav_mesh_aabb_: AABB, world_pos_: Vector3) -> void:
	self.nav_mesh = nav_mesh_
	self.nav_mesh_aabb = nav_mesh_aabb_
	self.world_pos = world_pos_

	self.vertices = nav_mesh.get_vertices()

func analyze() -> void:
	assert(clusters.is_empty())

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

		var has_external_edge := _has_external_edge(cluster_vertex_indices)

		var collision_pos := vertices[cluster_vertex_indices[0]] + self.world_pos
		var is_inside_geometry := Util.collision_point_test(collision_pos + Vector3(0, 0.3, 0), Layers.mask([Layers.L.TERRAIN, Layers.L.STATIC_GEOM]))
		var is_on_terrain := _is_on_terrain(cluster_vertex_indices)

		clusters.append(Cluster.new(cluster_polygon_indices, cluster_vertex_indices, has_external_edge, is_inside_geometry, is_on_terrain))


# Is inside terrain is checked at three different places because sometimes, index 0 is on a rock for the main cluster
func _is_on_terrain(cluster_vertex_indices: PackedInt32Array) -> bool:
	const offset = Vector3(0, 0.3, 0)
	var is_on_terrain := false

	# Check if the cluster is on terrain by raycasting from three different vertices
	var checks_at := [0.0, 0.5, 1.0]
	for f: float in checks_at:
		var idx := floori((cluster_vertex_indices.size() - 1) * f)
		var collision_pos := vertices[cluster_vertex_indices[idx]] + self.world_pos
		var hit := Util.raycast(collision_pos + offset, collision_pos - offset, Layers.mask([Layers.L.TERRAIN]))
		if hit:
			is_on_terrain = true
			break

	return is_on_terrain

func _polygons_are_adjacent(poly_a: PackedInt32Array, poly_b: PackedInt32Array) -> bool:
	var shared := 0
	for i in poly_a:
		if poly_b.has(i):
			shared += 1
			if shared >= 2:
				return true
	return false


func _has_external_edge(vertex_indices: PackedInt32Array) -> bool:
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
		# Inside Rock/Terrain -> discard
		if cluster.is_inside_geometry:
			return false
		
		# Not on terrain -> discard
		if not cluster.is_on_terrain:
			return false

		# if cluster.has_external_edge:
			# return true

		# Keep rest
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
				var vertex: Vector3 = self.vertices[idx]
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

class_name ScatteredRocks
extends Node3D

var mesh_instance: MeshInstance3D
var static_body: StaticBody3D

# Internal
var concave_polygon_shape: ConcavePolygonShape3D


func _init(sampler: PolygonSurfaceSampler) -> void:
	if not sampler.is_valid() or not DebugSettings.enable_rocks:
		return

	var rocksMesh := _generate_rocks_mesh(sampler)
	if rocksMesh != null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Rocks"
		mesh_instance.material_override = ResLoader.ROCKS_MAT
		mesh_instance.mesh = rocksMesh
		add_child(mesh_instance)

		# Collision
		static_body = StaticBody3D.new()
		var collision_shape := CollisionShape3D.new()
		self.concave_polygon_shape = _generate_collision_shape_from_array_mesh(rocksMesh)
		collision_shape.shape = self.concave_polygon_shape
		collision_shape.debug_fill = false
		static_body.add_child(collision_shape)
		static_body.set_collision_layer_value(Layers.L.STATIC_GEOM, true)
		add_child(static_body)


func get_faces() -> PackedVector3Array:
	if concave_polygon_shape == null:
		return PackedVector3Array()

	return concave_polygon_shape.get_faces()


func _generate_collision_shape_from_array_mesh(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var polygon_shape := ConcavePolygonShape3D.new()
	polygon_shape.set_faces(mesh.get_faces())
	return polygon_shape


# TODO this takes forever (200ms for 5 calls)
enum RockType {SMALL, MEDIUM, LARGE}
func _generate_rocks_mesh(sampler: PolygonSurfaceSampler) -> ArrayMesh:
	if not sampler.is_valid():
		return null

	# Standard deviation = x means:
	# 66% of samples are within [-x, x] of the mean
	# 96% of samples are within [-2x, 2x] of the mean
	var avg_rock_density_per_square_meter: float = 0.005
	var num_rocks: int = round(randfn(avg_rock_density_per_square_meter, avg_rock_density_per_square_meter) * sampler.get_total_area())

	# No mesh_instance
	if num_rocks <= 0 or randf() <= 0.25:
		return null

	var st_combined: SurfaceTool = SurfaceTool.new()
	for i in range(num_rocks):
		var t: Transform3D = sampler.get_random_point_transform()
		t = t.rotated_local(Vector3.UP, randf_range(0.0, TAU))

		var mesh: Mesh = ResLoader.basic_rocks_meshes.pick_random()
		var aabb: AABB = mesh.get_aabb()
		var max_mesh_side_length: float = max(aabb.size.x, aabb.size.z)
		var mesh_height: float = aabb.size.y

		var rock_type: RockType = RockType.MEDIUM
		var r := randf()
		if r <= 0.15:
			rock_type = RockType.LARGE

		# Spawn mesh_instance according to type
		if rock_type == RockType.LARGE:
			var height_factor := randf_range(2.5, 3.5) / mesh_height
			var side_factor := randf_range(5.0, 10.0) / max_mesh_side_length
			t = t.scaled_local(Vector3(side_factor, height_factor, side_factor))

		elif rock_type == RockType.MEDIUM:
			var height_factor := randf_range(1.75, 2.5) / mesh_height
			var side_factor := randf_range(1.25, 3.0) / max_mesh_side_length
			t = t.scaled_local(Vector3(side_factor, height_factor, side_factor))

		# elif rock_type == RockType.SMALL:
		# 	var max_height := randf_range(0.1, 0.15)
		# 	t = t.scaled_local(v_one * (max_height / mesh_height))

		st_combined.append_from(mesh, 0, t)
	return st_combined.commit()

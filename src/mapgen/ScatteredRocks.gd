class_name ScatteredRocks
extends Node3D

var rocks: MeshInstance3D
var rocks_collision: StaticBody3D


func _init(sampler: PolygonSurfaceSampler) -> void:
	if not sampler.is_valid() or not DebugSettings.enable_rocks:
		return

	var rocksMesh := generate_rocks_mesh(sampler)
	if rocksMesh != null:
		rocks = MeshInstance3D.new()
		rocks.name = "Rocks"
		rocks.material_override = ResLoader.ROCKS_MAT
		rocks.mesh = rocksMesh
		add_child(rocks)

		# Collision
		rocks_collision = StaticBody3D.new()
		var rocks_collision_shape := CollisionShape3D.new()
		rocks_collision_shape.shape = generate_collision_shape_from_array_mesh(rocksMesh)
		rocks_collision_shape.debug_fill = false
		rocks_collision.add_child(rocks_collision_shape)
		add_child(rocks_collision)


func generate_collision_shape_from_array_mesh(mesh: ArrayMesh) -> ConcavePolygonShape3D:
	var polygon_shape := ConcavePolygonShape3D.new()
	polygon_shape.set_faces(mesh.get_faces())
	return polygon_shape


enum RockType {SMALL, MEDIUM, LARGE}
func generate_rocks_mesh(sampler: PolygonSurfaceSampler) -> ArrayMesh:
	if not sampler.is_valid():
		return null

	# Standard deviation = x means:
	# 66% of samples are within [-x, x] of the mean
	# 96% of samples are within [-2x, 2x] of the mean
	var avg_rock_density_per_square_meter: float = 0.011
	var num_rocks: int = round(randfn(avg_rock_density_per_square_meter, avg_rock_density_per_square_meter) * sampler.get_total_area())

	if num_rocks <= 0 or randf() <= 0.35:
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
		#if r <= 0.07:
		# TODO only for navmesh tesitng
		if r <= 0.3:
			rock_type = RockType.LARGE

		# Spawn rocks according to type
		if rock_type == RockType.LARGE:
			var height_factor := randf_range(2.5, 3.5) / mesh_height
			var side_factor := randf_range(5.0, 10.0) / max_mesh_side_length
			t = t.scaled_local(Vector3(side_factor, height_factor, side_factor))

		elif rock_type == RockType.MEDIUM:
			var height_factor := randf_range(1.75, 2.5) / mesh_height
			var side_factor := randf_range(1.25, 2.5) / max_mesh_side_length
			t = t.scaled_local(Vector3(side_factor, height_factor, side_factor))

		# elif rock_type == RockType.SMALL:
		# 	var max_height := randf_range(0.1, 0.15)
		# 	t = t.scaled_local(v_one * (max_height / mesh_height))

		st_combined.append_from(mesh, 0, t)
	return st_combined.commit()

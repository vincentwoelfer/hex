@tool
class_name DebugVis3D

######################################################
# Materials
######################################################
static func mat(color: Color = Color.RED, xray: bool = false, use_shading: bool = false, disable_culling: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if !use_shading:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if xray:
		m.set_flag(BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	if disable_culling:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

######################################################
# Meshes
######################################################
static func _num_radial_segments(r: float) -> int:
	return clampi(roundi(r * 40.0), 6, 20)

static func sphere(r: float, m: StandardMaterial3D = null) -> SphereMesh:
	var s := SphereMesh.new()
	if m != null:
		s.material = m

	s.radial_segments = _num_radial_segments(r)
	s.rings = _num_radial_segments(r)
	s.height = 2 * r
	s.radius = r
	return s

static func capsule(r: float, h: float, m: StandardMaterial3D = null) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	if m != null:
		c.material = m

	c.radial_segments = _num_radial_segments(r)
	c.rings = _num_radial_segments(r)
	c.height = h
	c.radius = r
	return c

static func cylinder(r: float, h: float, m: StandardMaterial3D = null) -> CylinderMesh:
	var c := CylinderMesh.new()
	if m != null:
		c.material = m

	c.radial_segments = _num_radial_segments(r)
	c.rings = 2
	c.height = h
	c.bottom_radius = r
	c.top_radius = r
	return c

static func line_mesh(a: Vector3, b: Vector3, m: StandardMaterial3D = null) -> Mesh:
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(a)
	line.surface_add_vertex(b)
	line.surface_end()
	if m != null:
		line.surface_set_material(0, m)
	return line

static func path_mesh(path: PackedVector3Array, width: float = 0.1, m: StandardMaterial3D = null) -> Mesh:
	var mesh := ImmediateMesh.new()
	if path.size() < 2:
		return mesh
	
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(path.size() - 1):
		var start: Vector3 = path[i]
		var end: Vector3 = path[i + 1]
		var direction: Vector3 = (end - start).normalized()
		
		# Compute perpendicular vector for thickness (approximated using cross product)
		var up: Vector3 = Vector3.UP if abs(direction.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
		var perp: Vector3 = direction.cross(up).normalized() * width * 0.5
		
		# Create quad (two vertices per point)
		mesh.surface_add_vertex(start + perp)
		mesh.surface_add_vertex(start - perp)
		mesh.surface_add_vertex(end + perp)
		mesh.surface_add_vertex(end - perp)
	mesh.surface_end()
	if m != null:
		mesh.surface_set_material(0, m)

	return mesh


static func aabb_mesh(aabb: AABB, color: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = aabb.size
	mesh.material = mat(color, false, false, true) # Disable culling for AABBs
	return mesh


######################################################
# Spawning
######################################################
## If parent is null the instance will be added to the scene root, use global_pos.
## If parent is not null the instance will be added to the parent, use local_pos.
static func spawn(pos: Vector3, mesh: Mesh, parent: Node3D = null) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Util.spawn(instance, pos, parent)
	return instance

	
static func spawn_aabb(aabb: AABB, color: Color, parent: Node3D = null) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.mesh = aabb_mesh(aabb, color)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Util.spawn(instance, aabb.get_center(), parent)
	return instance


######################################################
# Visualize Shape Query
######################################################
static func visualize_collision_shape(pos: Vector3, shape: Shape3D, color: Color, delete_after: float = 0.0) -> void:
	# Construct a mesh + material from the shape
	var mesh: Mesh = (shape as Shape3D).get_debug_mesh()
	mesh.surface_set_material(0, mat(color, false, false))

	var instance: Node3D = spawn(pos, mesh)
	if delete_after > 0.0:
		Util.delete_after(delete_after, instance)


## Visualize a shape query with a mesh and material
##[br] Works with motion-sweeps and single static queries.
static func visualize_collision_shape_query(query: PhysicsShapeQueryParameters3D, color: Color, delete_after: float = 0.0) -> void:
	# Construct a mesh + material from the shape query
	var mesh: Mesh = (query.shape as Shape3D).get_debug_mesh()
	mesh.surface_set_material(0, mat(color, false, false))

	# Determine how many steps to take along the motion
	var step_distance: float = max(mesh.get_aabb().size.x, mesh.get_aabb().size.z) * 0.75
	var num_steps: int = clamp(ceili(query.motion.length() / step_distance), 1, 25)
	var sample_points := Util.spread_vec3(query.transform.origin, query.transform.origin + query.motion, num_steps)

	# Spawn
	for pos in sample_points:
		var instance: Node3D = spawn(pos, mesh)
		instance.global_basis = query.transform.basis
		if delete_after > 0.0:
			Util.delete_after(delete_after, instance)


static func visualize_collision_shape_query_motion_with_hit(query: PhysicsShapeQueryParameters3D, t: float, color_free: Color, color_hit: Color, delete_after: float = 0.0) -> void:
	# Check if query has no motion or is completely hit or miss
	if query.motion.length() == 0.0 or is_equal_approx(t, 0.0) or is_equal_approx(t, 1.0):
		visualize_collision_shape_query(query, color_hit if t < 0.5 else color_free, delete_after)
		return

	# Split into two shape queries and call with different colors
	var query_free := _duplicate_shape_query(query)
	query_free.motion *= t
	
	var query_hit := _duplicate_shape_query(query)
	query_hit.transform.origin += query_free.motion
	query_hit.motion *= (1.0 - t)

	visualize_collision_shape_query(query_free, color_free, delete_after)
	visualize_collision_shape_query(query_hit, color_hit, delete_after)


######################################################
# INTERNAL
######################################################
static func _duplicate_shape_query(original: PhysicsShapeQueryParameters3D) -> PhysicsShapeQueryParameters3D:
	var copy := PhysicsShapeQueryParameters3D.new()
	copy.shape = original.shape.duplicate() if original.shape != null else null
	copy.transform = original.transform
	copy.margin = original.margin
	copy.collide_with_areas = original.collide_with_areas
	copy.collide_with_bodies = original.collide_with_bodies
	copy.collision_mask = original.collision_mask
	copy.exclude = original.exclude.duplicate()
	return copy

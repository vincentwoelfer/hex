@tool
class_name DebugVis3D

######################################################
# Materials
######################################################
static func mat(color: Color = Color.RED, xray: bool = false, shading: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if !shading:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if xray:
		m.set_flag(BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	return m

######################################################
# Meshes
######################################################
static func _radial_segments(r: float) -> int:
	return clampi(roundi(r * 40.0), 6, 20)

static func sphere(r: float, m: StandardMaterial3D = null) -> SphereMesh:
	var s := SphereMesh.new()
	if m != null:
		s.material = m

	s.radial_segments = _radial_segments(r)
	s.rings = _radial_segments(r)
	s.height = 2 * r
	s.radius = r
	return s

static func capsule(r: float, h: float, m: StandardMaterial3D = null) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	if m != null:
		c.material = m

	c.radial_segments = _radial_segments(r)
	c.rings = _radial_segments(r)
	c.height = h
	c.radius = r
	return c

static func cylinder(r: float, h: float, m: StandardMaterial3D = null) -> CylinderMesh:
	var c := CylinderMesh.new()
	if m != null:
		c.material = m

	c.radial_segments = _radial_segments(r)
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

static func path_mesh(path: PackedVector3Array, width: float = 0.1) -> Mesh:
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
	return mesh


static func aabb_mesh(aabb: AABB, color: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = aabb.size
	
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = m
	return mesh


######################################################
# Helper method to spawn
######################################################
static func _add_child(instance: Node3D, parent: Node3D = null) -> void:
	if parent != null:
		parent.add_child(instance)
	else:
		Util.get_scene_root().add_child(instance)
	instance.reset_physics_interpolation()

	
######################################################
# Spawning
######################################################

## Helper method to spawn a mesh instance at a given position, not interactible afterwards
static func spawn(pos: Vector3, mesh: Mesh, parent: Node3D = null) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_child(instance, parent)
	return instance

	
static func spawn_aabb(aabb: AABB, color: Color, parent: Node3D = null) -> Node3D:
	var instance := MeshInstance3D.new()
	instance.mesh = aabb_mesh(aabb, color)
	instance.position = aabb.get_center()
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add_child(instance, parent)
	return instance

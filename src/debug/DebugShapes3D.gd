@tool
class_name DebugShapes3D


static func material(color: Color = Color.RED, xray: bool = false, shading: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if !shading:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if xray:
		mat.set_flag(BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)
	return mat


static func sphere_mesh(r: float, mat: StandardMaterial3D = null) -> PrimitiveMesh:
	var sphere := SphereMesh.new()
	if mat != null:
		sphere.material = mat

	var quality: int = clampi(roundi(r * 40.0), 4, 16)
	sphere.radial_segments = quality + 2
	sphere.rings = quality
	sphere.height = 2 * r
	sphere.radius = r
	return sphere

static func line_mesh(a: Vector3, b: Vector3, mat: StandardMaterial3D = null) -> Mesh:
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(a)
	line.surface_add_vertex(b)
	line.surface_end()
	if mat != null:
		line.surface_set_material(0, mat)
	return line

static func capsule_mesh(h: float, r: float, mat: StandardMaterial3D = null) -> PrimitiveMesh:
	var capsule := CapsuleMesh.new()
	if mat != null:
		capsule.material = mat

	capsule.radial_segments = 12
	capsule.rings = 12
	capsule.height = h
	capsule.radius = r
	return capsule


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


## Helper method to spawn a mesh instance at a given position, not interactible afterwards
static func spawn_mesh(pos: Vector3, mesh: Mesh, root: Node3D, ) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	root.add_child(instance)


static func spawn_aabb(aabb: AABB, color: Color, parent: Node3D) -> void:
	var vis := MeshInstance3D.new()
	vis.mesh = BoxMesh.new()
	(vis.mesh as BoxMesh).size = aabb.size
	vis.position = aabb.get_center()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	vis.material_override = mat
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(vis)

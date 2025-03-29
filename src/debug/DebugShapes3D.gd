@tool
class_name DebugShapes3D


static func create_debug_material(color: Color = Color.RED, shading: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if !shading:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# material.set_flag(BaseMaterial3D.FLAG_DISABLE_DEPTH_TEST, true)

	return material


static func create_sphere_mesh(r: float, color: Color = Color.RED, shading: bool = false) -> PrimitiveMesh:
	var material := create_debug_material(color, shading)
	var sphere := SphereMesh.new()
	sphere.material = material

	var quality: int = clampi(roundi(r * 40.0), 4, 16)
	sphere.radial_segments = quality + 2
	sphere.rings = quality
	sphere.height = 2 * r
	sphere.radius = r

	return sphere


static func create_capsule_mesh(h: float, r: float, color: Color = Color.RED, shading: bool = false) -> PrimitiveMesh:
	var material := create_debug_material(color, shading)

	var mesh := CapsuleMesh.new()
	mesh.material = material

	mesh.radial_segments = 12
	mesh.rings = 12
	mesh.height = h
	mesh.radius = r
	
	return mesh


static func create_path_mesh(path: PackedVector3Array, width: float = 0.1) -> Mesh:
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


static func spawn_visible_aabb(aabb: AABB, color: Color, parent: Node3D) -> void:
	var vis := MeshInstance3D.new()
	vis.mesh = BoxMesh.new()
	(vis.mesh as BoxMesh).size = aabb.size
	vis.position = aabb.get_center()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	vis.material_override = material
	vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(vis)

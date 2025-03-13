@tool
class_name DebugShapes3D


static func create_debug_material(color: Color = Color.RED, shading: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if !shading:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	parent.add_child(vis)

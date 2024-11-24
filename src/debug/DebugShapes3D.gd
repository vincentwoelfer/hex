@tool
class_name DebugShapes3D

static func create_sphere(r: float, color: Color = Color.RED, shading: bool = false) -> PrimitiveMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if !shading:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var sphere := SphereMesh.new()
	var quality: int = clampi(roundi(r * 40.0), 4, 16)
	sphere.radial_segments = quality + 2
	sphere.rings = quality
	sphere.height = 2 * r
	sphere.radius = r
	sphere.material = material

	return sphere


static func create_capsule(h: float, r: float, color: Color = Color.RED, shading: bool = false) -> PrimitiveMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if !shading:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mesh := CapsuleMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 12
	mesh.height = h
	mesh.radius = r
	mesh.material = material

	return mesh

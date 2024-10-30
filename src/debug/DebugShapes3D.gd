@tool
class_name DebugShapes3D

static func create_sphere(r: float, color: Color = Color.RED) -> PrimitiveMesh:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 6
	sphere.height = 2 * r
	sphere.radius = r
	sphere.material = material

	return sphere

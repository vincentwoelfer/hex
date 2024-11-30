class_name TriangleMeshTool

# This is a helper class to create a mesh from multiple triangle lists, each with their own offset

var st: SurfaceTool

func _init() -> void:
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)


func add_triangle_list(triangles: Array[Triangle], offset: Vector3) -> void:
	for tri in triangles:
		tri.a += offset
		tri.b += offset
		tri.c += offset
		tri.addToSurfaceTool(st)


func commit() -> Mesh:
	# Removes duplicates and actually create mesh
	st.index()
	st.optimize_indices_for_cache()
	st.generate_normals()
	return st.commit()

class_name HexGeometryMerger

# This is a helper class to create a mesh from multiple triangle lists, each with their own offset

var triangles: Array[Triangle]
var st: SurfaceTool


func _init() -> void:
	triangles = []
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)


func add_triangles(tris: Array[Triangle], offset: Vector3) -> void:
	for tri in tris:
		tri.a += offset
		tri.b += offset
		tri.c += offset
		tri.addToSurfaceTool(st)
		triangles.append(tri)


func generate_mesh() -> Mesh:
	# Removes duplicates and actually create mesh
	st.index()
	st.optimize_indices_for_cache()
	st.generate_normals()
	return st.commit()


func generate_faces() -> PackedVector3Array:
	var faces: PackedVector3Array = []
	faces.resize(triangles.size() * 3)
	for idx in range(triangles.size()):
		faces[idx * 3 + 0] = triangles[idx].a
		faces[idx * 3 + 1] = triangles[idx].b
		faces[idx * 3 + 2] = triangles[idx].c
	
	return faces

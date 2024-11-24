# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# Basic Rocks
var basic_rocks_path := "res://assets/blender/objects/"
var basic_rocks_meshes: Array[Mesh] = []

# Basic Grass
const GRASS_MAT: ShaderMaterial = preload('res://assets/materials/grass_material.tres')
const GRASS_MESH_HRES := preload('res://assets/meshes/basic_grass/basic_grass_hres.res')
const GRASS_MESH_MRES := preload('res://assets/meshes/basic_grass/basic_grass_mres.res')
const GRASS_MESH_LRES := preload('res://assets/meshes/basic_grass/basic_grass_lres.res')


func _ready() -> void:
	basic_rocks_meshes = load_all_meshes_from_dir(basic_rocks_path)
	Util.print_banner("Resource Loader")
	print("- Basic rocks meshes: " + str(basic_rocks_meshes.size()))
	Util.print_only_banner()

func load_all_meshes_from_dir(path: String) -> Array[Mesh]:
	var dir := DirAccess.open(path)
	if not dir:
		push_error("Could not open directory: " + path)
		return []

	var resources: Array[Mesh] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".res"):
			resources.append(load(path + file_name) as Mesh)
			
		file_name = dir.get_next()

	return resources

class_name SurfacePlant
extends Node3D

# const GRASS_MESH_HIGH := preload('res://assets/meshes/plants/grass_hres.obj')
# const GRASS_MESH_MED := preload('res://assets/meshes/plants/grass_mres.obj')
# const GRASS_MESH_LOW := preload('res://assets/meshes/plants/grass_lres.obj')
const GRASS_MAT: ShaderMaterial = preload('res://assets/materials/grass_material.tres')

const GRASS_MESH_HRES := preload('res://assets/meshes/basic_grass/basic_grass_hres.res')
const GRASS_MESH_MRES := preload('res://assets/meshes/basic_grass/basic_grass_mres.res')
const GRASS_MESH_LRES := preload('res://assets/meshes/basic_grass/basic_grass_lres.res')

var mesh_instance: MultiMeshInstance3D

# In m
var min_height := 0.2
var max_height := 1.2

# Only tip colors
var color_healthy := Color(0.15, 0.4, 0.1)
var color_dry := Color(0.55, 0.45, 0.03)

var curr_height: float = max_height
var curr_health: float = 1.0

var tween: Tween

var num_blades_total: int

#
var current_lod_factor: float = 1.0
var current_lod_mesh: int = 0

func _init() -> void:
	mesh_instance = MultiMeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = GRASS_MAT
	mesh_instance.extra_cull_margin = 0.5
	add_child(mesh_instance, true)

	# Only for testing
	set_shader_value(get_curr_color(), 'tip_color')
	set_shader_value(curr_height, 'height_mod')


func _ready() -> void:
	EventBus.Signal_TriggerLod.connect(recalculate_lod)


func recalculate_lod(cam_pos_global: Vector3) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	
	var dist := cam_pos_global.distance_squared_to(mesh_instance.global_position)

	var new_lod_factor: float
	var new_lod_mesh: int
	if dist <= 25 * 25:
		new_lod_factor = 1.0
		new_lod_mesh = 0
	elif dist <= 32 * 32:
		new_lod_factor = 0.9
		new_lod_mesh = 0
	elif dist <= 40 * 40:
		new_lod_factor = 0.8
		new_lod_mesh = 1
	elif dist <= 50 * 50:
		new_lod_factor = 0.5
		new_lod_mesh = 2
	elif dist <= 60 * 60:
		new_lod_factor = 0.3
		new_lod_mesh = 2
	elif dist <= 70 * 70:
		new_lod_factor = 0.2
		new_lod_mesh = 2
	elif dist <= 90 * 90:
		new_lod_factor = 0.1
		new_lod_mesh = 2
	elif dist <= 120 * 120:
		new_lod_factor = 0.05
		new_lod_mesh = 2
	else:
		new_lod_factor = 0.02
		new_lod_mesh = 2

	#new_lod_mesh = 2


	if current_lod_factor != new_lod_factor:
		current_lod_factor = new_lod_factor
		mesh_instance.multimesh.visible_instance_count = floori(num_blades_total * current_lod_factor)

	if current_lod_mesh != new_lod_mesh:
		current_lod_mesh = new_lod_mesh

		if current_lod_mesh == 0:
			mesh_instance.multimesh.mesh = GRASS_MESH_HRES
		elif current_lod_mesh == 1:
			mesh_instance.multimesh.mesh = GRASS_MESH_MRES
		else:
			mesh_instance.multimesh.mesh = GRASS_MESH_LRES


func get_curr_color() -> Color:
	var curr_color: Color = color_dry.lerp(color_healthy, curr_health)
	return curr_color


func processWorldStep(humidity: float, shade: float, nutrition: float) -> void:
	if tween:
		tween.kill()

	# Update own parameters
	var speed := 0.5
	var health_delta := (humidity - curr_health) * speed # lerp towards humidity value
	health_delta += (humidity - 0.5) * 0.5 * speed # Favor extremes
	health_delta += randf_range(-0.1, 0.1) * speed

	curr_health = clampf(curr_health + health_delta, 0.0, 1.0)
	curr_height = clampf(curr_height + nutrition * speed, min_height, max_height)

	# Die
	if curr_health <= 0.08:
		curr_height = min_height
		curr_health = 1.0

	# Set shader
	var color_start: Color = self.get_shader_value_color('tip_color')
	var height_start: float = self.get_shader_value_float('height_mod')

	# grassMultiMesh.set_instance_shader_parameter('tip_color', color_end)
	# grassMultiMesh.set_instance_shader_parameter('tip_color_dry', color_end)
	# grassMultiMesh.set_instance_shader_parameter('height_mod', height_end)
	# set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	tween = create_tween().set_parallel(true)
	tween.tween_method(set_shader_value.bind("tip_color"), color_start, get_curr_color(), 0.4)
	tween.tween_method(set_shader_value.bind("height_mod"), height_start, curr_height, 0.4)


func populate_multimesh(surface_sampler: PolygonSurfaceSampler) -> void:
	# Density per 1d-meter (one line)
	var density_1d: float = HexConst.grass_density;
	var area := surface_sampler.get_total_area()
	# Square density to get 2d -> weight by area
	num_blades_total = round(density_1d * density_1d * area)

	var mesh_to_use: Mesh = GRASS_MESH_HRES

	# Reduce in editor
	if Engine.is_editor_hint():
		var in_editor_density_reduction := 1.0
		num_blades_total = round(num_blades_total * in_editor_density_reduction)

	# Reduce if gpu is bad
	if RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		var bad_gpu_reduction := 0.3
		num_blades_total = round(num_blades_total * bad_gpu_reduction)
		#mesh_to_use = GRASS_MESH_LRES

	# Compute custom aabb
	mesh_instance.custom_aabb = surface_sampler.compute_custom_aabb(max_height)
	if DebugSettings.visualize_plant_custom_aabb:
		add_custom_aabb_visualization()

	# Create multi-mesh
	var multi_mesh := MultiMesh.new()
	multi_mesh.mesh = mesh_to_use
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = num_blades_total

	for i in range(num_blades_total):
		var t := surface_sampler.get_random_point_transform()
		multi_mesh.set_instance_transform(i, t)


	mesh_instance.multimesh = multi_mesh

# Key as last parameter to allow tween to bind this
func set_shader_value(value: Variant, key: String) -> void:
	mesh_instance.set_instance_shader_parameter(key, value)


func get_shader_value_color(key: String) -> Color:
	var value: Variant = mesh_instance.get_instance_shader_parameter(key)
	if value is not Color:
		return Color()
	return value


func get_shader_value_float(key: String) -> float:
	var value: Variant = mesh_instance.get_instance_shader_parameter(key)
	if value is not float:
		return 0.0
	return value


func add_custom_aabb_visualization() -> void:
	var vis := MeshInstance3D.new()
	vis.mesh = BoxMesh.new()
	(vis.mesh as BoxMesh).size = mesh_instance.custom_aabb.size
	vis.position = mesh_instance.custom_aabb.get_center()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0, 0.3)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vis.material_override = material
	add_child(vis, true)

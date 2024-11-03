class_name SurfacePlant
extends Node3D

const GRASS_MESH_HIGH := preload('res://assets/meshes/plants/grass_hres.obj')
const GRASS_MESH_LOW := preload('res://assets/meshes/plants/grass_lres.obj')
const GRASS_MAT: ShaderMaterial = preload('res://assets/materials/grass_material.tres')

var mesh_instance: MultiMeshInstance3D

var min_height := 0.2
var max_height := 3.0

# Only tip colors
var color_healthy := Color(0.15, 0.4, 0.1)
var color_dry := Color(0.55, 0.45, 0.03)

var curr_height: float = max_height
var curr_health: float = 1.0

var tween: Tween

var num_blades_total: int


func _init() -> void:
	mesh_instance = MultiMeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = GRASS_MAT
	mesh_instance.extra_cull_margin = 0.5
	add_child(mesh_instance, true)


	# Only for testing
	set_shader_value(get_curr_color(), 'tip_color')
	set_shader_value(curr_height, 'height_mod')


func get_curr_color() -> Color:
	var curr_color: Color = color_dry.lerp(color_healthy, curr_health)
	return curr_color

	# var color: Color
	# if get_viewport() != null:
	# 	var cam := get_viewport().get_camera_3d()
	# 	var dist: float = cam.global_position.distance_to(global_position)

	# 	var t: float = clampf(remap(dist, 5, 75, 0, 1), 0, 1)
	# 	color = Color.RED.lerp(Color.BLUE, t)

		# DEBUG
		#mesh_instance.multimesh.visible_instance_count = floor(remap(t, 0, 1, num_blades_total, 0))
		# mesh_instance.multimesh.instance_count = floor(remap(t, 0, 1, num_blades_total, 0))

		# for i in range(mesh_instance.multimesh.instance_count):
		# 	mesh_instance.multimesh.set_instance_transform(i, transforms[i])


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

	var mesh_to_use: Mesh = GRASS_MESH_HIGH

	# Reduce in editor
	if Engine.is_editor_hint():
		var in_editor_density_reduction := 0.5
		num_blades_total = round(num_blades_total * in_editor_density_reduction)

	# Reduce if gpu is bad
	if RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		var bad_gpu_reduction := 0.3
		num_blades_total = round(num_blades_total * bad_gpu_reduction)
		mesh_to_use = GRASS_MESH_LOW

	# Compute custom aabb
	mesh_instance.custom_aabb = surface_sampler.compute_custom_aabb(1.0)
	if DebugSettings.visualize_plant_custom_aabb:
		add_custom_aabb_visualization()

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

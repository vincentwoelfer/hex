@tool
class_name SurfacePlant
extends Node3D

# TODO make this extend ressource ????
var mesh_instance: MultiMeshInstance3D = MultiMeshInstance3D.new()

const GRASS_MESH_HIGH := preload('res://assets/grass/grass_high.obj')
const GRASS_MESH_LOW := preload('res://assets/grass/grass_low.obj')
const GRASS_MAT: ShaderMaterial = preload('res://assets/grass/mat_grass.tres')

var min_height := 0.2
var max_height := 4.0

var color_healthy := Color.SEA_GREEN
#var color_dry := Color(0.9, 0.5, 0.3).darkened(0.2)
var color_dry := Color(178, 80, 53)

var rand_color_offset: Color

var curr_height: float = min_height
var curr_health: float = 1.0

var speed := 0.5

var tween: Tween


func _init() -> void:
	mesh_instance = MultiMeshInstance3D.new()
	mesh_instance.name = 'GrassMultiMesh'
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = GRASS_MAT
	mesh_instance.extra_cull_margin = 1.0
	add_child(mesh_instance, true)

	rand_color_offset = Colors.randColorNoExtreme(0.2)
	if randf() <= 0.25:
		rand_color_offset = Color(1, 1, 1)

	# Only for testing
	set_shader_value(get_curr_color(), 'tip_color')
	set_shader_value(curr_height, 'height_mod')
	

func get_curr_color() -> Color:
	var curr_color: Color = color_dry.lerp(color_healthy, curr_health)
	curr_color = curr_color.lerp(rand_color_offset, 0.4)
	curr_color = curr_color.clamp(Color.BLACK, Color.WHITE)
	return curr_color


func processWorldStep(humidity: float, shade: float, nutrition: float) -> void:
	if tween:
		tween.kill()

	# Update own parameters
	var health_delta := (humidity - curr_health) * speed # lerp towards humidity value
	#health_delta += (humidity - 0.5) * 0.5 * speed # Favor extremes
	health_delta += randf_range(-0.2, 0.2) * speed
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
	var density_1d: int = ceil((HexConst.inner_radius + HexConst.outer_radius) / 2.0 * lerpf(0.0, 20.0, HexConst.grass_density));
	var num_blades_total: int = round(density_1d * density_1d)
	var mesh_to_use: Mesh = GRASS_MESH_HIGH
	# Reduce in editor
	if Engine.is_editor_hint():
		var in_editor_density_reduction := 0.1
		num_blades_total = round(num_blades_total * in_editor_density_reduction)

	# Reduce if gpu is bad
	if RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		var bad_gpu_reduction := 0.3
		num_blades_total = round(num_blades_total * bad_gpu_reduction)
		mesh_to_use = GRASS_MESH_LOW


	var multi_mesh := MultiMesh.new()
	multi_mesh.mesh = mesh_to_use
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = num_blades_total

	for i in range(num_blades_total):
		multi_mesh.set_instance_transform(i, surface_sampler.get_random_point_transform())

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

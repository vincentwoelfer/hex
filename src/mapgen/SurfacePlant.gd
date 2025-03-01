class_name SurfacePlant
extends Node3D

var mesh_instance: MultiMeshInstance3D

# In m
var min_height := 0.05
var max_height := 0.3

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
	mesh_instance.material_override = ResLoader.GRASS_MAT
	mesh_instance.extra_cull_margin = 0.5
	add_child(mesh_instance)

	# Only for testing
	set_shader_value(get_curr_color(), 'tip_color')
	set_shader_value(curr_height, 'height_mod')



func recalculate_lod(cam_pos_global: Vector3) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	
	var dist: float = cam_pos_global.distance_squared_to(mesh_instance.global_position)

	var array := calculate_lod(dist)
	var new_lod_factor: float = array[0]
	var new_lod_mesh: int = array[1]
	var new_is_visible: bool = array[2]
	
	update_visibility(new_is_visible)
	update_lod_factor(new_lod_factor)

	if current_lod_mesh != new_lod_mesh:
		current_lod_mesh = new_lod_mesh
		# This is REALLY slow
		update_lod_mesh()


func calculate_lod(dist: float) -> Array:
	var new_lod_factor: float
	var new_lod_mesh: int
	var new_is_visible: bool = true
	
	# LOD mesh switching is the most expensive part -> minimize changing it
	# 0 = HRES, 1 = MRES, 2 = LRES
	if dist <= pow(25, 2):
		new_lod_factor = 1.0
		new_lod_mesh = 2
	elif dist <= pow(32, 2):
		new_lod_factor = 0.9
		new_lod_mesh = 2
	elif dist <= pow(40, 2):
		new_lod_factor = 0.8
		new_lod_mesh = 2
	elif dist <= pow(50, 2):
		new_lod_factor = 0.5
		new_lod_mesh = 2
	elif dist <= pow(60, 2):
		new_lod_factor = 0.3
		new_lod_mesh = 2
	elif dist <= pow(70, 2):
		new_lod_factor = 0.2
		new_lod_mesh = 2
	elif dist <= pow(90, 2):
		new_lod_factor = 0.1
		new_lod_mesh = 2
	elif dist <= pow(120, 2):
		new_lod_factor = 0.05
		new_lod_mesh = 2
	elif dist <= pow(200, 2):
		new_lod_factor = 0.02
		new_lod_mesh = 2
	else:
		new_is_visible = false
	
	return [new_lod_factor, new_lod_mesh, new_is_visible]


func update_visibility(new_is_visible: bool) -> void:
	if not new_is_visible:
		mesh_instance.visible = false
	else:
		mesh_instance.visible = true


func update_lod_factor(new_lod_factor: float) -> void:
	if current_lod_factor != new_lod_factor:
		current_lod_factor = new_lod_factor
		mesh_instance.multimesh.visible_instance_count = floori(num_blades_total * current_lod_factor)


func update_lod_mesh() -> void:
	if current_lod_mesh == 0:
		mesh_instance.multimesh.mesh = ResLoader.GRASS_MESH_HRES
	elif current_lod_mesh == 1:
		mesh_instance.multimesh.mesh = ResLoader.GRASS_MESH_MRES
	else:
		mesh_instance.multimesh.mesh = ResLoader.GRASS_MESH_LRES


func get_curr_color() -> Color:
	var curr_color: Color = color_dry.lerp(color_healthy, curr_health)
	return curr_color


# func processWorldStep(humidity: float, shade: float, nutrition: float) -> void:
# 	if tween:
# 		tween.kill()

# 	# Update own parameters
# 	var speed := 0.5
# 	var health_delta := (humidity - curr_health) * speed # lerp towards humidity value
# 	health_delta += (humidity - 0.5) * 0.5 * speed # Favor extremes
# 	health_delta += randf_range(-0.1, 0.1) * speed

# 	curr_health = clampf(curr_health + health_delta, 0.0, 1.0)
# 	curr_height = clampf(curr_height + nutrition * speed, min_height, max_height)

# 	# Die
# 	if curr_health <= 0.08:
# 		curr_height = min_height
# 		curr_health = 1.0

# 	# Set shader
# 	var color_start: Color = self.get_shader_value_color('tip_color')
# 	var height_start: float = self.get_shader_value_float('height_mod')

# 	# grassMultiMesh.set_instance_shader_parameter('tip_color', color_end)
# 	# grassMultiMesh.set_instance_shader_parameter('tip_color_dry', color_end)
# 	# grassMultiMesh.set_instance_shader_parameter('height_mod', height_end)
# 	# set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

# 	tween = create_tween().set_parallel(true)
# 	tween.tween_method(set_shader_value.bind("tip_color"), color_start, get_curr_color(), 0.4)
# 	tween.tween_method(set_shader_value.bind("height_mod"), height_start, curr_height, 0.4)


func determine_num_blades(surface_sampler: PolygonSurfaceSampler) -> int:
	# Density per 1d-meter (one line)
	var density_1d: float = HexConst.grass_density;
	var area := surface_sampler.get_total_area()
	# Square density to get 2d -> weight by area
	var num_blades : int = round(density_1d * density_1d * area)

	# Reduce in editor
	if Engine.is_editor_hint():
		var in_editor_density_reduction := 1.0
		num_blades = round(num_blades * in_editor_density_reduction)

	# Reduce if gpu is bad
	if RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
		var bad_gpu_reduction := 0.3
		num_blades = round(num_blades * bad_gpu_reduction)

	return num_blades

func populate_multimesh(surface_sampler: PolygonSurfaceSampler) -> void:
	num_blades_total = determine_num_blades(surface_sampler)

	# Compute custom aabb
	mesh_instance.custom_aabb = surface_sampler.compute_custom_aabb(max_height)
	if DebugSettings.visualize_plant_custom_aabb:
		add_custom_aabb_visualization()

	# Create multi-mesh
	var multi_mesh := MultiMesh.new()

	# Use LRES mesh per default because new tiles are added far away -> prevents switching to lres directly
	multi_mesh.mesh = ResLoader.GRASS_MESH_LRES

	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.instance_count = num_blades_total

	# This has basically no performance improvement
	multi_mesh.physics_interpolation_quality = MultiMesh.INTERP_QUALITY_FAST

	# 12 floats per transform = 4 x vec3
	var buffer := PackedFloat32Array()
	buffer.resize(num_blades_total * 12)
	buffer.fill(0.0)

	for i in range(num_blades_total):
		var t := surface_sampler.get_random_point()
		var offset := i * 12

		# Indexing is "interleaved" for vectors (based on matrix layout)
		# First basis, then origin. First all x, then all y, then all z
		# Commented out elements are alway 0.0 (and already filled above)
		buffer[offset + 0] = 1.0
		# buffer[offset + 1] = t.basis.y.x
		# buffer[offset + 2] = t.basis.z.x
		buffer[offset + 3] = t.x
		# buffer[offset + 4] = t.basis.x.y
		buffer[offset + 5] = 1.0
		# buffer[offset + 6] = t.basis.z.y
		buffer[offset + 7] = t.y
		# buffer[offset + 8] = t.basis.x.z
		# buffer[offset + 9] = t.basis.y.z
		buffer[offset + 10] = 1.0
		buffer[offset + 11] = t.z
		
	# Applay buffer and set multimesh
	multi_mesh.set_buffer(buffer)

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
	add_child(vis)

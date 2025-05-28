extends Node3D
class_name CameraController

# Positional parameters. Divided into curr (actual camera values) and goal (values to lerp to) + min/max values
var zoom_curr: float = 15.0
var zoom_goal: float = zoom_curr
var zoom_min: float = 15.0
var zoom_max: float = 35.0
var zoom_input_speed: float = 4.0
var zoom_lerp_speed: float = 10.0

var zoom_min_at_dist: float = 12.0
var zoom_max_at_dist: float = 25.0

var zoom_min_manual: float = 3.0
var zoom_max_manual: float = 50.0
var zoom_manual_override: bool = false

# rotation = view angle = height of camera
var tilt_curr: float = deg_to_rad(50.0)
var tilt_goal: float = tilt_curr
var tilt_min: float = deg_to_rad(15.0) # from side
var tilt_max: float = deg_to_rad(89.5) # from above
var tilt_input_speed: float = deg_to_rad(200.0)
var tilt_lerp_speed: float = deg_to_rad(150.0)

# rotation arount UP axis
var orientation_goal: int = 0
var orientation_angle_curr: float
var orientation_angle_goal: float
var orientation_lerp_speed: float = deg_to_rad(360.0)

# Current follow point (center of players)
var follow_point_curr: Vector3
var follow_point_goal: Vector3
var follow_point_lerp_speed: float = 8.0

var fov_deg: float
var fov_padding_factor: float = 1.0 


# Only for debugging
var draw_debug_follow_point := false
var debug_mesh: MeshInstance3D

@onready var camera: Camera3D = $Camera

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	orientation_angle_goal = Util.get_hex_angle_interpolated(orientation_goal)
	orientation_angle_curr = orientation_angle_goal

	follow_point_goal = GameStateManager.cam_follow_point_manager.calculate_follow_aabb().get_center()
	follow_point_curr = follow_point_goal
	update_position()
	camera.reset_physics_interpolation()

	# Todo verify this is the correct way to get the FOV
	fov_deg = camera.fov

func _input(event: InputEvent) -> void:
	# Orientation (rotation left/right)
	if event.is_action_pressed("cam_rotate_left"):
		orientation_goal = (orientation_goal + 6 - 1) % 6
	if event.is_action_pressed("cam_rotate_right"):
		orientation_goal = (orientation_goal + 6 + 1) % 6
	orientation_angle_goal = Util.get_hex_angle_interpolated(orientation_goal)

	# Zoom (in/out)
	var zoom_input := 0.0
	if event.is_action_pressed("cam_zoom_in"):
		zoom_input -= 1.0
	if event.is_action_pressed("cam_zoom_out"):
		zoom_input += 1.0
		
	update_zoom_manual(zoom_input)

	if event.is_action_pressed("cam_zoom_auto"):
		zoom_manual_override = false


func handle_continuous_input(delta: float) -> void:
	# Tilt (rotation up/down)
	var tilt_input := Input.get_axis("cam_tilt_down", "cam_tilt_up")
	tilt_goal = clampf(tilt_goal + tilt_input * tilt_input_speed * delta, tilt_min, tilt_max)
		
	# Zoom (in/out)
	var zoom_input := Input.get_axis("cam_zoom_in", "cam_zoom_out")
	update_zoom_manual(zoom_input)


func update_zoom_manual(zoom_input: float) -> void:
	if zoom_input != 0.0:
		zoom_manual_override = true
		zoom_goal = clampf(zoom_goal + zoom_input * zoom_input_speed, zoom_min_manual, zoom_max_manual)


func _physics_process(delta: float) -> void:
	handle_continuous_input(delta)

	var aabb := GameStateManager.cam_follow_point_manager.calculate_follow_aabb()

	follow_point_goal = aabb.get_center()

	# Calculate zoom goal based on max dist
	if not zoom_manual_override:
		# var max_dist := GameStateManager.cam_follow_point_manager.calculate_cam_follow_point_max_dist(follow_point_goal)
		# zoom_goal = remap(max_dist, zoom_min_at_dist, zoom_max_at_dist, zoom_min, zoom_max)

		var radius: float = aabb.size.length() * 0.5
		var target_dist : float = radius / tan(deg_to_rad(fov_deg * 0.5)) * fov_padding_factor

		zoom_goal = clampf(target_dist, zoom_min, zoom_max)

	# Compute new current values by lerping towards goal values
	zoom_curr = Util.lerp_towards_f(zoom_curr, zoom_goal, zoom_lerp_speed, delta)
	tilt_curr = Util.lerp_towards_f(tilt_curr, tilt_goal, tilt_lerp_speed, delta)
	orientation_angle_curr = Util.lerp_towards_angle(orientation_angle_curr, orientation_angle_goal, orientation_lerp_speed, delta)
	follow_point_curr = Util.lerp_towards_vec3(follow_point_curr, follow_point_goal, follow_point_lerp_speed, delta)

	# Set values (also global cam orientation)
	update_position()
	GameStateManager.cam_follow_point_manager.set_global_camera_view_angle(orientation_angle_curr)

	draw_debug_mesh(follow_point_curr)

	# TODO this causes stuttering - Invesitage
	#RenderingServer.call_on_render_thread(update_shader_parameters)
	# RenderingServer.global_shader_parameter_set("global_camera_view_direction", actual_curr_rotation)
	# RenderingServer.global_shader_parameter_set("global_player_position", lookAtPoint)

func update_position() -> void:
	var cam_direction := Vector3.BACK.rotated(Vector3.LEFT, tilt_curr).rotated(Vector3.UP, orientation_angle_curr)
	var cam_pos := follow_point_curr + (cam_direction * zoom_curr)
	camera.look_at_from_position(cam_pos, follow_point_curr, Vector3.UP)


func draw_debug_mesh(location: Vector3) -> void:
	if draw_debug_follow_point:
		if debug_mesh == null:
			debug_mesh = MeshInstance3D.new()
			debug_mesh.mesh = DebugVis3D.sphere(0.2, DebugVis3D.mat(Color.CYAN))
			debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Util.get_scene_root().add_child(debug_mesh)

		# Just update global position
		debug_mesh.global_position = location
		debug_mesh.reset_physics_interpolation()


func raycast_into_world() -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_direction := camera.project_ray_normal(mouse_pos)
	var ray_end := ray_origin + ray_direction * 1000.0

	var result := PhysicUtil.raycast(ray_origin, ray_end, Layers.L.ALL)
	return result

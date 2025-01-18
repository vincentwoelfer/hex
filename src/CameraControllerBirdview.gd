extends Camera3D
class_name CameraControllerBirdview

var debug_mesh: MeshInstance3D

# Export parameters
var horizontalDistance: float = 6.0
var height: float = 5.0
var height_min: float = 0.5
var height_max: float = 13.0
var currZoom: float = 5.0
var zoomTarget: float = currZoom

# higher value = further away
var zoom_min: float = 0.075
var zoom_max: float = 12.0

# Half of 2m "character"
var char_height: float = 1.75
var look_at_height_above_ground := char_height * 0.5

var lookAtPoint: Vector3
var followPoint: Vector3 # = target, also used for movement
var orientation: int = 4 # from north looking south (to see the sun moving best)
# current rotation in angle
var actual_curr_rotation: float = 0

var speed: float = 14.0
var rotationLerpSpeed: float = 7.0
var lerpSpeed: float = 8.5 # almost instant, otherwise camera control feels sluggish

var own_movement: bool = false
var player_anchor: Node3D = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	actual_curr_rotation = compute_target_forward_angle(orientation)

	#func _ready() -> void:
	MapGeneration.generation_center_node = self


func get_map_generation_center_position() -> Vector3:
	return followPoint


# TODO:
# https://github.com/godotengine/godot-demo-projects/blob/4.2-31d1c0c/3d/kinematic_character/player/follow_camera.gd
# https://github.com/godotengine/godot-demo-projects/blob/4.2-31d1c0c/3d/kinematic_character/player/cubio.gd

# https://www.youtube.com/watch?v=xIKErMgJ1Yk

func _input(event: InputEvent) -> void:
	# Rotate
	if event.is_action_pressed("rotate_cam_left"):
		orientation = (orientation + 6 - 1) % 6
	if event.is_action_pressed("rotate_cam_right"):
		orientation = (orientation + 6 + 1) % 6

	# Zoom
	var zoom_speed := 0.3
	var zoom_vel := Input.get_axis("zoom_cam_forward", "zoom_cam_backward")
	zoomTarget += zoom_vel * zoom_speed
	zoomTarget = clampf(zoomTarget, zoom_min, zoom_max)


func updateContinuousInputs(delta: float) -> void:
	# Up / Down
	const height_speed := 9.0
	var vel := Input.get_axis("rotate_cam_down", "rotate_cam_up")
	height += vel * height_speed * delta
	height = clampf(height, height_min, height_max)


func getInputVec() -> Vector3:
	var inputDir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var ret: Vector3 = Vector3(inputDir.x, 0, inputDir.y)
	return ret.normalized()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if player_anchor != null:
		followPoint = player_anchor.global_transform.origin

	updateContinuousInputs(delta)

	currZoom = lerpf(currZoom, zoomTarget, rotationLerpSpeed * delta)

	var target_forward_angle := compute_target_forward_angle(orientation)

	actual_curr_rotation = lerp_angle(actual_curr_rotation, target_forward_angle, rotationLerpSpeed * delta)
	var forwardDir := Vector3(0, 0, -1).rotated(Vector3.UP, actual_curr_rotation) # not actually forward, lerps

	# Move follow point
	if own_movement:
		var inputDirRaw := getInputVec()
		var inputDir := inputDirRaw.rotated(Vector3.UP, target_forward_angle)
		followPoint += inputDir * (speed + currZoom / 3.0) * delta
		followPoint.y = get_map_height() + look_at_height_above_ground

	# Lerp follow point to lookAtPoint
	#lookAtPoint = lerp(lookAtPoint, followPoint, lerpSpeed * delta)
	lookAtPoint = followPoint

	# Camera position
	var camPos := lookAtPoint
	camPos += -forwardDir * horizontalDistance * currZoom
	camPos.y += currZoom * height

	global_position = camPos
	look_at(lookAtPoint)

	self.check_for_selection()

	# draw_debug_mesh(lookAtPoint)

	# TODO this causes stuttering - Invesitage
	#RenderingServer.call_on_render_thread(update_shader_parameters)
	# RenderingServer.global_shader_parameter_set("global_camera_view_direction", actual_curr_rotation)
	# RenderingServer.global_shader_parameter_set("global_player_position", lookAtPoint)


func check_for_selection() -> void:
	var hit: Dictionary = self.raycast_into_world()
	# 99999 is a placeholder for no hit, required to deselect tiles if none is selected
	var hit_pos := Vector3(99999, 0, 0)
	if not hit.is_empty():
		hit_pos = hit['position']

	EventBus.emit_signal("Signal_SelectedWorldPosition", hit_pos)


func draw_debug_mesh(location: Vector3) -> void:
	if debug_mesh == null:
		var scene_root := get_tree().root
		debug_mesh = MeshInstance3D.new()
		debug_mesh.name = "CameraControllerCapsule"
		debug_mesh.mesh = DebugShapes3D.create_capsule(char_height, 0.3, Color.RED, true)
		scene_root.add_child(debug_mesh)

	debug_mesh.global_transform.origin = location


func raycast_into_world() -> Dictionary:
	var mouse_pos := get_viewport().get_mouse_position()
	var ray_origin: Vector3 = self.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = self.project_ray_normal(mouse_pos)

	var ray_query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	ray_query.collide_with_areas = true

	var space_state := get_world_3d().direct_space_state
	var result := space_state.intersect_ray(ray_query)
	return result


func compute_target_forward_angle(orientation_: float) -> float:
	# Default Orientation = 1 -> Forward = -Z , this is archived with 90° into sin/cos
	# Thats why we subtract 90°
	var target_forward_angle := deg_to_rad((60.0 * orientation_ + 30.0) - 90.0) # Actually forward
	return target_forward_angle


func get_map_height() -> float:
	var hex_pos: HexPos = HexPos.xyz_to_hexpos_frac(get_map_generation_center_position()).round()
	var tile: HexTile = HexTileMap.get_by_pos(hex_pos)

	if tile != null:
		return tile.height * HexConst.height
	else:
		return 0.0

extends Camera3D

var debugSphere: MeshInstance3D

# Export parameters
var horizontalDistance: float = 6.0
var height: float = 5.0
var currZoom: float = 5.0
var zoomTarget: float = currZoom
# higher value = further away
var zoom_min: float = 0.075
var zoom_max: float = 7.0

var lookAtPoint: Vector3
var followPoint: Vector3 # = target, also used for movement
var orientation: int = 4 # from north looking south (to see the sun moving best)
# current rotation in angle
var actual_curr_rotation: float = 0

var speed: float = 14
var rotationLerpSpeed: float = 7.0
var lerpSpeed: float = 8.0 # almost instant

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	lookAtPoint = Vector3(0, 4, 0)
	followPoint = Vector3(0, 4, 0)
	actual_curr_rotation = compute_target_forward_angle(orientation)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("rotate_cam_left"):
		orientation = (orientation + 6 - 1) % 6
	if event.is_action_pressed("rotate_cam_right"):
		orientation = (orientation + 6 + 1) % 6

	# Zoom
	if Input.is_action_pressed("zoom_cam_forward"):
		zoomTarget -= 0.25
	if Input.is_action_pressed("zoom_cam_backward"):
		zoomTarget += 0.25
	zoomTarget = clampf(zoomTarget, zoom_min, zoom_max)

func getInputVec() -> Vector3:
	var inputDir := Vector3.ZERO
	if Input.is_action_pressed("move_cam_forward"):
		inputDir.z -= 1.0
	if Input.is_action_pressed("move_cam_backward"):
		inputDir.z += 1.0
	if Input.is_action_pressed("move_cam_left"):
		inputDir.x -= 1.0
	if Input.is_action_pressed("move_cam_right"):
		inputDir.x += 1.0
	return inputDir.normalized()


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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	currZoom = lerpf(currZoom, zoomTarget, rotationLerpSpeed * delta)

	var target_forward_angle := compute_target_forward_angle(orientation)

	actual_curr_rotation = lerp_angle(actual_curr_rotation, target_forward_angle, rotationLerpSpeed * delta)
	var forwardDir := Vector3(0, 0, -1).rotated(Vector3.UP, actual_curr_rotation) # not actually forward, lerps

	var inputDirRaw := getInputVec()
	var inputDir := inputDirRaw.rotated(Vector3.UP, target_forward_angle)

	# Move follow point, lookAtPoint follows this
	followPoint += inputDir * (speed + currZoom / 3.0) * delta
	lookAtPoint.x = lerpf(lookAtPoint.x, followPoint.x, lerpSpeed * delta)
	lookAtPoint.z = lerpf(lookAtPoint.z, followPoint.z, lerpSpeed * delta)

	# Camera position
	var camPos := lookAtPoint
	camPos += -forwardDir * horizontalDistance * currZoom
	camPos.y += currZoom * height

	global_position = camPos
	look_at(lookAtPoint)
	
	self.check_for_selection()

	RenderingServer.global_shader_parameter_set("global_camera_view_direction", actual_curr_rotation)

	draw_debug_sphere(lookAtPoint, maxf(currZoom * 0.1, 0.025))
	RenderingServer.global_shader_parameter_set("global_player_position", lookAtPoint)


func check_for_selection() -> void:
	var hit: Dictionary = self.raycast_into_world()
	var hit_pos := Vector3(9999, 0, 0)
	if not hit.is_empty():
		hit_pos = hit['position']

	EventBus.emit_signal("Signal_SelectedWorldPosition", hit_pos)


func draw_debug_sphere(location: Vector3, r: float) -> void:
	if debugSphere == null:
		var scene_root := get_tree().root
		debugSphere = MeshInstance3D.new()
		debugSphere.name = "DebugSphere"
		scene_root.add_child(debugSphere)

	debugSphere.mesh = DebugShapes3D.create_sphere(r, Color.RED)
	debugSphere.global_transform.origin = location

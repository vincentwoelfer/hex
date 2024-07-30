#@tool
extends Camera3D

var debugSphere: MeshInstance3D
func draw_debug_sphere(location, r):
	# Will usually work, but you might need to adjust this.
	var scene_root = get_tree().root.get_children()[0]

	# Create sphere with low detail of size.
	var sphere = SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 6
	sphere.radius = r
	sphere.height = r * 2
	# Bright red material (unshaded).
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0)
	material.flags_unshaded = true
	sphere.surface_set_material(0, material)

	# Add to meshinstance in the right place.
	if debugSphere != null:
		scene_root.remove_child(debugSphere)
	debugSphere = MeshInstance3D.new()
	debugSphere.mesh = sphere
	scene_root.add_child(debugSphere)
	debugSphere.global_transform.origin = location

# Export parameters
var horizontalDistance : float = 6.0
var height : float = 6.0
var zoom : float = 1.0
var zoomTarget : float = 1.0

var lookAtPoint : Vector3
var followPoint : Vector3
# = target, also used for movement
var orientation : int = 1
# current rotation in angle
var currRotation : float = 0

var speed : float = 11
var rotationLerpSpeed : float = 6.5
var lerpSpeed = 8 # almost instant

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	lookAtPoint = Vector3(0, 2, 0)
	followPoint = Vector3(0, 2, 0)

func _input(event):
	if event.is_action_pressed("rotate_cam_left"):
		orientation = (orientation + 6 - 1) % 6
	if event.is_action_pressed("rotate_cam_right"):
		orientation = (orientation + 6 + 1) % 6

	# Zoom
	if Input.is_action_pressed("zoom_cam_forward"):
		zoomTarget -= 0.25
	if Input.is_action_pressed("zoom_cam_backward"):
		zoomTarget += 0.25
	zoomTarget = clampf(zoomTarget, 0.4, 1.8)

func getInputVec() -> Vector3:
	var inputDir = Vector3.ZERO
	if Input.is_action_pressed("move_cam_forward"):
		inputDir.z -= 1.0
	if Input.is_action_pressed("move_cam_backward"):
		inputDir.z += 1.0
	if Input.is_action_pressed("move_cam_left"):
		inputDir.x -= 1.0
	if Input.is_action_pressed("move_cam_right"):
		inputDir.x += 1.0

	return inputDir.normalized()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	zoom = lerpf(zoom, zoomTarget, rotationLerpSpeed * delta)

	# Default Orientation = 1 -> Forward = -Z , this is archived with 90° into sin/cos
	# Thats why we subtract 90°
	var forwardAngle = deg_to_rad((60.0 * orientation + 30.0) - 90) # Actually forwars

	currRotation = lerp_angle(currRotation, forwardAngle, rotationLerpSpeed * delta)
	var forwardDir = Vector3(0,0,-1).rotated(Vector3.UP, currRotation) # not actually forward, lerps

	var inputDirRaw = getInputVec()
	var inputDir = inputDirRaw.rotated(Vector3.UP, forwardAngle)

	# Move follow point, lookAtPoint follows this
	followPoint += inputDir * speed * delta
	lookAtPoint.x = lerpf(lookAtPoint.x, followPoint.x, lerpSpeed * delta)
	lookAtPoint.z = lerpf(lookAtPoint.z, followPoint.z, lerpSpeed * delta)

	draw_debug_sphere(lookAtPoint, 0.1)

	# Camera position
	var camPos := lookAtPoint
	camPos += -forwardDir * horizontalDistance * zoom
	camPos.y += zoom * height

	global_position = camPos
	look_at(lookAtPoint)

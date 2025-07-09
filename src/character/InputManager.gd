class_name InputManager
extends Object

var device_id: int

var mouse_sensitivity := 0.08
var controller_sensitivity := 0.5

# Normalized movement input direction
# NOT transformed by current rotation
var input_direction: Vector3 = Vector3.ZERO

# Rotation. Currently this is the mouse input
var looking_dir: Vector3 = Vector3.ZERO
# var relative_rotation: Vector2 = Vector2.ZERO

# Special movement inputs
# Hold-Down
var wants_sprint: bool = false

# Press-Once
var jump_input: BufferedInputAction
var dash_input: BufferedInputAction
var skill_primary_input: BufferedInputAction
var skill_secondary_input: BufferedInputAction

var pickup_drop_input: BufferedInputAction

func _init(device_id_: int, parent_node_: Node3D) -> void:
	device_id = device_id_

	jump_input = BufferedInputAction.new(device_id, "jump", 0.125)
	dash_input = BufferedInputAction.new(device_id, "dash", 0.08)
	skill_primary_input = BufferedInputAction.new(device_id, "skill_primary", 0.1)
	skill_secondary_input = BufferedInputAction.new(device_id, "skill_secondary", 0.1)
	pickup_drop_input = BufferedInputAction.new(device_id, "pickup_drop", 0.1)
	

# Called once per frame / physics tick
func process(delta: float, world_pos: Vector3) -> void:
	# Press-Once
	self.jump_input.update(delta)
	self.dash_input.update(delta)
	self.skill_primary_input.update(delta)
	self.skill_secondary_input.update(delta)
	self.pickup_drop_input.update(delta)

	# Hold-Down
	self.wants_sprint = HexInput.is_action_pressed(device_id, "sprint")

	# Directional Movement (WASD / JoyStick)
	var inputDir := HexInput.get_vector(device_id, "move_left", "move_right", "move_forward", "move_backward")
	self.input_direction = Util.to_vec3(inputDir)
	
	# Rotate the input direction by the global camera's rotation
	var cam_view_angle := GameStateManager.cam_follow_point_manager.get_global_camera_view_angle()
	self.input_direction = self.input_direction.rotated(Vector3.UP, cam_view_angle).normalized()

	# Looking direction (Mouse / Right Joystick)
	if HexInput.is_mouse_keyboard_device(device_id):
		var hit := PhysicUtil.raycast_from_camera(Layers.PHY_TERRAIN_AND_STATIC)
		if hit.is_empty():
			self.looking_dir = Vector3.INF # Default looking direction if no hit
		else:
			var hit_pos: Vector3 = hit.position
			self.looking_dir = Util.to_vec3_planar(hit_pos - world_pos).normalized()

	# Looking direction for controller
	else:
		var right_joystick := HexInput.get_vector(device_id, "look_left", "look_right", "look_up", "look_down")
		self.looking_dir = Util.to_vec3(right_joystick)


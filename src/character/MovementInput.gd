class_name MovementInput
extends Node

var mouse_sensitivity := 0.10

# Normalized movement input direction
# NOT transformed by current rotation
var input_direction: Vector3 = Vector3.ZERO

# Rotation. Currently this is the mouse input
var relative_rotation: Vector2 = Vector2.ZERO

# Special movement input. For player, this translates to "is the key pressed"
var wants_jump: bool = false
var wants_dash: bool = false
var wants_sprint: bool = false

func handle_input_event(event: InputEvent) -> void:
    ###################
    ### Mouse Input
    ###################
    if event is InputEventMouseMotion:
        var e := event as InputEventMouseMotion
        # Character rotation
        self.relative_rotation.y = deg_to_rad(-e.relative.x * mouse_sensitivity)
        # rotate_y()

        # Head rotation
        self.relative_rotation.x = deg_to_rad(-e.relative.y * mouse_sensitivity)
        #head.rotate_x(deg_to_rad(-e.relative.y * mouse_sensitivity))
        #head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

    ###################
    ### Keyboard Input
    ###################


func update_keys() -> void:
    # Hold-Down
    if Input.is_action_pressed("sprint"):
        self.wants_sprint = true

    # Press-Once
    if Input.is_action_just_pressed("jump"):
        self.wants_jump = true

    if Input.is_action_just_pressed("dash"):
        self.wants_dash = true

    # Directional (WASD)
    var inputDir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    self.input_direction = Vector3(inputDir.x, 0.0, inputDir.y).normalized()


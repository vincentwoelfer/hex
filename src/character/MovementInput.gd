class_name MovementInput
extends Node

var mouse_sensitivity := 0.08

# Normalized movement input direction
# NOT transformed by current rotation
var input_direction: Vector3 = Vector3.ZERO

# Rotation. Currently this is the mouse input
var relative_rotation: Vector2 = Vector2.ZERO

# Special movement inputs
# Hold-Down
var wants_sprint: bool = false

# Press-Once
var jump_input := BufferedInputAction.new("jump", 0.125)
var dash_input := BufferedInputAction.new("dash", 0.08)


func handle_input_event(event: InputEvent) -> void:
    ###################
    ### Mouse Input
    ###################
    if event is InputEventMouseMotion:
        var e := event as InputEventMouseMotion
        # Character rotation
        self.relative_rotation.y = deg_to_rad(-e.relative.x * mouse_sensitivity)

        # Head rotation
        self.relative_rotation.x = deg_to_rad(-e.relative.y * mouse_sensitivity)


func consume_mouse_input() -> void:
    self.relative_rotation = Vector2.ZERO


# Called once per frame / physics tick
func update_keys(delta: float) -> void:
    # Hold-Down
    self.wants_sprint = Input.is_action_pressed("sprint")

    # Press-Once
    self.jump_input.update(delta)
    self.dash_input.update(delta)

    # Directional (WASD)
    var inputDir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    self.input_direction = Vector3(inputDir.x, 0.0, inputDir.y).normalized()

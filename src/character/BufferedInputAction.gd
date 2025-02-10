class_name BufferedInputAction

var action_name: String
var wants: bool
var buffer_time_sec: float
var buffer_timer: float

func _init(action_name_: String, buffer_time_sec_: float) -> void:
    if not InputMap.has_action(action_name_):
        print("Warning: BufferedInputAction Action not found in InputMap: " + action_name_)

    self.action_name = action_name_
    self.buffer_time_sec = buffer_time_sec_
    self.buffer_timer = 0.0


func update(delta: float) -> void:
    var pressed := Input.is_action_just_pressed(action_name)

    if pressed:
        buffer_timer = buffer_time_sec
        wants = true
    else:
        buffer_timer -= delta
        wants = buffer_timer > 0.0


func consume() -> void:
    wants = false
    buffer_timer = 0.0

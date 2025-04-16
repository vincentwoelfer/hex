class_name BufferedInputAction

# Input mapping
var device: int
var action_name: String

## Does the action want to be triggered right now?
var wants: bool

## Time in seconds how long to buffer the action.
##[br] Without being consumed, wants stays true for this long after the button has been pressed.
var buffer_time_sec: float

## Timer for the buffered action.
var buffer_timer: float

func _init(device_: int, action_name_: String, buffer_time_sec_: float) -> void:
	if not InputMap.has_action(action_name_):
		print("Warning: BufferedInputAction Action not found in InputMap: " + action_name_)

	self.device = device_
	self.action_name = action_name_

	self.buffer_time_sec = buffer_time_sec_

	# Reset state
	self.wants = false
	self.buffer_timer = 0.0


func update(delta: float) -> void:
	var pressed := HexInput.is_action_just_pressed(device, action_name)

	if pressed:
		buffer_timer = buffer_time_sec
		wants = true
	else:
		buffer_timer -= delta
		wants = buffer_timer > 0.0


func consume() -> void:
	# Reset state
	wants = false
	buffer_timer = 0.0

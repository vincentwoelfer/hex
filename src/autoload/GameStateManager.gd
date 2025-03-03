# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node


var global_camera_view_angle: float


func _ready() -> void:
	# Print Input Mappings
	# pretty_print_actions(get_input_mapping())
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Input.mouse_mode = Input.MOUSE_MODE_CONFINED


# React to keyboard inputs to directly trigger events
func _input(event: InputEvent) -> void:
	# Only execute in game, check necessary because EventBus is @tool
	if not Engine.is_editor_hint():
		# if event.is_action_pressed("toogle_per_tile_ui"):
			# print("PerTileUI visibility toogled")
			# EventBus.Signal_TooglePerTileUi.emit()
		###################################################################
		# NON-Signal Input Actions
		###################################################################
		# Quit game
		if event.is_action_pressed("quit_game"):
			request_quit_game()


func request_quit_game() -> void:
	Util.print_multiline_banner("Quitting game")
	MapGeneration.shutdown_threads()


func get_cam_follow_point() -> Vector3:
	# Depending on game state, this may not follow the players
	return PlayerManager.calculate_cam_follow_point()


func set_global_camera_view_angle(angle: float) -> void:
	global_camera_view_angle = angle

func get_global_camera_view_angle() -> float:
	return global_camera_view_angle


##################################################################
# Helper Functions
###################################################################
func get_input_mapping() -> Dictionary[String, String]:
	var mapping: Dictionary[String, String] = {}
	for action in InputMap.get_actions():
		if not (action.begins_with("ui_") or action.begins_with("cam_") or action.begins_with("spatial_")):
			mapping[action] = get_keys_for_action(action)
	return mapping


func get_keys_for_action(action: String) -> String:
	var key_list := []
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			# Add the physical key code to the list
			var key_string: String = (event as InputEventKey).as_text_physical_keycode()
			key_list.append(key_string)
		elif event is InputEventJoypadButton:
			var key_string: String = (event as InputEventJoypadButton).as_text()
			key_list.append(key_string)
	return ", ".join(key_list)


func pretty_print_actions(actions_dict: Dictionary[String, String]) -> void:
	var max_action_length: int = 0
	for action: String in actions_dict.keys():
		max_action_length = max(max_action_length, action.length())

	# Sort the dictionary by values (hotkeys) alphabetically
	var sorted_hotkeys: Array[String] = actions_dict.values()
	sorted_hotkeys.sort_custom(func(a: String, b: String) -> bool: return a < b)

	Util.print_banner("Key Bindings")
	for hotkey: String in sorted_hotkeys:
		var action := get_key_by_value(actions_dict, hotkey)
		var padding: String = " ".repeat(max_action_length - action.length())
		print("- %s:%s    %s" % [action, padding, actions_dict[action]])
	Util.print_only_banner()


func get_key_by_value(dict: Dictionary[String, String], value: String) -> String:
	for key: String in dict:
		if dict[key] == value:
			return key
	# Return an empty string if no matching value is found
	return ""

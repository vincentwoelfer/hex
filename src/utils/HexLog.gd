@tool
class_name HexLog

######################################################
# Printing / Logging
######################################################
const BANNER_WIDTH: int = 64
const BANNER_CHAR: String = "="

static func print_only_banner() -> void:
	print(BANNER_CHAR.repeat(BANNER_WIDTH))

static func print_banner(string: String) -> void:
	# Souround string with spaces
	string = " " + string + " "

	print(center_text(string, BANNER_WIDTH, BANNER_CHAR))

static func print_multiline_banner(string: String) -> void:
	# Souround string with spaces
	string = " " + string + " "

	var banner_line: String = BANNER_CHAR.repeat(BANNER_WIDTH)
	print(banner_line, "\n", center_text(string, BANNER_WIDTH, BANNER_CHAR), "\n", banner_line)

static func center_text(text: String, width: int, filler: String) -> String:
	var pad_size_total: int = max(0, (width - text.length()))

	var pad_size_left: int
	var pad_size_right: int
	if pad_size_total % 2 == 0:
		var pad_size: int = int(pad_size_total / 2.0)
		pad_size_left = pad_size
		pad_size_right = pad_size
	else:
		pad_size_left = floori(pad_size_total / 2.0)
		pad_size_right = pad_size_left + 1

	return filler.repeat(pad_size_left) + text + filler.repeat(pad_size_right)



##################################################################
# Helper Functions for displaying all key mappings. Old, maybe reuse
###################################################################
# func get_input_mapping() -> Dictionary[String, String]:
# 	var mapping: Dictionary[String, String] = {}
# 	for action in InputMap.get_actions():
# 		if not (action.begins_with("ui_") or action.begins_with("cam_") or action.begins_with("spatial_")):
# 			mapping[action] = get_keys_for_action(action)
# 	return mapping


# func get_keys_for_action(action: String) -> String:
# 	var key_list := []
# 	var events := InputMap.action_get_events(action)
# 	for event in events:
# 		if event is InputEventKey:
# 			# Add the physical key code to the list
# 			var key_string: String = (event as InputEventKey).as_text_physical_keycode()
# 			key_list.append(key_string)
# 		elif event is InputEventJoypadButton:
# 			var key_string: String = (event as InputEventJoypadButton).as_text()
# 			key_list.append(key_string)
# 	return ", ".join(key_list)


# func pretty_print_actions(actions_dict: Dictionary[String, String]) -> void:
# 	var max_action_length: int = 0
# 	for action: String in actions_dict.keys():
# 		max_action_length = max(max_action_length, action.length())

# 	# Sort the dictionary by values (hotkeys) alphabetically
# 	var sorted_hotkeys: Array[String] = actions_dict.values()
# 	sorted_hotkeys.sort_custom(func(a: String, b: String) -> bool: return a < b)

# 	HexLog.print_banner("Key Bindings")
# 	for hotkey: String in sorted_hotkeys:
# 		var action := get_key_by_value(actions_dict, hotkey)
# 		var padding: String = " ".repeat(max_action_length - action.length())
# 		print("- %s:%s    %s" % [action, padding, actions_dict[action]])
# 	HexLog.print_only_banner()


# func get_key_by_value(dict: Dictionary[String, String], value: String) -> String:
# 	for key: String in dict:
# 		if dict[key] == value:
# 			return key
# 	# Return an empty string if no matching value is found
# 	return ""

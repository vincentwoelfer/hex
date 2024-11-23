# Needs to be tool to enable event bus already in the editor itself
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

signal Signal_HexConstChanged()
signal Signal_SelectedWorldPosition(selection_position: Vector3)
signal Signal_SelectedHexTile(new_hex: HexTile)

# TIME
# Only for visual purposes
signal Signal_SetVisualLightTime(new_time: float)
signal Signal_WorldStep()
signal Signal_DayTimeChanged(new_time: float)
signal Signal_WeatherChanged(new_weather: WeatherControl.WeatherType)

###################################
# DIRECTLY FROM INPUT KEYS (default key as comment behind signal)
###################################
signal Signal_TooglePerTileUi() # 1
signal Signal_ToogleWorldTimeAutoAdvance() # 2
signal Signal_randomizeSelectedTile() # 3
signal Signal_TriggerWeatherChange() # 4
signal Signal_TriggerLod(cam_pos_global: Vector3) # 9
signal Signal_AdvanceWorldTimeOneStep() # Space
signal Signal_ToggleSpeedUpTime() # Shift


func _ready() -> void:
	# Print Input Mappings
	pretty_print_actions(get_input_mapping())

	# Actual signal connection is done in the code catching the signal like this:
	# EventBus.Signal_HexConstChanged.connect(generate_geometry)

	# Signal emitting is done like this:
	# EventBus.emit_signal("Signal_HexConstChanged", ...)

	##################
	# Connect signals here to enable logging functions below.
	##################

	# Connect to events to print debug info
	Signal_WeatherChanged.connect(_on_Signal_WeatherChanged)

	# Create a timer to trigger LOD updates
	var timer: Timer = Timer.new()
	timer.wait_time = 0.1 # Time in seconds
	timer.one_shot = false # Repeat indefinitely
	add_child(timer)
	timer.start()

	timer.timeout.connect(func() -> void:
		Signal_TriggerLod.emit(Util.get_global_cam_pos(self))
	)

	# Set occlusion culling on startup
	get_tree().root.use_occlusion_culling = DebugSettings.generate_terrain_occluder


# React to keyboard inputs to directly trigger events
func _input(event: InputEvent) -> void:
	# Only execute in game, check necessary because EventBus is @tool
	if not Engine.is_editor_hint():

		if event.is_action_pressed("toogle_per_tile_ui"):
			print("Toogle per tile UI")
			Signal_TooglePerTileUi.emit()

		if event.is_action_pressed("toogle_world_time_auto_advance"):
			Signal_ToogleWorldTimeAutoAdvance.emit()

		if event.is_action_pressed("advance_world_time_one_step"):
			Signal_AdvanceWorldTimeOneStep.emit()

		if event.is_action_pressed("randomize_selected_tile"):
			Signal_randomizeSelectedTile.emit()

		if event.is_action_pressed("hold_speed_up_time"):
			Signal_ToggleSpeedUpTime.emit()

		if event.is_action_pressed("trigger_weather_change"):
			Signal_TriggerWeatherChange.emit()

		if event.is_action_pressed("trigger_lod"):
			Signal_TriggerLod.emit(Util.get_global_cam_pos(self))

	###################################################################
	# NON-Signal Input Actions
	###################################################################
		if event.is_action_pressed("quit_game"):
			call_deferred("quit_game")

		if event.is_action_pressed("toogle_occlusion_culling"):
			if not DebugSettings.generate_terrain_occluder:
				print("Occlusion Culling not available without terrain occluders, can't enble it with this hotkey!")
				return

			get_tree().root.use_occlusion_culling = !get_tree().root.use_occlusion_culling
			print("Occlusion Culling set to ", get_tree().root.use_occlusion_culling)


func quit_game() -> void:
	print("================================= Quitting game =================================")
	# Finish threds before quitting tree
	(get_node('../MainScene/%MapGeneration') as MapGeneration).join_threads()
	get_tree().quit()

func _on_Signal_WeatherChanged(new_weather: WeatherControl.WeatherType) -> void:
	print("EventBus: Weather Changed to ", WeatherControl.WeatherType.keys()[new_weather])


# Helper functions
func get_input_mapping() -> Dictionary[String, String]:
	var mapping: Dictionary[String, String] = {}
	for action in InputMap.get_actions():
		if action.begins_with("ui_") or action.contains("_cam_") or action.begins_with("spatial_"):
			continue

		mapping[action] = get_keys_for_action(action)
	return mapping

func get_keys_for_action(action: String) -> String:
	var key_list := []
	var events := InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			key_list.append((event as InputEventKey).as_text_physical_keycode())
	return ", ".join(key_list)


func pretty_print_actions(actions_dict: Dictionary[String, String]) -> void:
	var max_action_length: int = 0
	for action: String in actions_dict.keys():
		max_action_length = max(max_action_length, action.length())
	
	# Sort the dictionary by values (hotkeys) alphabetically
	var sorted_hotkeys: Array[String] = actions_dict.values()
	sorted_hotkeys.sort_custom(func(a: String, b: String) -> bool: return a < b)
	
	print("=============== Key Bindings ===============")
	for hotkey: String in sorted_hotkeys:
		var action := get_key_by_value(actions_dict, hotkey)
		var padding: String = " ".repeat(max_action_length - action.length())
		print("%s:%s\t%s" % [action, padding, actions_dict[action]])
	print("============================================")


func get_key_by_value(dict: Dictionary[String, String], value: String) -> String:
	for key: String in dict:
		if dict[key] == value:
			return key
	# Return an empty string if no matching value is found
	return ""

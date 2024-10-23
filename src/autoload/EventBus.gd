# Needs to be tool to enable event bus already in the editor itself
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

signal Signal_HexConstChanged()
signal Signal_SelectedWorldPosition(selection_position: Vector3)
signal Signal_SelectedHexTile(new_hex: HexTile)

# Debug Signals
signal Signal_TooglePerTileUi(is_visible: bool)
# TODO this should not be saved here!
var is_per_tile_ui_on: bool = false

signal Signal_randomizeSelectedTile()

# TIME
# Only for visual purposes
signal Signal_SetVisualLightTime(new_time: float)

#
signal Signal_AdvanceWorldTimeOneStep() # Is input signal
signal Signal_ToogleWorldTimeAutoAdvance()

signal Signal_WorldStep()
signal Signal_ToggleSpeedUpTime()
signal Signal_DayTimeChanged(new_time: float)

signal Signal_TriggerWeatherChange() # Manual trigger for debugging, not intended for broadcasting
signal Signal_WeatherChanged(new_weather: WeatherControl.WeatherType) # For broadcasting

func _ready() -> void:
	# Connect signals here to enable logging functions below.
	# Actual signal connection is done in the code catching the signal like this:
	# EventBus.Signal_HexConstChanged.connect(generate_geometry)

	# Signal emittion:
	# EventBus.emit_signal("Signal_HexConstChanged", ...)

	# Connect to events to print debug info
	Signal_HexConstChanged.connect(_on_Signal_HexConstChanged)
	Signal_WeatherChanged.connect(_on_Signal_WeatherChanged)


# React to keyboard inputs to directly trigger events
func _input(event: InputEvent) -> void:
	# Only execute in game, check necessary because EventBus is @tool
	if not Engine.is_editor_hint():
		if event.is_action_pressed("toogle_per_tile_ui"):
			is_per_tile_ui_on = !is_per_tile_ui_on
			Signal_TooglePerTileUi.emit(is_per_tile_ui_on)

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

		if event.is_action_pressed("quit_game"):
			get_tree().quit()

# Function to handle the signal
func _on_Signal_HexConstChanged() -> void:
	pass
	#print("EventBus: Signal_HexConstChanged")

# Function to handle the signal
func _on_Signal_WeatherChanged(new_weather: WeatherControl.WeatherType) -> void:
	print("EventBus: Weather Changed to ", WeatherControl.WeatherType.keys()[new_weather])

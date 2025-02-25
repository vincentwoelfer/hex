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
# signal Signal_TooglePerTileUi() # 1


func _ready() -> void:
	# Actual signal connection is done in the code catching the signal like this:
	# EventBus.Signal_HexConstChanged.connect(generate_geometry)

	# Signal emitting is done like this:
	# EventBus.emit_signal("Signal_HexConstChanged", ...)

	##################
	# Connect signals here to enable logging functions below.
	##################

	# Connect to events to print debug info
	Signal_WeatherChanged.connect(_on_Signal_WeatherChanged)


func _on_Signal_WeatherChanged(new_weather: WeatherControl.WeatherType) -> void:
	print("EventBus: Weather Changed to ", WeatherControl.WeatherType.keys()[new_weather])



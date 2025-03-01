# Needs to be tool to enable event bus already in the editor itself
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# signal Signal_HexConstChanged()


###################################
# DIRECTLY FROM INPUT KEYS (default key as comment behind signal)
###################################
# signal Signal_TooglePerTileUi() # 1


func _ready() -> void:
	pass
	# Actual signal connection is done in the code catching the signal like this:
	# EventBus.Signal_HexConstChanged.connect(generate_geometry)

	# Signal emitting is done like this:
	# EventBus.emit_signal("Signal_HexConstChanged", ...)

	##################
	# Connect signals here to enable logging functions below.
	##################


# func _on_Signal_WeatherChanged(new_weather: WeatherControl.WeatherType) -> void:
# 	print("EventBus: Weather Changed to ", WeatherControl.WeatherType.keys()[new_weather])


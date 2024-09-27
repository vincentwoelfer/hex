@tool
class_name WeatherControl
extends Node

enum WeatherType {SUNSHINE, DRIZZLE, RAIN, HEAVY_RAIN, FOG}

@export var starting_weather: WeatherControl.WeatherType = WeatherControl.WeatherType.SUNSHINE
var current_weather: WeatherControl.WeatherType

func _ready() -> void:
	current_weather = starting_weather


func change_weather(new_weather: WeatherType) -> void:
	if new_weather != current_weather:
		current_weather = new_weather

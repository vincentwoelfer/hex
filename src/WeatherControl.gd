@tool
class_name WeatherControl
extends Node

enum WeatherType {SUNSHINE, DRIZZLE, RAIN, HEAVY_RAIN, FOG}

@export var starting_weather: WeatherControl.WeatherType = WeatherControl.WeatherType.SUNSHINE
var current_weather: WeatherControl.WeatherType

func _ready() -> void:
	current_weather = starting_weather
	EventBus.Signal_TriggerWeatherChange.connect(_on_weather_change_trigger)


func change_weather(new_weather: WeatherType) -> void:
	if new_weather != current_weather:
		current_weather = new_weather

func _on_weather_change_trigger() -> void:
	
	# TODO set these according to the WeatherSource of the day
	var weather_options := WeatherType.keys()
	var weather_probabilities : Array = []
	weather_probabilities.resize(weather_options.size())
	weather_probabilities.fill(1)


	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var new_weather = WeatherType[weather_options[rng.rand_weighted(weather_probabilities)]]

	change_weather(new_weather)
	

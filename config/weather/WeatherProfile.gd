@tool
class_name WeatherProfile
extends Resource

@export var temperature_change := 0

@export_category("Weather stats")
@export var weather_change_probability := 0.4
@export var weather_distribution: Dictionary[String, float] = {}

func sample_weather_type() -> WeatherControl.WeatherType:
	if weather_distribution.is_empty():
		return WeatherControl.WeatherType.SUNSHINE

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var rand_index: String = weather_distribution.keys()[rng.rand_weighted(weather_distribution.values())]
	var new_weather: WeatherControl.WeatherType = WeatherControl.WeatherType[rand_index]
	return new_weather

class_name WeatherProfile
extends Resource

@export var temperature_change := 0

@export_category("Weather stats")
@export var weather_change_probability := 0.4
@export var weather_distribution : Dictionary[String, float] = {
	"SUNSHINE": 1,
	"RAIN": 1,
}

func sample_weather_type() -> WeatherControl.WeatherType:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()

	var	new_weather =  WeatherControl.WeatherType[weather_distribution.keys()[rng.rand_weighted(weather_distribution.values())]]
	return new_weather

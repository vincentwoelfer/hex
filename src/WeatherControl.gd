@tool
class_name WeatherControl
extends Node

enum WeatherType {SUNSHINE, DRIZZLE, RAIN, HEAVY_RAIN, FOG}

@export var starting_weather: WeatherControl.WeatherType = WeatherControl.WeatherType.SUNSHINE
@export var weather_change_probability := 0.3 # per hour

var current_weather: WeatherControl.WeatherType
@onready var rain_particles: GPUParticles3D = %RainParticles

var weather_properties: Dictionary[WeatherType, Dictionary] = {
	WeatherType.SUNSHINE: {
		"sun_light_color": lerp(Color.LIGHT_YELLOW, Color.YELLOW, 0.4), 
		},
	WeatherType.DRIZZLE: {
		"sun_light_color": Color.DARK_GRAY,
		"env_volumetric_fog_density": 0.015
		},
	WeatherType.RAIN: {
		"sun_light_color": Color.DARK_GRAY,
		"env_volumetric_fog_density": 0.015
	},
	WeatherType.HEAVY_RAIN: {
		"sun_light_color": Color.DIM_GRAY,
		"env_volumetric_fog_density": 0.015
	},
	WeatherType.FOG: {
		"sun_light_color": Color.DARK_GRAY,
		"env_volumetric_fog_density": 0.030
	}
}


func _ready() -> void:
	current_weather = starting_weather
	EventBus.Signal_TriggerWeatherChange.connect(random_weather_change)
	EventBus.Signal_DayTimeChanged.connect(_on_time_progression)
	
	rain_particles.amount = 0
	rain_particles.hide()

func change_weather(new_weather: WeatherType) -> void:
	if new_weather != current_weather:
		current_weather = new_weather
		EventBus.Signal_WeatherChanged.emit(new_weather)
		update_rain(new_weather)
		
func update_rain(new_weather: WeatherType) -> void:
	var rain_amount := 0
	var tween = get_tree().create_tween()
	
	var rainy_weather_types = [WeatherType.DRIZZLE, WeatherType.RAIN, WeatherType.HEAVY_RAIN]
	if new_weather in rainy_weather_types:
		match new_weather:
			WeatherType.DRIZZLE: 
				rain_amount = 150
			WeatherType.RAIN:
				rain_amount = 300
			WeatherType.HEAVY_RAIN:
				rain_amount = 1000
		rain_particles.show()
	else:
		rain_particles.hide()

	rain_particles.amount = rain_amount


func _on_time_progression(day_time: float):
	if randf() < weather_change_probability:
		random_weather_change()

func random_weather_change() -> void:
	
	# TODO set these according to the WeatherSource of the day
	var weather_options := WeatherType.keys()
	var weather_probabilities : Array = []
	weather_probabilities.resize(weather_options.size())
	weather_probabilities.fill(1)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var new_weather = current_weather

	while new_weather == current_weather:
		new_weather = WeatherType[weather_options[rng.rand_weighted(weather_probabilities)]]
	change_weather(new_weather)
	

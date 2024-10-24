@tool
class_name WeatherControl
extends Node

enum WeatherType {SUNSHINE, CLOUDY, DRIZZLE, RAIN, HEAVY_RAIN, FOG}

@export var starting_weather: WeatherControl.WeatherType = WeatherControl.WeatherType.SUNSHINE
@export var weather_profile: WeatherProfile

var current_weather: WeatherControl.WeatherType
@onready var rain_particles: GPUParticles3D = %RainParticles

var weather_properties: Dictionary[WeatherType, Dictionary] = {
	WeatherType.SUNSHINE: {
		"sun_light_color": Color.LIGHT_YELLOW,
		"env_volumetric_fog_density": 0.003
	},
	WeatherType.CLOUDY: {
		"sun_light_color": Color.SNOW,
	},
	WeatherType.DRIZZLE: {
		"sun_light_color": Color.GRAY,
		"env_volumetric_fog_density": 0.01
	},
	WeatherType.RAIN: {
		"sun_light_color": Color.GRAY,
		"env_volumetric_fog_density": 0.01
	},
	WeatherType.HEAVY_RAIN: {
		"sun_light_color": Color.GRAY,
		"env_volumetric_fog_density": 0.01
	},
	WeatherType.FOG: {
		"sun_light_color": Color.GRAY,
		"env_volumetric_fog_density": 0.03
	}
}

# Actual tween duration may be limited further if time is auto-advancing
var tween: Tween
var desired_tween_duration := 0.25

# Wind strength and wetness shader parameters
var current_wind_strength := 1.0
var target_wind_strength := current_wind_strength
var max_wind_strength := 1.7

var current_wetness := 0.0
var target_wetness := current_wetness

var current_rain_amount_ratio := 0.0

func _ready() -> void:
	EventBus.Signal_TriggerWeatherChange.connect(force_new_weather)
	EventBus.Signal_DayTimeChanged.connect(_on_time_progression)

	if weather_profile == null:
		push_warning("No weather profile assigned, using default 'mixed'!")
		weather_profile = load("res://config/weather/MixedWeatherProfile.tres") as WeatherProfile

	current_weather = starting_weather
	rain_particles.amount_ratio = compute_rain_amount_ratio(current_weather)


func change_weather(new_weather: WeatherType) -> void:
	if new_weather != current_weather:
		current_weather = new_weather
		update_rain(new_weather)
		EventBus.Signal_WeatherChanged.emit(new_weather)


func compute_rain_amount_ratio(weather: WeatherType) -> float:
	var rain_ratio := 0.0
	if weather in [WeatherType.DRIZZLE, WeatherType.RAIN, WeatherType.HEAVY_RAIN]:
		match weather:
			WeatherType.DRIZZLE:
				rain_ratio = 0.2
			WeatherType.RAIN:
				rain_ratio = 0.5
			WeatherType.HEAVY_RAIN:
				rain_ratio = 1.0
	else:
		rain_ratio = 0.0
	return rain_ratio


func update_rain(new_weather: WeatherType) -> void:
	current_rain_amount_ratio = compute_rain_amount_ratio(new_weather)

	# Tween to value
	# Delete previous tween if still existing
	if tween:
		tween.kill()

	# Create Tween
	tween = create_tween().set_parallel(true)

	# Dont tween for longer than one hour lasts when auto-forwarding time
	var world_time_manager := get_node('%WorldTimeManager') as WorldTimeManager
	var current_tween_duration := minf(desired_tween_duration, world_time_manager.get_max_tween_time())
	tween.tween_property(rain_particles, "amount_ratio", current_rain_amount_ratio, current_tween_duration)

	# Compute target wind strength - rain+random for now
	target_wind_strength = (0.5 + current_rain_amount_ratio * 1.3 + randf_range(-0.3, 0.5))
	target_wind_strength = clampf(target_wind_strength, 0.0, max_wind_strength)

	if current_rain_amount_ratio > 0.0:
		target_wetness = 1.0
	else:
		target_wetness = 0.0


func change_towards_linear(curr: float, target: float, speed: float) -> float:
	var sgn := signf(target - curr)
	var result := curr + sgn * speed

	# Prevent overshooting
	if sgn > 0:
		result = min(result, target)
	else:
		result = max(result, target)
	return result


func _process(delta: float) -> void:
	# Update wind strength and wetness
	const wind_change_speed := 0.6
	current_wind_strength = change_towards_linear(current_wind_strength, target_wind_strength, wind_change_speed * delta)
	current_wind_strength = clampf(current_wind_strength, 0.0, max_wind_strength)

	const wetness_change_speed_saturating := 0.6
	const wetness_change_speed_drying := 0.1
	var wetness_change_speed: float
	if target_wetness > current_wetness:
		wetness_change_speed = wetness_change_speed_saturating * current_rain_amount_ratio
	else:
		wetness_change_speed = wetness_change_speed_drying
	
	current_wetness = change_towards_linear(current_wetness, target_wetness, wetness_change_speed * delta)
	current_wetness = clampf(current_wetness, 0.0, 1.0)

	# Set on rendering server
	RenderingServer.global_shader_parameter_set("global_wind_strength", current_wind_strength)
	RenderingServer.global_shader_parameter_set("global_world_wetness", current_wetness)

func _on_time_progression(day_time: float) -> void:
	if randf() < weather_profile.weather_change_probability:
		change_weather(weather_profile.sample_weather_type())


func force_new_weather() -> void:
	var new_weather := current_weather
	while new_weather == current_weather:
		new_weather = weather_profile.sample_weather_type()
	change_weather(new_weather)

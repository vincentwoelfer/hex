@tool
class_name WorldLightControl
extends Node

enum WeatherType {SUNSHINE, LIGHT_RAIN, HEAVY_RAIN, FOG}
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var sky: PanoramaSkyMaterial

const HOURS_PER_DAY: float = 24.0

var current_time: float = 12.0

@export_category("Sunshine hours")
@export var sunrise: float = 6.0
@export var sunset: float = 22.0

@export_category("Light parameters")
# Hours after sunrise / before sunset where the light is beeing interpolated
@export var sunrise_effect_hours: float = 3.0
@export var sunset_effect_hours: float = 3.0

@export var min_sun_light_energy: float = 0.0
@export var max_sun_light_energy: float = 2.0
@export var min_sky_light_energy: float = 0.5
@export var max_sky_light_energy: float = 1.0

@export var daytime_light_color: Color = Color8(255, 255, 205) # 205 is no mistake!
@export var sunrise_light_color: Color = Color8(255, 165, 0)
@export var sunset_light_color: Color = Color8(255, 165, 0)

@export_category("Weather parameters")
@export var starting_weather: WeatherType = WeatherType.SUNSHINE
var current_weather: WeatherType

var tween_duration := 1.0
var tween: Tween

var sun_rotation_x_start := 360.0
var sun_rotation_x_finish := 180.0
var sun_rotation_y_start := 120.0
var sun_rotation_y_finish := 60.0

func _ready() -> void:
	world_environment = get_node('%WorldEnvironment')
	sun = get_node('%SunLight')
	sky = world_environment.environment.sky.sky_material as PanoramaSkyMaterial

	current_weather = starting_weather
	EventBus.Signal_ChangeWorldTime.connect(change_time)

	jump_to_time(current_time)


func _process(delta: float) -> void:
	pass


func change_time(new_time: float) -> void:
	if current_time != new_time:
		current_time = new_time
		self.tween_to_time(current_time)


func change_wather(new_weather: WeatherType) -> void:
	if new_weather != current_weather:
		current_weather = new_weather
		#update_lighting(world_time, current_weather)


func jump_to_time(time: float) -> void:
	if sun == null or world_environment == null or sky == null:
		return

	var properties := interpolate_properties_for_time(time)

	for property: String in properties.keys():
		if property.begins_with('sun_'):
			sun.set(property.trim_prefix('sun_'), properties[property])
		elif property.begins_with('sky_'):
			sky.set(property.trim_prefix('sky_'), properties[property])


# TODO this only works per hour. Example: If tweening from mid of day to sunset, the tween will instantly (during day) reduce light linerily instead of waiting till start of sunset
func tween_to_time(time: float) -> void:
	if sun == null or world_environment == null or sky == null:
		return

	var properties := interpolate_properties_for_time(time)

	# Create Tween
	tween = create_tween().set_parallel(true)
	var current_tween_duration := tween_duration

	for property: String in properties.keys():
		if property.begins_with('sun_'):
			tween.tween_property(sun, property.trim_prefix('sun_'), properties[property], current_tween_duration)
		elif property.begins_with('sky_'):
			tween.tween_property(sky, property.trim_prefix('sky_'), properties[property], current_tween_duration)


func interpolate_properties_for_time(time: float) -> Dictionary:
	var time_from_sunrise := time - sunrise
	var time_to_sunset := sunset - time
	var sun_hours_per_day := HOURS_PER_DAY - sunrise - (HOURS_PER_DAY - sunset)
	var day_time_frac := clampf(time_from_sunrise / sun_hours_per_day, 0.0, 1.0)

	# Determine interpolation factor. 1 = full day, 0 = full night
	var interpolation_factor: float
	var color_lerp_from: Color = daytime_light_color
	if is_sunrise(time):
		interpolation_factor = clampf(time_from_sunrise / sunrise_effect_hours, 0.0, 1.0)
		color_lerp_from = sunrise_light_color
	elif is_sunset(time):
		interpolation_factor = clampf(time_to_sunset / sunset_effect_hours, 0.0, 1.0)
		color_lerp_from = sunset_light_color
	elif is_sun_above_surface(time):
		interpolation_factor = 1.0
	else:
		interpolation_factor = 0.0

	# Actually interpolate light intensity
	var sun_light_energy: float = lerpf(min_sun_light_energy, max_sun_light_energy, interpolation_factor)
	var sky_light_energy: float = lerpf(min_sky_light_energy, max_sky_light_energy, interpolation_factor)
	var light_color: Color = color_lerp_from.lerp(daytime_light_color, interpolation_factor)
	var sun_rotation: Vector3 = Vector3(
			deg_to_rad(lerpf(sun_rotation_x_start, sun_rotation_x_finish, day_time_frac)),
			deg_to_rad(lerpf(sun_rotation_y_start, sun_rotation_y_finish, day_time_frac)),
			0.0)

	var properties := {
		"sun_light_energy": sun_light_energy,
		"sun_light_color": light_color,
		"sun_rotation": sun_rotation,
		"sky_energy_multiplier": sky_light_energy,
		}

	return properties

func is_sun_above_surface(time: float) -> bool:
	return (time >= sunrise) and (time <= sunset)

func is_sunrise(time: float) -> bool:
	return time >= sunrise and time <= sunrise + sunrise_effect_hours

func is_sunset(time: float) -> bool:
	return time <= sunset and time >= sunset - sunset_effect_hours

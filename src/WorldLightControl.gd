@tool
class_name WorldLightControl
extends Node

enum WeatherType {SUNSHINE, LIGHT_RAIN, HEAVY_RAIN, FOG}
var world_environment: WorldEnvironment
var sun: DirectionalLight3D
var sky: PanoramaSkyMaterial
var world_time_manager: WorldTimeManager

const HOURS_PER_DAY: float = 24.0

@export_range(0.0, HOURS_PER_DAY, 0.2) var current_time: float = 7.0:
	set(value):
		current_time = value
		if Engine.is_editor_hint():
			jump_to_time(current_time)


@export_category("Sunshine hours")
@export var sunrise: float = 4.0
@export var sunset: float = 23.0

@export_category("Light parameters")
# Hours after sunrise / before sunset where the light is beeing interpolated
@export var sunrise_effect_hours: float = 3.0
@export var sunset_effect_hours: float = 3.0

# TODO interpolate energy differently. Color change needs to happen ~2-3 hours, light intensity change only within 30min
@export var min_sun_light_energy: float = 0.0
@export var max_sun_light_energy: float = 3.0
@export var min_sky_light_energy: float = 0.2
@export var max_sky_light_energy: float = 1.0

@export var daytime_light_color: Color = Color8(255, 255, 205) # 205 is no mistake!
@export var sunrise_light_color: Color = Color(1, 0.412, 0.235)
@export var sunset_light_color: Color = Color(1, 0.412, 0.235)

@export_category("Fog parameters")
@export var daytime_fog_density: float = 0.009
@export var sunrise_fog_density: float = 0.025
@export var sunset_fog_density: float = 0.015
@export var nighttime_fog_density: float = 0.025

@export_category("Weather parameters")
@export var starting_weather: WeatherType = WeatherType.SUNSHINE
var current_weather: WeatherType

# Actual tween duration may be limited further if time is auto-advancing
var tween: Tween
var desired_tween_duration := 0.5

# Height. -90 = Zenith.
var sun_rotation_x_down := -10.0
var sun_rotation_x_zenith := -30.0 # Should match ~scotland
# down -> zenith -> down

# East -> West, 0.0 = from South
var sun_rotation_y_start := 90.0
var sun_rotation_y_finish := -90.0

func _ready() -> void:
	world_environment = get_node('%WorldEnvironment') as WorldEnvironment
	sun = get_node('%SunLight') as DirectionalLight3D
	sky = world_environment.environment.sky.sky_material as PanoramaSkyMaterial
	world_time_manager = get_node('%WorldTimeManager') as WorldTimeManager
	
	current_time = fmod(WorldTimeManager.start_time, HOURS_PER_DAY)
	current_weather = starting_weather
	
	EventBus.Signal_SetVisualLightTime.connect(change_time)

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
		elif property.begins_with('env_'):
			world_environment.environment.set(property.trim_prefix('env_'), properties[property])


# TODO this only works per hour. Example: If tweening from mid of day to sunset, the tween will instantly (during day) reduce light linerily instead of waiting till start of sunset
func tween_to_time(time: float) -> void:
	if sun == null or world_environment == null or sky == null:
		return

	var properties := interpolate_properties_for_time(time)

	# Delete previous tween if still existing
	if tween:
		tween.kill()

	# Create Tween
	tween = create_tween().set_parallel(true)
	# Dont tween for longer than one hour lasts when auto-forwarding time
	var current_tween_duration := minf(desired_tween_duration, world_time_manager.get_max_tween_time())

	for property: String in properties.keys():
		if property.begins_with('sun_'):
			tween.tween_property(sun, property.trim_prefix('sun_'), properties[property], current_tween_duration)
		elif property.begins_with('sky_'):
			tween.tween_property(sky, property.trim_prefix('sky_'), properties[property], current_tween_duration)
		elif property.begins_with('env_'):
			tween.tween_property(world_environment.environment, property.trim_prefix('env_'), properties[property], current_tween_duration)


func interpolate_properties_for_time(time: float) -> Dictionary[String, Variant]:
	var time_from_sunrise := time - sunrise
	var time_to_sunset := sunset - time
	var sun_hours_per_day := HOURS_PER_DAY - sunrise - (HOURS_PER_DAY - sunset)
	var day_time_frac := clampf(time_from_sunrise / sun_hours_per_day, 0.0, 1.0)

	# Determine interpolation factor. 1 = full day, 0 = full night
	var interpolation_factor: float

	var color_lerp_from: Color = daytime_light_color
	var fog_density_lerp_from: float = daytime_fog_density

	if is_sunrise(time):
		interpolation_factor = clampf(time_from_sunrise / sunrise_effect_hours, 0.0, 1.0)
		color_lerp_from = sunrise_light_color
		fog_density_lerp_from = sunrise_fog_density
	elif is_sunset(time):
		interpolation_factor = clampf(time_to_sunset / sunset_effect_hours, 0.0, 1.0)
		color_lerp_from = sunset_light_color
		fog_density_lerp_from = sunset_fog_density
	elif is_sun_above_surface(time):
		interpolation_factor = 1.0
	else:
		interpolation_factor = 0.0
		fog_density_lerp_from = nighttime_fog_density


	# Actually interpolate light intensity
	# Ease light energy so it fades slowly and changes apruptly the moment the sun sets/rises.
	# ease-factor 1 = linear, < 1 = more abrupt close to 0.0
	var light_energy_factor := ease(interpolation_factor, 0.4)
	var sun_light_energy: float = lerpf(min_sun_light_energy, max_sun_light_energy, light_energy_factor)
	var sky_light_energy: float = lerpf(min_sky_light_energy, max_sky_light_energy, light_energy_factor)

	var light_color: Color = color_lerp_from.lerp(daytime_light_color, interpolation_factor)

	# Fog
	var fog_density: float = lerpf(fog_density_lerp_from, daytime_fog_density, interpolation_factor)

	# Lerp sun altitude from 0 -> zenith -> 0
	var sun_x: float
	if day_time_frac <= 0.5:
		sun_x = deg_to_rad(lerpf(sun_rotation_x_down, sun_rotation_x_zenith, day_time_frac * 2.0))
	else:
		sun_x = deg_to_rad(lerpf(sun_rotation_x_zenith, sun_rotation_x_down, (day_time_frac - 0.5) * 2.0))

	var sun_rotation: Vector3 = Vector3(
			sun_x,
			deg_to_rad(lerpf(sun_rotation_y_start, sun_rotation_y_finish, day_time_frac)),
			0.0)

	var properties: Dictionary[String, Variant] = {
		"sun_light_energy": sun_light_energy,
		"sun_light_color": light_color,
		"sun_rotation": sun_rotation,
		"sky_energy_multiplier": sky_light_energy,
		"env_volumetric_fog_density": fog_density,
		}

	return properties

func is_sun_above_surface(time: float) -> bool:
	return (time >= sunrise) and (time <= sunset)

func is_sunrise(time: float) -> bool:
	return time >= sunrise and time <= sunrise + sunrise_effect_hours

func is_sunset(time: float) -> bool:
	return time <= sunset and time >= sunset - sunset_effect_hours

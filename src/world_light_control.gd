class_name WorldLightControl
extends Node

enum WeatherType {SUNSHINE, LIGHT_RAIN, HEAVY_RAIN, FOG}
var world_environment: WorldEnvironment
var sun: DirectionalLight3D

# Time-sensitive variables
var world_time: float = 4.0
var day_length: float = 24.0
var hours_duration: float = 0.5 # in seconds
var current_hour: int = 0

@export_category("Sunshine hours")
@export var sunrise: float = 6.0
@export var sunset: float = 22.0
var sun_hours: float # derived


# Light parameters
@export_category("Light parameters")
@export var max_light_energy: float = 2.0
@export var min_light_energy: float = 2.0 # Turned off currently
@export var light_energy_ramping_hours: float = 2
var light_energy_ramp_frac: float # derived


var tween_duration = 0.5
var tween: Tween

var sun_rotation := {
	"x_start": 360,
	"x_finish": 180,
	"y_start": 120, 
	"y_finish": 60
}



func _ready() -> void:
	await get_tree().create_timer(0.1).timeout #TODO better solution to wait for World to build up
	world_environment = get_tree().get_first_node_in_group("world_environment")
	sun = get_tree().get_first_node_in_group("sun")
	
	# Derive values
	sun_hours = day_length - sunrise - (day_length - sunset)
	light_energy_ramp_frac = light_energy_ramping_hours / sun_hours
	update_lighting(world_time, WeatherType.SUNSHINE)


func _process(delta: float) -> void:
	world_time = fmod(world_time + (delta / hours_duration), day_length)
	var new_hour = floor(world_time)
	if current_hour != new_hour:
		current_hour = new_hour
		update_lighting(world_time, WeatherType.SUNSHINE)

func update_lighting(time: float, weather: WeatherType) -> void:

	var sun_properties = get_day_time_properties(time)

	# Create Tween
	#if tween:
	#	tween.kill()
	tween = create_tween().set_parallel(true)
	var current_tween_duration = tween_duration if current_hour == (sunset + 1) or is_sun_above_surface(time) else 0.0  
	for property in sun_properties.keys():
		tween.tween_property(sun, property, sun_properties[property], current_tween_duration)
	return

func get_day_time_properties(time) -> Dictionary:
	
	var day_time_frac = (time - sunrise) / sun_hours
	
	var light_energy = 0
	if is_sun_above_surface(time):
		var time_from_sundown = min(time - sunrise, sunset - time)
		#light_energy = cubic_interpolate(min_light_energy, max_light_energy, -5, 5, frac_to_sundown) # what values for pre/post
		light_energy_ramp_frac = clamp(time_from_sundown / light_energy_ramping_hours, 0, 1)
		light_energy = lerp(min_light_energy, max_light_energy, light_energy_ramp_frac) 
		print("Hour: ", current_hour , " L: ", light_energy, " pre ", light_energy_ramp_frac)
	
	var sun_properties = {
		"light_energy": light_energy,
		"light_color": Color.WHITE,
		"rotation": Vector3(
			deg_to_rad(lerp(sun_rotation["x_start"], sun_rotation["x_finish"], day_time_frac)), 
			deg_to_rad(lerp(sun_rotation["y_start"], sun_rotation["y_finish"], day_time_frac)),
			0)
		}
		
	return sun_properties

func is_sun_above_surface(time: float) -> bool:
	return (time >= sunrise) and (time <= sunset)

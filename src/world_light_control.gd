class_name WorldLightControl
extends Node

enum WeatherType {SUNSHINE, LIGHT_RAIN, HEAVY_RAIN, FOG}
var world_environment: WorldEnvironment
var sun: DirectionalLight3D

var world_time: float = 0.0
var day_length: float = 24.0
var hours_duration = 5.0 # seconds
var current_hour: int = 0


var tween_duration = 0.5
var tween: Tween

var sun_rotation := {
	"x_start": 10,
	"x_finish": -200,
	"y_start": 60, 
	"y_finish": -200
}

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout #TODO better solution to wait for World to build up
	world_environment = get_tree().get_first_node_in_group("world_environment")
	sun = get_tree().get_first_node_in_group("sun")
	await get_tree().create_timer(0.2).timeout
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
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	for property in sun_properties.keys():
		tween.tween_property(sun, property, sun_properties[property], tween_duration)
	return

func get_day_time_properties(time) -> Dictionary:
	
	var time_frac = time / 24.0
	
	var sun_properties = {
		"light_color": Color.YELLOW,
		"rotation": Vector3(lerp(sun_rotation["x_start"], sun_rotation["x_finish"], time_frac), 0, 0)
		}
	
	print(lerp(sun_rotation["x_start"], sun_rotation["x_finish"], time_frac))
	
	return sun_properties

func modulate_lighting(new: Dictionary) -> void:
	pass

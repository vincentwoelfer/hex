class_name WorldLightControl
extends Node

enum WeatherType {SUNSHINE, LIGHT_RAIN, HEAVY_RAIN, FOG}
var world_environment: WorldEnvironment
var sun: DirectionalLight3D

var tween: Tween

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout #TODO better solution to wait for World to build up
	world_environment = get_tree().get_first_node_in_group("world_environment")
	sun = get_tree().get_first_node_in_group("sun")
	await get_tree().create_timer(2.0).timeout
	update_lighting(10.0, WeatherType.SUNSHINE)

func update_lighting(time: float, weather: WeatherType) -> void:
	if tween:
		tween.kill()
	
	#tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(self, "dict:a", 100, 4.0)
	#ASK chat
	
	sun.light_color = Color.RED
	
	
	#var old_weather = {'Sun_light_color': 0.1, 'World_environment_color': 0.2}
	#var new_weather = {'Sun_light_color': 0.5, 'World_environment_color': 0.5}

	# Create Tween
	#tween = create_tween().set_parallel(true)
	
		
	return

func get_day_time_properties(time) -> Dictionary:
	
	return {}

func modulate_lighting(new: Dictionary) -> void:
	pass

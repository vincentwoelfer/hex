extends PanelContainer

@onready var header: Label = %HeaderLabel
@onready var infotext: RichTextLabel = %DebugLabel
@onready var world_light_control: WorldLightControl = %WorldLightControl
@onready var weather_control: WeatherControl = %WeatherControl


func _process(delta: float) -> void:
	header.text = "Debug Info Box"
	update_infotext()


func update_infotext() -> void:
	# Todo
	var hour := floorf(world_light_control.current_time)
	var minutes := floorf((world_light_control.current_time - hour) * 6)
	var phase := world_light_control.get_PhaseOfDay(world_light_control.current_time)
	var phase_name: String = world_light_control.PhaseOfDay.keys()[phase]

	infotext.text = ""
	infotext.append_text(str("Daytime: ", hour, ":", minutes, "0 | ", phase_name, "\n"))

	if weather_control != null:
		infotext.append_text(str("Weather: ", weather_control.WeatherType.keys()[weather_control.current_weather], "\n"))
		infotext.append_text(str("Profile: ", weather_control.weather_profile.resource_name, " \n"))

		var global_wind_strength := weather_control.current_wind_strength
		infotext.append_text(str("Wind Strength: ", snappedf(global_wind_strength, 0.1), " \n"))

		var wetness := weather_control.current_wetness
		infotext.append_text(str("Wetness: ", snappedf(wetness, 0.01), " \n"))

	infotext.append_text(str("FPS: ", snappedf(Engine.get_frames_per_second(), 0.01)))

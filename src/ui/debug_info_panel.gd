extends PanelContainer

@onready var header: Label = %HeaderLabel
@onready var infotext: RichTextLabel = %DebugLabel
@onready var world_light_control: WorldLightControl = %WorldLightControl
@onready var weather_control: WeatherControl = %WeatherControl


func _process(delta: float) -> void:
	header.text = "Debug Info Box"
	update_infotext()


func update_infotext() -> void:

	var hour := floorf(world_light_control.current_time)
	var minutes := floorf((world_light_control.current_time - hour) * 6)

	infotext.text = ""
	infotext.append_text(str("Daytime: ", hour, ":", minutes, "0h\n"))
	infotext.append_text(str("Weather: ", weather_control.WeatherType.keys()[weather_control.current_weather], "\n"))
	infotext.append_text(str("Profile: ", weather_control.weather_profile.resource_name, " \n"))
	infotext.append_text(str("FPS: ", snappedf(Engine.get_frames_per_second(), 0.1)))

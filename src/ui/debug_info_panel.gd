extends PanelContainer

@onready var header: Label = %HeaderLabel
@onready var infotext: RichTextLabel = %DebugLabel
@export var world_light_control : WorldLightControl


func _process(delta: float) -> void:
	header.text = "Debug Info Box"
	update_infotext()



func update_infotext() -> void:
	var hour = floor(world_light_control.world_time)
	var minutes = floor((world_light_control.world_time - hour) * 6)
	infotext.text = str("Daytime: ", hour, ":", minutes, "0h")

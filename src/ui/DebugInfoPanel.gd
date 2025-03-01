extends PanelContainer

@onready var header: Label = %HeaderLabel
@onready var infotext: RichTextLabel = %DebugLabel


func _process(delta: float) -> void:
	header.text = "Debug Info Box"
	update_infotext()


func update_infotext() -> void:
	infotext.text = ""
	infotext.append_text(str("FPS: ", snappedf(Engine.get_frames_per_second(), 0.01)))

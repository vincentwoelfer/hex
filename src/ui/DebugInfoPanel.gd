extends PanelContainer

@onready var header: Label = %HeaderLabel
@onready var text: RichTextLabel = %DebugLabel


func _process(delta: float) -> void:
	header.text = "Debug Info Box"
	update_infotext()


func update_infotext() -> void:
	text.text = ""

	# FPS
	text.append_text(str("FPS: ", snappedf(Engine.get_frames_per_second(), 0.01)))
	
	# Players
	text.append_text("\n\nPlayers:")
	for id in PlayerManager.players:
		var player := PlayerManager.players[id]
		text.push_color(player.color)
		text.append_text("\n%s (%s)" % [player.display_name, HexInput.get_device_display_name(player.input_device)])
		text.pop()

	# Devices
	if PlayerManager.get_unjoined_devices().size() > 0:
		text.append_text("\n\nUnconnected Devices:")
		for device in PlayerManager.get_unjoined_devices():
			text.append_text("\n%s" % [HexInput.get_device_display_name(device)])

class_name Tooltip
extends PanelContainer

@onready var fade_seconds := 0.5
@onready var header := %HeaderLabel
@onready var tooltip := %TooltipLabel

var tween: Tween

func _ready() -> void:
	EventBus.Signal_SelectionChanged.connect(on_selection_changed)
	modulate = Color.TRANSPARENT
	hide()
	

func on_selection_changed(new_selection: HexTile) -> void:
	if new_selection:
		show_tooltip(new_selection)
	else:
		hide_tooltip()


func show_tooltip(hex_tile: HexTile) -> void:
	if tween:
		tween.kill()
	
	header.text = "Meadow"
	tooltip.text = "[ICON] " + str(snappedf(hex_tile.humidity, 0.1)) + "\t(Soil humidity)\n"
	tooltip.text += "[ICON] " +  str(snappedf(1 - hex_tile.shade, 0.1)) + "\t(Sun exposure)\n"
	tooltip.text += "[ICON] " +  str(snappedf(hex_tile.nutrition, 0.1)) + "\t(Nutrition)"

	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(show)
	tween.tween_property(self, "modulate", Color.WHITE, fade_seconds)


func hide_tooltip() -> void:
	if tween:
		tween.kill()
	
	hide_animation()

func hide_animation() -> void:
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_seconds)
	tween.tween_callback(hide)

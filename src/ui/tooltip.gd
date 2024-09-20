class_name Tooltip
extends PanelContainer

@onready var fade_seconds := 0.5
@onready var header := %HeaderLabel
@onready var tooltip := %TooltipLabel

var icon_color: Color = Color.WHITE_SMOKE

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
	tooltip.text = ""
	#color_humidity.a = clampf(1, 0.8, 1)
	#label.push_color(color_humidity)
	#label.push_outline_color(Color(1, 1, 1, 1 * label_scale))
	tooltip.append_text(' [img color=#' + icon_color.to_html() + ']res://assets/icons/raindrop.png[/img]')
	tooltip.append_text(str(snappedf(hex_tile.humidity, 0.1), " (Soil humidity)", '\n'))

	# Shade
	tooltip.append_text(' [img color=#' + icon_color.to_html() + ']res://assets/icons/shade_white.png[/img]')
	tooltip.append_text(str(snappedf(1.0 - hex_tile.shade, 0.1), " (Sun exposure)",'\n'))

	tooltip.append_text(' [img color=#' + icon_color.to_html() + ']res://assets/icons/nutrition.png[/img]')
	tooltip.append_text(str(snappedf(hex_tile.shade, 0.1), " (Nutrition)", '\n'))

	tooltip.pop_all()
	
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

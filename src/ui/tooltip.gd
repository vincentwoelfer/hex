class_name Tooltip
extends PanelContainer

@onready var fade_seconds := 0.4
@onready var header := %HeaderLabel
@onready var tooltip := %TooltipLabel
@export var icon_width := 36

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
	tooltip.append_text('[img color=#' + icon_color.to_html() + ' width=' + str(icon_width) + ']res://assets/icons/raindrop.png[/img]')
	tooltip.append_text(str(" ", snappedf(hex_tile.humidity, 0.1), "\t(Soil humidity)", '\n'))

	# Shade
	tooltip.append_text('[img color=#' + icon_color.to_html() + ' width=' + str(icon_width) + ']res://assets/icons/shade_white.png[/img]')
	tooltip.append_text(str(" ", snappedf(1.0 - hex_tile.shade, 0.1), "\t(Sun exposure)",'\n'))

	tooltip.append_text('[img color=#' + icon_color.to_html() + ' width=' + str(icon_width) + ']res://assets/icons/nutrition.png[/img]')
	tooltip.append_text(str(" ", snappedf(hex_tile.nutrition, 0.1), "\t(Nutrition content)",'\n'))
	
	tooltip.append_text("\n\n-------------------------\n")
	tooltip.push_italics()
	tooltip.push_font_size(26)
	tooltip.append_text(compose_infotext(hex_tile))
	tooltip.pop_all()
	
	
	
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(show)
	tween.tween_property(self, "modulate", Color.WHITE, fade_seconds)

func compose_infotext(hex_tile: HexTile) -> String:
	var default_text := "\u2618The ground is very fertile.\n"
	var hazard_text := ""
	var event_text := ""
	
	if hex_tile.humidity < 0.2:
		hazard_text += "\u26A0The ground is very dry.\n"
	if hex_tile.shade > 0.6:
		hazard_text += "\u26A0This spot receives little sun light.\n"
	if hex_tile.nutrition < 0.3:
		hazard_text += "\u26A0The soil contains hardly any nutrients.\n"
	
	if hex_tile.is_secret_stash:
		event_text += "\u2753It looks like there might be something burried here.\n"
	
	if hazard_text != "":
		default_text = ""
	
	return default_text + hazard_text + event_text

func hide_tooltip() -> void:
	if tween:
		tween.kill()
	
	hide_animation()

func hide_animation() -> void:
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_seconds)
	tween.tween_callback(hide)

class_name HexTileLabel
extends Node3D

var label: RichTextLabel = null
var is_label_visible := false
var label_world_pos: Vector3

var color_humidity: Color = Color.BLUE.lightened(0.2)
var color_shade: Color = Color.BLACK.lightened(0.1)
var color_nutrition: Color = Color.DARK_OLIVE_GREEN

var initial_params: HexTileParams = null


func _init(params: HexTileParams) -> void:
	initial_params = params
	label = RichTextLabel.new()
	label.visible = is_label_visible


func _ready() -> void:
	update_label_text(initial_params)
	call_deferred("add_child", label)


func set_label_world_pos(world_pos: Vector3) -> void:
	label_world_pos = world_pos + Vector3(0.0, 0.1, 0.0)


func update_label_text(params: HexTileParams) -> void:
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.scroll_active = false

	var text_size := 60
	label.clear()
	label.text = ""
	label.append_text('[center]')
	label.push_font_size(text_size)
	label.push_outline_size(18)
	label.push_outline_color(Color(1, 1, 1))

	# Humidity
	label.push_color(color_humidity)
	label.append_text(str(snappedf(params.humidity, 0.1)) + ' ')
	label.append_text('[img height=' + str(text_size) + ' color=#' + color_humidity.to_html() + ']res://assets/ui/icons/raindrop.png[/img]\n')

	# Shade
	label.push_color(color_shade)
	label.append_text(str(snappedf(1.0 - params.shade, 0.1)) + ' ')
	label.append_text('[img height=' + str(text_size) + ' color=#' + color_shade.to_html() + ']res://assets/ui/icons/shade_white.png[/img]\n')

	# Nutrition
	label.push_color(color_nutrition)
	label.append_text(str(snappedf(params.nutrition, 0.1)) + ' ')
	label.append_text('[img height=' + str(text_size) + ' color=#' + color_nutrition.to_html() + ']res://assets/ui/icons/nutrition.png[/img]\n')

	label.pop_all()


func update_label_position() -> void:
	# Only abort if label should not be visible. Otherwise we need to update to determine if it might become visible
	if not is_label_visible:
		label.visible = false
		return

	var cam := Util.get_global_cam(self)
	var dist_to_cam := cam.global_transform.origin.distance_to(label_world_pos)

	# Update scale
	var scale_factor := get_scale_from_3d_distance_to_cam(dist_to_cam)
	label.scale = Vector2.ONE * scale_factor

	# Use size (including scale) to center position in 2d correctly
	label.position = cam.unproject_position(label_world_pos) - Vector2(label.size * 0.5 * scale_factor)

	# Check if visible
	label.visible = is_label_visible and not cam.is_position_behind(label_world_pos)

	# Update alpha
	# var alpha := get_alpha_from_3d_distance_to_cam(label_world_pos)


func get_scale_from_3d_distance_to_cam(dist: float) -> float:
	const near_dist := 10.0
	const far_dist := 50.0
	const min_scale := 0.1
	const max_scale := 1.0

	var factor: float = remap(dist, near_dist, far_dist, max_scale, min_scale)
	var s: float = clampf(factor, min_scale, max_scale)

	if s == min_scale:
		s = 0.0
	return s


func get_alpha_from_3d_distance_to_cam(dist: float) -> float:
	const near_dist := 30.0
	const far_dist := 45.0
	const min_scale := 0.3
	const max_scale := 1.0

	var factor: float = remap(dist, near_dist, far_dist, max_scale, min_scale)
	return clampf(factor, min_scale, max_scale)

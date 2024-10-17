@tool
class_name HexTile
extends Node3D

######################################################
# Parent / Struct class holding everything a hex tile can be/posess
######################################################

# Core Variables
var hexpos: HexPos
var height: int

# Visual Representation
var geometry: HexGeometry
var plant: SurfacePlant

# ToDo extract onto own class
var label := RichTextLabel.new()
var is_label_visible := false

# Field conditions
var humidity: float
var shade: float
var nutrition: float
var is_secret_stash: bool # Just a gimmick
var tile_type: String = "Meadow"

var color_humidity: Color = Color.BLUE.lightened(0.2)
var color_shade: Color = Color.BLACK.lightened(0.1)
var color_nutrition: Color = Color.DARK_OLIVE_GREEN


# Does not much, only actual constructor
func _init(hexpos_: HexPos, height_: int) -> void:
	self.hexpos = hexpos_
	self.height = height_
	if self.hexpos != null:
		self.name = 'HexTile' + hexpos._to_string()
	else:
		self.name = 'HexTile-Invalid'

	self.geometry = null
	self.plant = null

	self.humidity = randf()
	self.shade = randf()
	self.nutrition = randf()
	self.is_secret_stash = randf() < 0.1

	# Doesnt do anything, surprise Nek
	if self.humidity <= 0.1:
		self.tile_type = "Dry Meadow"

	if height > 0:
		add_child(label)

	# Signals
	EventBus.Signal_TooglePerTileUi.connect(toogleTileUi)
	EventBus.Signal_WorldStep.connect(processWorldStep)


func generate() -> void:
	# Delete old stuff
	if geometry != null:
		remove_child(geometry)
	if plant != null:
		remove_child(plant)

	# Get relevant parameters from Map (read-only)
	var adjacent_hex: Array[HexGeometry.AdjacentHex] = []
	for dir in range(6):
		var adjacent_height: int = MapManager.map.get_hex(self.hexpos.get_neighbor(dir)).height
		var adjacent_descr := ""

		# If neighbour does not exists set height to same as own tile and mark transition
		if adjacent_height == MapManager.INVALID_HEIGHT:
			adjacent_height = self.height
			adjacent_descr = 'invalid'

		adjacent_hex.push_back(HexGeometry.AdjacentHex.new(adjacent_height, adjacent_descr))

	# Add geometry
	geometry = HexGeometry.new(height, adjacent_hex)
	geometry.generate()
	add_child(geometry, true)

	# Add plants
	if height > 0:
		plant = SurfacePlant.new()
		plant.populate_multimesh(geometry.samplerHorizontal)
		add_child(self.plant, true)


func processWorldStep() -> void:
	# For now just end data here, this is not good!
	if plant != null:
		plant.processWorldStep(humidity, shade, nutrition)


func toogleTileUi(_is_label_visible: bool) -> void:
	self.is_label_visible = _is_label_visible


func _process(delta: float) -> void:
	update_label()


func get_scale_from_3d_distance_to_cam(global_pos: Vector3) -> float:
	const near_dist := 10.0
	const far_dist := 30.0
	const min_scale := 0.4
	const max_scale := 1.0

	var cam := get_viewport().get_camera_3d()
	var dist: float = cam.global_position.distance_to(global_pos)
	var factor: float = remap(dist, near_dist, far_dist, max_scale, min_scale)
	return clampf(factor, min_scale, max_scale)


func get_alpha_from_3d_distance_to_cam(global_pos: Vector3) -> float:
	const near_dist := 30.0
	const far_dist := 45.0
	const min_scale := 0.3
	const max_scale := 1.0

	var cam := get_viewport().get_camera_3d()
	var dist: float = cam.global_position.distance_to(global_pos)
	var factor: float = remap(dist, near_dist, far_dist, max_scale, min_scale)
	return clampf(factor, min_scale, max_scale)


func update_label() -> void:
	var label_pos: Vector3 = global_position + Vector3(0.0, 0.1, 0.0)
	var scale_factor := get_scale_from_3d_distance_to_cam(label_pos)

	# Colors
	var alpha := get_alpha_from_3d_distance_to_cam(label_pos)
	color_humidity.a = alpha
	color_shade.a = alpha
	color_nutrition.a = alpha

	label.scale = Vector2.ONE * scale_factor

	label.position = get_viewport().get_camera_3d().unproject_position(label_pos)

	label.visible = is_label_visible and not get_viewport().get_camera_3d().is_position_behind(label_pos)

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
	label.push_outline_color(Color(1, 1, 1, alpha))
	#label.append_text('[font bottom_spacing=-20]')
	#label.push_bgcolor(Color(0,0,0,0.2))

	# Humidity
	label.push_color(color_humidity)
	label.append_text(str(snappedf(self.humidity, 0.1)) + ' ')
	label.append_text('[img height=' + str(text_size) + ' color=#' + color_humidity.to_html() + ']res://assets/ui/icons/raindrop.png[/img]\n')

	# Shade
	label.push_color(color_shade)
	label.append_text(str(snappedf(1.0 - self.shade, 0.1)) + ' ')
	label.append_text('[img height=' + str(text_size) + ' color=#' + color_shade.to_html() + ']res://assets/ui/icons/shade_white.png[/img]\n')

	# Nutrition
	label.push_color(color_nutrition)
	label.append_text(str(snappedf(self.nutrition, 0.1)) + ' ')
	label.append_text('[img height=' + str(text_size) + ' color=#' + color_nutrition.to_html() + ']res://assets/ui/icons/nutrition.png[/img]\n')


	label.pop_all()

	# Use size (including scale) to center position in 2d correctly
	label.position -= Vector2(label.size * 0.5 * scale_factor)


func is_valid() -> bool:
	return hexpos != null


func calculate_shadow(sun_intensity: float) -> float:
	return sun_intensity * shade


#######################
####################### Feld:
# klima-bedingungen
# humidity
# Schatten  (wie viele Bäume)
# nutrition = wie gut wachsen sachen, erde vs sand/stein

# Was da drauf ist.
#

# Derived
# => aktuellen lichteinfall = Sonne - Schatten

#######################
####################### Allgemeint Wetter:
# Temperatur
# Aktueller Regenfall -> mehr wasser
# Aktuelle Sonne -> weniger wasser, mehr licht

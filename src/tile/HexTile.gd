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
var label := RichTextLabel.new()

# Field conditions
var humidity: float
var shade: float
var nutrition: float

var color_humidity: Color = Color.BLUE.lightened(0.2)
var color_shade: Color = Color.BLACK.lightened(0.1)

func _init(hexpos_: HexPos, height_: int) -> void:
	self.hexpos = hexpos_
	self.height = height_
	if self.hexpos != null:
		self.name = 'HexTile' + hexpos._to_string()
	else:
		self.name = 'HexTile-Invalid'

	self.geometry = null

	self.humidity = randf()
	self.shade = randf()
	self.nutrition = randf()

	add_child(label)


func _process(delta: float) -> void:
	update_label()


func update_label() -> void:
	var pos_3d_global: Vector3 = global_position + Vector3(0.0, 0.1, 0.0)
	## Camera Distance -> Scale
	var cam := get_viewport().get_camera_3d()
	var dist: float = cam.global_position.distance_to(pos_3d_global)
	dist = clampf(dist, 10.0, 25.0)
	var label_scale: float = remap(dist, 10.0, 25.0, 1.0, 0.5)
	label_scale = clampf(label_scale, 0.5, 1.0)
	label.scale = Vector2.ONE * label_scale

	label.position = get_viewport().get_camera_3d().unproject_position(pos_3d_global)
	label.visible = not get_viewport().get_camera_3d().is_position_behind(pos_3d_global)

	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.scroll_active = false

	label.clear()
	label.text = ""
	label.append_text('[center]')
	label.push_font_size(80)
	label.push_outline_size(16)
	#label.push_bgcolor(Color(0,0,0,0.2))

	# Humidity
	color_humidity.a = clampf(label_scale, 0.8, 1)
	label.push_color(color_humidity)
	label.push_outline_color(Color(1, 1, 1, 1 * label_scale))
	label.append_text(str(snappedf(self.humidity, 0.1)))
	label.append_text(' [img color=#' + color_humidity.to_html() + ']res://assets/icons/raindrop.png[/img]\n')

	# Shade
	color_shade.a = clampf(label_scale, 0.7, 1)
	label.push_color(color_shade)
	label.push_outline_color(Color(1, 1, 1, 1 * label_scale))
	label.append_text(str(snappedf(self.shade, 0.1)))
	label.append_text(' [img color=#' + color_shade.to_html() + ']res://assets/icons/shade.png[/img]\n')
	

	label.pop_all()

	# Use size (including scale) to center position in 2d correctly
	label.position -= Vector2(label.size * 0.5 * label_scale)


func assign_geometry(geom: HexGeometry) -> void:
	if self.geometry != null:
		remove_child(self.geometry)

	self.geometry = geom
	add_child(self.geometry, true)


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

class_name SelectionManager
extends Node

var current_selection: HexTile = null


func _init() -> void:
	EventBus.Signal_SelectedWorldPosition.connect(parse_selection_position)
	EventBus.Signal_randomizeSelectedTile.connect(randomize_selected_tile)


func parse_selection_position(pos: Vector3) -> void:
	var hex_pos_frac: HexPosFrac = HexPos.xyz_to_hexpos_frac(pos)
	var hex_pos: HexPos = hex_pos_frac.round()
	var hex_tile: HexTile = MapManager.map.get_hex(hex_pos)

	if hex_tile.is_valid():
		self.update_selected_hex_tile(hex_tile)
	else:
		self.update_selected_hex_tile(null)


func update_selected_hex_tile(new_selection: HexTile) -> void:
	if new_selection != current_selection:
		EventBus.emit_signal("Signal_SelectedHexTile", new_selection)
		unhighlight_current()
		current_selection = new_selection
		highlight_current()


func highlight_current() -> void:
	if current_selection != null:
		current_selection.geometry.terrainMesh.set_instance_shader_parameter("enabled", 1.0)


func unhighlight_current() -> void:
	if current_selection != null:
		current_selection.geometry.terrainMesh.set_instance_shader_parameter("enabled", 0.0)


func randomize_selected_tile() -> void:
	if current_selection != null:
		current_selection.params.humidity = randf()
		current_selection.params.shade = randf()
		current_selection.params.nutrition = randf()

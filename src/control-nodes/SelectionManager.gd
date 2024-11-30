class_name SelectionManager
extends Node

var current_selection: HexTile = null

func _init() -> void:
	EventBus.Signal_SelectedWorldPosition.connect(parse_selection_position)
	EventBus.Signal_randomizeSelectedTile.connect(randomize_selected_tile)


func parse_selection_position(pos: Vector3) -> void:
	var hex_pos_frac: HexPosFrac = HexPos.xyz_to_hexpos_frac(pos)
	var hex_pos: HexPos = hex_pos_frac.round()
	var hex_tile: HexTile = HexTileMap.get_by_pos(hex_pos)

	if hex_tile != null and hex_tile.is_valid():
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
		pass
		# current_selection.terrainMesh.material_overlay = ResLoader.HIGHLIGHT_MAT


func unhighlight_current() -> void:
	if current_selection != null:
		pass
		# current_selection.terrainMesh.material_overlay = null


func randomize_selected_tile() -> void:
	if current_selection != null and current_selection.is_valid() and current_selection.hex_pos != null:
		var t_start := Time.get_ticks_usec()
		Util.print_banner("Randomizing tile " + current_selection.hex_pos._to_string())

		current_selection.params.humidity = randf()
		current_selection.params.shade = randf()
		current_selection.params.nutrition = randf()

		# # For testing
		# var step := 2
		# current_selection.height += step
		# current_selection.position += Vector3(0, step * HexConst.height, 0)

		# for dir in range(6):
		# 	var n := MapManager.map.get_by_pos(current_selection.hex_pos.get_neighbour(dir))
		# 	if n != null:
		# 		n.generate()
		# current_selection.generate()

		# # Finish
		# var t := (Time.get_ticks_usec() - t_start) / 1000.0
		# print("Generated %d hex tiles in %4.0f ms" % [7, t])

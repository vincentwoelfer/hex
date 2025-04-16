# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node3D

# Caravan
var caravan: Caravan

# Sub-Managers
var cam_follow_point_manager: CameraFollowPointManager


func _ready() -> void:
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Input.mouse_mode = Input.MOUSE_MODE_CONFINED

	cam_follow_point_manager = CameraFollowPointManager.new()

	# NAVMAP - Dont use Util.get_map() here - for whatever reason it doesnt work in editor mode for autoload _ready() functions
	var nav_map := get_world_3d().navigation_map
	NavigationServer3D.set_debug_enabled(DebugSettings.nav_server_debug_mode)
	NavigationServer3D.map_set_cell_size(nav_map, HexConst.NAV_CELL_SIZE)
	NavigationServer3D.map_set_cell_height(nav_map, HexConst.NAV_CELL_SIZE)

	# EDGE MERGING
	# For two regions to be connected to each other, they must share a similar edge.
	# An edge is considered connected to another if both of its two vertices are
	# at a distance less than edge_connection_margin to the respective other edge's vertex.
	# -> THIS DOES NOT WORK FOR US RELIABLY
	NavigationServer3D.map_set_use_edge_connections(nav_map, true)

	# Increase margin for edge connections because we have an artificial border of one cell size
	NavigationServer3D.map_set_edge_connection_margin(nav_map, 0.25 + HexConst.NAV_CELL_SIZE) # default 0.25

	if Engine.is_editor_hint():
		return

	# Wait for nav chunks to be loaded
	var map_center_chunk_pos: HexPos = HexPos.xyz_to_hexpos_frac(HexConst.MAP_CENTER).round().to_chunk_base()
	await Util.wait_until(self, func() -> bool: return HexChunkMap.get_by_pos(map_center_chunk_pos) != null)
	var map_center_chunk: HexChunk = HexChunkMap.get_by_pos(map_center_chunk_pos)
	await Util.wait_until(self, func() -> bool: return map_center_chunk.find_child("@NavigationRegion*", true, false) != null)
	await get_tree().physics_frame
	await get_tree().physics_frame

	spawn_caravan()

	await get_tree().process_frame

	if HexInput.device_actions.size() > 1:
		# Always spawn keyboard player for development (after caravan has been spawened)
		PlayerManager.add_player(-1)

	# Add enemy spawner TODO make enemy number player number dependent
	add_child(Util.timer(1.5, spawn_enemy))
	add_child(Util.timer(1.0, delete_far_away_entities))


# React to keyboard inputs to directly trigger events
func _input(event: InputEvent) -> void:
	# Only execute in game, check necessary because EventBus is @tool
	if not Engine.is_editor_hint():
		# if event.is_action_pressed("toogle_per_tile_ui"):
			# print("PerTileUI visibility toogled")
			# EventBus.Signal_TooglePerTileUi.emit()
		###################################################################
		# NON-Signal Input Actions
		###################################################################
		# Quit game
		if event.is_action_pressed("quit_game"):
			request_quit_game()

		# DEBUG
		# Spawn enemy
		if event.is_action_pressed("dev_spawn_enemy"):
			spawn_enemy()

		if event.is_action_pressed("dev_spawn_crystal"):
			caravan.spawn_crystal()

		if event.is_action_pressed("dev_toggle_cam_follow_caravan"):
			cam_follow_point_manager.use_caravan_for_cam_follow = not cam_follow_point_manager.use_caravan_for_cam_follow


func request_quit_game() -> void:
	HexLog.print_multiline_banner("Quitting game")
	MapGeneration.request_shutdown_threads()


###################################################################
# Stuff
###################################################################
func delete_far_away_entities() -> void:
	var center := caravan.global_position
	# Deletion dist ist smaller than map/chunk deletion dist (but a factor of it)
	var max_dist: float = HexConst.distance_hex_to_m(MapGeneration.tile_generation_distance_hex) * 0.55
	var max_dist_sqared: float = max_dist * max_dist

	# Enemies
	for enemy: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_ENEMIES):
		if enemy.global_position.distance_squared_to(center) > max_dist_sqared:
			enemy.queue_free()

	# Crystals
	for crystal: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_CRYSTALS):
		if crystal.global_position.distance_squared_to(center) > max_dist_sqared:
			crystal.queue_free()

	# Escape portals
	for portal: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_ESCAPE_PORTALS):
		if portal.global_position.distance_squared_to(center) > max_dist_sqared:
			portal.queue_free()

	# Players - Teleport to caravan if too far aways
	var player_max_dist: float = HexConst.distance_hex_to_m(MapGeneration.tile_generation_distance_hex) * 0.3
	var player_max_dist_sqared: float = player_max_dist * player_max_dist

	for player: PlayerController in get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS):
		if player.global_position.distance_squared_to(center) > max_dist_sqared:
			# Find spawn pos
			var shape: CollisionShape3D = player.get_node("Collision")
			var teleport_pos := caravan.global_position + Util.rand_circular_offset_range(3.0, 3.0)
			var actual_teleport_pos := PhysicUtil.find_closest_valid_spawn_pos(teleport_pos, shape.shape, 0.5, 3.0, true)

			player.global_position = actual_teleport_pos
			player.reset_physics_interpolation()


###################################################################
# Spawner Functions
###################################################################
func spawn_enemy() -> void:
	if caravan == null:
		return

	var enemy_node: BasicEnemy = ResLoader.BASIC_ENEMY_SCENE.instantiate()

	# Find spawn pos
	var shape: CollisionShape3D = enemy_node.get_node("Collision")
	var spawn_pos := caravan.global_position + Util.rand_circular_offset_range(20, 25)
	var actual_spawn_pos := PhysicUtil.find_closest_valid_spawn_pos(spawn_pos, shape.shape, 0.5, 3.0, true)
	
	Util.spawn(enemy_node, actual_spawn_pos)


func spawn_escape_portal(caravan_goal: Vector3) -> void:
	var portal_node: EscapePortal = ResLoader.ESCAPE_PORTAL_SCENE.instantiate()

	# Find spawn pos
	var shape: CollisionShape3D = portal_node.get_node("Area3D/CollisionShape3D")

	var path_vector := (caravan_goal - caravan.global_position)
	var spawn_pos := caravan.global_position + randf() * path_vector

	# Chose one side of path vector
	var side_vector := path_vector.cross(Vector3.UP).normalized()
	var angle: float = randf_range(deg_to_rad(80), deg_to_rad(180 - 80))
	var side_vector_rotated := side_vector.rotated(Vector3.UP, angle) * Util.rand_sign()
	spawn_pos += side_vector_rotated * randf_range(30.0, 35.0)

	var mask := Layers.mask([Layers.L.TERRAIN])
	var actual_spawn_pos := PhysicUtil.find_closest_valid_spawn_pos(spawn_pos, shape.shape, 0.5, 3.0, true, mask)
	
	Util.spawn(portal_node, actual_spawn_pos)


func spawn_caravan() -> void:
	if caravan != null:
		return

	caravan = ResLoader.CARAVAN_SCENE.instantiate()

	# Find spawn pos
	var shape: CollisionShape3D = caravan.get_node("Collision")
	var spawn_pos: Vector3 = HexConst.MAP_CENTER
	var actual_spawn_pos := PhysicUtil.find_closest_valid_spawn_pos(spawn_pos, shape.shape, 1.0, 5.0, true)

	Util.duplicate_material_new_color(caravan.get_node("RotationAxis/Mesh") as MeshInstance3D, Colors.COLOR_CARAVAN)

	Util.spawn(caravan, actual_spawn_pos)
	cam_follow_point_manager.register_cam_follow_node(caravan)


func spawn_player(player: PlayerData) -> void:
	var player_node: PlayerController = ResLoader.PLAYER_SCENE.instantiate()
	player_node.init(player.input_device, player.color)

	# Find spawn pos
	var shape: CollisionShape3D = player_node.get_node("Collision")
	var spawn_pos := caravan.global_position + Util.rand_circular_offset_range(3.0, 3.0)
	var actual_spawn_pos := PhysicUtil.find_closest_valid_spawn_pos(spawn_pos, shape.shape, 0.5, 3.0, true)

	# Set player color
	Util.duplicate_material_new_color(player_node.get_node("RotationAxis/Mesh") as MeshInstance3D, player.color)

	Util.spawn(player_node, actual_spawn_pos)
	cam_follow_point_manager.register_cam_follow_node(player_node)

	# Link player data to node and vice versa
	player.player_node = player_node
	player_node.player_data = player
	

func despawn_player(player: PlayerData) -> void:
	cam_follow_point_manager.unregister_cam_follow_node(player.player_node)
	player.player_node.queue_free()

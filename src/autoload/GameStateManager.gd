# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node3D

# Caravan
var caravan: Caravan
var caravan_distance_traveled: float = 0.0
var caravan_last_pos: Vector3 = Vector3.ZERO
# not-runnning if game-over
var is_game_running := true

# Sub-Managers
var cam_follow_point_manager: CameraFollowPointManager

# Difficulty
var num_wave := 0 # starts at 0 (gets incremented before spawning)
var base_enemies_per_wave := 8
var scaling_enemies_per_wave := 4
var caravan_distance_per_wave := 40.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED

		if DebugSettings.low_performance_mode:
			print("Running in low performance mode")
			get_window().get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			get_window().get_viewport().scaling_3d_scale = 0.5

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

	dev_setup()

func dev_setup() -> void:
	if Engine.is_editor_hint():
		return

	# Wait for nav chunks to be loaded
	var map_center_chunk_pos: HexPos = HexPos.xyz_to_hexpos_frac(HexConst.MAP_CENTER).round().to_chunk_base()
	await Util.await_until(self, func() -> bool: return HexChunkMap.get_by_pos(map_center_chunk_pos) != null)
	var map_center_chunk: HexChunk = HexChunkMap.get_by_pos(map_center_chunk_pos)
	await Util.await_until(self, func() -> bool: return map_center_chunk.find_child("@NavigationRegion*", true, false) != null)
	await get_tree().physics_frame
	await get_tree().physics_frame

	spawn_caravan()

	await get_tree().process_frame

	# if HexInput.device_actions.size() > 1:
	# Always spawn keyboard player for development (after caravan has been spawened)
	PlayerManager.add_player(-1)
	# Add default gadget
	# (PlayerManager.players[0].player_node as PlayerController).pickup_gadget(GadgetBomb.new())

	# Delete far away entities every second
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

		###################################################################
		# DEBUG Input Actions
		###################################################################
		# Spawn enemy - F2
		if event.is_action_pressed("dev_spawn_enemy"):
			spawn_enemy()

		# Spawn wave - F3
		if event.is_action_pressed("dev_spawn_wave"):
			spawn_wave()

		# F4
		if event.is_action_pressed("dev_toggle_cam_follow_caravan"):
			cam_follow_point_manager.use_caravan_for_cam_follow = not cam_follow_point_manager.use_caravan_for_cam_follow


func request_quit_game() -> void:
	HexLog.print_multiline_banner_with_text("Quitting game")
	MapGeneration.request_shutdown_threads()


###################################################################
# Process
###################################################################
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# End of Game Check
	if is_game_running and get_tree().get_nodes_in_group(HexConst.GROUP_CRYSTALS).is_empty() and caravan_distance_traveled > 0.0:
		HexLog.print_only_banner()
		HexLog.print_banner_with_text("Game Over - You have no crystals left!")
		HexLog.print_banner_with_text("You have traveled %.2f m" % caravan_distance_traveled)
		HexLog.print_only_banner()
		is_game_running = false
		apply_grayscale_to_active_environment()

	if caravan != null and is_game_running:
		# Dont update if caravan is in debug-fast-speed mode
		if caravan.get_speed() <= caravan.speed:
			if caravan_last_pos != Vector3.ZERO:
				# Update distance traveled
				caravan_distance_traveled += Util.get_dist_planar(caravan.global_position, caravan_last_pos)
			caravan_last_pos = caravan.global_position

	# Spawn wave every caravan_distance_per_wave m traveled (+ 15.0 m starting offset)
	if is_game_running and caravan_distance_traveled > caravan_distance_per_wave * num_wave + 15.0:
		spawn_wave()


###################################################################
# Enemy Spawning / Difficulty
###################################################################
func spawn_wave() -> void:
	self.num_wave += 1
	var num_enemies := _get_wave_num_enemies(num_wave)
	print("Spawning wave %d with %d enemies (%d players)" % [num_wave, num_enemies, _get_num_players()])

	for i in range(num_enemies):
		spawn_enemy()

	# Spawn escape portals
	for i in range(4):
		GameStateManager.spawn_escape_portal()


func _get_wave_num_enemies(wave: int) -> int:
	var player_scaling: Array[float] = [1.0, 1.5, 2.0, 2.5]
	var player_scaling_factor: float = player_scaling[_get_num_players() - 1]

	var num_enemies: float = base_enemies_per_wave + scaling_enemies_per_wave * wave
	num_enemies *= player_scaling_factor

	return roundi(num_enemies)

###################################################################
# Stuff
###################################################################
func _get_num_players() -> int:
	return get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS).size()

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
	var player_max_dist: float = HexConst.distance_hex_to_m(MapGeneration.tile_generation_distance_hex) * 0.45
	var player_max_dist_sqared: float = player_max_dist * player_max_dist

	for player: PlayerController in get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS):
		if player.global_position.distance_squared_to(center) > player_max_dist_sqared:
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

	# Actual Spawning
	var enemy_node: BasicEnemy = ResLoader.BASIC_ENEMY_SCENE.instantiate()

	# Find spawn pos
	var shape: CollisionShape3D = enemy_node.get_node("Collision")
	var spawn_pos := caravan.global_position + Util.rand_circular_offset_range(20, 25)
	var actual_spawn_pos := PhysicUtil.find_closest_valid_spawn_pos(spawn_pos, shape.shape, 0.5, 3.0, true)
	
	Util.spawn(enemy_node, actual_spawn_pos)


func spawn_escape_portal() -> void:
	var portal_node: EscapePortal = ResLoader.ESCAPE_PORTAL_SCENE.instantiate()

	# Find spawn pos
	var shape: CollisionShape3D = portal_node.get_node("Area3D/CollisionShape3D")

	var spawn_pos := caravan.global_position + Util.rand_circular_offset_range(25, 30)

	var mask := Layers.mask([Layers.PHY.TERRAIN, Layers.PHY.STATIC_GEOM])
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

	Util.change_material_color(caravan.get_node("RotationAxis/Mesh") as MeshInstance3D, Colors.COLOR_CARAVAN)

	Util.spawn(caravan, actual_spawn_pos)
	cam_follow_point_manager.register_cam_follow_node(caravan)


func spawn_player(player: PlayerData) -> void:
	var player_node: PlayerController = ResLoader.PLAYER_SCENE.instantiate()
	player_node.init(player.input_device, player.color)

	# Find spawn pos
	var shape: CollisionShape3D = player_node.get_node("Collision")
	var spawn_pos := caravan.global_position + Util.rand_circular_offset_range(3.0, 3.0)
	var actual_spawn_pos := PhysicUtil.find_closest_valid_spawn_pos(spawn_pos, shape.shape, 0.5, 3.0, true)

	Util.change_material_color(player_node.get_node("RotationAxis/Mesh") as MeshInstance3D, player.color)

	Util.spawn(player_node, actual_spawn_pos)
	cam_follow_point_manager.register_cam_follow_node(player_node)

	# Link player data to node and vice versa
	player.player_node = player_node
	player_node.player_data = player

	player_node.pickup_gadget(GadgetBomb.new())
	

func despawn_player(player: PlayerData) -> void:
	cam_follow_point_manager.unregister_cam_follow_node(player.player_node)
	player.player_node.queue_free()


func apply_grayscale_to_active_environment() -> void:
	# Find the active WorldEnvironment in the current scene
	var world_env: Environment = Util.get_world().environment
	if world_env == null:
		push_warning("No active environment found.")
		return

	world_env.adjustment_enabled = true
	world_env.adjustment_saturation = 0.1

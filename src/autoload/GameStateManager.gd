# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node3D

# Caravan
var caravan: Caravan

# Sub-Managers
var cam_follow_point_manager: CameraFollowPointManager


# PlayerTeamTeleporter
enum TeamTeleporterStatus {ON_COOLDOWN, READY_TO_DEPLOY, DEPLOYED}
var team_teleporter_status: TeamTeleporterStatus = TeamTeleporterStatus.READY_TO_DEPLOY

var team_teleporter_cooldown: float = 10.0
var team_teleporter_active_time: float = 4.0
var team_teleporter_cooldown_timer: Timer
var team_teleporter_active_timer: Timer

func _ready() -> void:
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Input.mouse_mode = Input.MOUSE_MODE_CONFINED

	cam_follow_point_manager = CameraFollowPointManager.new()

	# NAVMAP
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
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Always spawn keyboard player for development (not in editor)
	if not Engine.is_editor_hint():
		PlayerManager.add_player(-1)

	# Add enemy spawner
	add_child(Util.timer(2.5, spawn_enemy))
	add_child(Util.timer(2.5, delete_far_away_entities))


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
	var max_dist: float = HexConst.distance_hex_to_m(MapGeneration.tile_deletion_distance_hex) * 0.8
	var max_dist_sqared: float = max_dist * max_dist

	# Enemies
	for enemy: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_ENEMIES):
		if enemy.global_position.distance_squared_to(center) > max_dist_sqared:
			enemy.queue_free()

	# Crystals
	for crystal: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_CRYSTALS):
		if crystal.global_position.distance_squared_to(center) > max_dist_sqared:
			crystal.queue_free()


###################################################################
# Spawner Functions
###################################################################
func spawn_enemy() -> void:
	if caravan == null:
		return

	var enemy_node: BasicEnemy = ResLoader.BASIC_ENEMY_SCENE.instantiate()

	# Find spawn pos
	var shape: CollisionShape3D = enemy_node.get_node("Collision")
	var spawn_pos: Vector3 = caravan.global_position + Util.rand_circular_offset_range(20, 25)

	# Match to navmesh, get height
	spawn_pos = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, spawn_pos)
	spawn_pos = MapGeneration.get_spawn_pos_height_on_map_surface(spawn_pos, shape)

	get_tree().root.add_child(enemy_node)
	enemy_node.global_position = spawn_pos
	enemy_node.reset_physics_interpolation()


func spawn_caravan() -> void:
	if caravan != null:
		return

	caravan = ResLoader.CARAVAN_SCENE.instantiate()

	# Find spawn height
	var spawn_pos: Vector3 = HexConst.MAP_CENTER
	var shape: CollisionShape3D = caravan.get_node("Collision")

	# Match to navmesh, get height - this requires a navmesh
	spawn_pos = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, spawn_pos)
	spawn_pos = MapGeneration.get_spawn_pos_height_on_map_surface(spawn_pos, shape)

	# Set color
	var mesh_instance := caravan.get_node("Mesh") as MeshInstance3D
	var new_mesh: Mesh = mesh_instance.mesh.duplicate(true)

	var new_mat: StandardMaterial3D = new_mesh.surface_get_material(0)
	new_mat.albedo_color = Colors.COLOR_CARAVAN
	new_mesh.surface_set_material(0, new_mat)
	mesh_instance.mesh = new_mesh

	# Add to scene
	get_tree().root.add_child(caravan)
	caravan.global_position = spawn_pos
	caravan.reset_physics_interpolation()

	cam_follow_point_manager.register_cam_follow_node(caravan)


func spawn_player(player: PlayerData) -> void:
	var player_node: PlayerController = ResLoader.PLAYER_SCENE.instantiate()
	player_node.init(player.input_device, player.color)

	# Find spawn pos
	var shape: CollisionShape3D = player_node.get_node("Collision")
	var spawn_pos := _find_spawn_pos_xz_near_caravan(player.id)

	# Match to navmesh, get height - this requires a navmesh
	spawn_pos = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, spawn_pos)
	spawn_pos = MapGeneration.get_spawn_pos_height_on_map_surface(spawn_pos, shape)

	# Set player color
	var mesh_instance := player_node.get_node("Mesh") as MeshInstance3D
	var new_mesh: Mesh = mesh_instance.mesh.duplicate(true)

	var new_mat: StandardMaterial3D = new_mesh.surface_get_material(0)
	new_mat.albedo_color = player.color
	new_mesh.surface_set_material(0, new_mat)
	mesh_instance.mesh = new_mesh

	# Add to scene
	get_tree().root.add_child(player_node)
	player_node.global_position = spawn_pos
	player_node.reset_physics_interpolation()

	# Link player data to node and vice versa
	player.player_node = player_node
	player_node.player_data = player
	
	GameStateManager.cam_follow_point_manager.register_cam_follow_node(player_node)


func despawn_player(player: PlayerData) -> void:
	GameStateManager.cam_follow_point_manager.unregister_cam_follow_node(player.player_node)
	player.player_node.queue_free()


###################################################################
# Helper
###################################################################
# TODO move to physics utils class
func _find_closest_valid_spawn_pos(pos: Vector3, shape: CollisionShape3D, match_to_navmesh: bool = true) -> Vector3:
	# Match to navmesh, get height - this requires a navmesh
	if match_to_navmesh:
		pos = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, pos)


	pos = MapGeneration.get_spawn_pos_height_on_map_surface(pos, shape)

	
	# Find spawn pos
	var shape: CollisionShape3D = player_node.get_node("Collision")
	var spawn_pos := _find_spawn_pos_xz_near_caravan(player.id)

	# Match to navmesh, get height - this requires a navmesh
	spawn_pos = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, spawn_pos)
	spawn_pos = MapGeneration.get_spawn_pos_height_on_map_surface(spawn_pos, shape)


func _find_spawn_pos_xz_near_caravan(exclude_id: int) -> Vector3:
	var reference_pos: Vector3 = GameStateManager.caravan.global_position
	return reference_pos + Util.rand_circular_offset_range(3.0, 3.0)

# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node3D


# Caravan
var caravan: Caravan


# Sub-Managers
var cam_follow_point_manager: CameraFollowPointManager


func _ready() -> void:
	# Print Input Mappings
	# pretty_print_actions(get_input_mapping())
	if not Engine.is_editor_hint():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# Input.mouse_mode = Input.MOUSE_MODE_CONFINED

	get_tree().debug_collisions_hint = DebugSettings.enable_debug_collision_visualizations

	cam_follow_point_manager = CameraFollowPointManager.new()

	#NAVMAP
	var nav_map := get_world_3d().navigation_map
	NavigationServer3D.set_debug_enabled(true)
	NavigationServer3D.map_set_cell_size(nav_map, HexConst.nav_cell_size)
	NavigationServer3D.map_set_cell_height(nav_map, HexConst.nav_cell_size)

	# EDGE MERGING
	# For two regions to be connected to each other, they must share a similar edge.
	# An edge is considered connected to another if both of its two vertices are
	# at a distance less than edge_connection_margin to the respective other edge's vertex.
	# -> THIS DOES NOT WORK FOR US RELIABLY
	NavigationServer3D.map_set_use_edge_connections(nav_map, true)
	NavigationServer3D.map_set_edge_connection_margin(nav_map, 0.5) # default 0.25


	# Wait for nav chunks to be loaded
	await Util.wait_until(self, func() -> bool: return get_tree().get_nodes_in_group(HexConst.NAV_CHUNKS_GROUP_NAME).size() > 12)

	spawn_caravan()

	# Always spawn keyboard player for development (not in editor)
	if not Engine.is_editor_hint():
		PlayerManager.add_player(-1)


	# Add enemy spawner
	var enemy_spawn_timer := Timer.new()
	enemy_spawn_timer.wait_time = 2.5
	enemy_spawn_timer.autostart = true
	enemy_spawn_timer.timeout.connect(spawn_enemy)
	add_child(enemy_spawn_timer)

	# TODO TEST ONLY
	await get_tree().create_timer(2.0).timeout
	remove_small_islands()


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
	Util.print_multiline_banner("Quitting game")
	MapGeneration.shutdown_threads()


##################################################################
# Spawner Functions
###################################################################
func spawn_enemy() -> void:
	var enemy_node: BasicEnemy = ResLoader.BASIC_ENEMY_SCENE.instantiate()

	# Find spawn pos
	var shape: CollisionShape3D = enemy_node.get_node("Collision")
	var spawn_pos: Vector3 = caravan.global_position + Util.randCircularOffsetRange(12, 20)
	spawn_pos = MapGeneration.get_capsule_spawn_pos_on_map_surface(spawn_pos, shape)

	get_tree().root.add_child(enemy_node)
	enemy_node.global_position = spawn_pos
	enemy_node.reset_physics_interpolation()


func remove_small_islands() -> void:
	var nav_map: RID = get_world_3d().navigation_map
	var all_regions: Array[RID] = NavigationServer3D.map_get_regions(nav_map)
	
	# print("========= REGIONS AABB =========")
	# for region_id in all_regions:
	# 	var aabb := NavigationServer3D.region_get_bounds(region_id)
	# 	if aabb.position.x >= -15 and aabb.position.x < 30:
	# 		print("X-min: ", aabb.position.x, "\tX-max: ", aabb.position.x + aabb.size.x)
	# print("========= END =========")
	
	# print("====== CHUNKS ======")
	# for c: HexChunk in HexChunkMap.chunks.values():
	# 	print(c.global_position)
	# print("========= END =========")
	

func spawn_caravan() -> void:
	if caravan != null:
		return

	caravan = ResLoader.CARAVAN_SCENE.instantiate()

	# Find spawn height
	var pos: Vector3 = HexConst.MAP_CENTER
	var shape: CollisionShape3D = caravan.get_node("Collision")
	var spawn_pos := MapGeneration.get_capsule_spawn_pos_on_map_surface(pos, shape)

	# Set color
	var mesh_instance := caravan.get_node("Mesh") as MeshInstance3D
	var new_mesh: Mesh = mesh_instance.mesh.duplicate(true)

	var new_mat: StandardMaterial3D = new_mesh.surface_get_material(0)
	new_mat.albedo_color = Color.TEAL
	new_mesh.surface_set_material(0, new_mat)
	mesh_instance.mesh = new_mesh

	# Add to scene
	get_tree().root.add_child(caravan)
	caravan.global_position = spawn_pos
	caravan.reset_physics_interpolation()

	cam_follow_point_manager.register_cam_follow_node(caravan)

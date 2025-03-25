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
	NavigationServer3D.map_set_use_edge_connections(nav_map, true)

	# Wait for nav chunks to be loaded
	await Util.wait_until(self, func() -> bool: return get_tree().get_nodes_in_group(HexConst.NAV_CHUNKS_GROUP_NAME).size() > 12)

	spawn_caravan()

	# Always spawn keyboard player for development (not in editor)
	if not Engine.is_editor_hint():
		PlayerManager.add_player(-1)


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


func request_quit_game() -> void:
	Util.print_multiline_banner("Quitting game")
	MapGeneration.shutdown_threads()


##################################################################
# Spawner Functions
###################################################################
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
	caravan.global_transform.origin = spawn_pos

	cam_follow_point_manager.register_cam_follow_node(caravan)

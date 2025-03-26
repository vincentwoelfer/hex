# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# Global Variables
const MAX_PLAYERS: int = 4

# Dictionary of players, indexed by their id
var players: Dictionary[int, PlayerData] = {}


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		var new_player_ids := handle_join_input()
		handle_leave_input(new_player_ids)


# Returns the new player id
func add_player(device: int) -> int:
	var id: int = _get_available_player_id()
	if id == -1:
		print("No more player slots available")
		return -1

	players[id] = PlayerData.new(id, "Player-" + str(id), Colors.getPlayerColor(id), device)
	var player: PlayerData = players[id]
	spawn_player(player)
	print("%s joined with device %s" % [player.display_name, HexInput.get_device_display_name(player.input_device)])
	return id


func remove_player(id: int) -> void:
	if not players.has(id):
		print("No player with id %d" % [id])
		return

	var player: PlayerData = players[id]
	players.erase(id)
	print("%s left" % [player.display_name])

	despawn_player(player)
	

func _get_available_player_id() -> int:
	for i in range(MAX_PLAYERS):
		if not players.has(i):
			return i
	return -1


# Handle input for joining/leaving the match
func handle_join_input() -> Array[int]:
	var new_ids: Array[int] = []
	for device in get_unjoined_devices():
		if HexInput.is_action_just_pressed(device, "join_match"):
			var id := add_player(device)
			if id != -1:
				new_ids.append(id)
	return new_ids
			
func handle_leave_input(ignore_ids: Array[int]) -> void:
	for player: PlayerData in players.values():
		if HexInput.is_action_just_pressed(player.input_device, "leave_match"):
			if not ignore_ids.has(player.id):
				remove_player(player.id)


# returns an array of all valid devices that are not associated with a joined player
func get_unjoined_devices() -> Array[int]:
	var devices := Input.get_connected_joypads()
	# also consider keyboard player
	devices.append(-1)
	
	# filter out devices that are joined:
	return devices.filter(func(device: int) -> bool: return !_is_device_joined(device))


func _is_device_joined(device: int) -> bool:
	for player: PlayerData in players.values():
		if device == player.input_device:
			return true
	return false


###################################################
# Spawning
###################################################	
func spawn_player(player: PlayerData) -> void:
	var player_node: PlayerController = ResLoader.PLAYER_SCENE.instantiate()
	player_node.init(player.input_device, player.color)

	# Find spawn pos
	var shape: CollisionShape3D = player_node.get_node("Collision")
	var spawn_pos := _find_spawn_pos_xz_near_team(player.id)
	spawn_pos = MapGeneration.get_capsule_spawn_pos_on_map_surface(spawn_pos, shape)

	# Set player color
	var mesh_instance := player_node.get_node("Mesh") as MeshInstance3D
	var new_mesh: Mesh = mesh_instance.mesh.duplicate(true)

	var new_mat: StandardMaterial3D = new_mesh.surface_get_material(0)
	new_mat.albedo_color = player.color
	new_mesh.surface_set_material(0, new_mat)
	mesh_instance.mesh = new_mesh

	get_tree().root.add_child(player_node)
	player_node.global_position = spawn_pos
	player_node.reset_physics_interpolation()

	player.player_node = player_node
	GameStateManager.cam_follow_point_manager.register_cam_follow_node(player_node)


func despawn_player(player: PlayerData) -> void:
	GameStateManager.cam_follow_point_manager.unregister_cam_follow_node(player.player_node)
	player.player_node.queue_free()


func _find_spawn_pos_xz_near_team(exclude_id: int) -> Vector3:
	var reference_pos: Vector3 = GameStateManager.caravan.get_global_transform().origin
	return reference_pos + Util.vec3FromRadiusAngle(3.0, randf_range(0, TAU))

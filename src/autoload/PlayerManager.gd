# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# Global Variables
const MAX_PLAYERS: int = 4

# Dictionary of players, indexed by their id
var players: Dictionary[int, PlayerData] = {}

var cam_follow_nodes: Array[Node3D] = []

var player_scene: PackedScene = preload('res://scenes/PlayerCharacter.tscn')


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
func find_spawn_pos_xz_near_team(exclude_id: int) -> Vector3:
	# TODO Find caravan pos
	var possible_reference_players: Array[PlayerData] = players.values().filter(func(p: PlayerData) -> bool: return p.id != exclude_id)

	if possible_reference_players.is_empty():
		return HexConst.MAP_CENTER + Vector3(0, 0, 3) # TODO this is a hack

	# Next to random player
	var player: PlayerData = possible_reference_players.pick_random()
	var reference_pos: Vector3 = player.player_node.global_transform.origin
	var pos: Vector3 = reference_pos + Util.vec3FromRadiusAngle(3.0, randf_range(0, TAU))
	return pos

	
func spawn_player(player: PlayerData) -> void:
	var player_node: PlayerController = player_scene.instantiate()
	player_node.init(player.input_device, player.color)

	# Find spawn pos
	var shape: CollisionShape3D = player_node.get_node("Collision")
	var spawn_pos := find_spawn_pos_xz_near_team(player.id)
	spawn_pos = MapGeneration.get_capsule_spawn_pos_on_map_surface(spawn_pos, shape)

	# Set player color
	var mesh_instance := player_node.get_node("Mesh") as MeshInstance3D
	var new_mesh: Mesh = mesh_instance.mesh.duplicate(true)

	var new_mat: StandardMaterial3D = new_mesh.surface_get_material(0)
	new_mat.albedo_color = player.color
	new_mesh.surface_set_material(0, new_mat)
	mesh_instance.mesh = new_mesh

	get_tree().root.add_child(player_node)
	player_node.global_transform.origin = spawn_pos

	player.player_node = player_node
	register_cam_follow_node(player_node)


func despawn_player(player: PlayerData) -> void:
	unregister_cam_follow_node(player.player_node)
	player.player_node.queue_free()


###################################################
# Camera Follow
###################################################
func register_cam_follow_node(node: Node3D) -> void:
	if not node in cam_follow_nodes:
		cam_follow_nodes.append(node)

func unregister_cam_follow_node(node: Node3D) -> void:
	if node in cam_follow_nodes:
		cam_follow_nodes.erase(node)

func calculate_cam_follow_point() -> Vector3:
	if cam_follow_nodes.is_empty():
		var zero := HexConst.MAP_CENTER
		zero.y = MapGeneration._get_approx_map_height_at_pos(zero) + 2.0
		return zero

	var p: Vector3 = Vector3.ZERO
	for node in cam_follow_nodes:
		p += node.get_global_transform_interpolated().origin
	p /= float(cam_follow_nodes.size())
	return p

func calculate_cam_follow_point_max_dist(cam_follow_point: Vector3) -> float:
	if cam_follow_nodes.is_empty():
		return 0.0

	var max_dist: float = 0.0
	for node in cam_follow_nodes:
		var dist: float = node.global_position.distance_to(cam_follow_point)
		max_dist = max(max_dist, dist)
	return max_dist

class_name CameraFollowPointManager
extends Object

var global_camera_view_angle: float
var cam_follow_nodes: Array[Node3D] = []
var use_caravan_for_cam_follow: bool = false


func set_global_camera_view_angle(angle: float) -> void:
	global_camera_view_angle = angle
func get_global_camera_view_angle() -> float:
	return global_camera_view_angle


func register_cam_follow_node(node: Node3D) -> void:
	if not node in cam_follow_nodes:
		cam_follow_nodes.append(node)
func unregister_cam_follow_node(node: Node3D) -> void:
	if node in cam_follow_nodes:
		cam_follow_nodes.erase(node)


func get_active_cam_follow_nodes() -> Array[Node3D]:
	var active_cam_follow_nodes: Array[Node3D] = cam_follow_nodes.duplicate()

	# Exclude caravan (unless its the only one). Caravan is always at index 0
	if not use_caravan_for_cam_follow and active_cam_follow_nodes.size() > 1:
		active_cam_follow_nodes.remove_at(0)
	return active_cam_follow_nodes


func calculate_follow_aabb() -> AABB:
	var aabb := AABB()
	var active_cam_follow_nodes := get_active_cam_follow_nodes()

	if active_cam_follow_nodes.is_empty():
		var zero := HexConst.MAP_CENTER
		zero.y = MapGeneration.get_hex_tile_height_at_map_pos(zero)
		aabb.position = zero
		return aabb
	
	aabb.position = active_cam_follow_nodes[0].get_global_transform_interpolated().origin
	for p in active_cam_follow_nodes:
		aabb = aabb.expand(p.get_global_transform_interpolated().origin)

	return aabb

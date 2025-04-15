class_name CameraFollowPointManager
extends Object

var global_camera_view_angle: float
var cam_follow_nodes: Array[Node3D] = []
var use_caravan_for_cam_follow: bool = true


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


func calculate_cam_follow_point() -> Vector3:
	var active_cam_follow_nodes := get_active_cam_follow_nodes()

	if active_cam_follow_nodes.is_empty():
		var zero := HexConst.MAP_CENTER
		zero.y = MapGeneration.get_hex_tile_height_at_map_pos(zero)
		return zero

	var p: Vector3 = Vector3.ZERO
	for node in active_cam_follow_nodes:
		p += node.get_global_transform_interpolated().origin
		#p += node.global_position
	p /= float(active_cam_follow_nodes.size())
	return p


func calculate_cam_follow_point_max_dist(cam_follow_point: Vector3) -> float:
	var active_cam_follow_nodes := get_active_cam_follow_nodes()

	if active_cam_follow_nodes.is_empty():
		return 0.0

	var max_dist: float = 0.0
	for node in active_cam_follow_nodes:
		var dist: float = node.global_position.distance_to(cam_follow_point)
		max_dist = max(max_dist, dist)
	return max_dist

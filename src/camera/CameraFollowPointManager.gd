class_name CameraFollowPointManager
extends Object

var global_camera_view_angle: float
var cam_follow_nodes: Array[Node3D] = []


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

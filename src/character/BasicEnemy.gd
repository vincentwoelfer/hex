class_name BasicEnemy
extends CharacterBody3D

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision

var speed: float = 2.5

var target: Node3D = null
var target_reached_dist: float

var goal_choosing_timer: Timer

func _ready() -> void:
	add_to_group(HexConst.GROUP_NAV_ENEMIES)

	path_finding_agent.init(Color.RED, collision.shape, DebugSettings.show_path_basic_enemy)

	self.floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)

	# Set initial goal
	choose_new_goal()

	# This is for choosing a new goal, replanning the already found path to same goal happens periodically inside path_finding_agent
	goal_choosing_timer = Util.timer(0.75, choose_new_goal)
	add_child(goal_choosing_timer)


func _physics_process(delta: float) -> void:
	var movement: Vector3
	if target == null or path_finding_agent.is_navigation_done():
		movement = Vector3.ZERO
	else:
		# Move, Dont touch y to not mess with gravity
		movement = path_finding_agent.get_direction() * speed
		velocity.x = movement.x
		velocity.z = movement.z

	# Reached target - custom larger radius to enable "explosion" later on
	if target != null and Util.get_dist_planar(global_position, target.global_position) <= target_reached_dist:
		queue_free()
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y += HexConst.GRAVITY * delta

	move_and_slide()


func choose_new_goal() -> void:
	target = null

	var nav_map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return

	# REAL HACKY, rework!
	var possible_goals := GameStateManager.cam_follow_point_manager.cam_follow_nodes
	if possible_goals.size() == 0:
		return

	# Choose closest goal
	var closest_goal_idx := -1
	var min_distance := 9999.0
	for i in range(0, possible_goals.size()):
		var start_point: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, global_position)
		var end_point: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, possible_goals[i].global_position)
		var path := NavigationServer3D.map_get_path(nav_map, start_point, end_point, true)

		var distance := get_total_path_length(path)
		if distance < min_distance:
			min_distance = distance
			closest_goal_idx = i

	target = possible_goals[closest_goal_idx]
	path_finding_agent.set_track_target(target)
	target_reached_dist = _compute_target_done_dist()


func _compute_target_done_dist() -> float:
	# This is a bit hacky, but we need to get the target's collision shape
	# and use its extents to determine how far we need to be from the target
	var target_radius: float = 0.0
	if target != null:
		for child in target.get_children():
			if child is CollisionShape3D:
				var shape: Shape3D = (child as CollisionShape3D).shape
				if shape is SphereShape3D:
					target_radius = (shape as SphereShape3D).radius
				elif shape is CapsuleShape3D:
					target_radius = (shape as CapsuleShape3D).radius
				elif shape is CylinderShape3D:
					target_radius = (shape as CylinderShape3D).radius
				# Add more shape types if needed

	return path_finding_agent.radius + target_radius + 0.2

func get_total_path_length(points: PackedVector3Array) -> float:
	if points.size() <= 1:
		return 0.0

	var total_length: float = 0.0
	for i in range(1, points.size()):
		total_length += points[i - 1].distance_to(points[i])
	return total_length

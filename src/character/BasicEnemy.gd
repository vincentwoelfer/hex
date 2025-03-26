class_name BasicEnemy
extends CharacterBody3D

# Scene references
@onready var nav_agent: NavigationAgent3D = $NavAgent

var speed: float = 2.0

var has_goal: bool = false
var current_goal: Vector3

var debug_path: DebugPathInstance

var replan_timer: Timer

func _ready() -> void:
	nav_agent.debug_enabled = DebugSettings.caravan_debug_path

	var color := nav_agent.debug_path_custom_color
	color.a = 0.3
	debug_path = DebugPathInstance.new(color, 0.03)
	add_child(debug_path)

	# Set initial goal
	choose_new_goal()

	replan_timer = Timer.new()
	replan_timer.wait_time = 0.2
	replan_timer.autostart = true
	replan_timer.timeout.connect(choose_new_goal)
	add_child(replan_timer)


func _physics_process(delta: float) -> void:
	if not has_goal:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Reached target
	if global_position.distance_to(current_goal) <= 1.2:
		queue_free()
		return

	# Move
	var next_position := nav_agent.get_next_path_position()
	var direction := (next_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	# Update visual path
	debug_path.update_path(nav_agent.get_current_navigation_path(), global_position)


func choose_new_goal() -> void:
	has_goal = false

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

	current_goal = NavigationServer3D.map_get_closest_point(nav_map, possible_goals[closest_goal_idx].get_global_transform().origin)
	if current_goal == Vector3.ZERO:
		return

	nav_agent.set_target_position(current_goal)
	has_goal = true


func get_total_path_length(points: PackedVector3Array) -> float:
	if points.size() <= 1:
		return 0.0

	var total_length: float = 0.0
	for i in range(1, points.size()):
		total_length += points[i - 1].distance_to(points[i])
	return total_length

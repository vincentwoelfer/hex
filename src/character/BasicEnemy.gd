class_name BasicEnemy
extends CharacterBody3D

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision

var speed: float = 2.5
var gravity: float = - ProjectSettings.get_setting("physics/3d/default_gravity")

var has_target: bool
var target: Node3D

var replan_timer: Timer

func _ready() -> void:
	path_finding_agent.init(Color(1.0, 0.0, 0.0), collision.shape)

	# Set initial goal
	choose_new_goal()

	# This is for choosing a new goal, replanning to same goal happens periodically inside path_finding_agent
	replan_timer = Timer.new()
	replan_timer.wait_time = 0.75
	replan_timer.autostart = true
	replan_timer.timeout.connect(choose_new_goal)
	add_child(replan_timer)


func _physics_process(delta: float) -> void:
	if not has_target:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Reached target
	if global_position.distance_to(target.global_position) <= 1.0:
		queue_free()
		return

	# Move
	var direction := path_finding_agent.get_direction()
	var movement := direction * speed

	# Dont touch y
	velocity.x = movement.x
	velocity.z = movement.z

	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	move_and_slide()


func choose_new_goal() -> void:
	has_target = false

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
	has_target = true


func get_total_path_length(points: PackedVector3Array) -> float:
	if points.size() <= 1:
		return 0.0

	var total_length: float = 0.0
	for i in range(1, points.size()):
		total_length += points[i - 1].distance_to(points[i])
	return total_length

class_name BasicEnemy
extends CharacterBody3D

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision

var speed: float = 2.5

var target: Node3D = null
var target_reached_dist: float


# Goal choosing logic
var goal_choosing_timer: Timer
var goal_choosing_interval: float = 0.75


func _ready() -> void:
	add_to_group(HexConst.GROUP_ENEMIES)

	path_finding_agent.init(Color.RED, collision.shape, DebugSettings.show_path_basic_enemy)

	self.floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)

	# Set initial goal
	_choose_new_goal()

	# This is for choosing a new goal, replanning the already found path to same goal happens periodically inside path_finding_agent
	goal_choosing_timer = Util.timer(goal_choosing_interval, _choose_new_goal)
	add_child(goal_choosing_timer)


func _physics_process(delta: float) -> void:
	# returns ZERO if no path/goal
	var movement: Vector3 = path_finding_agent.get_direction() * speed

	if movement == Vector3.ZERO:
		self.goal_choosing_timer.start()
		_choose_new_goal()
	else:
		# Move, Dont touch y to not mess with gravity
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


func _get_possible_goals() -> Array[Node3D]:
	var possible_goals: Array[Node3D] = []

	# Add caravan by default (TODO maybe check if caravan has crystals left?)
	possible_goals.append(GameStateManager.caravan)
	
	# Add players (TODO this requires them to have an attack)
	for node in get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS):
		possible_goals.append(node)

	# Add crystals
	for crystal: Crystal in get_tree().get_nodes_in_group(HexConst.GROUP_CRYSTALS):
		if crystal.state in [Crystal.State.CARRIED_BY_PLAYER, Crystal.State.ON_GROUND]:
			possible_goals.append(crystal)

	return possible_goals


func _choose_new_goal() -> void:
	target = null
	# Reset timer
	goal_choosing_timer.start()

	var nav_map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return

	# REAL HACKY, rework!
	var possible_goals := _get_possible_goals()
	if possible_goals.size() == 0:
		return

	# Choose closest goal - TODO add weighting logic in future
	var min_distance := 9999.0
	var best_goal: Node3D = null
	for goal: Node3D in possible_goals:
		if goal == null or goal.is_queued_for_deletion():
			continue

		var path := NavigationServer3D.map_get_path(nav_map, global_position, goal.global_position, false)
		var distance := Util.get_total_path_length(path)
		if distance < min_distance:
			min_distance = distance
			best_goal = goal

	if best_goal == null:
		return

	# Plan optimized path to choosen goal
	target = best_goal
	path_finding_agent.set_track_target(target)
	target_reached_dist = _compute_target_done_dist()


func _compute_target_done_dist() -> float:
	# This is a bit hacky, but we need to get the target's collision shape
	# and use its extents to determine how far we need to be from the target
	var target_radius: float = 0.0
	if target != null:
		for child in target.get_children():
			# Use first collision shape found
			if child is CollisionShape3D:
				var shape: Shape3D = (child as CollisionShape3D).shape
				if shape is SphereShape3D:
					target_radius = (shape as SphereShape3D).radius
				elif shape is CapsuleShape3D:
					target_radius = (shape as CapsuleShape3D).radius
				elif shape is CylinderShape3D:
					target_radius = (shape as CylinderShape3D).radius
				# Add more shape types if needed

				break

	return path_finding_agent.radius + target_radius + 0.2

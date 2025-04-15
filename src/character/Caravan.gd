class_name Caravan
extends CharacterBody3D

var speed: float = 1.5

# Global Path params
var min_goal_distance: float = 30.0
var max_goal_distance: float = 50.0
var path_dir_mean: float = Util.get_hex_angle_interpolated(5)
var path_dir_rand_deviation: float = deg_to_rad(15)

var has_goal: bool = false
var current_goal: Vector3

var velocity_no_collision: Vector3 = Vector3.ZERO

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision

# TEST
var crystal_timer: Timer

func _ready() -> void:
	# Pathfinding agent
	path_finding_agent.init(Colors.COLOR_CARAVAN, collision.shape, DebugSettings.show_path_caravan)
	path_finding_agent.replan_interval_s = -1.0

	# Caravan can climb more to avoid getting stuck
	self.floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)

	# Set initial goal
	choose_new_goal()

	# TEST
	crystal_timer = Util.timer(1.5, spawn_crystal)
	add_child(crystal_timer)


func get_speed() -> float:
	# Move faster for testing if Caravan is alone
	if GameStateManager.cam_follow_point_manager.get_active_cam_follow_nodes().size() == 1:
		return 10.0
	else:
		return speed

func spawn_crystal() -> void:
	var crystal: Node3D = ResLoader.CRYSTAL_SCENE.instantiate()
	var spawn_pos: Vector3 = self.global_position + Util.rand_circular_offset_range(1.5, 2.5) + Vector3(0, 2.0, 0)

	crystal.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
	Util.spawn(crystal, spawn_pos)
	

func _physics_process(delta: float) -> void:
	var movement: Vector3
	if path_finding_agent.is_navigation_done() or not has_goal:
		if not choose_new_goal():
			print("Unable to find new caravan goal!")

	# Move, Dont touch y to not mess with gravity
	movement = path_finding_agent.get_direction() * self.get_speed()
	velocity.x = movement.x
	velocity.z = movement.z

	# Apply gravity
	if not is_on_floor():
		velocity.y += HexConst.GRAVITY * delta

	# Store velocity before move_and_slide
	self.velocity_no_collision = velocity
	move_and_slide()

	# TODO: Not perfect, but works for now
	push_characters()
		# self.velocity = self.velocity_no_collision
		# move_and_slide()

func push_characters() -> bool:
	var pushed_any_character: bool = false

	# Check for collisions
	for i: int in get_slide_collision_count():
		var c: KinematicCollision3D = get_slide_collision(i)
		var other_body: Node3D = c.get_collider()

		# Only push other CharacterBody3D nodes
		if other_body is CharacterBody3D and other_body != self:
			pushed_any_character = true
			self._push_character(other_body as CharacterBody3D, c.get_normal())

	return pushed_any_character


func _push_character(target: CharacterBody3D, collision_normal: Vector3) -> void:
	var push_direction: Vector3 = - collision_normal
	push_direction.y = 0.0
	push_direction = push_direction.normalized()

	var push_velocity: Vector3 = self.velocity_no_collision.length() * 1.3 * push_direction

	# Remove component of targets velocity in the direction of the push
	var target_velocity_along_push: Vector3 = push_direction * target.velocity.dot(push_direction)

	# Apply the push and remove any velocity going against that push
	target.velocity = target.velocity - target_velocity_along_push + push_velocity
	# target.move_and_slide()


func choose_new_goal() -> bool:
	var nav_map: RID = Util.get_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		has_goal = false
		return false

	# Determine random path direction
	var r := randf_range(min_goal_distance, max_goal_distance)
	var angle := randf_range(path_dir_mean - path_dir_rand_deviation, path_dir_mean + path_dir_rand_deviation)
	var goal_pos := global_position + Util.vec3_from_radius_angle(r, angle)

	# Find valid nearby position - height offset
	goal_pos += Vector3.UP * 0.5
	current_goal = PhysicUtil.find_closest_valid_spawn_pos(goal_pos, collision.shape, 1.0, 5.0, true, Layers.TERRAIN_AND_STATIC)

	# Validate the goal
	if current_goal == Vector3.INF:
		print("Caravan goal is invalid, trying again...")
		has_goal = false
		return false

	# Set the new goal for navigation
	path_finding_agent.set_target(current_goal)
	print("Caravan has new goal : ", current_goal)
	has_goal = true
	return true

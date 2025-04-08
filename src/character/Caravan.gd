class_name Caravan
extends CharacterBody3D

var speed: float = 1.25

# Global Path params
var min_goal_distance: float = 30.0
var max_goal_distance: float = 50.0
var path_dir_mean: float = Util.getHexAngleInterpolated(5)
var path_dir_rand_deviation: float = deg_to_rad(15)

var has_goal: bool = false
var current_goal: Vector3

var velocity_no_collision: Vector3 = Vector3.ZERO

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision


func _ready() -> void:
	path_finding_agent.init(Colors.COLOR_CARAVAN, collision.shape)
	path_finding_agent.show_path = DebugSettings.show_path_caravan

	# Caravan can climb more to avoid getting stuck
	self.floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)

	# Set initial goal
	choose_new_goal()


func _physics_process(delta: float) -> void:
	if path_finding_agent.is_navigation_done() or not has_goal:
		choose_new_goal()
		move_and_slide()
		return

	# Move, Dont touch y to not mess with gravity
	var movement := path_finding_agent.get_direction() * speed
	velocity.x = movement.x
	velocity.z = movement.z

	# Apply gravity
	if not is_on_floor():
		velocity.y += HexConst.GRAVITY * delta

	self.velocity_no_collision = velocity
	move_and_slide()

	# TODO: Not perfect, but works for now
	if push_characters():
		self.velocity = self.velocity_no_collision
		move_and_slide()

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


func choose_new_goal() -> void:
	var nav_map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		has_goal = false
		return

	var r := randf_range(min_goal_distance, max_goal_distance)
	var angle := randf_range(path_dir_mean - path_dir_rand_deviation, path_dir_mean + path_dir_rand_deviation)
	var random_goal_pos := global_position + Util.vec3FromRadiusAngle(r, angle)

	# Set the new goal for navigation
	current_goal = NavigationServer3D.map_get_closest_point(nav_map, random_goal_pos)
	if current_goal == Vector3.ZERO:
		has_goal = false
		return

	path_finding_agent.set_target(current_goal)
	print("Caravan has new goal : ", current_goal)
	has_goal = true


func _push_character(target: CharacterBody3D, collision_normal: Vector3) -> void:
	# TODO not perfect, gets stuck on slopes sometimes
	var push_direction: Vector3 = - collision_normal
	push_direction.y = 0.0
	push_direction = push_direction.normalized()

	var push_velocity: Vector3 = self.speed * 1.3 * push_direction

	# Remove component of targets velocity in the direction of the push
	var target_velocity_along_push: Vector3 = push_direction * target.velocity.dot(push_direction)
	
	# Apply the push and remove any velocity going against that push
	target.velocity = target.velocity - target_velocity_along_push + push_velocity
	target.move_and_slide()

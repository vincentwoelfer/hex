class_name Caravan
extends HexPhysicsCharacterBody3D

var speed: float = 1.0

# Global Path params
var min_goal_distance: float = 30.0
var max_goal_distance: float = 50.0
var path_dir_mean: float = Util.get_hex_angle_interpolated(5)
var path_dir_rand_deviation: float = deg_to_rad(15)

var has_goal: bool = false
var current_goal: Vector3
var goal_marker: Node3D = null

var velocity_no_collision: Vector3 = Vector3.ZERO

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision
@onready var caravan_depot: CaravanDepot = $RotationAxis/CaravanDepot

func _ready() -> void:
	# more than player
	self.mass = 150.0

	# Pathfinding agent
	path_finding_agent.init(Colors.COLOR_CARAVAN, collision.shape, DebugSettings.show_path_caravan)
	path_finding_agent.replan_interval_s = -1.0

	# Caravan can climb more to avoid getting stuck
	self.floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)

	# Set initial goal
	choose_new_goal()


func get_speed() -> float:
	# Move faster for testing if Caravan is alone
	if GameStateManager.cam_follow_point_manager.get_active_cam_follow_nodes() == [self]:
		return 10.0
	else:
		if caravan_depot.has_objects():
			return speed
		else:
			# TODO: Caravan movement breaks if this is 0 -> investigate
			return 0.001
	

func _physics_process(delta: float) -> void:
	if path_finding_agent.is_navigation_done() or not has_goal:
		if not choose_new_goal():
			print("Unable to find new caravan goal!")

	var m: CharMovement = CharMovement.new()
	m.input_dir = Util.to_vec2(path_finding_agent.get_direction())
	m.input_speed = self.get_speed()
	
	# Fake values, instant accel/decel
	m.accel_ramp_time = 0.0
	m.decel_ramp_time = 0.0
	m.max_possible_speed = self.speed

	m.input_control_factor = 1.0
	m.vertical_override = 0.0

	self._custom_physics_process(delta, m)


func choose_new_goal() -> bool:
	var nav_map: RID = Util.get_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		has_goal = false
		return false

	# Determine random path direction
	var r := randf_range(min_goal_distance, max_goal_distance)
	var angle := randf_range(path_dir_mean - path_dir_rand_deviation, path_dir_mean + path_dir_rand_deviation)
	var goal_pos := global_position + Util.vec3_from_radius_angle(r, angle)

	# Find valid nearby position with height offset + larger collision shape
	goal_pos += Vector3.UP * 0.5
	var larger_shape: CylinderShape3D = collision.shape.duplicate(true)
	larger_shape.radius = larger_shape.radius * 3.0

	current_goal = PhysicUtil.find_closest_valid_spawn_pos(goal_pos, larger_shape, 1.0, 6.0, true, Layers.TERRAIN_AND_STATIC)

	# Validate the goal
	if current_goal == Vector3.INF:
		print("Caravan goal is invalid, trying again...")
		has_goal = false
		return false

	# Set the new goal for navigation
	path_finding_agent.set_target(current_goal)
	print("Caravan has new goal : ", current_goal)
	has_goal = true

	# Spawn portals TODO along path, not around caravan
	for i in range(5):
		GameStateManager.spawn_escape_portal(current_goal)

	return true

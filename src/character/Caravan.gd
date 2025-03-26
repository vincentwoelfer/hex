class_name Caravan
extends CharacterBody3D

# Scene references
@onready var nav_agent: NavigationAgent3D = $NavAgent

var speed: float = 1.25

# Global Path params
var min_goal_distance: float = 30.0
var max_goal_distance: float = 50.0
var path_dir_mean: float = Util.getHexAngleInterpolated(5)
var path_dir_rand_deviation: float = deg_to_rad(15)

var has_goal: bool = false
var current_goal: Vector3

var debug_path: DebugPathInstance

func _ready() -> void:
	debug_path = DebugPathInstance.new(Color(0, 0.407843, 0.164706, 0.5), 0.05, DebugSettings.debug_path_caravan)
	add_child(debug_path)

	# Set initial goal
	choose_new_goal()


func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished() or not has_goal:
		choose_new_goal()
		return

	var next_position := nav_agent.get_next_path_position()
	var direction := (next_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

	# Update visual path
	debug_path.update_path(nav_agent.get_current_navigation_path(), global_position)


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

	nav_agent.set_target_position(current_goal)
	print("Caravan has new goal : ", current_goal)
	has_goal = true

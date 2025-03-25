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
	nav_agent.debug_enabled = DebugSettings.caravan_debug_path

	var color := nav_agent.debug_path_custom_color
	color.a = 0.5
	debug_path = DebugPathInstance.new(color, 0.05)
	add_child(debug_path)

	# Set initial goal
	choose_new_goal()


func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished() or not has_goal:
		choose_new_goal()
		return

	var next_position := nav_agent.get_next_path_position()
	var direction := (next_position - global_transform.origin).normalized()
	velocity = direction * speed
	move_and_slide()

	# Update visual path, manually replace first point by own position
	var path := nav_agent.get_current_navigation_path()
	if path.size() > 0:
		path[0] = global_transform.origin
	debug_path.update_path(path)


func choose_new_goal() -> void:
	var nav_map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		has_goal = false
		return

	var r := randf_range(min_goal_distance, max_goal_distance)
	var angle := randf_range(path_dir_mean - path_dir_rand_deviation, path_dir_mean + path_dir_rand_deviation)
	var random_goal_pos := global_transform.origin + Util.vec3FromRadiusAngle(r, angle)

	# Set the new goal for navigation
	current_goal = NavigationServer3D.map_get_closest_point(nav_map, random_goal_pos)
	if current_goal == Vector3.ZERO:
		has_goal = false
		return

	nav_agent.set_target_position(current_goal)
	print("Caravan has new goal : ", current_goal)
	has_goal = true

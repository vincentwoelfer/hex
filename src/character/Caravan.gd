class_name Caravan
extends CharacterBody3D

var speed: float = 15.25

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


# TEST
var crystal_timer: Timer


func _ready() -> void:
	path_finding_agent.init(Colors.COLOR_CARAVAN, collision.shape)
	path_finding_agent.show_path = DebugSettings.show_path_caravan

	# Caravan can climb more to avoid getting stuck
	self.floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)

	# Set initial goal
	choose_new_goal()

	# TEST
	crystal_timer = Timer.new()
	crystal_timer.wait_time = 0.75
	crystal_timer.autostart = true
	crystal_timer.timeout.connect(spawn_crystal)
	add_child(crystal_timer)


func spawn_crystal() -> void:
	return
	var crystal: Node3D = ResLoader.CRYSTAL_SCENE.instantiate()

	var spawn_pos: Vector3 = self.global_position + Util.randCircularOffsetRange(1.5, 2.5) + Vector3(0, 2.0, 0)

	get_tree().root.add_child(crystal)
	crystal.global_position = spawn_pos
	crystal.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), randf_range(0, TAU))
	crystal.reset_physics_interpolation()


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


func choose_new_goal() -> void:
	var nav_map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		has_goal = false
		return

	var r := randf_range(min_goal_distance, max_goal_distance)
	var angle := randf_range(path_dir_mean - path_dir_rand_deviation, path_dir_mean + path_dir_rand_deviation)
	var random_goal_pos := global_position + Util.vec3FromRadiusAngle(r, angle)

	# Set the new goal for navigation
	var goal_pos: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, random_goal_pos)

	DebugShapes3D.spawn_mesh(goal_pos + Vector3(0, 0.5, 0), DebugShapes3D.sphere_mesh(0.15, DebugShapes3D.material(Color.BLUE, true)), Util.get_scene_root())

	goal_pos = find_free_position_near(goal_pos)
	current_goal = NavigationServer3D.map_get_closest_point(nav_map, goal_pos)
	if current_goal == Vector3.ZERO:
		has_goal = false
		return

	path_finding_agent.set_target(current_goal)
	print("Caravan has new goal : ", current_goal)
	has_goal = true


# New circle must contain original center or this might clip through walls entierely
var check_radius: float = 4.0
var check_height: float = 0.25
var check_height_offset: Vector3 = Vector3(0, 0.5, 0)

var max_search_radius: float = 4.0
var search_step: float = 2.0

func _is_area_free(pos: Vector3) -> bool:
	var shape := CylinderShape3D.new()
	shape.radius = check_radius
	shape.height = check_height
	var query := PhysicsShapeQueryParameters3D.new()
	query.set_shape(shape)
	query.transform = Transform3D(Basis.IDENTITY, pos + check_height_offset)
	query.collision_mask = Layers.mask([Layers.L.TERRAIN, Layers.L.STATIC_GEOM])
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := get_world_3d().direct_space_state.intersect_shape(query, 1)
	var free := result.size() == 0

	var sp_green := DebugShapes3D.sphere_mesh(check_radius, DebugShapes3D.material(Color.GREEN, false))
	var sp_red := DebugShapes3D.sphere_mesh(check_radius, DebugShapes3D.material(Color.RED, false))
	sp_green.height = 0.15
	sp_red.height = 0.15

	if free:
		DebugShapes3D.spawn_mesh(pos + check_height_offset * 2.0, sp_green, Util.get_scene_root())
	else:
		DebugShapes3D.spawn_mesh(pos + check_height_offset, sp_red, Util.get_scene_root())

	return free


func find_free_position_near(origin: Vector3) -> Vector3:
	if _is_area_free(origin):
		return origin

	# Expand outward in a spiral/sphere pattern
	var i := 0
	for r in range(search_step, max_search_radius, search_step):
		for angle in range(0.0, TAU, deg_to_rad(60)):
			i += 1
			var new_pos := origin + Util.vec3FromRadiusAngle(r, angle)
			if _is_area_free(new_pos):
				return new_pos
				

	return origin # fallback: no free space found

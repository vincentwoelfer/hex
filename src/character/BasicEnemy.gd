class_name BasicEnemy
extends CharacterBody3D

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision
@onready var mesh: MeshInstance3D = $Mesh
var mesh_material: StandardMaterial3D

var speed: float = 2.5

var target: Node3D = null
var target_reached_dist: float

# Goal choosing logic
var goal_choosing_timer: Timer
var goal_choosing_interval: float = 0.75

# Exploding
var is_exploding := false
var explosion_radius: float = 1.8

const explosion_duration := 0.85
const explosion_wave_count := 3
const explosion_max_size := 2.0
var explosion_target_color := Colors.mod_sat_val_hue(Color.RED, 0.1, 1.0)


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
	if is_exploding:
		# Execute move_and_slide() to enable gravity/being pushed
		move_and_slide()
		return

	# returns ZERO if no path/goal
	var movement: Vector3 = path_finding_agent.get_direction() * speed

	if movement == Vector3.ZERO:
		self.goal_choosing_timer.start()
		_choose_new_goal()
	else:
		# Move, Dont touch y to not mess with gravity
		velocity.x = movement.x
		velocity.z = movement.z

	# Apply gravity
	if not is_on_floor():
		velocity.y += HexConst.GRAVITY * delta

	# Reached target - custom larger radius to enable "explosion" later on
	if target != null and Util.get_dist_planar(global_position, target.global_position) <= target_reached_dist:
		queue_free()
		return

	_check_player_near_for_explosion()

	move_and_slide()


func _check_player_near_for_explosion() -> void:
	if is_exploding:
		return

	for player: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS):
		if global_position.distance_to(player.global_position) <= explosion_radius:
			_start_exploding()


func _get_possible_goals() -> Array[Node3D]:
	var possible_goals: Array[Node3D] = []

	# Add caravan by default (TODO maybe check if caravan has crystals left?)
	possible_goals.append(GameStateManager.caravan)
	
	# Add players
	for player: PlayerController in get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS):
		possible_goals.append(player)

	# Add crystals
	for crystal: Crystal in get_tree().get_nodes_in_group(HexConst.GROUP_CRYSTALS):
		# Carried by player is already in goal selection through player itself
		# Carried by caravan is already in goal selection through caravan itself
		if crystal.state in [Crystal.State.ON_GROUND]:
			possible_goals.append(crystal)

	return possible_goals


func _choose_new_goal() -> void:
	target = null

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


# Exploding
func _start_exploding() -> void:
	if is_exploding:
		return

	is_exploding = true
	goal_choosing_timer.stop()

	self.velocity = Vector3.ZERO

	add_child(Util.timer(self.explosion_duration, _on_explodion_finish, true))
	_explosion_effect()

	var effect_height := 0.5
	var effect := DebugVis3D.cylinder(explosion_radius, effect_height, DebugVis3D.mat(Color(Color.RED.lightened(0.25), 0.15), false))
	DebugVis3D.spawn(Vector3.UP * 0.5 * effect_height, effect, self)


func _on_explodion_finish() -> void:
	self.queue_free()
	# TODO drop crystal
	# TODO add explosion effect (external particle, not self-growth)


func _explosion_effect() -> void:
	var tween_trans_type := Tween.TRANS_ELASTIC
	var tween_ease_type := Tween.EASE_IN_OUT

	# Add color tween
	mesh_material = mesh.get_active_material(0) as StandardMaterial3D
	var original_color := mesh_material.albedo_color
	var color_tween := create_tween()
	color_tween.set_trans(tween_trans_type)
	color_tween.set_ease(tween_ease_type)
	color_tween.tween_method(_change_material_color, original_color, explosion_target_color, explosion_duration)

	# Add scale tween
	var size_tween := create_tween()
	size_tween.set_trans(tween_trans_type)
	size_tween.set_ease(tween_ease_type)

	var time_per_wave := explosion_duration / float(explosion_wave_count)

	for i in range(explosion_wave_count):
		# i = 0,1,2 for 3 waves
		# t = 0.33 ,0.66, 1.0 for 3 waves
		var t := float(i + 1) / float(explosion_wave_count)
		var scale_value := lerpf(1.0, explosion_max_size, t)

		# These tween effects are executed after one another, we queue them all here
		size_tween.tween_property(mesh, "scale", Vector3.ONE * scale_value, time_per_wave)


func _change_material_color(c: Color) -> void:
	if not mesh_material:
		return

	# If not yet duplicated, do it now to avoid modifying shared material
	if mesh_material.resource_local_to_scene == false:
		mesh_material = mesh_material.duplicate()
		mesh_material.resource_local_to_scene = true
		mesh.set_surface_override_material(0, mesh_material)
	
	mesh_material.albedo_color = c

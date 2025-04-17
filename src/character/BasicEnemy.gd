class_name BasicEnemy
extends HexPhysicsCharacterBody3D

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision
@onready var pick_up_manager: PickUpManager = $RotationAxis/PickUpManager
@onready var mesh: MeshInstance3D = $RotationAxis/Mesh
var mesh_material: StandardMaterial3D

var speed: float = 3.6

var target: Node3D = null

# Goal choosing logic
var goal_choosing_timer: Timer
var goal_choosing_interval: float = 0.5

# Exploding
var is_exploding := false
var explosion_radius: float = 2.0
var explosion_force: float = 200.0

# Explosion visual
var explosion_duration := 0.5
var explosion_visual_wave_count := 3
var explosion_visual_max_size_scale := 2.0
var explosion_viusal_target_color := Colors.mod_sat_val_hue(Color.RED, 0.1, 1.0)

# stuck check
var stuck_check_last_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	self.mass = 10.0
	add_to_group(HexConst.GROUP_ENEMIES)

	path_finding_agent.init(Color.RED, collision.shape, DebugSettings.show_path_basic_enemy)

	self.floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)

	self.pick_up_manager.set_pickup_radius(1.3)

	# Set initial goal
	if not _choose_new_goal():
		print("BasicEnemy: No goal found, deleting!")
		queue_free()
		return
		
	# This is for choosing a new goal, replanning the already found path to same goal happens periodically inside path_finding_agent
	goal_choosing_timer = Util.timer(goal_choosing_interval, _choose_new_goal)
	add_child(goal_choosing_timer)

	add_child(Util.timer(1.5, _periodic_stuck_check))


func _physics_process(delta: float) -> void:
	if is_exploding:
		# Execute move_and_slide() to enable gravity/being pushed
		# move_and_slide()
		return

	# Replan if no path
	if not path_finding_agent.get_has_path():
		self.goal_choosing_timer.start()
		if not _choose_new_goal():
			print("BasicEnemy: No goal found, exploding!")
			_start_exploding()

	_check_crystal_pickup()

	if not pick_up_manager.is_carrying():
		_check_player_near_for_explosion()

	# Movement
	var m: CharMovement = CharMovement.new()
	m.input_dir = Util.to_vec2(path_finding_agent.get_direction())
	m.input_speed = _get_speed()
	
	# Fake values, instant accel/decel
	m.accel_ramp_time = 0.0
	m.decel_ramp_time = 0.0
	m.max_possible_speed = self.speed # use max speed here

	m.input_control_factor = 1.0
	m.vertical_override = 0.0

	self._custom_physics_process(delta, m)


func _check_player_near_for_explosion() -> void:
	if is_exploding:
		return

	for player: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS):
		if global_position.distance_to(player.global_position) <= explosion_radius:
			_start_exploding()


func _check_crystal_pickup() -> void:
	if is_exploding:
		return

	if not pick_up_manager.is_carrying() and pick_up_manager.has_object_to_pick_up():
		pick_up_manager.perform_pickup_or_drop_action()


func _get_possible_goals() -> Array[Node3D]:
	var possible_goals: Array[Node3D] = []

	# MODE WITHD CRYSTAL -> run away
	if pick_up_manager.is_carrying():
		for portal: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_ESCAPE_PORTALS):
			possible_goals.append(portal)

	# MODE NO CRYSTAL -> seek crystal/players
	else:
		# Add caravan
		if GameStateManager.caravan.caravan_depot.has_objects():
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


func _choose_new_goal() -> bool:
	target = null

	var nav_map: RID = Util.get_map()
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return false

	var possible_goals := _get_possible_goals()
	if possible_goals.size() == 0:
		return false

	# Choose closest goal - TODO add weighting logic in future
	var min_dist := INF
	var best_goal: Node3D = null
	for goal: Node3D in possible_goals:
		if goal == null or goal.is_queued_for_deletion():
			continue

		var path := NavigationServer3D.map_get_path(nav_map, global_position, goal.global_position, false)
		var distance := Util.get_total_path_length(path)
		if distance < min_dist:
			min_dist = distance
			best_goal = goal

	if best_goal == null:
		return false

	# Plan optimized path to choosen goal
	target = best_goal
	path_finding_agent.set_track_target(target)
	return true


# Exploding
func _start_exploding() -> void:
	if is_exploding:
		return

	is_exploding = true
	goal_choosing_timer.stop()

	self.velocity = Vector3.ZERO

	add_child(Util.timer(self.explosion_duration, _on_explodion_finish, true))
	_explosion_visual_self_effect()

	# Red indicator, gets deleted because its a child
	var effect_height := 0.5
	var effect := DebugVis3D.cylinder(explosion_radius, effect_height, DebugVis3D.mat(Color(Color.RED.lightened(0.25), 0.15), false))
	DebugVis3D.spawn(Vector3.UP * 0.5 * effect_height, effect, self)


func _on_explodion_finish() -> void:
	# define area
	var area := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = explosion_radius
	shape.height = explosion_radius
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.set_collision_mask_value(Layers.L.PLAYER_CHARACTERS, true)
	area.set_collision_mask_value(Layers.L.PICKABLE_OBJECTS, true)
	area.add_child(collision_shape)
	add_child(area)

	# Required for the newly added area to work
	await get_tree().physics_frame
	await get_tree().physics_frame

	# APPLY
	var bodies := area.get_overlapping_bodies()
	for body in bodies:
		if body == self:
			continue
		if body is RigidBody3D:
			var rigid_body: RigidBody3D = body
			var impulse := Util.calculate_explosion_impulse(global_position, body.global_position, explosion_force, explosion_radius)
			rigid_body.apply_central_impulse(impulse)

		elif body is HexPhysicsCharacterBody3D:
			var hex_body: HexPhysicsCharacterBody3D = body
			var impulse := Util.calculate_explosion_impulse(global_position, body.global_position, explosion_force, explosion_radius)
			# TODO for now add additional force to the character to counteract the bug in its movement code
			impulse *= 2.0
			hex_body.apply_external_impulse(impulse)


	pick_up_manager.drop_object()
	
	# TODO add explosion effect (external particle, not self-growth) ?
	self.queue_free()


func _explosion_visual_self_effect() -> void:
	var tween_trans_type := Tween.TRANS_ELASTIC
	var tween_ease_type := Tween.EASE_IN_OUT

	# Add color tween
	mesh_material = mesh.get_active_material(0) as StandardMaterial3D
	var original_color := mesh_material.albedo_color
	var color_tween := create_tween()
	color_tween.set_trans(tween_trans_type)
	color_tween.set_ease(tween_ease_type)
	color_tween.tween_method(_change_material_color, original_color, explosion_viusal_target_color, explosion_duration)

	# Add scale tween
	var size_tween := create_tween()
	size_tween.set_trans(tween_trans_type)
	size_tween.set_ease(tween_ease_type)

	var time_per_wave := explosion_duration / float(explosion_visual_wave_count)

	for i in range(explosion_visual_wave_count):
		# i = 0,1,2 for 3 waves
		# t = 0.33 ,0.66, 1.0 for 3 waves
		var t := float(i + 1) / float(explosion_visual_wave_count)
		var scale_value := lerpf(1.0, explosion_visual_max_size_scale, t)

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


func _periodic_stuck_check() -> void:
	if global_position.distance_to(stuck_check_last_pos) < 0.1:
		print("BasicEnemy: Stuck, exploding!")
		_start_exploding()
		return
	stuck_check_last_pos = global_position


func _get_speed() -> float:
	if pick_up_manager.is_carrying():
		return speed * 0.85
	else:
		return speed

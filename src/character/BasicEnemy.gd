class_name BasicEnemy
extends HexPhysicsCharacterBody3D

# Scene references
@onready var path_finding_agent: PathFindingAgent = $PathFindingAgent
@onready var collision: CollisionShape3D = $Collision
@onready var pick_up_manager: PickUpManager = $RotationAxis/PickUpManager
@onready var mesh: MeshInstance3D = $RotationAxis/Mesh
var mesh_material: StandardMaterial3D

var speed_normal: float = 3.5
var speed_carrying: float = 2.5

var target: Node3D = null

# Goal choosing logic
var goal_choosing_timer: Timer
var goal_choosing_interval: float = 0.5

# Exploding
var is_exploding := false
var explosion_radius: float = 2.2
var explosion_force: float = 200.0

var explosion_cooldown: float = 0.5
var explosion_cooldown_timestamp: float = 0.0

# Explosion visual
var explosion_duration := 0.5
var explosion_visual_wave_count := 3
var explosion_visual_max_size_scale := 2.1
var explosion_viusal_target_color := Color.RED.lightened(0.5)

# stuck check
var stuck_check_last_pos: Vector3 = Vector3.ZERO

# testing
var ui: BasicEnemyUI
var hp := 100.0


func _ready() -> void:
	path_finding_agent.init(Color.RED, collision.shape, DebugSettings.show_path_basic_enemy)

	floor_max_angle = deg_to_rad(HexConst.NAV_AGENT_MAX_SLOPE_BASIS_DEG + HexConst.NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG)
	

	# Set initial goal
	if not _choose_new_goal():
		print("BasicEnemy: No goal found, deleting!")
		queue_free()
		return
		
	# This is for choosing a new goal, replanning the already found path to same goal happens periodically inside path_finding_agent
	goal_choosing_timer = Util.timer(goal_choosing_interval, _choose_new_goal)
	add_child(goal_choosing_timer)

	add_child(Util.timer(3.0, _periodic_stuck_check))

	###########################
	ui = UIManager.attach_ui_scene(self, ResLoader.BASIC_ENEMY_UI_SCENE)
	ui.set_health(100, 100)


func _physics_process(delta: float) -> void:
	hp -= delta * 15.5
	ui.set_health(hp, 100)

	if is_exploding:
		# Execute move_and_slide() to enable gravity/being pushed
		# move_and_slide()
		return

	# Replan if no path
	if not path_finding_agent.get_has_path():
		self.goal_choosing_timer.start()
		if not _choose_new_goal():
			print("BasicEnemy: No goal found, exploding!")
			_exposion_skill_start()

	_check_crystal_pickup()

	if not pick_up_manager.is_carrying():
		_check_player_near_for_explosion()

	# Movement
	var m: HexCharMovementParams = HexCharMovementParams.new()
	m.input_dir = Util.to_vec2(path_finding_agent.get_direction())
	m.input_speed = _get_speed()
	m.max_possible_speed = self.speed_normal # use normal/max speed here, not carrying speed
	self._custom_physics_process(delta, m)


func _check_player_near_for_explosion() -> void:
	if is_exploding:
		return

	for player: Node3D in get_tree().get_nodes_in_group(HexConst.GROUP_PLAYERS):
		if global_position.distance_to(player.global_position) <= explosion_radius:
			_exposion_skill_start()


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
func _exposion_skill_start() -> void:
	if is_exploding or not Util.has_time_passed(explosion_cooldown_timestamp, explosion_cooldown):
		return

	is_exploding = true
	explosion_cooldown_timestamp = Util.now() + explosion_duration
	goal_choosing_timer.stop()
	self.velocity = Vector3.ZERO

	Util.timer_one_shot(self.explosion_duration, _on_explodion_finish)
	VFXAoeRangeIndicator.spawn_at_parent(self, explosion_radius, self.explosion_duration)
	_explosion_visual_self_effect_start()


func _on_explodion_finish() -> void:
	# define area
	var area := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = explosion_radius
	shape.height = explosion_radius
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.set_collision_mask_value(Layers.PHY.PLAYER_CHARACTERS, true)
	area.set_collision_mask_value(Layers.PHY.PICKABLE_OBJECTS, true)
	area.add_child(collision_shape)
	add_child(area)

	VFXFlameExplosionRadial.spawn_global_pos(global_position + Vector3.UP * 0.8, VFXFlameExplosionRadial.ColorGradient.RED)

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

	# Remove area
	area.queue_free()

	pick_up_manager.drop_object()
	
	# TODO add explosion effect (external particle, not self-growth) ?

	# Reset back to normal state
	is_exploding = false
	goal_choosing_timer.start()


func _explosion_visual_self_effect_start() -> void:
	var tween_trans_type := Tween.TRANS_ELASTIC
	var tween_ease_type := Tween.EASE_IN_OUT

	var color_tween := create_tween()
	var scale_tween := create_tween().set_trans(tween_trans_type).set_ease(tween_ease_type)

	var reset_time := 0.05

	# Add color tween (only one)
	mesh_material = mesh.get_active_material(0) as StandardMaterial3D
	var original_color := mesh_material.albedo_color
	_change_material_color(original_color) # Trigger once to duplicate
	color_tween.tween_method(_change_material_color, original_color, explosion_viusal_target_color, explosion_duration)
	color_tween.tween_method(_change_material_color, explosion_viusal_target_color, original_color, reset_time)

	# Add scale tween (multiple waves)
	var time_per_wave := explosion_duration / float(explosion_visual_wave_count)

	for i in range(explosion_visual_wave_count):
		# i = 0,1,2 for 3 waves
		# t = 0.33 ,0.66, 1.0 for 3 waves
		var t := float(i + 1) / float(explosion_visual_wave_count)
		var scale_value := lerpf(1.0, explosion_visual_max_size_scale, t)

		# These tween effects are executed after one another, we queue them all here
		scale_tween.tween_property(mesh, "scale", Vector3.ONE * scale_value, time_per_wave)
	scale_tween.tween_property(mesh, "scale", Vector3.ONE, reset_time)


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
		_exposion_skill_start()
		return
	stuck_check_last_pos = global_position


func _get_speed() -> float:
	if pick_up_manager.is_carrying():
		return speed_carrying
	else:
		return speed_normal

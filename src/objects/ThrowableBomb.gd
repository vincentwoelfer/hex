extends RigidBody3D
class_name ThrowableBomb

@onready var collision: CollisionShape3D = $Collision

var bounces: int = 0
var max_bounces: int = 2

var min_time_between_bounces_sec: float = 0.12
var last_bounce_time_counter: float = min_time_between_bounces_sec

var explosion_radius: float = 3.8
var explosion_force: float = 170.0

var exploded := false


func _ready() -> void:
    # Set the physics material
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.8
	mat.friction = 0.5
	mat.rough = true
	self.physics_material_override = mat

	self.contact_monitor = true
	self.max_contacts_reported = 1 # only one contact per bounce

	# Collision config
	# self.angular_damp = 1.5
	# self.linear_damp = 1.5

func _physics_process(delta: float) -> void:
	last_bounce_time_counter -= delta

	# If contact
	if last_bounce_time_counter <= 0.0 and get_contact_count() > 0:
		last_bounce_time_counter = min_time_between_bounces_sec
		bounces += 1

	if bounces >= max_bounces:
		explode()


func explode() -> void:
	# Only explode once
	if exploded:
		return
	exploded = true

	var effect_height := explosion_radius * 0.5
	var effect := DebugVis3D.cylinder(explosion_radius, effect_height, DebugVis3D.mat(Color(Color.RED.lightened(0.25), 0.15), false))
	var effect_node := DebugVis3D.spawn(global_position + Vector3.UP * 0.5 * effect_height, effect)
	Util.delete_after(0.35, effect_node)

	# define area
	var area := Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = explosion_radius
	shape.height = explosion_radius
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.set_collision_mask_value(Layers.L.PLAYER_CHARACTERS, true)
	area.set_collision_mask_value(Layers.L.ENEMY_CHARACTERS, true)
	area.set_collision_mask_value(Layers.L.PICKABLE_OBJECTS, true)
	area.add_child(collision_shape)

	Util.spawn(area, global_position)
	
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

			# Less impulse for other bombs
			if body is ThrowableBomb:
				impulse *= 0.5
			rigid_body.apply_central_impulse(impulse)
			continue

		elif body is HexPhysicsCharacterBody3D:
			var hex_body: HexPhysicsCharacterBody3D = body

			# IMPULSE to players / Caravan
			if hex_body.is_in_group(HexConst.GROUP_PLAYERS) or (hex_body == GameStateManager.caravan):
				var impulse := Util.calculate_explosion_impulse(global_position, body.global_position, explosion_force, explosion_radius)
				# TODO for now add additional force to the character to counteract the bug in its movement code
				impulse *= 2.0
				hex_body.apply_external_impulse(impulse)
				continue

			# Kill Enemies
			elif hex_body.is_in_group(HexConst.GROUP_ENEMIES):
				var enemy := hex_body as BasicEnemy
				enemy.pick_up_manager.drop_object()
				enemy.queue_free()
				continue

			
	# TODO add explosion effect (external particle, not self-growth) ?
	await Util.await_time(0.15)
	area.queue_free()
	self.queue_free()

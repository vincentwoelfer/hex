extends RigidBody3D
class_name ThrowableBomb

@onready var collision: CollisionShape3D = $Collision

var bounces: int = 0
var max_bounces: int = 2

var min_time_between_bounces_sec: float = 0.12
var last_bounce_time_counter: float = min_time_between_bounces_sec

var explosion_radius: float = 3.75
var explosion_force: float = 170.0

var direct_hit_radius: float = 2.0

# gravity scale per bounce, used to reduce the gravity effect on the bomb
var gravity_scale_per_bounce: Array[float] = [3.0, 2.5]

var exploded := false

var area: Area3D


func _ready() -> void:
	# Set the physics material
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.8
	mat.friction = 0.5
	mat.rough = true
	self.physics_material_override = mat

	self.contact_monitor = true
	self.max_contacts_reported = 1 # only one contact per bounce, this is only for performance, not logic

	# Collision config
	# self.angular_damp = 1.5
	# self.linear_damp = 1.5

	# Gravity scale
	_update_gravity_scale()

	# define area
	area = Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = explosion_radius
	shape.height = explosion_radius
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.set_collision_mask_value(Layers.PHY.PLAYER_CHARACTERS, true)
	area.set_collision_mask_value(Layers.PHY.ENEMY_CHARACTERS, true)
	area.set_collision_mask_value(Layers.PHY.PICKABLE_OBJECTS, true)
	area.add_child(collision_shape)
	add_child(area)
	area.top_level = true

func _update_gravity_scale() -> void:
	# Update gravity scale based on bounces
	if bounces < gravity_scale_per_bounce.size():
		self.gravity_scale = gravity_scale_per_bounce[bounces]
	else:
		self.gravity_scale = 1.0  # Default gravity scale if exceeded

func _physics_process(delta: float) -> void:
	# Update area position
	area.global_position = global_position

	# Bounce logic
	last_bounce_time_counter -= delta

	# If contact
	var should_explode := false
	if last_bounce_time_counter <= 0.0 and get_contact_count() > 0:
		last_bounce_time_counter = min_time_between_bounces_sec
		bounces += 1
		_update_gravity_scale()

		# If enemy near, explode directly
		if check_direct_hit():
			should_explode = true

	if bounces >= max_bounces:
		should_explode = true

	if should_explode:
		explode()


func explode() -> void:
	# Only explode once
	if exploded:
		return
	exploded = true

	VFXBombExplosion.spawn_global_pos(global_position)
	VFXAoeRangeIndicator.spawn_global_pos(global_position, explosion_radius, 0.3)

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


	self.queue_free()


func check_direct_hit() -> bool:
	var mask := Layers.mask([Layers.PHY.ENEMY_CHARACTERS])
	for body in area.get_overlapping_bodies():
		if body is CollisionObject3D:
			if ((body as CollisionObject3D).collision_layer & mask) != 0:
				if global_position.distance_to(body.global_position) <= direct_hit_radius:
					return true
	return false

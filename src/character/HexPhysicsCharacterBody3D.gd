extends CharacterBody3D
class_name HexPhysicsCharacterBody3D
# A component that enables physics-based force interactions.

########################################################################
# Configurable Properties
########################################################################
# ## Velocity magnitude above which an impulse is considered strong
# @export var strong_impulse_threshold: float = 10.0

# ## Fraction of input retained when a strong impulse hits
# @export var strong_impulse_control_factor: float = 0.5

# ## Multiplier for force applied to others when colliding
# @export var push_force_factor: float = 10.0

# ## Whether to apply forces to other characters with this component
# @export var allow_char_push: bool = true

# var blend_mode_mix := true

########################################################################
# CONFIGURABLE PROPERTIES
########################################################################
## Mass of this character for physics calculations
var mass: float = 50.0
var external_impulse_damp_lerp_speed: float = 8.0

var rigid_body_impulse_factor: float = 2.0
var character_body_force_factor: float = 2.0

########################################################################
# Internal state
########################################################################

# IMPULSES (instantaneous forces)
var external_impulse: Vector3 = Vector3.ZERO

# FORCES (continuous forces)
var external_force_this_frame: Vector3 = Vector3.ZERO

var velocity_before_move: Vector3


########################################################################
# Character Movement Input
########################################################################
class CharMovement:
	var input_dir: Vector2
	var input_speed: float

	# Time to max speed / stand-still
	var accel_ramp_time: float
	var decel_ramp_time: float
	var max_possible_speed: float

	# For jumping/slamming
	var vertical_override: float = 0.0

	# For e.g. airborne
	var input_control_factor: float = 1.0

	func get_accel() -> float:
		return input_speed / max(accel_ramp_time, 0.001)

	func get_decel() -> float:
		# In theory this is max_possible_speed / decel_ramp_time
		return max_possible_speed / max(decel_ramp_time, 0.001)


########################################################################
# Methods
########################################################################
func _compute_self_controlled_planar_velocity_change(delta: float, m: CharMovement) -> Vector3:
	if m.input_dir.length() == 0.0:
		m.input_speed = 0.0

	var curr_vel := Util.to_vec2(self.velocity)
	var current_speed: float = curr_vel.length()

	# Compute target velocity in the XZ plane
	var target_vel: Vector2 = m.input_dir * m.input_speed

	# Compute velocity difference
	var vel_delta: Vector2 = target_vel - curr_vel

	# Determine if acceleration or deceleration
	var accel_decel_value: float = m.get_accel() if vel_delta.dot(m.input_dir) > 0.0 else m.get_decel()

	# Apply acceleration/deceleration
	var vel_change: Vector2 = vel_delta.normalized() * accel_decel_value * delta

	# Prevent overshooting (this also works for deceleration towards 0)
	if vel_change.length() > vel_delta.length():
		vel_change = vel_delta

	# Factor in control factor
	if m.input_control_factor > 0.0:
		vel_change *= m.input_control_factor

	return Util.to_vec3(vel_change)


func _update_vertical_velocity(delta: float, m: CharMovement) -> void:
	# Apply gravity
	if not is_on_floor():
		self.velocity.y += self._get_current_gravity() * delta
	else:
		# Reset vertical velocity when on the ground
		self.velocity.y = 0.0

	# Apply vertical override
	if m.vertical_override != 0.0:
		self.velocity.y = m.vertical_override


func _compute_vel_change_through_external_forces(self_controlled_vel_change: Vector3) -> Vector3:
	var external_force_dir := external_force_this_frame.normalized()
	# Remove component of self_controlled_vel_change against the direction of the external force
	var intended_velocity_against_force: Vector3 = external_force_dir * self_controlled_vel_change.dot(external_force_dir)
	# Apply external force and remove any own velocity going against that external force
	var resulting_vel_change := self_controlled_vel_change - intended_velocity_against_force + external_force_this_frame

	# Reset external force
	external_force_this_frame = Vector3.ZERO

	return resulting_vel_change

########################################################################
# Physics TICK
########################################################################
func _custom_physics_process(delta: float, m: CharMovement) -> void:
	# Compute new self-controlled velocity change based on desired input
	var self_controlled_vel_change := _compute_self_controlled_planar_velocity_change(delta, m)

	# Apply one-frame external force
	var vel_change := _compute_vel_change_through_external_forces(self_controlled_vel_change)

	# Apply velocity change & impulses
	velocity += vel_change + external_impulse
	external_impulse = Vector3.ZERO

	self._update_vertical_velocity(delta, m)

	velocity_before_move = velocity
	move_and_slide()

	_handle_collisions(delta)

	_dampen_external_impulse(delta)

	if self is PlayerController and external_impulse.length() > 0.001:
		print("Curr player external impulse strenght: ", external_impulse.length())


# func _compute_impulse_velocity_change(delta: float) -> Vector3:
# 	# Compute impulse velocity change
# 	var impulse_vel_change: Vector3 = external_impulse.normalized() * external_impulse.length()
# 	# Apply impulse velocity change
# 	velocity += impulse_vel_change

# 	# Reset external impulse
# 	external_impulse = Vector3.ZERO

# 	return impulse_vel_change


########################################################################
# Collision Handling
########################################################################
func _handle_collisions(delta: float) -> void:
	# After moving, handle collisions and apply forces to others
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(i)
		var collider := collision.get_collider()
		var push_normal := -collision.get_normal()
		var coll_pos := collision.get_position()

		push_normal.y = 0.0
		push_normal = push_normal.normalized()

		# If collided with a RigidBody3D, apply an impulse to it
		if collider is RigidBody3D:
			var rigid_body: RigidBody3D = collider

			# Calculate impulse based on this body's velocity and mass
			var contact_speed: float = velocity_before_move.dot(push_normal)
			if contact_speed <= 0.0:
				continue

			# Impulse vector directed away from this character (into the collider)
			var impulse_vec: Vector3 = push_normal * (contact_speed * rigid_body_impulse_factor)
			# var push_position := coll_pos - rigid_body.global_position
			var push_position := coll_pos

			# Apply impulse to the rigid body
			rigid_body.apply_central_impulse(impulse_vec)
			print("RigidBody3D normal:           ", push_normal)
			print("RigidBody3D speed:            ", contact_speed)
			print("RigidBody3D impulse strenght: ", impulse_vec.length())
			continue

		# If collided with another CharacterBody3D that has this component, apply forces to both
		if collider is HexPhysicsCharacterBody3D:
			var other_char: HexPhysicsCharacterBody3D = collider

			# For now only heavy characters can push lighter ones
			if self.mass > other_char.mass:
				# Calculate contact speed as velocity against the collision normal
				var contact_speed: float = velocity_before_move.dot(push_normal)
				if contact_speed <= 0.0:
					continue

				# Impulse vector directed away from this character (into the collider)
				var force: Vector3 = push_normal * contact_speed * character_body_force_factor

				# Apply the push
				other_char.apply_external_force(force)
			continue


## Dampen external velocity over time (simulate friction or regaining control)
func _dampen_external_impulse(delta: float) -> void:
	external_impulse = Util.lerp_towards_vec3(external_impulse, Vector3.ZERO, external_impulse_damp_lerp_speed, delta)


## Add a continuous force to be applied this frame
func apply_external_force(force: Vector3) -> void:
	force.y = 0.0
	external_force_this_frame += force


## Apply an instantaneous impulse (knockback force) to this character.
## This adds to the external velocity, factoring in this character's mass.
func apply_external_impulse(impulse: Vector3) -> void:
	impulse.y = 0.0
	external_impulse += impulse
	# external_impulse += impulse / mass


func _get_current_gravity() -> float:
	if self.has_method("_get_custom_gravity"):
		return self.call("_get_custom_gravity")
	else:
		return -self.get_gravity().length()

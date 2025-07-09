class_name GadgetBomb
extends AbstractGadget

var flame_thrower_instance: VFXFlameThrower = null


########## Override ##########
func skill_primary() -> void:
	flame_thrower_skill()

func skill_secondary() -> void:
	throw_bomb()
##############################

func flame_thrower_skill() -> void:
	if flame_thrower_instance != null:
		flame_thrower_instance.queue_free()
		flame_thrower_instance = null

	else:
		flame_thrower_instance = VFXFlameThrower.spawn_at_parent(self)


func throw_bomb() -> void:
	Input.start_joy_vibration(self.input.device_id, 0.0, 0.3, 0.1)

	var bomb: ThrowableBomb = ResLoader.THROWABLE_BOMB_SCENE.instantiate()
	bomb.add_collision_exception_with(self)

	var hold_offset: Vector3 = Vector3.FORWARD * 0.5 + Vector3.UP * 0.8
	var throw_origin := global_transform.origin + self.basis * hold_offset

	Util.spawn(bomb, throw_origin)

	# Apply torque (rotation)
	var torque_strength: float = 1.5
	var torque := Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)) * torque_strength
	bomb.apply_torque_impulse(torque)

	# Apply force
	var throw_dir: Vector3 = (Vector3.FORWARD * 0.65 + Vector3.UP * 0.55).normalized()
	var throw_force: float = 75.0
	var force: Vector3 = self.basis * throw_dir * throw_force
	bomb.apply_central_impulse(force)

	# Hacky - avoid bombs to collide with the player
	await Util.await_time(0.25)
	if bomb != null:
		bomb.remove_collision_exception_with(self.get_parent())

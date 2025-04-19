extends Node3D
class_name CaravanDepot

@onready var hex_character: HexPhysicsCharacterBody3D = $'../..'

var area: Area3D

# Crystal data
var hold_basis_offset: Vector3 = Vector3.UP * 0.7
var crystal_capsule_shape: CapsuleShape3D

var carried_objects: Array[Crystal] = []

const num_start_crystals: int = 10

func _ready() -> void:
	# React to huge impulses
	hex_character.connect("Signal_huge_impulse_received", _drop_object_to_ground)

	# Fetch crystal dimensions
	var crystal_node: Node3D = ResLoader.CRYSTAL_SCENE.instantiate()
	crystal_capsule_shape = (crystal_node.get_node("Collision") as CollisionShape3D).shape as CapsuleShape3D
	crystal_node.queue_free()

	# Add initial crystals
	_fill_storage(num_start_crystals)

	# FOR TESTING
	await Util.await_time(1.0)
	_drop_object_to_ground()


func has_objects() -> bool:
	return not carried_objects.is_empty()


func get_object_position_in_storage(index: int) -> Vector3:
	var stack_index := floori(index / 2.0)

	var storage_base := global_transform.origin + global_transform.basis * hold_basis_offset
	var radius := crystal_capsule_shape.radius

	var vertical_step := Vector3(0.0, radius * 2.0 + 0.05, 0.0)
	var horizontal_offset := Vector3(radius + 0.025, 0.0, 0.0)
	var forward_offset_random := Vector3(randf_range(-0.05, 0.05), 0.0, randf_range(-0.1, 0.1))

	
	var is_left: bool = index % 2 == 0
	var side_offset := horizontal_offset * (-1.0 if is_left else 1.0)

	var final_pos := storage_base + global_transform.basis * (side_offset + forward_offset_random + vertical_step * stack_index)
	return final_pos


func get_object_rotation_in_storage(index: int) -> Basis:
	var b: Basis = Basis.IDENTITY
	# Randomize rotation TODO fix/improve
	b *= Basis(Vector3.RIGHT, deg_to_rad(randf_range(80.0, 100.0)))
	b *= Basis(Vector3.UP, deg_to_rad(randf_range(0.0, 360.0)))
	b *= Basis(Vector3.FORWARD, deg_to_rad(randf_range(0.0, 15.0)))
	return b


func _fill_storage(number: int) -> void:
	for i in range(number):
		var crystal: Crystal = ResLoader.CRYSTAL_SCENE.instantiate()
		add_to_storage(crystal)


func add_to_storage(crystal: Crystal) -> void:
	if carried_objects.has(crystal):
		push_error("Crystal already in storage")
		return

	# Freeze object
	crystal.freeze = true
	crystal.linear_velocity = Vector3.ZERO
	crystal.angular_velocity = Vector3.ZERO

	# Set collision mask
	hex_character.add_collision_exception_with(crystal)

	# Re-Parent
	var original_parent: Node = crystal.get_parent()
	if original_parent:
		original_parent.remove_child(crystal)
	add_child(crystal)

	# Add to storage
	carried_objects.append(crystal)
	var index := carried_objects.size() - 1
	crystal.state = Crystal.State.ON_CARAVAN

	# Set position & orientation
	crystal.global_transform.origin = get_object_position_in_storage(index)
	crystal.global_transform.basis = get_object_rotation_in_storage(index)


# Removes from storage, DOES NOT ADD BACK TO TREE
func remove_from_storage() -> Crystal:
	if carried_objects.is_empty():
		return null

	# Remove from storage
	var crystal: Crystal = carried_objects.pop_back()
	var index: int = carried_objects.size()
	 # TODO ???
	crystal.state = Crystal.State.ON_GROUND

	# Re-parent
	self.remove_child(crystal)

	# Set position TODO ???
	# crystal.global_transform.origin = get_object_position_in_storage(index)
	# crystal.global_transform.basis = get_object_rotation_in_storage(index)

	# Set collision mask
	hex_character.remove_collision_exception_with(crystal)

	# Unfreeze object
	crystal.freeze = false
	crystal.linear_velocity = Vector3.ZERO
	crystal.angular_velocity = Vector3.ZERO
	return crystal


func _drop_object_to_ground(impulse: Vector3 = Vector3.ZERO) -> void:
	var crystal: Crystal = remove_from_storage()
	if not crystal:
		return

	crystal.state = Crystal.State.ON_GROUND

	var index := carried_objects.size()
	var spawn_pos := get_object_position_in_storage(index) + Vector3.UP * 0.05
	Util.spawn(crystal, spawn_pos)

	crystal.global_transform.basis = get_object_rotation_in_storage(index)

	var torque := Vector3(randfn(0, 1), randfn(0, 1), randfn(0, 1)) * 0.75
	crystal.apply_torque_impulse(torque)

	if impulse == Vector3.ZERO:
		# Default impulse
		impulse = Vector3.UP * 0.05
	else:
		# Scale impulse by 0.5 for rigid bodies + 0.25 because it fell from depot
		impulse *= 0.5 * 0.25

	crystal.apply_central_impulse(impulse)

extends Node3D
class_name CaravanDepot

@onready var hex_character: HexPhysicsCharacterBody3D = $'../..'

var area: Area3D
var radius: float = 1.8

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

	# area = Area3D.new()
	# var shape := CylinderShape3D.new()
	# shape.radius = radius
	# shape.height = radius
	# var collision_shape := CollisionShape3D.new()
	# collision_shape.shape = shape
	# area.add_child(collision_shape)
	# add_child(area)

	# area.set_collision_mask_value(Layers.L.ALL, true)

	# # Visualize area
	# var effect := DebugVis3D.cylinder(radius, radius, DebugVis3D.mat(Color(Color.DARK_CYAN, 0.1), false))
	# DebugVis3D.spawn(Vector3.ZERO, effect, self)

	# Add initial crystals
	_fill_storage(num_start_crystals)

	# FOR TESTING
	await Util.await_time(1.0)
	_drop_object_to_ground()


func has_objects() -> bool:
	return not carried_objects.is_empty()


func get_object_position_in_storage(index: int) -> Vector3:
	var storage_base := global_transform.origin + global_transform.basis * hold_basis_offset
	var vertical_step := Vector3(0.0, crystal_capsule_shape.radius * 2.0 + 0.05, 0.0)
	var horizontal_offset := Vector3(crystal_capsule_shape.radius, 0.0, 0.0) # adjust as needed

	var stack_index := floori(index / 2.0)
	var is_left: bool = index % 2 == 0
	var side_offset := horizontal_offset * (-1.0 if is_left else 1.0)

	var final_pos := storage_base + global_transform.basis * (side_offset + vertical_step * stack_index)
	return final_pos


func get_object_rotation_in_storage(index: int) -> Basis:
	var b: Basis = Basis(Vector3.RIGHT, deg_to_rad(randf_range(80.0, 100.0)))
	b *= Basis(Vector3.UP, deg_to_rad(randf_range(0.0, 360.0)))
	b *= Basis(Vector3.LEFT, deg_to_rad(randf_range(0.0, 15.0)))
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


func _drop_object_to_ground() -> void:
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
	crystal.apply_central_impulse(Vector3.UP * 0.05)


# func _get_closest_pickup_candidate() -> Crystal:
# 	var bodies: Array[Node3D] = area.get_overlapping_bodies()
# 	var closest: Crystal = null
# 	var min_dist_sq: float = INF

# 	for body in bodies:
# 		if body is Crystal:
# 			var crystal := body as Crystal
# 			if not crystal.can_be_picked_up():
# 				continue
# 			var dist_sq: float = global_position.distance_squared_to(crystal.global_position)
# 			if dist_sq < min_dist_sq:
# 				min_dist_sq = dist_sq
# 				closest = crystal

# 	return closest

# func _pick_up_object(obj: Crystal) -> void:
# 	if carried_object:
# 		return

# 	obj.freeze = true
# 	obj.linear_velocity = Vector3.ZERO
# 	obj.angular_velocity = Vector3.ZERO

# 	var original_parent: Node = obj.get_parent()
# 	if original_parent:
# 		original_parent.remove_child(obj)
# 	add_child(obj)

# 	if hex_character is PlayerController:
# 		obj.state = Crystal.State.CARRIED_BY_PLAYER
# 	elif hex_character is BasicEnemy:
# 		obj.state = Crystal.State.CARRIED_BY_ENEMY
# 	else:
# 		print("Unknown character type: ", hex_character)

# 	hex_character.add_collision_exception_with(obj)

# 	obj.global_transform.origin = _get_carried_object_position()
# 	carried_object = obj


# func _drop_object_to_ground() -> void:
# 	if carried_objects.is_empty():
# 		return

# 	hex_character.remove_collision_exception_with(carried_object)
# 	carried_object.state = Crystal.State.ON_GROUND

# 	remove_child(carried_object)
# 	get_tree().root.add_child(carried_object)
# 	carried_object.global_transform.origin = _get_carried_object_position()
# 	carried_object.freeze = false
# 	carried_object = null

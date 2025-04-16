extends Node3D
class_name PickUpManager

@onready var hex_character: HexPhysicsCharacterBody3D = $'../..'

var area: Area3D
var radius: float = 1.8

var hold_offset: Vector3 = Vector3.FORWARD * 0.5 + Vector3.UP * 0.9
var carried_object: Crystal = null

func _ready() -> void:
	hex_character.connect("Signal_huge_impulse_received", _drop_object)

	area = Area3D.new()

	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = radius
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.add_child(collision_shape)
	add_child(area)
	area.set_collision_mask_value(Layers.L.PICKABLE_OBJECTS, true)

	# var effect := DebugVis3D.cylinder(radius, radius, DebugVis3D.mat(Color(Color.GREEN, 0.05), false))
	# DebugVis3D.spawn(Vector3.ZERO, effect, self)


func is_carrying() -> bool:
	return carried_object != null


func has_object_to_pick_up() -> bool:
	return _get_closest_pickup_candidate() != null


func pickup_or_drop() -> bool:
	var performed_action := false
	if carried_object:
		_drop_object()
		performed_action = true
	else:
		var target: Crystal = _get_closest_pickup_candidate()
		if target:
			_pick_up_object(target)
			performed_action = true

	return performed_action


func _get_closest_pickup_candidate() -> Crystal:
	var bodies: Array[Node3D] = area.get_overlapping_bodies()
	var closest: Crystal = null
	var min_dist_sq: float = INF

	for body in bodies:
		if body is Crystal:
			var crystal := body as Crystal
			if not crystal.can_be_picked_up():
				continue
			var dist_sq: float = global_position.distance_squared_to(crystal.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest = crystal

	return closest

func _pick_up_object(obj: Crystal) -> void:
	if carried_object:
		return

	obj.freeze = true
	obj.linear_velocity = Vector3.ZERO
	obj.angular_velocity = Vector3.ZERO

	var original_parent: Node = obj.get_parent()
	if original_parent:
		original_parent.remove_child(obj)
	add_child(obj)

	if hex_character is PlayerController:
		obj.state = Crystal.State.CARRIED_BY_PLAYER
	elif hex_character is BasicEnemy:
		obj.state = Crystal.State.CARRIED_BY_ENEMY
	else:
		print("Unknown character type: ", hex_character)

	hex_character.add_collision_exception_with(obj)

	obj.global_transform.origin = global_transform.origin + global_transform.basis * hold_offset
	carried_object = obj


func _drop_object() -> void:
	if not carried_object:
		return

	# TODO ensure spawn position is outside of geometry

	hex_character.remove_collision_exception_with(carried_object)
	carried_object.state = Crystal.State.ON_GROUND

	remove_child(carried_object)
	get_tree().root.add_child(carried_object)
	carried_object.global_transform.origin = global_transform.origin + global_transform.basis * hold_offset
	carried_object.freeze = false
	carried_object = null

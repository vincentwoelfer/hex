extends Node3D
class_name PickUpManager

@onready var hex_character: HexPhysicsCharacterBody3D = $'../..'

var area: Area3D
var pickup_radius: float = 1.6

var hold_offset: Vector3 = Vector3.FORWARD * 0.45 + Vector3.UP * 0.85
var carried_object: Crystal = null

func _ready() -> void:
	hex_character.connect("Signal_huge_impulse_received", drop_object)

	area = Area3D.new()

	var shape := CylinderShape3D.new()
	shape.radius = pickup_radius
	shape.height = pickup_radius
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.add_child(collision_shape)
	add_child(area)
	area.set_collision_mask_value(Layers.L.PICKABLE_OBJECTS, true)
	area.set_collision_mask_value(Layers.L.CARAVAN, true)

	# var effect := DebugVis3D.cylinder(pickup_radius, pickup_radius, DebugVis3D.mat(Color(Color.GREEN, 0.05), false))
	# DebugVis3D.spawn(Vector3.ZERO, effect, self)


func set_pickup_radius(radius: float) -> void:
	pickup_radius = radius
	var shape := ((area.get_child(0) as CollisionShape3D).shape as CylinderShape3D)
	shape.radius = pickup_radius
	shape.height = pickup_radius


func is_carrying() -> bool:
	return carried_object != null


func has_object_to_pick_up() -> bool:
	return _get_closest_pickup_candidate_from_ground() != null or has_depot_for_pickup_in_range()


func has_depot_for_dropoff_in_range() -> bool:
	return _get_closest_depot(false) != null


func has_depot_for_pickup_in_range() -> bool:
	return _get_closest_depot(true) != null


enum PickupPriority {DEPOT, GROUND}
func perform_pickup_or_drop_action(priority: PickupPriority) -> bool:
	var performed_any_action := false

	if carried_object:
		# Drop to depot if possible, otherwise drop to ground
		var depot: CaravanDepot = _get_closest_depot(false)
		drop_object(depot)
		performed_any_action = true

	else:
		# Pick up from ground or depot, depending on the priority
		var callables: Array[Callable] = [Callable(self, "_pickup_from_depot"), Callable(self, "_pickup_from_ground")]
		if priority == PickupPriority.GROUND:
			callables.reverse()

		if callables[0].call():
			performed_any_action = true
		elif callables[1].call():
			performed_any_action = true

	return performed_any_action

func _pickup_from_ground() -> bool:
	var target: Crystal = _get_closest_pickup_candidate_from_ground()
	if target:
		pick_up_object(target)
		return true
	return false

func _pickup_from_depot() -> bool:
	var depot: CaravanDepot = _get_closest_depot(true)
	if depot:
		var crystal := depot.remove_from_storage()
		pick_up_object(crystal)
		return true
	return false


func pick_up_object(obj: Crystal) -> void:
	if carried_object:
		return

	obj.freeze = true
	obj.linear_velocity = Vector3.ZERO
	obj.angular_velocity = Vector3.ZERO

	var original_parent: Node = obj.get_parent()
	if original_parent:
		original_parent.remove_child(obj)
	add_child(obj)

	if self.hex_character is PlayerController:
		obj.state = Crystal.State.CARRIED_BY_PLAYER
	elif self.hex_character is BasicEnemy:
		obj.state = Crystal.State.CARRIED_BY_ENEMY
	else:
		print("Unknown character type: ", hex_character)

	hex_character.add_collision_exception_with(obj)

	obj.global_transform.origin = _get_carried_object_position()
	carried_object = obj


func drop_object(depot: CaravanDepot = null) -> void:
	if not carried_object:
		return

	hex_character.remove_collision_exception_with(carried_object)
	remove_child(carried_object)

	# Drop to depot if possible
	if depot:
		depot.add_to_storage(carried_object)
	else:
		carried_object.state = Crystal.State.ON_GROUND
		get_tree().root.add_child(carried_object)
		# TODO ensure spawn position is outside of geometry
		carried_object.global_transform.origin = _get_carried_object_position()
		carried_object.freeze = false

	carried_object = null


func _get_carried_object_position() -> Vector3:
	return global_transform.origin + global_transform.basis * hold_offset


func _get_closest_pickup_candidate_from_ground() -> Crystal:
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

func _get_closest_depot(require_not_empty: bool) -> CaravanDepot:
	var bodies: Array[Node3D] = area.get_overlapping_bodies()
	var closest: CaravanDepot = null
	var min_dist_sq: float = INF

	for body in bodies:
		if body is Caravan:
			var depot := (body as Caravan).caravan_depot
			
			if require_not_empty and not depot.has_objects():
				continue

			var dist_sq: float = global_position.distance_squared_to(depot.global_position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				closest = depot
	return closest

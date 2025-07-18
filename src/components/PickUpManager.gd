extends Node3D
class_name PickUpManager

@onready var hex_character: HexPhysicsCharacterBody3D

var area: Area3D

var hold_offset: Vector3 = Vector3.FORWARD * 0.45 + Vector3.UP * 0.85
var carried_object: Crystal = null
enum PickupPriority {DEPOT, GROUND}

# Customizeable
@export var pickup_radius: float = 1.6
@export var pickup_priority: PickupPriority = PickupPriority.GROUND
@export var can_pickup_from_depot: bool = true
@export var can_drop_to_depot: bool = true


func _ready() -> void:
	# Create area for pickup detection
	area = Area3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = pickup_radius
	shape.height = pickup_radius
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	area.add_child(collision_shape)
	add_child(area)
	area.set_collision_mask_value(Layers.PHY.PICKABLE_OBJECTS, true)
	area.set_collision_mask_value(Layers.PHY.CARAVAN, true)

	# var effect := DebugVis3D.cylinder(pickup_radius, pickup_radius, DebugVis3D.mat(Color(Color.GREEN, 0.05), false))
	# DebugVis3D.spawn(Vector3.ZERO, effect, self)


########################################################################
# General Stuff
########################################################################
func set_pickup_radius(radius: float) -> void:
	pickup_radius = radius
	var shape := ((area.get_child(0) as CollisionShape3D).shape as CylinderShape3D)
	shape.radius = pickup_radius
	shape.height = pickup_radius


func is_carrying() -> bool:
	return carried_object != null


func _get_carried_object_position() -> Vector3:
	return global_transform.origin + global_transform.basis * hold_offset


## General function, this equals the "pickup/drop button pressed" event
## Returns true/false if an action was performed
func perform_pickup_or_drop_action() -> bool:
	var performed_any_action := false

	if carried_object:
		var depot: CaravanDepot = null
		if can_drop_to_depot:
			# Drop to depot if possible, otherwise drop to ground
			depot = _get_closest_depot(false)
		drop_object(depot)
		performed_any_action = true

	else:
		# Pick up from ground or depot, depending on the priority and ability
		var callables: Array[Callable] = [Callable(self, "_pickup_from_ground")]
		if can_pickup_from_depot:
			callables.append(Callable(self, "_pickup_from_depot"))

		# If depot is priority, reverse the order of callables
		if pickup_priority == PickupPriority.DEPOT:
			callables.reverse()

		for callable: Callable in callables:
			if callable.call():
				performed_any_action = true
				break

	return performed_any_action


########################################################################
# PICKUP
########################################################################

func has_object_to_pick_up() -> bool:
	if can_pickup_from_depot:
		return _get_closest_pickup_candidate_from_ground() != null or _get_closest_depot(true) != null
	else:
		return _get_closest_pickup_candidate_from_ground() != null

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

	hex_character.add_collision_exception_with(obj)

	obj.global_transform.origin = _get_carried_object_position()
	carried_object = obj


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

########################################################################
# DROPING
########################################################################

func has_depot_for_dropoff_in_range() -> bool:
	return _get_closest_depot(false) != null


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


func drop_to_ground_with_impulse(impulse: Vector3) -> void:
	if not carried_object:
		return

	# Drop to ground - no caravan depot considered
	var prev_carried_object: Crystal = carried_object
	drop_object(null)

	# 0.5 for rigid bodies in general, additional 0.5 because object was dropped
	var impulse_factor := 0.5 * 0.5
	prev_carried_object.apply_impulse(Vector3.ZERO, impulse * impulse_factor)


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

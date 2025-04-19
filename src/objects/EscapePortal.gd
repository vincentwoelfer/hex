extends Node3D
class_name EscapePortal

var radius: float
@onready var area: Area3D = $Area3D
@onready var collision_shape_3d: CollisionShape3D = $Area3D/CollisionShape3D

var captured_crystals_time_counters: Dictionary[WeakRef, float] = {}

func _ready() -> void:
	add_to_group(HexConst.GROUP_ESCAPE_PORTALS)

	radius = (collision_shape_3d.shape as CylinderShape3D).radius

	area.set_collision_mask_value(Layers.L.PICKABLE_OBJECTS, true)
	area.set_collision_mask_value(Layers.L.ENEMY_CHARACTERS, true)

	area.connect("body_entered", _on_body_entered)

	area.gravity_point = true
	area.gravity_point_center = global_position + Vector3.UP * 3.5


func _on_body_entered(body: Node3D) -> void:
	if body.is_queued_for_deletion():
		return

	if body.is_in_group(HexConst.GROUP_ENEMIES):
		var enemy: BasicEnemy = body as BasicEnemy
		enemy.pick_up_manager.drop_object()
		enemy.queue_free()
		return
		# print("Enemy picked up by escape portal")

	if body.is_in_group(HexConst.GROUP_CRYSTALS):
		var crystal: Crystal = body as Crystal
		if not crystal.state == Crystal.State.ON_GROUND:
			return

		captured_crystals_time_counters[weakref(crystal)] = 1.8


func _process(delta: float) -> void:
	for weak_ref: WeakRef in captured_crystals_time_counters.keys():
		# Check if the crystal is still valid
		var crystal: Crystal = weak_ref.get_ref()
		if crystal == null or not is_instance_valid(crystal) or crystal.is_queued_for_deletion():
			captured_crystals_time_counters.erase(weak_ref)
			continue

		# Check if the crystal is still in portal and not grabbed
		if Util.get_dist_planar(crystal.global_position, global_position) > radius * 1.5 or crystal.state != Crystal.State.ON_GROUND:
			captured_crystals_time_counters.erase(weak_ref)
			continue
		
		# Reduce time
		captured_crystals_time_counters[weak_ref] -= delta

		# Delete crystal if time is up
		if captured_crystals_time_counters[weak_ref] <= 0.0:
			captured_crystals_time_counters.erase(weak_ref)
			crystal.queue_free()
			continue
		
		# print("Crystal picked up by escape portal")

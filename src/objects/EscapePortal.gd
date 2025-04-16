extends Node3D
class_name EscapePortal

var radius: float
@onready var area: Area3D = $Area3D
@onready var collision_shape_3d: CollisionShape3D = $Area3D/CollisionShape3D

var queued_for_deletion: Array[Node3D] = []

func _ready() -> void:
    add_to_group(HexConst.GROUP_ESCAPE_PORTALS)

    radius = (collision_shape_3d.shape as CylinderShape3D).radius

    area.set_collision_mask_value(Layers.L.PICKABLE_OBJECTS, true)
    area.set_collision_mask_value(Layers.L.ENEMY_CHARACTERS, true)

    area.connect("body_entered", _on_body_entered)


func _on_body_entered(body: Node3D) -> void:
    if body.is_queued_for_deletion() or body in queued_for_deletion:
        return

    if body.is_in_group(HexConst.GROUP_ENEMIES):
        var enemy: BasicEnemy = body as BasicEnemy
        enemy.pick_up_manager._drop_object()
        enemy.queue_free()
        # print("Enemy picked up by escape portal")

    elif body.is_in_group(HexConst.GROUP_CRYSTALS):
        var crystal: Crystal = body as Crystal

        if not crystal.state == Crystal.State.ON_GROUND:
            return

        queued_for_deletion.append(crystal)
        await Util.await_time(2.25)
        queued_for_deletion.erase(crystal)

        # Check if the crystal is still in portal
        if Util.get_dist_planar(crystal.global_position, global_position) > radius:
            return

        if not crystal.is_queued_for_deletion():
            crystal.queue_free()
        
        # print("Crystal picked up by escape portal")

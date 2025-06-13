extends Node3D
class_name BombExplosion

static var scene: PackedScene = preload("res://scenes/effects/BombExplosion.tscn")

static func spawn_global_pos(pos: Vector3) -> BombExplosion:
	var instance := scene.instantiate() as Node3D # as BombExplosion
	Util.spawn(instance, pos, null)
	Util.delete_after(5.0, instance)
	return instance

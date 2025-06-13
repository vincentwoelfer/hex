extends Node3D
class_name AoeRangeIndicator

static var scene: PackedScene = preload("res://scenes/effects/AoeRangeIndicator.tscn")

static func spawn_global_pos(pos: Vector3, radius: float, lifetime: float) -> AoeRangeIndicator:
	var instance := scene.instantiate() as AoeRangeIndicator
	instance._resize_decal(radius)
	Util.spawn(instance, pos, null)
	Util.delete_after(lifetime, instance)
	return instance


static func spawn_at_parent(parent: Node3D, radius: float, lifetime: float) -> AoeRangeIndicator:
	var instance := scene.instantiate() as AoeRangeIndicator
	instance._resize_decal(radius)
	Util.spawn(instance, Vector3.ZERO, parent)
	Util.delete_after(lifetime, instance)
	instance.top_level = true
	return instance


func _resize_decal(radius: float) -> void:
	var decal := $Decal as Decal
	if decal:
		# Resize the decal to match the radius - x2 to cover the full diameter
		decal.size.x = radius * 2.0
		decal.size.z = radius * 2.0

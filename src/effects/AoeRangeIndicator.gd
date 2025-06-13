extends Node3D
class_name AoeRangeIndicator

static var scene: PackedScene = preload("res://scenes/effects/AoeRangeIndicator.tscn")

static func spawn(pos: Vector3, radius: float, lifetime: float) -> AoeRangeIndicator:
	var instance := scene.instantiate() as AoeRangeIndicator
	instance._resize_decal(radius)
	Util.spawn(instance, pos, null)
	Util.delete_after(lifetime, instance)
	return instance


func _resize_decal(radius: float) -> void:
	var decal := $Decal as Decal
	if decal:
		decal.size.x = radius * 2.0
		decal.size.z = radius * 2.0

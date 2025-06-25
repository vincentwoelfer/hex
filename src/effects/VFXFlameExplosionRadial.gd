@tool
extends Node3D
class_name VFXFlameExplosionRadial

static var scene: PackedScene = preload("res://scenes/effects/FlameExplosionRadial.tscn")


@export_tool_button("Restart Particles")
var button := start


static func spawn_global_pos(pos: Vector3) -> VFXFlameExplosionRadial:
	var instance := scene.instantiate() as VFXFlameExplosionRadial
	Util.spawn(instance, pos, null)
	Util.delete_after(1.0, instance)
	instance.start()
	return instance
	

func start() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).one_shot = true
			(child as GPUParticles3D).emitting = true

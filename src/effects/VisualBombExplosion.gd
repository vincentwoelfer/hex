@tool
extends Node3D
class_name VisualBombExplosion

static var scene: PackedScene = preload("res://scenes/effects/BombExplosion.tscn")

# https://www.youtube.com/shorts/Q1JE_4JV20o

@export_tool_button("Restart Particles")
var button := start

static func spawn_global_pos(pos: Vector3) -> void:
	var instance: VisualBombExplosion = scene.instantiate() as VisualBombExplosion
	Util.spawn(instance, pos, null)
	Util.delete_after(1.0, instance)
	instance.start()
	

func start() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			(child as GPUParticles3D).one_shot = true
			(child as GPUParticles3D).emitting = true

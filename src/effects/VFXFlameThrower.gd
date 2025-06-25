@tool
extends Node3D
class_name VFXFlameThrower

static var scene: PackedScene = preload("res://scenes/effects/FlameThrower.tscn")

# https://www.youtube.com/shorts/Q1JE_4JV20o

@export_tool_button("Restart Particles")
var button := start

static func spawn_at_parent(parent: Node3D) -> VFXFlameThrower:
	var instance := scene.instantiate() as VFXFlameThrower
	Util.spawn(instance, Vector3(0, 1.2, 0), parent)
	instance.start()
	return instance
	

func start() -> void:
	for child in get_children():
		if child is GPUParticles3D:
			pass
			# (child as GPUParticles3D).one_shot = false
			# (child as GPUParticles3D).restart()

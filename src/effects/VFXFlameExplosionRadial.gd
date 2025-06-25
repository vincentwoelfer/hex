@tool
extends Node3D
class_name VFXFlameExplosionRadial

static var scene: PackedScene = preload("res://scenes/effects/FlameExplosionRadial.tscn")

static var color_ramp_natural: GradientTexture1D = preload("res://assets/effects/FlameNaturalColorRamp.tres")
static var color_ramp_red: GradientTexture1D = preload("res://assets/effects/FlameRedColorRamp.tres")

@export_tool_button("Restart Particles")
var button := start

enum ColorGradient {NATURAL, RED}

static func spawn_global_pos(pos: Vector3, color: ColorGradient = ColorGradient.NATURAL) -> VFXFlameExplosionRadial:
	var instance := scene.instantiate() as VFXFlameExplosionRadial
	Util.spawn(instance, pos, null)
	Util.delete_after(1.0, instance)
	instance.start(color)
	return instance
	

func start(color: ColorGradient) -> void:
	for child in get_children():
		if child is GPUParticles3D:
			var particles: GPUParticles3D = child as GPUParticles3D
			particles.one_shot = true
			particles.emitting = true
			
			if color == ColorGradient.RED:
				var mat: ParticleProcessMaterial = particles.process_material.duplicate()
				mat.color_ramp = color_ramp_red
				particles.process_material = mat

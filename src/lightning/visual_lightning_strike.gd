extends Node3D
class_name VisualLightningStrike

static var effect_scene = preload("res://scenes/effects/lightning/visual_lightning_strike.tscn")
static var lightning_particles_scene = preload("res://scenes/effects/lightning_particles.tscn") # Make sure you have this scene preloaded or loaded


func _ready():
	pass
	

func _process(delta: float):
	pass

func play_effect(position: Vector3, duration: float=3.0):
	var lightning_particles = lightning_particles_scene.instantiate()
	lightning_particles.global_transform.origin = position


static func spawn(position: Vector3):
	var instance = effect_scene.instantiate()
	Util.get_scene_root().add_child(instance)
	instance.play_effect(position)

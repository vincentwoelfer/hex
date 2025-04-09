extends Node3D
class_name VisualLightningStrike

static var default_duration := 0.25
static var effect_scene = preload("res://scenes/effects/lightning/visual_lightning_strike.tscn")
static var lightning_particles_scene = preload("res://scenes/effects/lightning_particles.tscn") # Make sure you have this scene preloaded or loaded


func _ready():
	pass
	

func _process(delta: float):
	pass

static func spawn(position: Vector3, duration: float=default_duration):
	var instance = effect_scene.instantiate()
	instance.global_position = position
	Util.get_scene_root().add_child(instance)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = duration
	timer.connect("timeout", Callable(instance, "queue_free"))
	instance.add_child(timer)
	timer.start()

	#var lightning_particles = lightning_particles_scene.instantiate()
	#lightning_particles.global_transform.origin = position

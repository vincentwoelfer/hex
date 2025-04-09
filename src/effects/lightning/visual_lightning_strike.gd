extends Node3D
class_name VisualLightningStrike

static var default_duration := 0.6
static var lightning_scene = preload("res://scenes/effects/lightning/visual_lightning_strike.tscn")
static var lightning_particles_scene = preload("res://scenes/effects/lightning_particles.tscn") # Make sure you have this scene preloaded or loaded
var timer: Timer
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var preset_color_gradients := {
	"pink": preload("res://assets/shaders/lightning/lightning_gradient_texture_pink.tres"),
	"black": preload("res://assets/shaders/lightning/lightning_gradient_texture_black.tres")
	
}

var lightning_material : ShaderMaterial

var duration: float
var time_elapsed := 0.0

func _ready():
	pass

func _process(delta: float) -> void:
	time_elapsed += delta
	print(time_elapsed / duration)
	lightning_material.set_shader_parameter("time_elapsed_frac", time_elapsed / duration)
	
	
func setup_shader_materials(duration: float, color_preset: String):
	
	lightning_material = mesh_instance_3d.get_active_material(1).duplicate()
	mesh_instance_3d.set_surface_override_material(1, lightning_material)
	
	lightning_material.set_shader_parameter("gradient_color_texture", preset_color_gradients[color_preset])

	
static func spawn(position: Vector3, duration: float=default_duration, color_preset: String="black"):
	var instance = lightning_scene.instantiate()
	instance.global_position = position
	Util.get_scene_root().add_child(instance)
	
	instance.setup_shader_materials(duration, color_preset)
	instance.duration = duration
	instance.timer = Timer.new()
	instance.timer.wait_time = duration
	instance.timer.one_shot = true
	instance.timer.connect("timeout", Callable(instance, "queue_free"))
	instance.add_child(instance.timer)
	instance.timer.start()
	
	

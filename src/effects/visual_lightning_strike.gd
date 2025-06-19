extends Node3D
class_name VisualLightningStrike

static var default_duration := 0.6
static var lightning_scene := preload("res://scenes/effects/visual_lightning_strike.tscn")

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@onready var preset_color_gradients := {
	"pink": preload("res://assets/shaders/lightning/lightning_gradient_texture_pink.tres"),
	"black": preload("res://assets/shaders/lightning/lightning_gradient_texture_black.tres")
	
}

var lightning_material: ShaderMaterial
var floor_mark_material: ShaderMaterial
var lightning_wave_material: ShaderMaterial

var duration: float
# Timer both for deletion and progress tracking
var timer: Timer

func _process(delta: float) -> void:
	var time_elapsed: float = timer.time_left
	lightning_material.set_shader_parameter("time_elapsed_frac", time_elapsed / duration)
	lightning_wave_material.set_shader_parameter("time_elapsed_frac", time_elapsed / duration)
	

func setup_shader_materials(color_preset: String) -> void:
	floor_mark_material = mesh_instance_3d.get_active_material(0).duplicate()
	mesh_instance_3d.set_surface_override_material(0, floor_mark_material)
	
	lightning_material = mesh_instance_3d.get_active_material(1).duplicate()
	mesh_instance_3d.set_surface_override_material(1, lightning_material)
	
	lightning_wave_material = mesh_instance_3d.get_active_material(2).duplicate()
	mesh_instance_3d.set_surface_override_material(2, lightning_wave_material)
	
	floor_mark_material.set_shader_parameter("gradient_color_texture", preset_color_gradients[color_preset])
	lightning_material.set_shader_parameter("gradient_color_texture", preset_color_gradients[color_preset])
	lightning_wave_material.set_shader_parameter("gradient_color_texture", preset_color_gradients[color_preset])

	
static func spawn(pos: Vector3, spawn_on_floor: bool = true, duration_: float = default_duration, color_preset: String = "black") -> void:
	var instance: VisualLightningStrike = lightning_scene.instantiate()
	if spawn_on_floor:
		pos = PhysicUtil.raycast_first_hit_pos(pos + Vector3.UP * 1000, pos - Vector3.UP * 1000, Layers.PHY_TERRAIN_AND_STATIC)
		pos += Vector3.UP * 0.2

	Util.spawn(instance, pos)
	
	instance.setup_shader_materials(color_preset)
	instance.duration = duration_

	instance.timer = Util.timer(duration_, instance.queue_free, true)
	instance.add_child(instance.timer)

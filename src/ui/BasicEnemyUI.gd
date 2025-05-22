extends Control
class_name BasicEnemyUI

@export var anchor: Marker3D
@export var camera: Camera3D

@onready var health_bar: TextureProgressBar = $HealthBar

func _setup() -> void:
	var ui_root := get_tree().root.get_node("main/CanvasLayer")
	reparent(ui_root)

	set_health(70, 100)


func set_health(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.min_value = 0.0
	health_bar.value = clampf(current, 0.0, max_val)


func _process(delta: float) -> void:
	if not anchor or not camera:
		visible = false
		return

	var world_pos: Vector3 = anchor.global_position
	var screen_pos: Vector2 = camera.unproject_position(world_pos)

	if camera.is_position_behind(world_pos):
		print("Camera is behind enemy, hiding health bar")
		visible = false
		return

	visible = true
	global_position = screen_pos - size * 0.5

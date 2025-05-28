extends Control
class_name BasicEnemyUI


@onready var health_bar: TextureProgressBar = $HealthBar


func set_health(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.min_value = 0.0
	health_bar.value = clampf(current, 0.0, max_val)


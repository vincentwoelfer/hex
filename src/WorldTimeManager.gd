@tool
class_name WorldTimeManager
extends Node

const HOURS_PER_DAY: float = 24.0

@export_range(0.0, HOURS_PER_DAY, 0.5) var current_time: float = 12.0:
	set(value):
		current_time = value
		EventBus.Signal_ChangeWorldTime.emit(current_time)

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass



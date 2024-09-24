class_name WorldTimeManager
extends Node

var current_world_time: float = 6.0
@export var duration_sec_per_hour: float = 0.5

var timer: Timer

func _on_timer_timeout() -> void:
	print("Timer has finished!")


func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = duration_sec_per_hour
	timer.one_shot = false
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)
	timer.start()


func _on_timer_tick() -> void:
	# Advance one hour
	current_world_time += 1.0

	var day_time: float = fmod(current_world_time, 24.0)

	EventBus.Signal_ChangeWorldTime.emit(day_time)

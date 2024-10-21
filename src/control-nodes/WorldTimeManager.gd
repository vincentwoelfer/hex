@tool
class_name WorldTimeManager
extends Node

const start_time: float = 8.0
var current_world_time: float = start_time
var duration_sec_per_hour: float = 1.0
const time_step := 1.0
var speed_up_factor: float = 2.5

var auto_advance: bool = false
var day_time: float

var timer: Timer


@export_tool_button("Advance World Time", "Callable")
var button_action := self.advance_world_time_one_step


func _ready() -> void:
	timer = Timer.new()
	timer.wait_time = duration_sec_per_hour
	timer.one_shot = false
	timer.timeout.connect(advance_world_time_one_step)
	add_child(timer)

	if auto_advance:
		timer.start()

	# Connect Signals
	EventBus.Signal_ToogleWorldTimeAutoAdvance.connect(_on_Signal_ToogleWorldTimeAutoAdvance)
	EventBus.Signal_AdvanceWorldTimeOneStep.connect(advance_world_time_one_step)
	EventBus.Signal_ToggleSpeedUpTime.connect(_on_Signal_ToogleSpeedUpTime)


func _on_Signal_ToogleWorldTimeAutoAdvance() -> void:
	self.set_auto_advance_time(not auto_advance)


func _on_Signal_ToogleSpeedUpTime() -> void:
	if self.timer.wait_time == duration_sec_per_hour:
		self.timer.wait_time = duration_sec_per_hour / speed_up_factor
	else:
		self.timer.wait_time = duration_sec_per_hour


func set_auto_advance_time(auto_advance_new: bool) -> void:
	if auto_advance_new != auto_advance:
		auto_advance = auto_advance_new
		if auto_advance:
			timer.start()
		else:
			timer.stop()


func get_max_tween_time() -> float:
	# Only limit tween time if auto advancing
	if auto_advance:
		return duration_sec_per_hour * 0.99
	else:
		return 999.0


func advance_world_time_one_step() -> void:
	# Advance one hour
	current_world_time += time_step

	day_time = fmod(current_world_time, 24.0)
	EventBus.Signal_SetVisualLightTime.emit(day_time)
	EventBus.Signal_WorldStep.emit()
	EventBus.Signal_DayTimeChanged.emit(day_time)

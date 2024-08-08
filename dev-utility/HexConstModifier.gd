@tool
extends Node

# See HexConst

@export_range(2.0, 5.0, 0.1) var outer_radius: float = HexConst.outer_radius:
	set(value):
		outer_radius = value
		HexConst.outer_radius = value
		EventBus.emit_signal("Signal_HexConstChanged")

@export_range(1.5, 4.0, 0.1) var inner_radius: float = HexConst.inner_radius:
	set(value):
		inner_radius = value
		HexConst.inner_radius = value
		EventBus.emit_signal("Signal_HexConstChanged")

@export_range(0.4, 5.0, 0.1) var height: float = HexConst.height:
	set(value):
		height = value
		HexConst.height = value
		EventBus.emit_signal("Signal_HexConstChanged")

@export_range(0.0, 1.0, 0.025) var transition_height_factor: float = HexConst.transition_height_factor:
	set(value):
		transition_height_factor = value
		HexConst.transition_height_factor = value
		EventBus.emit_signal("Signal_HexConstChanged")

@export_range(0.0, 1.0, 0.025) var core_circle_smooth_strength: float = HexConst.core_circle_smooth_strength:
	set(value):
		core_circle_smooth_strength = value
		HexConst.core_circle_smooth_strength = value
		EventBus.emit_signal("Signal_HexConstChanged")

@export_range(0, 6, 1) var extra_verts_per_side: int = HexConst.extra_verts_per_side:
	set(value):
		extra_verts_per_side = value
		HexConst.extra_verts_per_side = value
		EventBus.emit_signal("Signal_HexConstChanged")

@tool
extends Node

# See HexConstants

@export_range(2.0, 5.0, 0.25) var outer_radius: float = HexConstants.outer_radius:
	set(value):
		outer_radius = value		
		HexConstants.outer_radius = value
		EventBus.emit_signal("Signal_HexConstantsChanged")

@export_range(1.5, 4.0, 0.25) var inner_radius: float = HexConstants.inner_radius:
	set(value):
		inner_radius = value
		HexConstants.inner_radius = value
		EventBus.emit_signal("Signal_HexConstantsChanged")

@export_range(1.0, 8.0, 0.5) var height: float = HexConstants.height:
	set(value):
		height = value
		HexConstants.height = value
		EventBus.emit_signal("Signal_HexConstantsChanged")

@export_range(0.0, 1.0, 0.05) var transition_height_factor: float = HexConstants.transition_height_factor:
	set(value):
		transition_height_factor = value
		HexConstants.transition_height_factor = value
		EventBus.emit_signal("Signal_HexConstantsChanged")

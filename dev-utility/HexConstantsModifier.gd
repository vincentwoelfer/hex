@tool
extends Node

@export_range(0.5, 5, 0.5) var width: float = HexConstants.width:
	set(value):
		width = value		
		HexConstants.width = value
		EventBus.emit_signal("Signal_HexConstantsChanged")

@export_range(0.5, 5, 0.5) var height: float = HexConstants.height:
	set(value):
		height = value
		HexConstants.height = value
		EventBus.emit_signal("Signal_HexConstantsChanged")

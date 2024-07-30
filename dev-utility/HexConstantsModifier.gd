@tool
extends Node

@export_range(0.5, 5, 0.5) var width: float = 1.0:
	set(value):
		width = value
		HexConstants.regenerate = true
		HexConstants.width = value


@export_range(0.5, 5, 0.5) var height: float = 1.0:
	set(value):
		height = value
		HexConstants.regenerate = true
		HexConstants.height = value

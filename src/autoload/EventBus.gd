# Needs to be tool to enable event bus already in the editor itself
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

signal Signal_HexConstChanged()
signal Signal_SelectionPosition(selection_position: Vector3)
signal Signal_SelectionChanged(new_hex: HexTile)

# Debug Signals
signal Signal_TooglePerTileUi(is_visible: bool)
var is_per_tile_ui_on: bool = true

func _ready() -> void:
	# Connect signals here to enable logging functions below.
	# Actual signal connection is done in the code catching the signal like this:
	# EventBus.Signal_HexConstChanged.connect(generate_geometry)

	# Signal emittion:
	# EventBus.emit_signal("Signal_HexConstChanged", ...)

	# Connect to events to print debug info
	Signal_HexConstChanged.connect(_on_Signal_HexConstChanged)


# Reacht to keyboard inputs to directly trigger events
func _input(event: InputEvent) -> void:
	# Only execute in game, check necessary because EventBus is @tool
	if not Engine.is_editor_hint():
		if event.is_action_pressed("toogle_per_tile_ui"):
			is_per_tile_ui_on = !is_per_tile_ui_on
			Signal_TooglePerTileUi.emit(is_per_tile_ui_on)

# Function to handle the signal
func _on_Signal_HexConstChanged() -> void:
	print("EventBus: Signal_HexConstChanged")

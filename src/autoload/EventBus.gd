# Needs to be tool to enable event bus already in the editor itself
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

signal Signal_HexConstChanged()
signal Signal_SelectionPosition(selection_position: Vector3)

func _ready() -> void:
    # Connect signals here to enable logging functions below.
    # Actual signal connection is done in the code catching the signal like this:
    # EventBus.Signal_HexConstChanged.connect(generate_geometry)

    # Signal emittion:
    # EventBus.emit_signal("Signal_HexConstChanged", ...)

    Signal_HexConstChanged.connect(_on_Signal_HexConstChanged)
    Signal_SelectionPosition.connect(_on_Signal_SelectionPosition)

# Function to handle the signal
func _on_Signal_HexConstChanged() -> void:
    print("EventBus: Signal_HexConstChanged")

func _on_Signal_SelectionPosition(selection_position: Vector3) -> void:
    pass
    #print("Selection at ", selection_position)

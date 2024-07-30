# Needs to be tool to enable event bus already in the editor itself
@tool
extends Node

signal Signal_HexConstantsChanged()

func _ready() -> void:
    # Connect the signal to a local function within EventBus
    Signal_HexConstantsChanged.connect(_on_Signal_HexConstantsChanged)

# Function to handle the signal
func _on_Signal_HexConstantsChanged() -> void:
    print("EventBus: Signal_HexConstantsChanged")

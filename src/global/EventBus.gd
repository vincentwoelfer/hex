# Needs to be tool to enable event bus already in the editor itself
@tool
extends Node
#class_name EventBus

signal Signal_HexConstChanged()

func _ready() -> void:
    # Connect the signal to a local function within EventBus
    Signal_HexConstChanged.connect(_on_Signal_HexConstChanged)

# Function to handle the signal
func _on_Signal_HexConstChanged() -> void:    
    print("EventBus: Signal_HexConstChanged")

@abstract class_name AbstractGadget
extends Node3D

var input: InputManager

func init(input_: InputManager) -> void:
    self.input = input_


func _physics_process(delta: float) -> void:
    if input.skill_primary_input.wants:
        input.skill_primary_input.consume()
        skill_primary()

    if input.skill_secondary_input.wants:
        input.skill_secondary_input.consume()
        skill_secondary()

func skill_primary() -> void:
    pass

func skill_secondary() -> void:
    pass



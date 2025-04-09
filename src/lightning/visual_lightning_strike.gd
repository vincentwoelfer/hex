extends Node3D
class_name VisualLightningStrike

static var effect_scene = preload("res://scenes/effects/lightning/visual_lightning_strike.tscn")


func _ready():
	pass
	

func _process(delta: float):
	pass


static func spawn(pos: Vector3):
	var instance = effect_scene.instantiate()
	#get_tree().root.add_child(instance)
	#instance.play_effect(position)

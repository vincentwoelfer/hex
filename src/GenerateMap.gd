#@tool
extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(-4, 4):
		var mesh_generator_scene := preload("res://scenes/HexGeometry.tscn")
		var tile : Node3D = mesh_generator_scene.instantiate()
		
		# Set parameters
		#tile.width = 2.0
		#tile.height = 2.0		
		
		tile.position = Vector3(i, 0, 0)

		# Add to the current scene
		add_child(tile)
		tile.owner = self


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

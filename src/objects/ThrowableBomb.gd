extends RigidBody3D
class_name ThrowableBomb

@onready var collision: CollisionShape3D = $Collision


func _ready() -> void:
	add_to_group(HexConst.GROUP_CRYSTALS)

    # Set the physics material
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	mat.friction = 1.0
	mat.rough = true
	self.physics_material_override = mat

	# Collision config
	self.angular_damp = 4.5
	self.linear_damp = 0.3

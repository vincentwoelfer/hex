extends RigidBody3D
class_name Crystal

@onready var collision: CollisionShape3D = $Collision

func _ready() -> void:
	add_to_group(HexConst.GROUP_NAV_CRYSTALS)

    # Set the physics material
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	mat.friction = 1.0
	mat.rough = true
	self.physics_material_override = mat

	self.angular_damp = 4.5
	self.linear_damp = 0.3

extends RigidBody3D
class_name Crystal

@onready var collision: CollisionShape3D = $Collision

enum State {ON_CARAVAN, ON_GROUND, CARRIED_BY_PLAYER, CARRIED_BY_ENEMY}

var state: Crystal.State = State.ON_GROUND


func can_be_picked_up() -> bool:
	return state == State.ON_GROUND or state == State.ON_CARAVAN


func _ready() -> void:
	# Unsure if this is good. Looks better but might interfere with player movement
	# self.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

    # Set the physics material
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.5
	mat.friction = 1.0
	mat.rough = true
	self.physics_material_override = mat

	# Collision config
	self.angular_damp = 1.5
	self.linear_damp = 1.5

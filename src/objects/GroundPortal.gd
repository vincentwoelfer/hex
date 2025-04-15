extends Node3D
class_name GroundPortal


# Since we can only have one at a time we use static variables to have a global state
enum TeamTeleporterStatus {ON_COOLDOWN, READY_TO_DEPLOY, DEPLOYED}
static var status: TeamTeleporterStatus = TeamTeleporterStatus.READY_TO_DEPLOY

static var cooldown: float = 10.0
static var active_time: float = 4.0
static var cooldown_timer: Timer
static var active_timer: Timer


func _ready() -> void:
    pass

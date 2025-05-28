extends CanvasLayer

class UIElement:
	var parent: Node3D
	var anchor: Marker3D
	var control: Control


var node_ui_mapping: Dictionary[Node3D, UIElement] = {}

@onready var camera: Camera3D = null

func _process(delta: float) -> void:
	if camera == null:
		camera = Util.get_global_cam(self)
	if camera == null:
		return

	for node: Node3D in node_ui_mapping.keys():
		if not is_instance_valid(node):
			remove_ui_for_node(node)
			continue

		var ui_element: UIElement = node_ui_mapping[node]		
		if not is_instance_valid(ui_element.control):
			node_ui_mapping.erase(node)
			continue

		_process_ui(ui_element)


func _process_ui(ui_element: UIElement) -> void:
	# Determine global position of the UI element
	var global_pos : Vector3
	if ui_element.anchor:
		global_pos = ui_element.anchor.global_position
	else:
		global_pos = ui_element.parent.global_position

	# Dont show if behind the camera
	if camera.is_position_behind(global_pos):
		ui_element.control.visible = false
		return
	
	# Unproject the position to screen coordinates
	var screen_pos := camera.unproject_position(global_pos)

	ui_element.control.visible = true
	ui_element.control.position = screen_pos


func attach_ui_scene(node_3d: Node3D, ui_scene: PackedScene) -> Control:
	if node_ui_mapping.has(node_3d):
		push_warning("UI already attached to this node")
		return node_ui_mapping[node_3d].control

	var ui_instance := ui_scene.instantiate() as Control
	add_child(ui_instance)

	# Create UIElement
	var ui_element := UIElement.new()
	ui_element.parent = node_3d
	ui_element.anchor = node_3d.get_node_or_null("UIAnchor") as Marker3D
	ui_element.control = ui_instance
	node_ui_mapping[node_3d] = ui_element

	# Free UI automatically when 3D node is freed
	node_3d.tree_exiting.connect(func() -> void: remove_ui_for_node(node_3d))

	return ui_instance


func remove_ui_for_node(node_3d: Node3D) -> void:
	if node_ui_mapping.has(node_3d):
		var ui_element := node_ui_mapping[node_3d]
		if is_instance_valid(ui_element.control):
			ui_element.control.queue_free()
		node_ui_mapping.erase(node_3d)

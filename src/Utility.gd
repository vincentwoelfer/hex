class_name Utility

static func randColor() -> Color:
	return Color(0.5, randf(), randf(), 1.0)

static func getHexCorner(r: float, dir: int) -> Vector2:
	var angle_deg := 60.0 * dir
	var angle_rad := PI / 180.0 * angle_deg
	return Vector2(r * cos(angle_rad), r * sin(angle_rad))

static func getHexCornerArray(r: float) -> PackedVector2Array:
	var array := PackedVector2Array()
	for dir in HexDirection.values():
		array.append(getHexCorner(r, dir))
	return array

static func getHexCorner3(r: float, dir: int) -> Vector3:
	var angle_deg := 60.0 * dir
	var angle_rad := PI / 180.0 * angle_deg
	return Vector3(r * cos(angle_rad), 0.0, r * sin(angle_rad))

static func getHexCornerArray3(r: float) -> PackedVector3Array:
	var array := PackedVector3Array()
	for dir in HexDirection.values():
		array.append(getHexCorner3(r, dir))
	return array

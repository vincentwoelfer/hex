class_name Colors


static func randColor() -> Color:
	return Color(randf(), randf(), randf(), 1.0)


static func randColorNoExtreme(offset: float = 0.1) -> Color:
	var lo := offset
	var hi := 1.0 - offset
	return Color(randf_range(lo, hi), randf_range(lo, hi), randf_range(lo, hi), 1.0)


static func randColorVariation(color: Color, variation: float = 0.2) -> Color:
	return color + Color(randf_range(-variation, variation), randf_range(-variation, variation), randf_range(-variation, variation), 0.0)


static func getDistincHexColor(i: int) -> Color:
	# -> R-G-B - Magenta-
	assert(i >= 0 and i <= 5)
	if i == 0: return Color.RED
	if i == 1: return Color.DARK_GREEN
	if i == 2: return Color.MEDIUM_BLUE
	if i == 3: return Color.DARK_MAGENTA
	if i == 4: return Color.ORANGE
	if i == 5: return Color.AQUA
	return Color.BLACK


static func getColorForIncline(inclineDeg: float) -> Color:
	if inclineDeg <= 15.0:
		inclineDeg = 0
	inclineDeg = clampf(inclineDeg / 70.0, 0, 1)

	#const green := Color.FOREST_GREEN
	var green := Color.DARK_GREEN.lerp(Color8(22, 17, 12), 0.9)
	const gray := Color.DIM_GRAY
	var color := green.lerp(gray, inclineDeg)

	return color

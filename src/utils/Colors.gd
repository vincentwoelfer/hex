class_name Colors


static func randColor() -> Color:
	return Color(randf(), randf(), randf(), 1.0)


static func randColorNoExtreme(offset: float = 0.1) -> Color:
	var lo := offset
	var hi := 1.0 - offset
	return Color(randf_range(lo, hi), randf_range(lo, hi), randf_range(lo, hi), 1.0)


static func colorVariation(color: Color, variation: float = 0.1) -> Color:
	return color + Color(randf_range(-variation, variation), randf_range(-variation, variation), randf_range(-variation, variation), 0.0)

#############################################################################
# Distrinc HEX colors for each side, top and transitions
#############################################################################
static func getDistincHexColor(i: int) -> Color:
	# -> R-G-B - Magenta-
	assert(i >= 0 and i <= 5)
	if i == 0: return Color.RED
	if i == 1: return Color.DARK_GREEN
	if i == 2: return Color.DARK_BLUE
	if i == 3: return Color.AQUA
	if i == 4: return Color.DARK_MAGENTA
	if i == 5: return Color.ORANGE
	return Color.BLACK

static func getDistinctHexColorTopSide() -> Color:
	return Color(0.15, 0.3, 0.15)


static func modifyColorForCornerArea(base: Color) -> Color:
	#return base.lerp(Color(base.g, base.b, base.r), 0.8).lightened(0.5)
	#return base.lerp(Color.MAGENTA, 0.65)
	return Color(base.b, base.r, base.r)


static func modifyColorForTransitionType(base: Color, trans_type: HexGeometryInput.TransitionType) -> Color:
	if trans_type == HexGeometryInput.TransitionType.SHARP:
		return base.darkened(0.8)
	elif trans_type == HexGeometryInput.TransitionType.SMOOTH:
		return base.lightened(0.2)
	
	return base.lerp(Color.BLACK, 0.9)


static func getColorForIncline(inclineDeg: float) -> Color:
	if inclineDeg <= 25.0:
		inclineDeg = 0.0
	if inclineDeg >= 30:
		pass
		#inclineDeg = 70.0
	inclineDeg = clampf(inclineDeg / 70.0, 0.0, 1.0)

	var green := Color.DARK_GREEN.lerp(Color8(22, 17, 12), 0.9)
	const gray := Color8(16, 17, 13)
	
	var color := green.lerp(gray, inclineDeg)

	return color

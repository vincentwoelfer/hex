class_name Colors


static func randColor() -> Color:
	return Color(randf(), randf(), randf(), 1.0)


static func randColorNoExtreme(offset: float = 0.1) -> Color:
	var lo := offset
	var hi := 1.0 - offset
	return Color(randf_range(lo, hi), randf_range(lo, hi), randf_range(lo, hi), 1.0)


static func colorVariation(color: Color, variation: float = 0.08) -> Color:
	# Random effect scales with that component value
	# Otherwise a dark color changes drastically and a bright one not at all
	var var_r := remap(color.r, 0.0, 1.0, 0.5, 1.3)
	var var_g := remap(color.g, 0.0, 1.0, 0.5, 1.3)
	var var_b := remap(color.b, 0.0, 1.0, 0.5, 1.3)
	return (color + Color(randf_range(-variation, variation) * var_r, randf_range(-variation, variation) * var_g, randf_range(-variation, variation) * var_b, 0.0)).clamp()

#############################################################################
# Distrinc HEX colors for each side, top and transitions
#############################################################################
static func getDistincHexColor(i: int) -> Color:
	# -> R-G-B - Magenta-
	assert(i >= 0 and i <= 5)
	if i == 0: return Color.RED
	if i == 1: return Color.DARK_GREEN.darkened(0.3)
	if i == 2: return Color.DARK_BLUE
	if i == 3: return Color.AQUA
	if i == 4: return Color.DARK_MAGENTA
	if i == 5: return Color.DARK_ORANGE
	return Color.BLACK

static func getDistinctHexColorTopSide() -> Color:
	return Color(0.15, 0.3, 0.15)


static func modifyColorForCornerArea(base: Color) -> Color:
	return base.lerp(Color(0.15, 0.3, 0.15), 0.8)


static func modifyColorForTransitionType(base: Color, trans_type: HexGeometryInput.TransitionType) -> Color:
	if trans_type == HexGeometryInput.TransitionType.SHARP:
		return base.darkened(0.8)
	elif trans_type == HexGeometryInput.TransitionType.SMOOTH:
		return base.lightened(0.15)
	
	return base.lerp(Color.BLACK, 0.9)


static func getColorForIncline(inclineDeg: float) -> Color:

	# Remap & clamp
	inclineDeg = remap(inclineDeg, 30.0, 70.0, 0.0, 1.0)
	inclineDeg = clampf(inclineDeg, 0.0, 1.0)

	#var green := Color.DARK_GREEN.lerp(Color8(22, 17, 12), 0.9)
	#var gray := Color8(16, 17, 13)

	var ground := Color8(13, 12, 8)
	var wall := Color(0.17, 0.19, 0.21)
	
	var color := ground.lerp(wall, inclineDeg)

	return color

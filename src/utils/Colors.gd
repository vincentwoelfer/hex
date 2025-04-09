class_name Colors


static func rand_color() -> Color:
	return Color(randf(), randf(), randf(), 1.0)


static func rand_color_no_extreme(offset: float = 0.1) -> Color:
	var lo := offset
	var hi := 1.0 - offset
	return Color(randf_range(lo, hi), randf_range(lo, hi), randf_range(lo, hi), 1.0)


static func rand_variation(color: Color, variation: float = 0.08) -> Color:
	# Random effect scales with that component value
	# Otherwise a dark color changes drastically and a bright one not at all
	var var_r := remap(color.r, 0.0, 1.0, 0.5, 1.3)
	var var_g := remap(color.g, 0.0, 1.0, 0.5, 1.3)
	var var_b := remap(color.b, 0.0, 1.0, 0.5, 1.3)
	return (color + Color(randf_range(-variation, variation) * var_r, randf_range(-variation, variation) * var_g, randf_range(-variation, variation) * var_b, 0.0)).clamp()


static func set_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


## Change hue, input [-1, 1]
static func rotate_hue(color: Color, hue_d: float) -> Color:
	color.h = fmod(color.h + hue_d, 1.0)
	return color


## Get a color with a different saturation and value.
## Sat=0 -> fade to white
## Val=0 -> fade to black
static func mod_sat_val(color: Color, sat_d: float = 0.0, val_d: float = 0.0) -> Color:
	var h: float = color.h
	var s: float = clamp(color.s + sat_d, 0.0, 1.0)
	var v: float = clamp(color.v + val_d, 0.0, 1.0)
	return Color.from_hsv(h, s, v, color.a)


## Get a color with a different saturation and value.
## Sat=0 -> fade to white
## Val=0 -> fade to black
## Hue +- 1 
static func mod_sat_val_hue(color: Color, sat_d: float = 0.0, val_d: float = 0.0, hue_d: float = 0.0) -> Color:
	var h: float = fmod(color.h + hue_d, 1.0)
	var s: float = clamp(color.s + sat_d, 0.0, 1.0)
	var v: float = clamp(color.v + val_d, 0.0, 1.0)
	return Color.from_hsv(h, s, v, color.a)


#############################################################################
# Distrinc HEX colors for each side, top and transitions
#############################################################################
static func get_distinct_hex_color(i: int) -> Color:
	# -> R-G-B - Magenta-
	assert(i >= 0 and i <= 5)
	if i == 0: return Color.RED
	if i == 1: return Color.DARK_GREEN.darkened(0.3)
	if i == 2: return Color.DARK_BLUE
	if i == 3: return Color.AQUA
	if i == 4: return Color.DARK_MAGENTA
	if i == 5: return Color.DARK_ORANGE
	return Color.BLACK

static func get_distinct_hex_color_top_side() -> Color:
	return Color(0.15, 0.3, 0.15)


static func modify_color_for_corner_area(base: Color) -> Color:
	return base.lerp(Color(0.15, 0.3, 0.15), 0.8)


static func modify_color_for_transition_type(base: Color, trans_type: HexGeometryInput.TransitionType) -> Color:
	if trans_type == HexGeometryInput.TransitionType.SHARP:
		return base.darkened(0.8)
	elif trans_type == HexGeometryInput.TransitionType.SMOOTH:
		return base.lightened(0.15)
	
	return base.lerp(Color.BLACK, 0.9)


static func get_color_for_incline(incline_deg: float) -> Color:
	# Remap & clamp
	incline_deg = remap(incline_deg, 30.0, 70.0, 0.0, 1.0)
	incline_deg = clampf(incline_deg, 0.0, 1.0)

	#var green := Color.DARK_GREEN.lerp(Color8(22, 17, 12), 0.9)
	#var gray := Color8(16, 17, 13)

	#var ground := Color8(13, 12, 8)
	var ground := Color8(4, 8, 2)
	var wall := Color(0.17, 0.19, 0.21)
	
	var color := ground.lerp(wall, incline_deg)

	return color

#############################################################################
# STATIC COLOR DEFINITIONS
#############################################################################
# For players
const PLAYER_COLORS: Array[Color] = [Color.FUCHSIA, Color.ROYAL_BLUE, Color.WEB_GREEN, Color.GOLD]
static func get_player_colors() -> Array[Color]:
	return PLAYER_COLORS

static func get_player_color(i: int) -> Color:
	assert(i >= 0 and i < PLAYER_COLORS.size())
	return PLAYER_COLORS[i]

# Caravan
const COLOR_CARAVAN: Color = Color.TEAL

# Needs to be tool to read these in other tool scripts!
@tool
extends Node

# See https://www.redblobgames.com/grids/hexagons/
# We use flat-top orientation

# Distance from center to the corners.
# This is the same as the length of the sides.
# Also known as "size"
var outer_radius: float = 3.0

# Radius of the workable core area.
# Must be smaller than outer_radius * 0.86 (size of largest circle in outer hex)
var inner_radius: float = 2.0

# Height of one hex cell
var height: float = 2.0

# Transition points are at height * this factor above zero.
# 0.5 = in the middle
# 0.1 = almost above ground | reaching down a lot
var transition_height_factor: float = 0.75


# ========================================================
# ==================== Derived values ====================
# ========================================================

# Full horizontal (along East-West) size of hexagon = width
func horizontal_size() -> float:
    return 2.0 * outer_radius

# Full vertical (along North-South) size of hexagon = "height"
func vertical_size() -> float:
    return sqrt(3.0) * outer_radius

# Distance from center to the closest point of the sides.
func outer_circle_radius() -> float:
    # = outer_radius * 0.86
    return outer_radius * sqrt(3.0) / 2.0

func transition_height() -> float:
    return height * transition_height_factor


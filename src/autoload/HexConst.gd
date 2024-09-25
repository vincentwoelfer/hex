# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# See https://www.redblobgames.com/grids/hexagons/
# We use flat-top orientation

# Distance from center to the corners.
# This is the same as the length of the sides.
# Also known as "size"
var outer_radius: float = 4.0

# Radius of the workable Regular area.
# Must be smaller than outer_radius * 0.86 (size of largest circle in outer hex)
var inner_radius: float = 3.5

# Height of one hex cell
var height: float = 0.5

# Transition points are at height * this factor above zero.
# 0.5 = in the middle
# 0.1 = almost above ground | reaching down a lot
var transition_height_factor: float = 0.5

# Between 0 (hard hexagon) and 1 (circle)
var core_circle_smooth_strength := 0.35

# Extra vertices per hexagon side
var extra_verts_per_side := 4

# Extra vertices per hexagon center
var extra_verts_per_center := 5


# NOT HEX CONST - here for editing in edior and hex-geom regeneration triggering
var grass_density := 0.8

# ========================================================
# ==================== Derived values ====================
# ========================================================

# Full horizontal (along East-West) size of hexagon = width
func horizontal_size() -> float:
    return 2.0 * outer_radius

# Full vertical (along North-South) size of hexagon = "height"
func vertical_size() -> float:
    return sqrt(3.0) * outer_radius

# Distance from center to the closest point of the sides of the outer_radius
func outer_radius_interior_circle() -> float:
    # = outer_radius * 0.86
    return outer_radius * sqrt(3.0) / 2.0

# Distance from center to the closest point of the sides of the inner_radius
func inner_radius_interior_circle() -> float:
    # = inner_radius * 0.86
    return inner_radius * sqrt(3.0) / 2.0

func transition_height(adjacent: float) -> float:
    if adjacent < 0.0:
        return height * (1.0 - transition_height_factor) * adjacent
    elif adjacent > 0.0:
        return height * transition_height_factor * adjacent
    else:
        return 0.0

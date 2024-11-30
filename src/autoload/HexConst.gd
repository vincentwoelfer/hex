# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# See https://www.redblobgames.com/grids/hexagons/
# We use flat-top orientation

# Distance from center to the corners.
# This is the same as the length of the sides.
# Also known as "size"
var outer_radius: float = 1.5

# Radius of the workable Regular area. Distance from center to the sides.
# Must be smaller than outer_radius * 0.86 (size of largest circle in outer hex)
var inner_radius: float = 1.1

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
var extra_verts_per_center := 7

# Interpolation for vertex height between 0 / border height and Barycentric Coords
var smooth_height_factor_inner := 1.0
var smooth_height_factor_outer := 1.0

var trans_type_max_height_diff := 4


# NOT HEX CONST - here for editing in edior and hex-geom regeneration triggering
# 1D-Density. Instances per meter
var grass_density := 10.0


var chunk_size: int = 2


# Use smooth groups
var smooth_vertex_normals: bool = false
# ========================================================
# ==================== Actual Constants ==================
# ========================================================
const MAP_MIN_HEIGHT: int = 1
const MAP_MAX_HEIGHT: int = 20

const MAP_OCEAN_HEIGHT: int = 0
const MAP_INVALID_HEIGHT: int = -999

# Includes one circle of ocean
# Size = n means n circles around the map origin. So n=1 means 7 tiles (one origin tile and 6 additional tiles)
const MAP_SIZE: int = 3


# ========================================================
# ==================== Derived values ====================
# ========================================================

# Full horizontal (along East-West) size of hexagon = width
func horizontal_size() -> float:
    return 1.5 * outer_radius

# Full vertical (along North-South) size of hexagon = "height"
func vertical_size() -> float:
    return sqrt(3.0) * outer_radius

# Convert distance in meters to distance in hex-tiles (center to center)
func distance_m_to_hex(dist_m: float) -> int:
    return round(dist_m / vertical_size())

# Convert distance in hex-tiles (center to center) to distance in meters
func distance_hex_to_m(dist_hex: int) -> float:
    return dist_hex * vertical_size()

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

# +3 because each corner hast 2 extra verts but we only want
# the first 2 from the starting corner and the one missing from the enxt corner
func total_verts_per_side() -> int:
    return 3 + HexConst.extra_verts_per_side

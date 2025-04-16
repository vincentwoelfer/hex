@tool
class_name HexConst
extends Node

# See https://www.redblobgames.com/grids/hexagons/
# We use flat-top orientation

# Distance from center to the corners.
# This is the same as the length of the sides.
# Also known as "size"
static var outer_radius: float = 2.5

# Distance from center to the sides.
# Radius of the workable Regular area.
# Must be smaller than outer_radius * 0.86 (size of largest circle in outer hex)
static var inner_radius: float = 2.15

# Height of one hex cell
static var height: float = 0.5

# Transition points are at height * this factor above zero.
# 0.5 = in the middle
# 0.1 = almost above ground | reaching down a lot
static var transition_height_factor: float = 0.5

# Between 0 (hard hexagon) and 1 (circle)
static var core_circle_smooth_strength := 0.5

# Extra vertices per hexagon side
static var extra_verts_per_side := 3

# Extra vertices per hexagon center
static var extra_verts_per_center := 7

# Interpolation for vertex height between 0 / border height and Barycentric Coords
static var smooth_height_factor_inner := 1.0
static var smooth_height_factor_outer := 1.0

# Maximum height difference for smooth transitions
static var trans_type_max_height_diff := 7.0

# Use smooth groups
static var smooth_vertex_normals: bool = false

# ========================================================
# ==================== Actual Constants ==================
# ========================================================
const CHUNK_SIZE: int = 4

const MAP_HEIGHT_MIN: int = 1
const MAP_HEIGHT_MAX: int = 18
const MAP_HEIGHT_INVALID: int = -999


# ==================== GROUPS ========================
const GROUP_NAV_CHUNKS: String = "nav_chunks"
const GROUP_PLAYERS: String = "players"
const GROUP_ENEMIES: String = "enemies"
const GROUP_CRYSTALS: String = "crystals"
const GROUP_ESCAPE_PORTALS: String = "escape_portals"

# ==================== Navigation ========================
# These must be multiples of each others
const NAV_CELL_SIZE: float = 0.1
const NAV_AGENT_RADIUS: float = 0.8

# Define a basis slope angle, then give the agents more ability (to compensate for small path errors)
# but also reduce the nav-mesh generation a bit to avoid too steep slopes
const NAV_AGENT_MAX_SLOPE_BASIS_DEG := 47.5
const NAV_AGENT_MAX_SLOPE_ACTUAL_OFFSET_DEG := 12.5
const NAV_AGENT_MAX_SLOPE_NAV_MESH_OFFSET_DEG := -2.5


# ==================== STUFF =============================
const MAP_CENTER: Vector3 = Vector3(-10, 0, -10)


# ========================================================
# ==================== Derived values ====================
# ========================================================

# Full horizontal (along East-West) size of hexagon = width
static func horizontal_size() -> float:
    return 1.5 * outer_radius


# Full vertical (along North-South) size of hexagon = "height"
static func vertical_size() -> float:
    return sqrt(3.0) * outer_radius


# Convert distance in meters to distance in hex-tiles (center to center)
static func distance_m_to_hex(dist_m: float) -> int:
    return round(dist_m / vertical_size())


# Convert distance in hex-tiles (center to center) to distance in meters
static func distance_hex_to_m(dist_hex: int) -> float:
    return dist_hex * vertical_size()


# Distance from center to the closest point of the sides of the outer_radius
static func outer_radius_interior_circle() -> float:
    # = outer_radius * 0.86
    return outer_radius * sqrt(3.0) / 2.0


# Distance from center to the closest point of the sides of the inner_radius
static func inner_radius_interior_circle() -> float:
    # = inner_radius * 0.86
    return inner_radius * sqrt(3.0) / 2.0


static func transition_height(adjacent: float) -> float:
    if adjacent < 0.0:
        return height * (1.0 - transition_height_factor) * adjacent
    elif adjacent > 0.0:
        return height * transition_height_factor * adjacent
    else:
        return 0.0


# +3 because each corner hast 2 extra verts but we only want
# the first 2 from the starting corner and the one missing from the enxt corner
static func total_verts_per_side() -> int:
    return 3 + HexConst.extra_verts_per_side


static func dir_to_corner_index(i: int) -> int:
    return i * HexConst.total_verts_per_side()

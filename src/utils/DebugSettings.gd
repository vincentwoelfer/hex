@tool
class_name DebugSettings
extends Node

# Generate stuff. Normal = true
static var enable_rocks: bool = true

static var enable_grass: bool = false
# 1D-Density. Instances per meter
static var grass_density := 8.0

# Debug Visualization. Normal = false
static var use_distinc_hex_colors: bool = false
static var use_chunk_colors: bool = true
static var visualize_hex_input: bool = false
static var visualize_plant_custom_aabb: bool = false

static var enable_debug_collision_visualizations: bool = false
static var enable_terrain_collision_visualizations: bool = false

# Navigation visualization
static var show_raw_debug_path: bool = false

static var show_path_caravan: bool = true
static var show_path_basic_enemy: bool = false
static var show_path_player_to_caravan: bool = true

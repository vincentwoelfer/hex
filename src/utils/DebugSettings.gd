@tool
class_name DebugSettings
extends Node

static var low_performance_mode: bool = RenderingServer.get_video_adapter_type() != RenderingDevice.DEVICE_TYPE_DISCRETE_GPU

# Generate stuff. Normal = true
static var enable_rocks: bool = true

static var enable_grass: bool = false
# 1D-Density. Instances per meter
static var grass_density := 8.0

# Debug Visualization. Normal = false
static var use_distinc_hex_colors: bool = false
static var use_chunk_colors: bool = false
static var visualize_hex_input: bool = false
static var visualize_plant_custom_aabb: bool = false

static var enable_terrain_collision_visualizations: bool = true

# Navigation visualization
static var nav_server_debug_mode: bool = false
static var show_raw_debug_path: bool = false

static var show_path_caravan: bool = true
static var show_path_basic_enemy: bool = false
static var show_path_player_to_caravan: bool = false

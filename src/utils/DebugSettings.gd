@tool
class_name DebugSettings
extends Node

# Generate stuff. Normal = true
static var enable_grass: bool = false
static var enable_rocks: bool = false
static var generate_collision: bool = false

# Performance
static var generate_terrain_occluder: bool = false

# Debug Visualization. Normal = false
static var use_distinc_hex_colors: bool = true
static var use_chunk_colors: bool = true
static var visualize_hex_input: bool = false
static var visualize_plant_custom_aabb: bool = false
static var visualize_collision_shapes: bool = false

# Environment
static var fixed_sun_energy: bool = false

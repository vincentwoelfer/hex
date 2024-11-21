@tool
class_name DebugSettings
extends Node

# Generate stuff. Normal = true
static var enable_grass: bool = true
static var enable_rocks: bool = true
static var generate_collision: bool = true

# Performance
static var generate_terrain_occluder: bool = false

# Debug Visualization. Normal = false
static var use_distinc_hex_colors: bool = false
static var visualize_hex_input: bool = false
static var visualize_plant_custom_aabb: bool = false

# Environment
static var fixed_sun_energy: bool = false

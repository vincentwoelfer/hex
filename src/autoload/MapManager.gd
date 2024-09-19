# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

# This is the radius of the hex-map
#const map_size: int = 3

var map: HexMap = HexMap.new()

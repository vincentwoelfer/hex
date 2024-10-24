# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

const MIN_HEIGHT: int = 1
const MAX_HEIGHT: int = 20

const OCEAN_HEIGHT: int = 0
const INVALID_HEIGHT: int = -1

# Includes one circle of ocean
# Size = n means n circles around the map origin. So n=1 means 7 tiles (one origin tile and 6 additional tiles)
const MAP_SIZE: int = 8
# 12 for most performance tests in the past

var map: HexMap = HexMap.new()

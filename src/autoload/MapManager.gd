# Needs to be tool to read these in other tool scripts!
# No class_name here, the name of the singleton is set in the autoload
@tool
extends Node

const MIN_HEIGHT: int = 1
const MAX_HEIGHT: int = 20

const OCEAN_HEIGHT: int = 0
const INVALID_HEIGHT: int = -1

# Includes one circle of ocean
const MAP_SIZE: int = 5

var map: HexMap = HexMap.new()

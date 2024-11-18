class_name HexTileParams

var humidity: float
var shade: float
var nutrition: float
var is_secret_stash: bool # Just a gimmick
var tile_type: String = "Meadow"


func _init() -> void:
	humidity = randf_range(0.2, 0.9)
	shade = randf_range(0.2, 0.9)
	nutrition = randf_range(0.2, 0.9)
	is_secret_stash = randf() < 0.1

	# Doesnt do anything, surprise Nek
	if humidity <= 0.1:
		tile_type = "Dry Meadow"

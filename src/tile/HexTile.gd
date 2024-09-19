class_name HexTile

######################################################
# Parent / Struct class holding everything a hex tile can be/posess
######################################################

# Core Variables
var hexpos: HexPos
var height: int

# Visual Representation
var geometry: HexGeometry

# Field conditions
var humidity: float
var shade: float
var nutrition: float

func _init(hexpos_: HexPos, height_: int) -> void:
    self.hexpos = hexpos_
    self.height = height_

    self.geometry = null

    self.humidity = randf()
    self.shade = randf()
    self.nutrition = randf()


func calculate_shadow(sun_intensity: float) -> float:
    return sun_intensity * shade


#######################
####################### Feld:
# klima-bedingungen
# humidity
# Schatten  (wie viele Bäume)
# nutrition = wie gut wachsen sachen, erde vs sand/stein

# Was da drauf ist.
#

# Derived
# => aktuellen lichteinfall = Sonne - Schatten

#######################
####################### Allgemeint Wetter:
# Temperatur
# Aktueller Regenfall -> mehr wasser
# Aktuelle Sonne -> weniger wasser, mehr licht 

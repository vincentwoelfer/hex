class_name HexMap

# Hash-Map of Hexes. Key = int, Value = Hex
var tiles: Dictionary = {}

class HexTile:
    var hexpos: HexPos
    var height: int

    func _init(hexpos_: HexPos, height_: int) -> void:
        hexpos = hexpos_
        height = height_


func add_hex(hex: HexPos, height : int) -> void:
    var key: int = hex.hash()

    if tiles.has(key):
        print("Map already has tile at r: %d, q: %d, s:%d!" % [hex.r, hex.q, hex.s])
        return

    tiles[key] = HexTile.new(hex, height)


func get_hex(hex: HexPos) -> HexTile:
    var key: int = hex.hash()

    if not tiles.has(key):
        #print("Map has no tile at r: %d, q: %d, s:%d!" % [hex.r, hex.q, hex.s])
        return HexTile.new(null, -1)

    return tiles[key]

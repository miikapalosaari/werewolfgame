extends Node2D

var playerID: int
var isAlive: bool = true

func _enter_tree() -> void:
	playerID = name.to_int()
	set_multiplayer_authority(playerID)

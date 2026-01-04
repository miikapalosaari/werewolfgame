extends Node

var localGameState: Dictionary = {}

# Called when the server sends a full or partial game state update
@rpc("authority", "call_remote")
func updateState(newGameState: Dictionary):
	print("ClientManager: Received new game state")
	localGameState = newGameState

	# Forward to the active scene if it has a handler
	var scene = get_tree().current_scene
	if scene and scene.has_method("applyGameState"):
		scene.applyGameState(newGameState)

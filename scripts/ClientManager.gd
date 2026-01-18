extends Node

var localState: Dictionary = {}

# Called when the server sends a full or partial game state update
@rpc("any_peer", "call_remote")
func updateState(newState: Dictionary):
	localState = newState

	# Forward to the active scene if it has a handler
	var scene = get_tree().current_scene
	if scene and scene.has_method("applyState"):
		scene.applyState(newState)

@rpc("any_peer")
func requestDayDecision():
	var scene = get_tree().current_scene
	if scene and scene.has_method("requestDayDecision"):
		scene.requestDayDecision()
	else:
		print("Client: MainScene not ready for day decision")

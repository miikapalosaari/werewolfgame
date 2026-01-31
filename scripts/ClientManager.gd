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

@rpc("any_peer")
func requestClientResetUI():
	var scene = get_tree().current_scene
	if scene and scene.has_method("resetUI"):
		scene.resetUI()
	else:
		print("Client: MainScene not ready for resetUI")

@rpc("any_peer")
func requestClientToSleep():
	var scene = get_tree().current_scene
	if scene and scene.has_method("sleepClient"):
		scene.sleepClient()

@rpc("any_peer")
func requestClientToWake():
	var scene = get_tree().current_scene
	if scene and scene.has_method("wakeClient"):
		scene.wakeClient()

@rpc("any_peer")
func onGameEnded(winner: String):
	print("Game ended! Winner:", winner)
	var scene = get_tree().current_scene
	if scene and scene.has_method("showGameOver"):
		scene.showGameOver(winner)

@rpc("any_peer")
func returnToLobby():
	print("Returning to lobby")
	var scene = get_tree().current_scene
	if scene and scene.has_node("WinnerLayer"):
		scene.get_node("WinnerLayer").visible = false
	get_tree().change_scene_to_file("res://scenes/LobbyScene.tscn")

extends Node

var playersReady: Dictionary = {}
var serverGameState: Dictionary = {}

func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		return
	print("GameManager loaded")
	
	RolesManager.loadAllRoles()
	print("Found Roles:")
	
	for key in RolesManager.roles.keys():
		var role = RolesManager.roles[key]
		print("ID:", role["id"])

@rpc("any_peer")
func requestFullState():
	var peerID = multiplayer.get_remote_sender_id()
	ClientManager.rpc_id(peerID, "updateState", serverGameState)

@rpc("any_peer", "call_remote")
func playerReady():
	var peerID = multiplayer.get_remote_sender_id()
	playersReady[peerID] = true
	print("Player ready:", peerID)
	checkIfAllReady()

@rpc("any_peer")
func startGame():
	if not OS.has_feature("dedicated_server"):
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")

func checkIfAllReady():
	if playersReady.size() == multiplayer.get_peers().size():
		print("All players ready, starting game")
		rpc("startGame")
		

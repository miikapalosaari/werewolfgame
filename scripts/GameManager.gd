extends Node

var playersReady: Dictionary = {} 

func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		return
	print("MainScene loaded...")
	
	RolesManager.loadAllRoles()
	print("Found Roles:")
	
	for key in RolesManager.roles.keys():
		var role = RolesManager.roles[key]
		print("ID:", role["id"])

func _process(delta: float) -> void:
	pass
	
@rpc("any_peer", "call_remote")
func playerReady():
	var peerID = multiplayer.get_remote_sender_id()
	playersReady[peerID] = true
	print("Player ready:", peerID)
	checkIfAllReady()

func checkIfAllReady():
	if playersReady.size() == multiplayer.get_peers().size():
		print("All players ready, starting game")
		rpc("startGame")

@rpc("any_peer")
func startGame():
	if not OS.has_feature("dedicated_server"):
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")

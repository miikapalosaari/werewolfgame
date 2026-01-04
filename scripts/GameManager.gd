extends Node

var serverGameState: Dictionary = {
	"players": {},
	"roles": {},
	"phase": "lobby",
	"round": 0
}

var lobbyState: Dictionary = {
	"players": {},
	"leader": null
}

func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		return
	multiplayer.peer_connected.connect(playerConnected)
	multiplayer.peer_disconnected.connect(playerDisconnected)
	print("GameManager loaded")
	
	RolesManager.loadAllRoles()
	print("Found Roles:")
	
	for key in RolesManager.roles.keys():
		var role = RolesManager.roles[key]
		print("ID:", role["id"])

# RPC : Client requests full state
@rpc("any_peer")
func requestFullState():
	var peerID = multiplayer.get_remote_sender_id()
	if serverGameState["phase"] == "lobby":
		ClientManager.rpc_id(peerID, "updateState", lobbyState)
	else:
		ClientManager.rpc_id(peerID, "updateState", serverGameState)

# RPC : Client presses ready button
@rpc("any_peer", "call_remote")
func playerReady():
	var peerID = multiplayer.get_remote_sender_id()
	lobbyState["players"][peerID]["ready"] = true
	print("Player ready:", peerID)
	broadcastLobbyState()
	checkIfAllReady()

# RPC : Start game for clients
@rpc("any_peer")
func startGame():
	if not OS.has_feature("dedicated_server"):
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
		
		
func playerConnected(id) -> void:
	lobbyState["players"][id] = {
		"name": str(id),
		"ready": false
	}
	
	if lobbyState["leader"] == null:
		lobbyState["leader"] = id
	
	broadcastLobbyState()

func playerDisconnected(id) -> void:
	lobbyState["players"].erase(id)
	
	if lobbyState["leader"] == id:
		var peers = multiplayer.get_peers()
		if peers.size() > 0:
			lobbyState["leader"] = peers[0]
		else:
			lobbyState["leader"] = null
	broadcastLobbyState()

func checkIfAllReady():
	for id in lobbyState["players"].keys():
		if not lobbyState["players"][id]["ready"]:
			return
	print("All players ready, starting game")
	rpc("startGame")
		

func broadcastLobbyState():
	for peerID in multiplayer.get_peers():
		ClientManager.rpc_id(peerID, "updateState", lobbyState)

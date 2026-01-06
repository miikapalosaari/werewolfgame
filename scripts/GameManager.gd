extends Node

enum GamePhase {
	LOBBY,
	STARTING,
	NIGHT,
	DAY,
	VOTING,
	ENDED
}

var currentPhase: GamePhase = GamePhase.LOBBY
var currentRound: int = 0
var players: Dictionary = {}
var lobbyLeader: int = -1

var roles: Dictionary = {}
var pendingActions: Array = []
var votes: Dictionary = {}
var roleCounts: Dictionary = {}

func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		return
	
	NetworkManager.playerConnected.connect(onPlayerConnected)
	NetworkManager.playerDisconnected.connect(onPlayerDisconnected)
	print("GameManager loaded")
	
	roles = RolesManager.loadAllRoles()
	print("Found Roles:")
	
	for key in roles.keys():
		var role = roles[key]
		print("ID:", role["id"])

# RPC : Client can request full state
@rpc("any_peer")
func requestFullState():
	var peerID = multiplayer.get_remote_sender_id()
	ClientManager.rpc_id(peerID, "updateState", buildStateSnapshot(peerID))

# RPC : Client presses ready button
@rpc("any_peer", "call_remote")
func playerReady():
	var peerID = multiplayer.get_remote_sender_id()
	if currentPhase != GamePhase.LOBBY:
		return
	if not players.has(peerID):
		return
		
	players[peerID].ready = true
	print("Player ready:", peerID)
	broadcastState()
	if checkIfAllReady():
		rpc("startGame")

# RPC : Start game for clients
#@rpc("authority", "call_remote")
@rpc("any_peer")
func startGame():
	print("Starting game")
	currentPhase = GamePhase.STARTING
	currentRound = 1
	if not OS.has_feature("dedicated_server"):
		get_tree().change_scene_to_file("res://scenes/MainScene.tscn")
	broadcastState()
		
@rpc("any_peer", "call_remote")
func updateRoleCounts(newCounts: Dictionary):
	if multiplayer.get_remote_sender_id() != lobbyLeader:
		print("Only lobby leader can update role counts")
		return

	roleCounts = newCounts
	print("Updated role counts:", roleCounts)
	broadcastState()

		
func onPlayerConnected(peerID) -> void:
	print("Player connected (" + str(peerID) + ")")
	players[peerID] = {
		"name": str(peerID),
		"role": "",
		"alive": true,
		"ready": false
	}
	
	if lobbyLeader == -1:
		lobbyLeader = peerID
	broadcastState()

func onPlayerDisconnected(peerID) -> void:
	print("Player disconnected (" + str(peerID) + ")")
	players.erase(peerID)
	
	if peerID == lobbyLeader:
		lobbyLeader = pickNewLeader()
		
	if players.is_empty():
		resetGame()
	else:
		broadcastState()

func checkIfAllReady() -> bool:
	for id in players.values():
		if not id.ready:
			return false
	return true

func buildStateSnapshot(peerID: int) -> Dictionary:
	return {
		"phase": currentPhase,
		"round": currentRound,
		"players": players,
		"leader": lobbyLeader,
		"roles": roles,
		"roleCounts": roleCounts,
		"selfID": peerID
	}

func broadcastState():
	for peerID in multiplayer.get_peers():
		ClientManager.rpc_id(peerID, "updateState", buildStateSnapshot(peerID))

func resetGame() -> void:
	currentPhase = GamePhase.LOBBY
	currentRound = 0
	players.clear()
	lobbyLeader = -1
	
func pickNewLeader() -> int:
	if players.is_empty():
		return -1

	var peerIDs := players.keys()
	peerIDs.sort()
	return peerIDs[0]

func assignRoles() -> void:
	var peerIDs = players.keys()

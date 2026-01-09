extends Node

enum GamePhase {
	LOBBY,
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
var clientSelections: Dictionary = {}
var selectionTimer: Timer 

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
		
	selectionTimer = Timer.new()
	selectionTimer.one_shot = true
	add_child(selectionTimer)
	selectionTimer.connect("timeout", Callable(self, "onSelectionTimerTimeout"))

# RPC : Client can request full state
@rpc("any_peer")
func requestFullState():
	var peerID = multiplayer.get_remote_sender_id()
	ClientManager.rpc_id(peerID, "updateState", buildStateSnapshot(peerID))

# RPC : Client presses ready button
@rpc("any_peer")
func playerReady():
	if not multiplayer.is_server():
		return
	var peerID = multiplayer.get_remote_sender_id()
	if currentPhase != GamePhase.LOBBY:
		return
	if not players.has(peerID):
		return
		
	players[peerID].ready = true
	print("Player ready:", peerID)
	broadcastState()
	if checkIfAllReady():
		startGame()

# RPC : Start game for clients
@rpc("any_peer")
func startGame():
	if not multiplayer.is_server():
		return
	print("Starting game")
	currentRound = 1
	assignRoles()
	startNight()
	broadcastState()
	
	rpc("clientStartGame")

@rpc("any_peer")
func clientStartGame():
	if OS.has_feature("dedicated_server"):
		return
	get_tree().change_scene_to_file("res://scenes/MainScene.tscn")

@rpc("any_peer")
func updateRoleCounts(newCounts: Dictionary):
	if not multiplayer.is_server():
		return
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

func canSeeRole(viewerID: int, targetID: int) -> bool:
	var viewerRole = players[viewerID]["role"]
	var targetRole = players[targetID]["role"]
	
	# If roles are not assigned yet or invalid, hide everything except yourself
	if not roles.has(viewerRole) or not roles.has(targetRole):
		return viewerID == targetID

	# Everyone can see their own role
	if viewerID == targetID:
		return true
		
	var viewerData = roles[viewerRole]
	var targetData = roles[targetRole]

	# If viewer's role has canSeeTeam set to false
	if not viewerData.get("canSeeTeam", false):
		return false
		
	return viewerData.get("team", "") == targetData.get("team", "")

func buildStateSnapshot(peerID: int) -> Dictionary:
	var filteredPlayers: Dictionary = {}
	for id in players.keys():
		var p = players[id].duplicate()
		if not canSeeRole(peerID, id):
			p["role"] = "hidden"
		filteredPlayers[id] = p
	
	return {
		"phase": currentPhase,
		"round": currentRound,
		"players": filteredPlayers,
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
	print("Assigning roles:")
	var rolePool: Array = []
	for roleID in roleCounts.keys():
		var count = roleCounts[roleID]
		for i in range(count):
			rolePool.append(roleID)
			
	rolePool.shuffle()
	
	var peerIDs = players.keys()
	peerIDs.shuffle()
	for i in range(min(peerIDs.size(), rolePool.size())):
		var peerID = peerIDs[i]
		players[peerID]["role"] = rolePool[i]
		print("Assigned ", rolePool[i], " to ", peerID)

@rpc("any_peer")
func requestClientSelection():
	if OS.has_feature("dedicated_server"):
		return
	var scene = get_tree().current_scene
	if scene and scene.has_method("clientSendSelection"):
		scene.clientSendSelection()
	else:
		print("Client: no clientSendSelection() on current scene")

@rpc("any_peer")
func sendClientSelection(selection: Array):
	if not multiplayer.is_server():
		return
	var peerID = multiplayer.get_remote_sender_id()
	receiveClientSelection(peerID, selection)

func receiveClientSelection(peerID: int, selection: Array) -> void:
	clientSelections[peerID] = selection

func startSelectionTimer(seconds: float) -> void:
	selectionTimer.wait_time = seconds
	selectionTimer.start()

func onSelectionTimerTimeout():
	if not multiplayer.is_server():
		return
	print("Selecting time over, requesting selections from clients")
	for peerID in multiplayer.get_peers():
		rpc_id(peerID, "requestClientSelection")
		
	await get_tree().create_timer(2.0).timeout
	fillMissingSelections()
	
	match currentPhase:
		GamePhase.NIGHT:
			resolveNight()

func printAllSelections(selections: Dictionary):
	print("All Player Selections")
	for peerID in selections.keys():
		var selection: Array = selections[peerID]
		print("Player ", peerID, " selected: ", selection)

func fillMissingSelections():
	for peerID in players.keys():
		if not clientSelections.has(peerID):
			clientSelections[peerID] = []

func startNight() -> void:
	if not multiplayer.is_server():
		return
		
	print("Starting Night Phase")
	currentPhase = GamePhase.NIGHT
	clientSelections.clear()
	startSelectionTimer(30)
	broadcastState()

func startDay() -> void:
	if not multiplayer.is_server():
		return
	print("Starting Day Phase")

func startVoting() -> void:
	if not multiplayer.is_server():
		return

func getMostCommonSelection(selections: Array) -> Dictionary:
	var counts: Dictionary = {}
	for s in selections:
		counts[s] = counts.get(s, 0) + 1

	var highest: int = counts.values().max()
	var mostCommon: Array = []

	for key in counts.keys():
		if counts[key] == highest:
			mostCommon.append(key)

	return {
		"mostCommon": mostCommon,
		"count": highest,
		"tie": mostCommon.size() > 1
	}


func resolveNight() -> void:
	if not multiplayer.is_server():
		return
	print("Starting to resolve night selections")
	printAllSelections(clientSelections)
	
	var killSelections: Array = []
	for peerID in players.keys():
		var player = players[peerID]
		var roleID = player["role"]
		var role = roles[roleID]

		if not role.get("actsAtNight", false):
			print("Player ", peerID, " does not actAtNight")
			continue
		
		if not clientSelections.has(peerID):
			continue
			
		killSelections.append_array(clientSelections[peerID])
	
	if killSelections.is_empty():
		print("No night actions submitted")
		advancePhase()
		return
	
	var result = getMostCommonSelection(killSelections)
	if result["tie"]:
		print("Tie between:", result["mostCommon"])
		print("Nobody dies")
	else:
		print("Most common:", result["mostCommon"][0])
		print("Player ", result["mostCommon"][0], " dies")
		players[result["mostCommon"][0]]["alive"] = false
	broadcastState()
	advancePhase()

func resolveVote() -> void:
	if not multiplayer.is_server():
		return

func advancePhase() -> void:
	match currentPhase:
		GamePhase.NIGHT:
			startDay()
		GamePhase.DAY:
			startVoting()
		GamePhase.VOTING:
			startNight()

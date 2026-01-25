extends Node

enum GamePhase {
	LOBBY,
	NIGHT,
	DAY,
	VOTING,
	ENDED
}

const GamePhaseNames := {
	GamePhase.LOBBY: "Lobby",
	GamePhase.NIGHT: "Night",
	GamePhase.DAY: "Day",
	GamePhase.VOTING: "Voting",
	GamePhase.ENDED: "Ended"
}

func getCurrentPhaseString() -> String:
	return GamePhaseNames[currentPhase]

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
var pendingTimerStart: Dictionary = {}
var dayDecisions: Dictionary = {}
var nightOrder: Array = []
var currentNightActorIndex: int = 0
var mainScenesLoaded: Dictionary = {}

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
		rpc("clientStartGame")
		
		
@rpc("any_peer")
func clientMainSceneLoaded():
	var peerID = multiplayer.get_remote_sender_id()
	print("Server: client main scene loaded:", peerID)
	mainScenesLoaded[peerID] = true
	
	if mainScenesLoaded.size() == players.size():
		print("All clients ready. Starting game logic.")
		startGame()

# RPC : Start game for clients
@rpc("any_peer")
func startGame():
	if not multiplayer.is_server():
		return
	currentPhase = GamePhase.NIGHT
	print("Starting game")
	currentRound = 1
	assignRoles()
	buildNightOrder()
	startNight()
	broadcastState()

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
		"phase": getCurrentPhaseString(),
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
	mainScenesLoaded.clear()
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
func sendClientSelection(selection: Dictionary):
	if not multiplayer.is_server():
		return
	var peerID = multiplayer.get_remote_sender_id()
	receiveClientSelection(peerID, selection)

func receiveClientSelection(peerID: int, selection: Dictionary) -> void:
	clientSelections[peerID] = selection

@rpc("any_peer")
func startSyncedTimer(server_start_msec: int, duration_msec: int):
	var scene = get_tree().current_scene
	if scene and scene.has_method("startSyncedTimer"):
		scene.startSyncedTimer(server_start_msec, duration_msec)
	else:
		pendingTimerStart = {
			"start": server_start_msec,
			"duration": duration_msec
		}
		print("Client: MainScene not ready for timer sync")

	
func startSelectionTimer(seconds: float) -> void:
	selectionTimer.wait_time = seconds
	selectionTimer.start()
	var now = Time.get_ticks_msec()
	var duration = int(seconds * 1000)
	rpc("startSyncedTimer", now, duration)

func onSelectionTimerTimeout():
	if not multiplayer.is_server():
		return

	match currentPhase:
		GamePhase.NIGHT:
			await get_tree().create_timer(1.0).timeout
			fillMissingSelections()
			startNextNightRole()
			
		GamePhase.DAY:
			print("Day discussion time over")
			await get_tree().create_timer(2.0).timeout
			resolveDayDecision()
			for peerID in multiplayer.get_peers():
				ClientManager.rpc_id(peerID, "requestClientResetUI")
				
		GamePhase.VOTING:
			print("Selecting time over, requesting selections from clients")
			for peerID in multiplayer.get_peers():
				rpc_id(peerID, "requestClientSelection")
			await get_tree().create_timer(2.0).timeout
			fillMissingSelections()
			resolveVote()
			for peerID in multiplayer.get_peers():
				ClientManager.rpc_id(peerID, "requestClientResetUI")

func printAllSelections(selections: Dictionary):
	print("All Player Selections")
	for peerID in selections.keys():
		var selection: Dictionary = selections[peerID]
		print("Player ", peerID, " selected: ", selection)

func fillMissingSelections():
	for peerID in players.keys():
		if not clientSelections.has(peerID):
			clientSelections[peerID] = {}

func buildNightOrder():
	nightOrder.clear()
	for roleID in roles.keys():
		var role = roles[roleID]
		if role.get("actsAtNight", false):
			nightOrder.append(roleID)
	nightOrder.sort_custom(func(a, b): return roles[a]["nightOrder"] < roles[b]["nightOrder"])

func startNight() -> void:
	if not multiplayer.is_server():
		return
	for peerID in players.keys():
		ClientManager.rpc_id(peerID, "requestClientToSleep")
		print("request sleep for: ", peerID)
	print("Starting Night Phase")
	clientSelections.clear()
	currentNightActorIndex = 0
	startNextNightRole()
	broadcastState()

@rpc("any_peer")
func sendDayDecision(decision: String):
	if not multiplayer.is_server():
		return
	var peerID = multiplayer.get_remote_sender_id()
	dayDecisions[peerID] = decision
	print("Received day decision from", peerID, ":", decision)

func resolveDayDecision():
	if not multiplayer.is_server():
		return

	var voteCount := {
		"vote": 0,
		"skip": 0
	}

	# Count votes from all alive players
	for peerID in players.keys():
		var decision: String = dayDecisions.get(peerID, "skip")
		voteCount[decision] += 1

	print("Day decision results:", voteCount)

	# Majority logic
	if voteCount["vote"] > voteCount["skip"]:
		print("Players chose to start voting")
		enterVoting()
	else:
		print("Players skipped voting, going to night")
		enterNight()


func startDay() -> void:
	if not multiplayer.is_server():
		return
	for peerID in players.keys():
		ClientManager.rpc_id(peerID, "requestClientToWake")
	print("Starting Day Phase")
	dayDecisions.clear()
	clientSelections.clear()
	for peerID in multiplayer.get_peers():
		ClientManager.rpc_id(peerID, "requestDayDecision")
	startSelectionTimer(60)
	broadcastState()

func startVoting() -> void:
	if not multiplayer.is_server():
		return
	print("Starting Voting Phase")
	clientSelections.clear()
	startSelectionTimer(15)
	broadcastState()

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

func startNextNightRole():
	# Loop until role with at least one alive player is found, or the end is reached
	while currentNightActorIndex < nightOrder.size():
		var roleID = nightOrder[currentNightActorIndex]
		
		# Find all alive players with this role
		var alivePlayersWithRole := []
		for peerID in players.keys():
			if players[peerID]["alive"] and players[peerID]["role"] == roleID:
				alivePlayersWithRole.append(peerID)
				
		# Skip roles with no alive players
		if alivePlayersWithRole.is_empty():
			print("Skipping role ", roleID, "- no assigned or alive players")
			currentNightActorIndex += 1
			continue

		for peerID in players.keys():
			ClientManager.rpc_id(peerID, "requestClientToSleep")
		
		print("Night: waking up ", roleID)
		for peerID in alivePlayersWithRole:
			ClientManager.rpc_id(peerID, "requestClientToWake")
			print("request wake for: ", peerID)
			rpc_id(peerID, "requestClientSelection")
		currentNightActorIndex += 1
		startSelectionTimer(15)
		return
	resolveNight()

func resolveNight() -> void:
	if not multiplayer.is_server():
		return
	print("Starting to resolve night")
	
	var collected: Dictionary = {}
	# Collect selections per action
	for peerID in players.keys():
		if not clientSelections.has(peerID):
			continue
		var roleID = players[peerID]["role"]
		var role = roles[roleID]

		if not role.get("nightActions"):
			continue
			
		for action in role["nightActions"]:
			var type = action["type"]
			if not collected.has(type):
				collected[type] = []
			if clientSelections[peerID].has(type):
				collected[type].append(clientSelections[peerID][type])

	# Resolve each action using its resolution rule
	for actionType in collected.keys():
		var resolution: String = "majorityWins"
		var found: bool = false
		for peerID in players.keys():
			if found:
				break
			var roleID = players[peerID]["role"]
			var role = roles[roleID]

			if role.has("nightActions"):
				for action in role["nightActions"]:
					if action["type"] == actionType:
						resolution = action["resolution"]
						found = true
						break
		resolveAction(actionType, resolution, collected[actionType])
			
	clientSelections.clear()
	#broadcastState()
	advancePhase()

func resolveVote() -> void:
	if not multiplayer.is_server():
		return
		
	var votes: Array = []

	for peerID in players.keys():
		var sel = clientSelections.get(peerID, {})
		if sel.has("vote"):
			votes.append(sel["vote"])

	resolveMajorityWins("vote", votes)
	advancePhase()

func enterNight():
	currentPhase = GamePhase.NIGHT
	print("== ENTER NIGHT ==")

	for peerID in players.keys():
		ClientManager.rpc_id(peerID, "requestClientToSleep")

	clientSelections.clear()
	currentNightActorIndex = 0
	buildNightOrder()
	startNextNightRole()
	broadcastState()

func enterDay():
	currentPhase = GamePhase.DAY
	print("== ENTER DAY ==")

	for peerID in players.keys():
		ClientManager.rpc_id(peerID, "requestClientToWake")

	dayDecisions.clear()
	clientSelections.clear()
	startSelectionTimer(10)
	broadcastState()

	for peerID in multiplayer.get_peers():
		ClientManager.rpc_id(peerID, "requestDayDecision")

func enterVoting():
	currentPhase = GamePhase.VOTING
	print("== ENTER VOTING ==")

	clientSelections.clear()
	startSelectionTimer(15)
	broadcastState()


func advancePhase() -> void:
	match currentPhase:
		GamePhase.NIGHT:
			enterDay()
		GamePhase.DAY:
			enterVoting()
		GamePhase.VOTING:
			enterNight()


func resolveAction(actionType: String, resolution: String, selections: Array) -> void:
	match resolution:
		"majorityWins":
			resolveMajorityWins(actionType, selections)
		"individual":
			resolveIndividual(actionType, selections)
		_:
			print("Unknown resolution:", resolution)
			
func resolveMajorityWins(actionType: String, selections: Array) -> void:
	if selections.is_empty():
		print("No selections for", actionType)
		return
		
	var result := getMostCommonSelection(selections)
	if result["tie"]:
		print("Tie in ", actionType, " - no effect")
		return

	var targetID: int = result["mostCommon"][0]
	match actionType:
		"kill":
			if players.has(targetID) and players[targetID]["alive"]:
				players[targetID]["alive"] = false
				print("Player ", targetID, " was killed")
		"vote":
			if players.has(targetID) and players[targetID]["alive"]:
				players[targetID]["alive"] = false
				print("Player ", targetID, " was voted off")

func resolveIndividual(actionType: String, selections: Array) -> void:
	if selections.is_empty():
		print("No selections for ", actionType)
		return

	for targetID in selections:
		match actionType:
			"investigate":
				if players.has(targetID):
					var targetRole: String = players[targetID]["role"]
					for actorID in clientSelections.keys():
						if clientSelections[actorID].get(actionType) == targetID:
							print("Player ", actorID, " selected ", targetID, " -> role: ", targetRole)

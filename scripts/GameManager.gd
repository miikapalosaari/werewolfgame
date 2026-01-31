extends Node

var colorPool: Array = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.ORANGE,
	Color.PURPLE,
	Color.CYAN,
	Color.MAGENTA,
	Color.BROWN,
	Color.DARK_GREEN,
	Color.DARK_BLUE,
	Color.DARK_RED,
	Color.PINK,
	Color.TEAL,
	Color.GOLD,
	Color.SKY_BLUE,
	Color.LIME,
	Color.MAROON,
	Color.NAVY_BLUE,
	Color.GRAY
]

var availableColors: Array = []
var playerColors: Dictionary = {}

enum GamePhase {
	LOBBY,
	NIGHT_ROLE,
	NIGHT_RESOLVE,
	DAY_DECISION,
	VOTING,
	TRANSITION,
	ENDED
}

const GamePhaseNames := {
	GamePhase.LOBBY: "Lobby",
	GamePhase.NIGHT_ROLE: "Night",
	GamePhase.NIGHT_RESOLVE: "NightResolve",
	GamePhase.DAY_DECISION: "Day",
	GamePhase.VOTING: "Voting",
	GamePhase.TRANSITION: "Transition",
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
var transitionTimer: Timer
var phaseLocked: bool = false
var currentNightRole: String = ""
var alivePlayersWithRole: Array = []


func debugPhase(msg: String):
	print("[PHASE] ", msg, " | CurrentPhase:", getCurrentPhaseString(), " | Round:", currentRound)

func debugPlayers(msg: String):
	print("[PLAYERS] ", msg, " | Players:", players.keys())

func debugSelections(msg: String):
	print("[SELECTIONS] ", msg, " | ClientSelections:", clientSelections)

func initPlayerColors():
	availableColors = colorPool.duplicate()
	availableColors.shuffle()
	playerColors.clear()

func assignColorToPlayer(peerID: int):
	if availableColors.is_empty():
		print("No more colors available!")
		return
		
	var color = availableColors.pop_back()
	playerColors[peerID] = color
	players[peerID]["color"] = color
	print("Assigned color", color, "to", peerID)

func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		return
	initPlayerColors()
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
	
	transitionTimer = Timer.new()
	transitionTimer.one_shot = true
	add_child(transitionTimer)
	transitionTimer.connect("timeout", Callable(self, "onTransitionTimerTimeout"))
	
	debugPhase("Ready function completed")

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
	print("Starting game")
	currentRound = 1
	assignRoles()
	buildNightOrder()
	debugPlayers("Assigned roles, starting first phase")
	enterPhase(GamePhase.NIGHT_ROLE)
	broadcastState()

@rpc("any_peer")
func clientStartGame():
	if OS.has_feature("dedicated_server"):
		return
	get_tree().change_scene_to_file("res://scenes/MainScene.tscn")

@rpc("any_peer")
func updateRoleCounts(roleID: String, value: int):
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != lobbyLeader:
		print("Only lobby leader can update role counts")
		return

	roleCounts[roleID] = value
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
	assignColorToPlayer(peerID)
	broadcastState()

func onPlayerDisconnected(peerID) -> void:
	print("Player disconnected (" + str(peerID) + ")")
	players.erase(peerID)
	
	if playerColors.has(peerID):
		var color = playerColors[peerID]
		availableColors.append(color)
		playerColors.erase(peerID)
	
	for selKey in clientSelections.keys():
		var selDict = clientSelections[selKey]
		var keysToErase = []
		for k in selDict.keys():
			if selDict[k] == peerID:
				keysToErase.append(k)
		for k in keysToErase:
			selDict.erase(k)

	clientSelections.erase(peerID)
	
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

func buildNightInfoForPeer(peerID):
	if currentPhase != GamePhase.NIGHT_ROLE:
		return {
			"awakeRole": "",
			"youAreAwake": false,
			"nightActionHint": ""
		}

	var hint := ""
	if roles.has(currentNightRole):
		hint = roles[currentNightRole].get("nightActionHint", "")

	return {
		"awakeRole": currentNightRole,
		"youAreAwake": alivePlayersWithRole.has(peerID),
		"nightActionHint": hint
	}


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
		"selfID": peerID,
		"nightInfo": buildNightInfoForPeer(peerID),
		"playerColors": playerColors
	}

func broadcastState():
	for peerID in multiplayer.get_peers():
		ClientManager.rpc_id(peerID, "updateState", buildStateSnapshot(peerID))

func resetGame() -> void:
	mainScenesLoaded.clear()
	currentPhase = GamePhase.LOBBY
	currentRound = 0
	clientSelections.clear()
	dayDecisions.clear()
	pendingTimerStart.clear()
	phaseLocked = false
	currentNightActorIndex = 0
	alivePlayersWithRole.clear()
	nightOrder.clear()
	currentNightRole = ""
	
	# Reset players
	for peerID in players.keys():
		players[peerID]["ready"] = false
		players[peerID]["alive"] = true
		players[peerID]["role"] = ""
	
	if players.size() > 0 and not players.has(lobbyLeader):
		lobbyLeader = pickNewLeader()
	
	for peerID in multiplayer.get_peers():
		ClientManager.rpc_id(peerID, "returnToLobby")
	
	broadcastState()

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
	debugSelections("Received selection from peer: " + str(peerID))
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
	debugPhase("Selection timer started for " + str(seconds) + "s")
	var now = Time.get_ticks_msec()
	var duration = int(seconds * 1000)
	rpc("startSyncedTimer", now, duration)

func onSelectionTimerTimeout():
	if not multiplayer.is_server():
		return

func enterPhase(phase: GamePhase):
	if not multiplayer.is_server():
		return
		
	if currentPhase == GamePhase.ENDED:
		debugPhase("Game ended, ignoring enterPhase")
		return
		
	if phaseLocked:
		debugPhase("Phase locked, cannot enter new phase: " + str(phase))
		return

	debugPhase("Entering phase: " + str(phase))
	currentPhase = phase
	phaseLocked = true

	match phase:
		GamePhase.NIGHT_ROLE:
			startNightRolePhase()

		GamePhase.DAY_DECISION:
			startDayPhase()

		GamePhase.VOTING:
			startVotingPhase()
			
		GamePhase.NIGHT_RESOLVE:
			startNightResolvePhase()
		_:
			print("[PHASE] Unknown phase: ", phase)

func startNightResolvePhase():
	resolveNight()
	
	for peerID in players.keys():
		ClientManager.rpc_id(peerID, "requestClientResetUI")
		ClientManager.rpc_id(peerID, "requestClientToWake")
	phaseLocked = false
	enterPhase(GamePhase.DAY_DECISION)


func startDayPhase():
	clientSelections.clear()
	dayDecisions.clear()
	broadcastState()

	startTransition(2.0, "fadeIn")
	await transitionTimer.timeout
	
	for peerID in multiplayer.get_peers():
		ClientManager.rpc_id(peerID, "requestDayDecision")
		
	broadcastState()
	
	startSelectionTimer(10.0)
	await selectionTimer.timeout
	
	await get_tree().create_timer(2.0).timeout
	var result = resolveDayDecision()
	
	startTransition(2.0, "fadeOut")
	await transitionTimer.timeout
	
	phaseLocked = false
	currentPhase = result
	broadcastState()
	enterPhase(result)

func startVotingPhase():
	clientSelections.clear()
	dayDecisions.clear()
	broadcastState()
	
	startTransition(2.0, "fadeIn")
	await transitionTimer.timeout
	
	startSelectionTimer(10.0)
	await selectionTimer.timeout
	
	for peerID in multiplayer.get_peers():
		rpc_id(peerID, "requestClientSelection")

	await get_tree().create_timer(2.0).timeout
	fillMissingSelections()
	resolveVoting()
	
	startTransition(2.0, "fadeOut")
	await transitionTimer.timeout
	
	phaseLocked = false
	enterPhase(GamePhase.NIGHT_ROLE)

func startNightRolePhase():
	clientSelections.clear()
	dayDecisions.clear()
	currentNightActorIndex = 0
	# Start the first night role
	startNextNightRole()

@rpc("any_peer")
func startSyncedTransition(server_start_msec: int, duration_msec: int, transition_type: String, phase: String):
	var scene = get_tree().current_scene
	if scene and scene.has_method("clientStartSyncedTransition"):
		scene.clientStartSyncedTransition(server_start_msec, duration_msec, transition_type, phase)
	else:
		pendingTimerStart = {
			"start": server_start_msec,
			"duration": duration_msec,
			"type": transition_type,
			"phase": phase
		}

func startTransition(seconds: float, transition_type):
	if not multiplayer.is_server():
		return
	debugPhase("Starting transition: " + transition_type + " for " + str(seconds) + "s")
	var now = Time.get_ticks_msec()
	var duration = int(seconds * 1000)
	rpc("startSyncedTransition", now, duration, transition_type, getCurrentPhaseString())
	transitionTimer.wait_time = seconds
	transitionTimer.start()


func onTransitionTimerTimeout():
	pass

func resolveDay():
	var nextPhase = resolveDayDecision()
	
	for peerID in players.keys():
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
	debugSelections("Filled missing selections")

func buildNightOrder():
	nightOrder.clear()
	for roleID in roles.keys():
		var role = roles[roleID]
		if role.get("actsAtNight", false):
			nightOrder.append(roleID)
	nightOrder.sort_custom(func(a, b): return roles[a]["nightOrder"] < roles[b]["nightOrder"])

@rpc("any_peer")
func sendDayDecision(decision: String):
	if not multiplayer.is_server():
		return
	if currentPhase != GamePhase.DAY_DECISION:
		return
	var peerID = multiplayer.get_remote_sender_id()
	dayDecisions[peerID] = decision
	print("Received day decision from", peerID, ":", decision)

func resolveDayDecision() -> GamePhase:
	if not multiplayer.is_server():
		return GamePhase.NIGHT_ROLE
	var voteCount := {
		"vote": 0,
		"skip": 0
	}

	# Count votes from all alive players
	for peerID in players.keys():
		if not players[peerID]["alive"]:
			continue
		var decision: String = dayDecisions.get(peerID, "skip")
		voteCount[decision] += 1

	print("Day decision results:", voteCount)

	# Majority logic
	if voteCount["vote"] > voteCount["skip"]:
		print("Players chose to start voting")
		return GamePhase.VOTING
	else:
		print("Players skipped voting, going to night")
		return GamePhase.NIGHT_ROLE

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
	if currentNightActorIndex >= nightOrder.size():
		# All roles done, go to night resolve
		phaseLocked = false
		enterPhase(GamePhase.NIGHT_RESOLVE)
		return

	broadcastState()
	currentNightRole = nightOrder[currentNightActorIndex]
	alivePlayersWithRole.clear()
	for peerID in players.keys():
		if players[peerID]["alive"] and players[peerID]["role"] == currentNightRole:
			alivePlayersWithRole.append(peerID)

	if alivePlayersWithRole.is_empty():
		print("[NIGHT] Skipping role ", currentNightRole, "- no assigned or alive players")
		currentNightActorIndex += 1
		startNextNightRole()
		return

	debugPhase("Next night role: " + currentNightRole)
	broadcastState()

	# Put everyone to sleep
	for peerID in players.keys():
		ClientManager.rpc_id(peerID, "requestClientToSleep")
		print("[NIGHT] request sleep for: ", peerID)

	# Wake the current role
	for peerID in alivePlayersWithRole:
		ClientManager.rpc_id(peerID, "requestClientToWake")
		print("[NIGHT] request wake for: ", peerID)

	# FadeIn
	startTransition(2.0, "fadeIn")
	await transitionTimer.timeout

	# Start selection timer
	startSelectionTimer(10.0)
	await selectionTimer.timeout

	# Request selection
	for peerID in alivePlayersWithRole:
		rpc_id(peerID, "requestClientSelection")

	await get_tree().create_timer(0.5).timeout
	fillMissingSelections()

	# FadeOut
	startTransition(2.0, "fadeOut")
	await transitionTimer.timeout

	# Broadcast and advance to next role
	broadcastState()
	phaseLocked = false
	currentNightActorIndex += 1
	startNextNightRole()



func resolveNight() -> void:
	if not multiplayer.is_server():
		return

	print("Starting to resolve night")

	var collected: Dictionary = {}
	for peerID in players.keys():
		if clientSelections.has(peerID):
			var roleID = players[peerID]["role"]
			var role = roles[roleID]
			if role.has("nightActions"):
				for action in role["nightActions"]:
					var type = action["type"]
					if not collected.has(type):
						collected[type] = []
					if clientSelections[peerID].has(type):
						collected[type].append(clientSelections[peerID][type])

	for actionType in collected.keys():
		var resolution := "majorityWins"
		var found := false
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
	checkWinConditions()

	if currentPhase != GamePhase.ENDED:
		for peerID in players.keys():
			ClientManager.rpc_id(peerID, "requestClientResetUI")
			ClientManager.rpc_id(peerID, "requestClientToWake")

func resolveVoting() -> void:
	if not multiplayer.is_server():
		return
		
	var votes: Array = []

	for peerID in players.keys():
		if not players[peerID]["alive"]:
			continue
		var sel = clientSelections.get(peerID, {})
		if sel.has("vote"):
			votes.append(sel["vote"])

	resolveMajorityWins("vote", votes)
	checkWinConditions()
	if currentPhase != GamePhase.ENDED:
		for peerID in players.keys():
			ClientManager.rpc_id(peerID, "requestClientResetUI")

# ====================RESOLVING AND WIN_CONDITION====================

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


func checkWinConditions() -> void:
	if not multiplayer.is_server():
		return
	
	var aliveTeams: Dictionary = {}
	
	for peerID in players.keys():
		if not players[peerID]["alive"]:
				continue
				
		var roleID = players[peerID]["role"]
		
		if roleID == "" or not roles.has(roleID):
			continue
		
		var role = roles[roleID]
		var team = role.get("team", "neutral")
		
		if team != "neutral":
			aliveTeams[team] = aliveTeams.get(team, 0) + 1
				
	if aliveTeams.get("werewolves", 0) == 0:
		currentPhase = GamePhase.ENDED
		endGame("Villagers")
	elif aliveTeams.get("villagers", 0) <= aliveTeams.get("werewolves", 0):
		currentPhase = GamePhase.ENDED
		endGame("Werewolves")

func endGame(winner: String) -> void:
	print("=== GAME OVER ===")
	print("Winner:", winner)
	
	startTransition(2.0, "fadeOut")
	await transitionTimer.timeout

	for peerID in players.keys():
		ClientManager.rpc_id(peerID, "onGameEnded", winner)
	
	startTransition(2.0, "fadeIn")
	await transitionTimer.timeout
	
	currentPhase = GamePhase.ENDED
	phaseLocked = true

	await get_tree().create_timer(5.0).timeout
	resetGame()

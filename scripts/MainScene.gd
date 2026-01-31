extends Node

enum SelectionMode {
	NONE,
	NIGHT_ACTION,
	VOTE
}

var localState: Dictionary = {}
var selectedPlayers: Dictionary = {}
var maxPlayersToSelect: int = 2
var syncedTimerEnd: int = 0
var pendingTimerStart: Dictionary = {}
var lastDisplayedTime := ""
var selectionMode: SelectionMode = SelectionMode.NONE
var isAwake: bool = false
var fadeTween: Tween

var playerNodes: Dictionary = {}

@onready var playerList: Node = $VBoxContainer
@onready var playerRingContainer: Node = $PlayerContainer
@onready var layoutRect: Node = $PlayerContainer/LayoutRect
@onready var fadeRect: ColorRect = $FadeCanvasLayer/FadeColorRect
@onready var currentRoleAwake: Label = $CanvasLayer/BlackoutOverlay/Label

func isSelfDead() -> bool:
	var selfID = localState.get("selfID")
	return localState.get("players", {}).get(selfID, {}).get("alive", true) == false


func _ready():
	if GameManager.pendingTimerStart.size() > 0:
		var t = GameManager.pendingTimerStart
		startSyncedTimer(t["start"], t["duration"])
		GameManager.pendingTimerStart.clear()
	print("Client: MainScene loaded, requesting game state...")
	GameManager.rpc_id(1, "clientMainSceneLoaded")
	GameManager.rpc_id(1, "requestFullState")
	
func _process(delta):
	if syncedTimerEnd == 0:
		return

	var now = Time.get_ticks_msec()
	var remaining = syncedTimerEnd - now
	
	if remaining < 0:
		remaining = 0

	var totalSeconds := int(ceil(remaining / 1000.0))
	var minutes: = int(totalSeconds / 60)
	var seconds: = int(totalSeconds % 60)

	var formatted := "%02d:%02d" % [minutes, seconds]

	if formatted != lastDisplayedTime:
		$TopUI/TimerLabel.text = formatted
		$CanvasLayer/BlackoutOverlay/TimerLabel.text = formatted
		lastDisplayedTime = formatted

func applyState(state: Dictionary):
	print("Applying game state:\n", JSON.stringify(state, "\t", 2))
	localState = state
	var nightInfo = state["nightInfo"]
	updatePlayersInRect()
	$TopUI/PhaseLabel.text = localState["phase"]
	$CanvasLayer/BlackoutOverlay/PhaseLabel.text = localState["phase"]
	
	if isSelfDead():
		selectionMode = SelectionMode.NONE
		isAwake = false
		hideDayDecisionUI()
		$CanvasLayer.visible = false
		currentRoleAwake.text = ""
		$TopLeftUI/RoleLabel.text = "Spectator"
		$TopLeftUI/HintLabel.text = "You are dead. Watching the game."
		if fadeTween:
			fadeTween.kill()
		fadeRect.visible = false
		return
	
	match localState["phase"]:
		"Night":
			hideDayDecisionUI()
			if nightInfo["youAreAwake"]:
				showNightHint(nightInfo)
			else:
				$TopLeftUI/RoleLabel.text = "Your role: " + str(localState["players"][localState["selfID"]].get("role", "unknown"))
				$TopLeftUI/HintLabel.text = ""
				
			if nightInfo.has("awakeRole") and nightInfo["awakeRole"] != "":
				currentRoleAwake.text = "Role awake: " + nightInfo["awakeRole"]
			else:
				currentRoleAwake.text = ""
		"Day":
			isAwake = true
			selectionMode = SelectionMode.NONE
			currentRoleAwake.text = ""
			$TopLeftUI/RoleLabel.text = "Your role: " + str(localState["players"][localState["selfID"]].get("role", "unknown"))
			$TopLeftUI/HintLabel.text = "Start vote or skip to next night"
		"Voting":
			isAwake = true
			selectionMode = SelectionMode.VOTE
			currentRoleAwake.text = ""
			hideDayDecisionUI()
			$TopLeftUI/RoleLabel.text = "Your role: " + str(localState["players"][localState["selfID"]].get("role", "unknown"))
			$TopLeftUI/HintLabel.text = "Vote Player by clicking a player"

func updatePlayersInRect() -> void:
	# Clear previous players (except layout rectangle)
	for child in playerRingContainer.get_children():
		if child != layoutRect:
			child.queue_free()
	playerNodes.clear()

	var players: Dictionary = localState["players"]
	if players.is_empty():
		return

	var selfID: int = localState["selfID"]
	if not players.has(selfID):
		return

	var rect: Rect2 = layoutRect.get_global_rect()
	var rectLocal: Rect2 = layoutRect.get_rect()

	# Place SELF (bottom center)
	var selfData: Dictionary = players[selfID]
	var selfNode: Node = preload("res://scenes/Player.tscn").instantiate()
	playerRingContainer.add_child(selfNode)
	var n1: String = selfData["displayName"]
	var selfColor: Color = localState["playerColors"].get(selfID, Color.WHITE)
	selfNode.setup(n1, selfColor, selfID, Vector2(128, 128))
	if not selfData["alive"]:
		selfNode.setDeadVisual()
	selfNode.connect("playerSelected", Callable(self, "onPlayerSelected"))
	playerNodes[selfID] = selfNode

	var bottomCenter: Vector2 = Vector2(
		rectLocal.position.x + rectLocal.size.x * 0.5,
		rectLocal.position.y + rectLocal.size.y
	)
	selfNode.position = bottomCenter
	selfNode.setFacingFromTable("bottom")

	var otherIDs: Array = players.keys()
	otherIDs.erase(selfID)
	otherIDs.sort()

	var totalOthers: int = otherIDs.size()
	if totalOthers == 0:
		return

	var maxTopPlayers: int = 7
	var maxSidePlayers: int = 6

	# Dynamically calculate counts
	var topCount: int = min(totalOthers, maxTopPlayers)
	var remaining = totalOthers - topCount
	var leftCount: int = min(int(remaining / 2), maxSidePlayers)
	var rightCount: int = min(remaining - leftCount, maxSidePlayers)

	var playerSize: = Vector2(96, 96)
	var margin: int = 32
	var topSpacing: float = rectLocal.size.x / float(topCount + 1)
	var sideSpacing: float = playerSize.y + margin

	var index: int = 0

	# Top side
	for i in range(topCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var n: String = data["displayName"]
		var color: Color = localState["playerColors"].get(peerID, Color.WHITE)

		var node: Node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(n, color, peerID, playerSize)
		if not data["alive"]:
			node.setDeadVisual()
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		playerNodes[peerID] = node
		
		var targetLocal = Vector2(rectLocal.position.x + (i + 1) * topSpacing + playerSize.x * 0.5, rectLocal.position.y)
		node.position = targetLocal - node.getRectSize() * 0.5
		node.setFacingFromTable("top")
		index += 1


	# Left side
	for i in range(leftCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var n: String = data["displayName"]
		var color: Color = localState["playerColors"].get(peerID, Color.WHITE)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(n, color, peerID, playerSize)
		if not data["alive"]:
			node.setDeadVisual()
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		playerNodes[peerID] = node
		
		var targetLocal = Vector2(rectLocal.position.x, rectLocal.position.y + (i + 1) * sideSpacing)
		node.position = playerRingContainer.to_local(targetLocal - node.getRectSize() * 0.5)
		node.setFacingFromTable("left")
		index += 1

	# Right side
	for i in range(rightCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var n: String = data["displayName"]
		var color: Color = localState["playerColors"].get(peerID, Color.WHITE)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(n, color, peerID, playerSize)
		if not data["alive"]:
			node.setDeadVisual()
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		playerNodes[peerID] = node
		
		var targetLocal = Vector2(rectLocal.position.x + rectLocal.size.x + playerSize.x, rectLocal.position.y + (i + 1) * sideSpacing)
		node.position = playerRingContainer.to_local(targetLocal - node.getRectSize() * 0.5)
		node.setFacingFromTable("right")
		index += 1

func onPlayerSelected(peerID: int) -> void:
	if isSelfDead():
		return
	
	if not localState["players"][peerID]["alive"]:
		print("Cannot select dead player")
		return
	
	if peerID == localState["selfID"]:
		print("Cannot select yourself")
		return

		
	match selectionMode:
		SelectionMode.NIGHT_ACTION:
			handleNightActionSelection(peerID)
		SelectionMode.VOTE:
			handleVoteSelection(peerID)
		SelectionMode.NONE:
			return

func handleNightActionSelection(peerID: int) -> void:
	var selfID: int = localState["selfID"]
	var myRoleID: String = localState["players"][selfID]["role"]
	var myRole: Dictionary = localState["roles"][myRoleID]
	var nightActions: Array = myRole.get("nightActions", [])

	if nightActions.is_empty():
		return

	var actionType: String = nightActions[0]["type"]
	if selectedPlayers.get(actionType) == peerID:
		selectedPlayers.erase(actionType)
	else:
		selectedPlayers[actionType] = peerID
	updatePlayerHighlights()

func handleVoteSelection(peerID: int) -> void:
	if selectedPlayers.get("vote") == peerID:
		selectedPlayers.erase("vote")
	else:
		selectedPlayers["vote"] = peerID
	updatePlayerHighlights()

func updatePlayerHighlights():
	for id in playerNodes.keys():
		playerNodes[id].setSelected(false)

	for key in selectedPlayers.keys():
		var pid = selectedPlayers[key]
		if playerNodes.has(pid):
			playerNodes[pid].setSelected(true)

func showNightHint(nightInfo: Dictionary):
	var selfID = localState.get("selfID", null)
	if selfID == null or not localState.get("players", {}).has(selfID):
		$TopLeftUI/RoleLabel.text = "Your role: unknown"
		$TopLeftUI/HintLabel.text = nightInfo.get("nightActionHint", "")
		return

	$TopLeftUI/RoleLabel.text = "Your role: " + str(localState["players"][selfID].get("role", "unknown"))
	$TopLeftUI/HintLabel.text = nightInfo.get("nightActionHint", "")

@rpc("any_peer")
func clientSendSelection():
	print("Client: ", multiplayer.get_unique_id(), " is sending selection: ", selectedPlayers)
	GameManager.rpc_id(1, "sendClientSelection", selectedPlayers)

func clientStartSyncedTransition(server_start_msec: int, duration_msec: int, transition_type: String, phase: String):
	var now = Time.get_ticks_msec()
	var elapsed = now - server_start_msec

	var remaining = duration_msec - elapsed

	# Clamp for late joiners
	if remaining < 0:
		remaining = 0
	if remaining > duration_msec:
		remaining = duration_msec

	var remainingSeconds = remaining / 1000.0

	print("Client synced transition:", transition_type, "phase:", phase, "remaining:", remainingSeconds)

	match transition_type:
		"fadeOut":
			fadeOut(remainingSeconds)
		"fadeIn":
			fadeIn(remainingSeconds)

func fadeOut(duration: float):
	if isSelfDead():
		return
	if fadeTween:
		fadeTween.kill()
	
	fadeRect.visible = true
	fadeRect.modulate.a = 0.0
	
	fadeTween = create_tween()
	fadeTween.tween_property(fadeRect, "modulate:a", 1.0, duration)
	
func fadeIn(duration: float):
	if isSelfDead():
		return
	if fadeTween:
		fadeTween.kill()
		
	fadeRect.visible = true
	fadeRect.modulate.a = 1.0
		
	fadeTween = create_tween()
	fadeTween.tween_property(fadeRect, "modulate:a", 0.0, duration)
	fadeTween.finished.connect(func():
		fadeRect.visible = false
	)

func startSyncedTimer(server_start_msec: int, duration_msec: int):
	var now = Time.get_ticks_msec()
	var elapsed = now - server_start_msec

	# Compute remaining time
	var remaining = duration_msec - elapsed

	# Clamp so late joiners don't get extra time
	if remaining < 0:
		remaining = 0
	if remaining > duration_msec:
		remaining = duration_msec

	# Set the absolute end time
	syncedTimerEnd = now + remaining

	print("Client synced timer remaining (sec): ", remaining / 1000.0)


func hideDayDecisionUI():
	$DayDecisionsUI/StartVoteButton.visible = false
	$DayDecisionsUI/SkipButton.visible = false

@rpc("any_peer")
func requestDayDecision():
	if isSelfDead():
		return
	print("Client: Server requests day decision")
	$DayDecisionsUI/StartVoteButton.visible = true
	$DayDecisionsUI/SkipButton.visible = true

func resetUI():
	print("Resetting UI")
	selectedPlayers.clear()
	updatePlayerHighlights()

func sleepClient():
	isAwake = false
	selectionMode = SelectionMode.NONE
	if not isSelfDead():
		$CanvasLayer.visible = true

func wakeClient():
	isAwake = true
	selectionMode = SelectionMode.NIGHT_ACTION
	if not isSelfDead():
		$CanvasLayer.visible = false

func showGameOver(winner: String):
	$WinnerLayer/BackgroundRect/Label.text = winner + " Won!"
	$WinnerLayer.visible = true

func _on_start_vote_button_pressed() -> void:
	GameManager.rpc_id(1, "sendDayDecision", "vote")
	hideDayDecisionUI()

func _on_skip_button_pressed() -> void:
	GameManager.rpc_id(1, "sendDayDecision", "skip")
	hideDayDecisionUI()

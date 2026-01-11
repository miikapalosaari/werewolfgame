extends Node

var localState: Dictionary = {}
var selectedPlayers: Dictionary = {}
var maxPlayersToSelect: int = 2
var syncedTimerEnd: int = 0
var pendingTimerStart: Dictionary = {}
var lastDisplayedTime := ""

@onready var playerList: Node = $VBoxContainer
@onready var playerRingContainer: Node = $PlayerContainer
@onready var layoutRect: Node = $PlayerContainer/LayoutRect

func _ready():
	if GameManager.pendingTimerStart.size() > 0:
		var t = GameManager.pendingTimerStart
		startSyncedTimer(t["start"], t["duration"])
		GameManager.pendingTimerStart.clear()
	print("Client: MainScene loaded, requesting game state...")
	GameManager.rpc_id(1, "requestFullState")
	
func _process(delta):
	if syncedTimerEnd == 0:
		return

	var now = Time.get_ticks_msec()
	var remaining = syncedTimerEnd - now
	
	if remaining < 0:
		remaining = 0

	var totalSeconds: int = remaining / 1000
	var minutes: = int(totalSeconds / 60)
	var seconds: = int(totalSeconds % 60)

	var formatted := "%02d:%02d" % [minutes, seconds]

	if formatted != lastDisplayedTime:
		$TopUI/TimerLabel.text = formatted
		lastDisplayedTime = formatted

func applyState(state: Dictionary):
	print("Applying game state:\n", JSON.stringify(state, "\t", 2))
	localState = state
	updatePlayersInRect()

func updatePlayersInRect() -> void:
	# Clear previous players (except layout rectangle)
	for child in playerRingContainer.get_children():
		if child != layoutRect:
			child.queue_free()

	var players: Dictionary = localState["players"]
	if players.is_empty():
		return

	var selfID: int = localState["selfID"]
	if not players.has(selfID):
		return

	var rect: Rect2 = layoutRect.get_global_rect()

	# Place SELF (bottom center)
	var selfData: Dictionary = players[selfID]
	var selfNode: Node = preload("res://scenes/Player.tscn").instantiate()
	playerRingContainer.add_child(selfNode)
	var n1: String = selfData["name"]
	if selfData["alive"]:
		n1 += "(Alive)"
	else:
		n1 += "(Not Alive)"
	selfNode.setup(n1, Color.RED, selfID, Vector2(128, 128))
	selfNode.connect("playerSelected", Callable(self, "onPlayerSelected"))

	var bottomCenter: Vector2 = Vector2(
		rect.position.x + rect.size.x * 0.5,
		rect.end.y
	)
	
	var half: Vector2 = selfNode.getRectSize() * 0.5
	selfNode.position = bottomCenter - half

	var otherIDs: Array = players.keys()
	otherIDs.erase(selfID)
	otherIDs.sort()

	var totalOthers: int = otherIDs.size()
	if totalOthers == 0:
		return

	var maxTopPlayers: int = 7
	var maxSidePlayers: int = 6

	# Dynamically calculate counts
	var topCount: int = totalOthers
	if topCount > maxTopPlayers:
		topCount = maxTopPlayers
	var remaining = totalOthers - topCount

	var leftCount := int(remaining / 2)
	if leftCount > maxSidePlayers:
		leftCount = maxSidePlayers

	var rightCount: int = remaining - leftCount
	if rightCount > maxSidePlayers:
		rightCount = maxSidePlayers

	var centerX: float = rect.position.x + rect.size.x * 0.5
	var topY: float = rect.position.y
	var leftX: float = rect.position.x
	var rightX: float = rect.end.x

	var playerSize: = Vector2(96, 96)
	var margin: int = 32
	var topSpacing: float = rect.size.x / float(topCount + 1)
	var leftSpacing: float = playerSize.y + margin
	var rightSpacing: float = playerSize.y + margin

	var index: int = 0

	# Top side
	for i in range(topCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var n: String = data["name"]
		if data["alive"]:
			n += "(Alive)"
		else:
			n += "(Not Alive)"
		var x: float = rect.position.x + (i + 1) * topSpacing
		var y: float = topY
		var hue: float = fmod(index * 0.61, 1.0)
		var color: Color = Color.from_hsv(hue, 0.75, 0.9)

		var node: Node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(n, color, peerID, Vector2(96, 96))
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		var half2: Vector2 = node.getRectSize() * 0.5
		node.position = Vector2(x, y) - half2
		index += 1

	# Left side
	for i in range(leftCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var n: String = data["name"]
		if data["alive"]:
			n += "(Alive)"
		else:
			n += "(Not Alive)"
		var x: float = leftX
		var y: float = rect.position.y + (i + 1) * leftSpacing
		var hue: float = fmod(index * 0.61, 1.0)
		var color: Color = Color.from_hsv(hue, 0.75, 0.9)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(n, color, peerID, Vector2(96, 96))
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		var half3: Vector2 = node.getRectSize() * 0.5
		node.position = Vector2(x, y) - half3
		index += 1

	# Right side
	for i in range(rightCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var n: String = data["name"]
		if data["alive"]:
			n += "(Alive)"
		else:
			n += "(Not Alive)"
		var x: float = rightX
		var y: float = rect.position.y + (i + 1) * rightSpacing
		var hue: float = fmod(index * 0.61, 1.0)
		var color: Color = Color.from_hsv(hue, 0.75, 0.9)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(n, color, peerID, Vector2(96, 96))
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		var half4: Vector2 = node.getRectSize() * 0.5
		node.position = Vector2(x, y) - half4
		index += 1

func onPlayerSelected(peerID: int) -> void:
	var selfID = localState["selfID"]
	var myRoleID = localState["players"][selfID]["role"]
	var myRole = localState["roles"][myRoleID]
	var nightActions = myRole.get("nightActions", [])

	if nightActions.is_empty():
		return

	if not localState["players"][peerID]["alive"]:
		print("Cannot select dead player")
		return
		
	# For now assuming 1 nightAction
	var actionType = nightActions[0]["type"]
	if selectedPlayers.has(actionType) and selectedPlayers[actionType] == peerID:
		selectedPlayers.erase(actionType)
	else:
		selectedPlayers[actionType] = peerID
	$Label.text = str(selectedPlayers)

@rpc("any_peer")
func clientSendSelection():
	print("Client: ", localState["selfID"], " is sending selection: ", selectedPlayers)
	GameManager.rpc_id(1, "sendClientSelection", selectedPlayers)

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

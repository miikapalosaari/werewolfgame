extends Node

var localState: Dictionary = {}
var selectedPlayers: Array = []
var maxPlayersToSelect: int = 2
@onready var playerList: Node = $VBoxContainer
@onready var playerRingContainer: Node = $PlayerContainer
@onready var layoutRect: Node = $PlayerContainer/LayoutRect

func _ready():
	print("Client: MainScene loaded, requesting game state...")
	GameManager.rpc_id(1, "requestFullState")

func applyState(state: Dictionary):
	print("Applying game state:", state)
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
	selfNode.setup(selfData["name"], Color.RED, selfID, Vector2(128, 128))
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
		var x: float = rect.position.x + (i + 1) * topSpacing
		var y: float = topY
		var hue: float = fmod(index * 0.61, 1.0)
		var color: Color = Color.from_hsv(hue, 0.75, 0.9)

		var node: Node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(data["name"], color, peerID, Vector2(96, 96))
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		var half2: Vector2 = node.getRectSize() * 0.5
		node.position = Vector2(x, y) - half2
		index += 1

	# Left side
	for i in range(leftCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var x: float = leftX
		var y: float = rect.position.y + (i + 1) * leftSpacing
		var hue: float = fmod(index * 0.61, 1.0)
		var color: Color = Color.from_hsv(hue, 0.75, 0.9)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(data["name"], color, peerID, Vector2(96, 96))
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		var half3: Vector2 = node.getRectSize() * 0.5
		node.position = Vector2(x, y) - half3
		index += 1

	# Right side
	for i in range(rightCount):
		var peerID: int = otherIDs[index]
		var data: Dictionary = players[peerID]
		var x: float = rightX
		var y: float = rect.position.y + (i + 1) * rightSpacing
		var hue: float = fmod(index * 0.61, 1.0)
		var color: Color = Color.from_hsv(hue, 0.75, 0.9)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(data["name"], color, peerID, Vector2(96, 96))
		node.connect("playerSelected", Callable(self, "onPlayerSelected"))
		var half4: Vector2 = node.getRectSize() * 0.5
		node.position = Vector2(x, y) - half4
		index += 1

func onPlayerSelected(peerID: int) -> void:
	if selectedPlayers.has(peerID):
		selectedPlayers.erase(peerID)
		$Label.text = str(selectedPlayers)
		return

	if selectedPlayers.size() >= maxPlayersToSelect:
		print("Selection full, cannot select more")
		$Label.text = str(selectedPlayers)
		return

	selectedPlayers.append(peerID)
	$Label.text = str(selectedPlayers)

@rpc("any_peer")
func clientSendSelection():
	print("Client: ", localState["selfID"], " is sending selection: ", selectedPlayers)
	GameManager.rpc_id(1, "sendClientSelection", selectedPlayers)

extends Node

var localState: Dictionary = {}
@onready var playerList: Node = $VBoxContainer
@onready var playerRingContainer: Node = $PlayerContainer
@export var ringRadius: float = 200.0
@export var center: Vector2 = Vector2(400, 300)

func _ready():
	print("Client: MainScene loaded, requesting game state...")
	GameManager.rpc_id(1, "requestFullState")

func applyState(state: Dictionary):
	print("Applying game state:", state)
	localState = state
	
	for child in playerList.get_children():
		child.queue_free()

	var myID = localState["selfID"]
	var players = localState["players"]

	for peerID in players.keys():
		var p = players[peerID]
		var name = p["name"]
		var role = p["role"]

		if peerID == myID:
			name += " (me)"

		var label = Label.new()
		label.text = "%s - %s" % [name, role]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		playerList.add_child(label)
		
	updateRingOfPlayers()
		
func updateRingOfPlayers() -> void:
	for child in playerRingContainer.get_children():
		child.queue_free()
		
	var players: Dictionary = localState["players"]
	var playerCount: int = players.size()
	if playerCount == 0:
		return
		
	var index: int = 0
	for peerID in players.keys():
		var p = players[peerID]
		var name = p["name"]
		var hue = fmod(index * 0.71, 1.0)
		var saturation := 0.65 if index % 2 == 0 else 0.85
		var value := 0.95 if index % 3 == 0 else 0.80
		var color = Color.from_hsv(hue, saturation, value)
		
		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(name, color)
		
		var angle = TAU * (float(index) / playerCount)
		var pos = center + Vector2(cos(angle), sin(angle)) * ringRadius
		node.position = pos
		index += 1

extends Node

var localState: Dictionary = {}
@onready var playerList: Node = $VBoxContainer

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

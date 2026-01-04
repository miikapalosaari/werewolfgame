extends Control

@onready var playerList = $Panel/PlayersContainer/ScrollContainer/PlayerList

func applyState(state: Dictionary):
	print("Lobby: applyState")
#
	if not state.has("players"):
		return
	updatePlayerList(state["players"], state.get("leader"))

func updatePlayerList(players: Dictionary, leader_id):
	# Clear old labels
	for child in playerList.get_children():
		child.queue_free()

	# Add a simple label for each player
	for id in players.keys():
		var data = players[id]
		var label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		var ready_text = "Not Ready"
		if data["ready"]:
			ready_text = "Ready"

		var leader_text = ""
		if id == leader_id:
			leader_text = " (Leader)"
			
		label.text = data["name"] + " - " + ready_text + leader_text
		playerList.add_child(label)

func _on_ready_button_pressed() -> void:
	GameManager.rpc_id(1, "playerReady")

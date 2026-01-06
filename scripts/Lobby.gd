extends Control

@onready var playerList = $Panel/PlayersContainer/ScrollContainer/PlayerList
@onready var roleSettings = $RoleSettingsContainer
var localState: Dictionary = {}

func applyState(state: Dictionary):
	print("Lobby: applyState")
	localState = state
	
	if not state.has("players"):
		return
	updatePlayerList(state["players"], state.get("leader"))
	buildRoleSettingsUI(state["roles"])

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
		
func buildRoleSettingsUI(roles: Dictionary):
	for child in roleSettings.get_children():
		child.queue_free()

	var counts = localState.get("roleCounts", {})

	for roleID in roles.keys():
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label = Label.new()
		label.text = roleID
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var input = SpinBox.new()
		input.min_value = 0
		input.max_value = 20
		input.name = roleID

		# Use server value if available
		input.value = counts.get(roleID, 0)

		row.add_child(label)
		row.add_child(input)
		roleSettings.add_child(row)

func _on_ready_button_pressed() -> void:
	GameManager.rpc_id(1, "playerReady")

func _on_apply_settings_button_pressed() -> void:
	var newCounts: Dictionary = {}
	for row in roleSettings.get_children():
		var inputNode = row.get_child(1)  # SpinBox is second child
		var roleID = inputNode.name
		newCounts[roleID] = int(inputNode.value)
	GameManager.rpc_id(1, "updateRoleCounts", newCounts)

extends Control

@onready var playerList = $Panel/ScrollContainer/PlayerList
@onready var roleSettings = $RolePanel/RoleSettingsContainer
var localState: Dictionary = {}

func _ready() -> void:
	GameManager.rpc_id(1, "requestFullState")

func applyState(state: Dictionary):
	localState = state
	
	if not state.has("players"):
		return
	updatePlayerList(state["players"], state.get("leader"))
	buildRoleSettingsUI(state["roles"])

func updatePlayerList(players: Dictionary, leaderID):
	# Clear old labels
	for child in playerList.get_children():
		child.queue_free()

	# Add a simple label for each player
	for id in players.keys():
		var data = players[id]
		
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = 40
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var playerLabel = Label.new()
		playerLabel.text = data["name"]
		playerLabel.add_theme_font_size_override("font_size", 36)
		playerLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		playerLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var playerColor: Color = localState.get("playerColors", {}).get(id, Color.WHITE)
		playerLabel.add_theme_color_override("font_color", playerColor)
		row.add_child(playerLabel)
		
		var readyLabel = Label.new()
		readyLabel.text = "Ready" if data["ready"] else "Not Ready"
		readyLabel.add_theme_font_size_override("font_size", 36)
		readyLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		readyLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var readyColor: Color = Color.GREEN if data["ready"] else Color.RED
		readyLabel.add_theme_color_override("font_color", readyColor)
		row.add_child(readyLabel)
		
		if id == leaderID:
			var leaderLabel = Label.new()
			leaderLabel.text = " (Leader)"
			leaderLabel.add_theme_font_size_override("font_size", 36)
			leaderLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			leaderLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var leaderColor: Color = Color.YELLOW
			leaderLabel.add_theme_color_override("font_color", leaderColor)
			row.add_child(leaderLabel)
		
		playerList.add_child(row)
		
func buildRoleSettingsUI(roles: Dictionary):
	for child in roleSettings.get_children():
		child.queue_free()

	var counts = localState.get("roleCounts", {})
	var leaderID = localState.get("leader")
	var selfID = localState.get("selfID")
	
	var iAmLeader = (selfID == leaderID)

	for roleID in roles.keys():
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label = Label.new()
		label.text = roleID
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		if iAmLeader:
			var input = SpinBox.new()
			input.min_value = 0
			input.max_value = 20
			input.name = roleID
			input.value = counts.get(roleID, 0)
			input.connect("value_changed", Callable(self, "_on_spinbox_value_changed").bind(roleID))
			row.add_child(input)
		else:
			var valueLabel = Label.new()
			valueLabel.text = str(counts.get(roleID, 0))
			valueLabel.size_flags_horizontal = Control.SIZE_FILL
			row.add_child(valueLabel)
		roleSettings.add_child(row)

func _on_ready_button_pressed() -> void:
	GameManager.rpc_id(1, "playerReady")

func _on_spinbox_value_changed(value, roleID):
	GameManager.rpc_id(1, "updateRoleCounts", roleID, value)

extends Control

@onready var playerList = $Panel/ScrollContainer/PlayerList
@onready var roleSettings = $RolePanel/RoleSettingsContainer
var totalPlayers: int = 0
var localState: Dictionary = {}

func _ready() -> void:
	GameManager.rpc_id(1, "requestFullState")

func applyState(state: Dictionary):
	localState = state
	
	if not state.has("players"):
		return
		
	totalPlayers = state["players"].size()
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
		row.custom_minimum_size.y = 40

		var label = Label.new()
		label.text = roleID
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 36)
		row.add_child(label)
		
		var valueLabel = Label.new()
		valueLabel.text = str(counts.get(roleID, 0))
		valueLabel.size_flags_horizontal = Control.SIZE_FILL
		valueLabel.add_theme_font_size_override("font_size", 36)
		row.add_child(valueLabel)

		if iAmLeader:
			var minusButton = Button.new()
			minusButton.text = "-"
			minusButton.size_flags_horizontal = Control.SIZE_FILL
			minusButton.size_flags_vertical = Control.SIZE_FILL
			minusButton.add_theme_font_size_override("font_size", 36)
			minusButton.connect("pressed", Callable(self, "_on_role_value_button_pressed").bind(roleID, -1, valueLabel))
			minusButton.custom_minimum_size = Vector2(40, 40)
			row.add_child(minusButton)

			var plusButton = Button.new()
			plusButton.text = "+"
			plusButton.size_flags_horizontal = Control.SIZE_FILL
			plusButton.size_flags_vertical = Control.SIZE_FILL
			plusButton.add_theme_font_size_override("font_size", 36)
			plusButton.connect("pressed", Callable(self, "_on_role_value_button_pressed").bind(roleID, 1, valueLabel))
			plusButton.custom_minimum_size = Vector2(40, 40)
			row.add_child(plusButton)
		roleSettings.add_child(row)

func _on_ready_button_pressed() -> void:
	GameManager.rpc_id(1, "playerReady")

func updatePlusButtons():
	var counts = localState.get("roleCounts", {})
	var totalRoles = 0
	for rID in counts.keys():
		totalRoles += int(counts[rID])

	for row in roleSettings.get_children():
		for child in row.get_children():
			if child is Button and child.text == "+":
				child.disabled = totalRoles >= totalPlayers


func _on_role_value_button_pressed(roleID: String, delta: int, valueLabel: Label):
	var current = int(valueLabel.text)
	
	var totalRoles = 0
	for rID in localState.get("roleCounts", {}):
		if rID == roleID:
			totalRoles += max(0, current + delta)
		else:
			totalRoles += int(localState["roleCounts"].get(rID, 0))
	
	if totalRoles > totalPlayers and delta > 0:
		return
	
	current = max(0, current + delta)
	valueLabel.text = str(current)
	localState["roleCounts"][roleID] = current
	_on_role_value_changed(roleID, current)
	updatePlusButtons()

func _on_role_value_changed(roleID: String, value: int):
	GameManager.rpc_id(1, "updateRoleCounts", roleID, value)

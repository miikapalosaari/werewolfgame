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

func updatePlayerList(players: Dictionary, leader_id):
	# Clear old labels
	for child in playerList.get_children():
		child.queue_free()

	# Add a simple label for each player
	for id in players.keys():
		var data = players[id]
		var label = Label.new()
		label.custom_minimum_size.y = 40
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

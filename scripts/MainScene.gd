extends Node

var localState: Dictionary = {}
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

	var self_id: int = localState["selfID"]
	if not players.has(self_id):
		return

	var rect: Rect2 = layoutRect.get_global_rect()

	# Place SELF (bottom center)
	var self_data = players[self_id]
	var self_node := preload("res://scenes/Player.tscn").instantiate()
	playerRingContainer.add_child(self_node)
	self_node.setup(self_data["name"], Color.RED)
	self_node.scale = Vector2(4, 4)

	var bottom_center := Vector2(
		rect.position.x + rect.size.x * 0.5,
		rect.end.y
	)
	self_node.global_position = bottom_center - self_node.size * self_node.scale * 0.5

	var other_ids: Array = players.keys()
	other_ids.erase(self_id)
	other_ids.sort()

	var total_others := other_ids.size()
	if total_others == 0:
		return

	# Maximum players per side
	var max_top := 7
	var max_side := 6

	# Dynamically calculate counts
	var top_count = total_others
	if top_count > max_top:
		top_count = max_top

	var remaining = total_others - top_count

	var left_count := int(remaining / 2)
	if left_count > max_side:
		left_count = max_side

	var right_count = remaining - left_count
	if right_count > max_side:
		right_count = max_side

	var center_x := rect.position.x + rect.size.x * 0.5
	var top_y := rect.position.y
	var left_x := rect.position.x
	var right_x := rect.end.x

	# Calculate spacing
	var top_spacing := 0.0
	if top_count > 1:
		top_spacing = rect.size.x / float(top_count + 1)
	else:
		top_spacing = rect.size.x / 2.0

	var left_spacing := 0.0
	if left_count > 1:
		left_spacing = rect.size.y / float(left_count + 1)
	else:
		left_spacing = rect.size.y / 2.0

	var right_spacing := 0.0
	if right_count > 1:
		right_spacing = rect.size.y / float(right_count + 1)
	else:
		right_spacing = rect.size.y / 2.0

	var index := 0

	# Top side
	for i in range(top_count):
		var peer_id = other_ids[index]
		var data = players[peer_id]

		var x := rect.position.x + (i + 1) * top_spacing
		var y := top_y

		var hue = fmod(index * 0.61, 1.0)
		var color = Color.from_hsv(hue, 0.75, 0.9)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(data["name"], color)
		node.global_position = Vector2(x, y) - node.size * 0.5
		node.scale = Vector2(1.5, 1.5)
		index += 1

	# Left side
	for i in range(left_count):
		var peer_id = other_ids[index]
		var data = players[peer_id]

		var x := left_x
		var y := rect.position.y + (i + 1) * left_spacing

		var hue = fmod(index * 0.61, 1.0)
		var color = Color.from_hsv(hue, 0.75, 0.9)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(data["name"], color)
		node.global_position = Vector2(x, y) - node.size * 0.5
		node.scale = Vector2(1.5, 1.5)
		index += 1

	# Right side
	for i in range(right_count):
		var peer_id = other_ids[index]
		var data = players[peer_id]

		var x := right_x
		var y := rect.position.y + (i + 1) * right_spacing

		var hue = fmod(index * 0.61, 1.0)
		var color = Color.from_hsv(hue, 0.75, 0.9)

		var node = preload("res://scenes/Player.tscn").instantiate()
		playerRingContainer.add_child(node)
		node.setup(data["name"], color)
		node.global_position = Vector2(x, y) - node.size * 0.5
		node.scale = Vector2(1.5, 1.5)
		index += 1

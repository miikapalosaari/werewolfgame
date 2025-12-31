extends MultiplayerSpawner

@export var networkPlayer: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(spawnPlayer)
	multiplayer.peer_disconnected.connect(despawnPlayer)
	
func spawnPlayer(id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var player: Node = networkPlayer.instantiate()
	player.name = str(id)
	
	get_node(spawn_path).call_deferred("add_child", player)
	
func despawnPlayer(id: int) -> void:
	if not multiplayer.is_server():
		return
		
	var parent : Node = get_node(spawn_path)
	var playerNode : Node = parent.get_node_or_null(str(id))
	
	if playerNode:
		playerNode.queue_free()
		
	print("Despawning a player")
	

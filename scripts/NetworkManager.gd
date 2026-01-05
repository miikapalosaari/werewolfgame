extends Node

var maxClients: int = 20
var peer: ENetMultiplayerPeer
var defaultPort: int = 25566

signal playerConnected(peerID)
signal playerDisconnected(peerID)

func _exit_tree() -> void:
	closeConnection()

func _ready() -> void:
	multiplayer.connection_failed.connect(connectionFailed)
	multiplayer.server_disconnected.connect(serverDisconnected)
	
	multiplayer.peer_connected.connect(
		func(id): playerConnected.emit(id)
	)
	multiplayer.peer_disconnected.connect(
		func(id): playerDisconnected.emit(id)
	)

	if OS.has_feature("dedicated_server"):
		var port = defaultPort
		var args = OS.get_cmdline_args()
		
		for i in range(args.size()):
			if args[i] == "--port" and i + 1 < args.size():
				port = int(args[i + 1])
				break
		startServer(port)

func startClient(ipToUse: String, portToUse: int) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ipToUse, portToUse)
	multiplayer.multiplayer_peer = peer
	
func startServer(port: int) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, maxClients)
	multiplayer.multiplayer_peer = peer
	print("Server started on port %d" % port)
	
func connectionFailed() -> void:
	print("Connection failed")
	multiplayer.multiplayer_peer = null

func serverDisconnected() -> void:
	print("Disconnected from server")
	multiplayer.multiplayer_peer = null

func closeConnection() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		print("Disconnecting from server...")
		multiplayer.multiplayer_peer.disconnect_peer(1)
		multiplayer.multiplayer_peer = null

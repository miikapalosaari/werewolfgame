extends Node

var maxClients: int = 20
var peer: ENetMultiplayerPeer
var defaultPort: int = 25566

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		var port = defaultPort
		var args = OS.get_cmdline_args()
		
		for i in range(args.size()):
			if args[i] == "--port" and i + 1 < args.size():
				port = int(args[i + 1])
				break
		startServer(defaultPort)

func startClient(ipToUse: String, portToUse: int) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_client(ipToUse, portToUse)
	multiplayer.multiplayer_peer = peer
	
func startServer(port: int) -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, maxClients)
	multiplayer.multiplayer_peer = peer
	print("Server started on port %d" % port)

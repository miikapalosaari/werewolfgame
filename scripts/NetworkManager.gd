extends Node

const port: int = 7777
var maxClients: int = 20

var peer: ENetMultiplayerPeer
const serverIp: String = "34.51.225.82"

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		print("starting a dedicated server")
		startServer()
	else:
		print("not dedicated server")

func startServer() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(port, maxClients)
	multiplayer.multiplayer_peer = peer
	
func startClient() -> void:
	peer = ENetMultiplayerPeer.new()
	var ipToUse: String = ""
	#if OS.get_name() == "Android":
	#	ipToUse = serverIp
	#else: 
	#	ipToUse = "localhost"
	peer.create_client(serverIp, port)
	multiplayer.multiplayer_peer = peer

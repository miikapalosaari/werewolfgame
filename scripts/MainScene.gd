extends Node

func _ready():
	print("Client: MainScene loaded, requesting game state...")
	GameManager.rpc_id(1, "requestFullState")

func applyGameState(newGameState):
	print("Applying game state:", newGameState)

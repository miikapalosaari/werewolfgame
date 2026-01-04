extends Control

@onready var ipInput = $VBoxContainer/IPInput
@onready var portInput = $VBoxContainer/PortInput

func _on_join_button_pressed() -> void:
	var ip = ipInput.text.strip_edges()
	var port = portInput.text.strip_edges()
	print("joining to: " + ip + ":" + port)
	NetworkManager.startClient(ip, port.to_int())
	if not OS.has_feature("dedicated_server"):
		print("Joining to lobby")
		get_tree().change_scene_to_file("res://scenes/LobbyScene.tscn")

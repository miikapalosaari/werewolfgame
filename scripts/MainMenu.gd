extends Control

@onready var ipInput = $VBoxContainer/IPInput
@onready var portInput = $VBoxContainer/PortInput
@onready var nameInput = $VBoxContainer/NameInput

func _on_join_button_pressed() -> void:
	var ip = ipInput.text.strip_edges()
	var port = portInput.text.strip_edges()
	var nickname = nameInput.text.strip_edges()
	print("joining to: " + ip + ":" + port)
	NetworkManager.pendingNickname = nickname
	NetworkManager.startClient(ip, port.to_int())

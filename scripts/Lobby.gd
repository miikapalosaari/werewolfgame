extends Control

@onready var ipInput = $VBoxContainer/IPInput
@onready var portInput = $VBoxContainer/PortInput

func _on_join_button_pressed() -> void:
	var ip = ipInput.text.strip_edges()
	var port = portInput.text.strip_edges()
	print("joining to: " + ip + ":" + port)
	NetworkManager.startClient(ip, port.to_int())

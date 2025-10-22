extends Control

func _on_join_button_pressed() -> void:
	NetworkManager.startClient()


func _on_host_button_pressed() -> void:
	NetworkManager.startServer()

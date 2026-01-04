extends Control

func _on_ready_button_pressed() -> void:
	GameManager.rpc_id(1, "playerReady")

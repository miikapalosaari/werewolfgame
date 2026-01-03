extends Node

func _ready() -> void:
	if not OS.has_feature("dedicated_server"):
		return
	print("MainScene loaded...")
	
	RolesManager.loadAllRoles()
	print("Found Roles:")
	
	for key in RolesManager.roles.keys():
		var role = RolesManager.roles[key]
		print("ID:", role["id"])

func _process(delta: float) -> void:
	pass

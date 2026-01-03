extends Node

class_name RoleManager

var roles : Dictionary = {}

func loadAllRoles() -> void:
	var dir: DirAccess = DirAccess.open("res://roles")
	if dir == null:
		push_error("Could not open roles folder")
		return
		
	dir.list_dir_begin()
	var filename: String = dir.get_next()
	
	while filename != "":
		if not dir.current_is_dir() and filename.ends_with(".json"):
			var path = "res://roles/" + filename
			var file: FileAccess = FileAccess.open(path, FileAccess.READ)
			if file:
				var text: String = file.get_as_text()
				var json := JSON.new()
				var error := json.parse(text)
				if error == OK:
					roles[json.data["id"]] = json.data
				else:
					push_error("Failed to parse JSON: " + path)
				file.close()
		filename = dir.get_next()
	dir.list_dir_end()

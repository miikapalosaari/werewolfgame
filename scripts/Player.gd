extends Node2D

@onready var colorRect: ColorRect = $ColorRect
@onready var nameLabel: Label = $ColorRect/Label
var peerID: int = 0
signal playerSelected(peerID)

func getRectSize() -> Vector2:
	return colorRect.size

func setup(n: String, color: Color, id: int, s: Vector2):
	peerID = id
	nameLabel.text = n
	colorRect.color = color
	colorRect.size = s
	nameLabel.position.x = (colorRect.size.x - nameLabel.size.x) * 0.5
	nameLabel.position.y = -nameLabel.size.y

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var globalRect = Rect2(colorRect.global_position, colorRect.size)
			if globalRect.has_point(event.position):
				emit_signal("playerSelected", peerID)

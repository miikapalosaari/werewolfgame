extends Node2D

@onready var characterBaseRect: TextureRect = $CharacterBaseRect
@onready var nameLabel: Label = $CharacterBaseRect/Label
@onready var characterHighlightRect: TextureRect = $CharacterHighlightRect
@onready var characterHatColorRect: TextureRect = $CharacterHatColorRect
var peerID: int = 0
var isSelected: bool = false
signal playerSelected(peerID)

func getRectSize() -> Vector2:
	return characterBaseRect.size

func setup(n: String, color: Color, id: int, s: Vector2):
	peerID = id
	nameLabel.text = n
	nameLabel.pivot_offset = nameLabel.size * 0.5
	
	setSize(s)
	setHatColor(color)
	setSelected(false)

func setSize(s: Vector2):
	characterBaseRect.size = s
	characterHighlightRect.size = s
	characterHatColorRect.size = s
	
	var half = s * 0.5
	characterBaseRect.position = -half
	characterHighlightRect.position = -half
	characterHatColorRect.position = -half

func setHatColor(c: Color):
	characterHatColorRect.modulate = c

func setSelected(selected: bool):
	isSelected = selected
	characterHighlightRect.visible = selected

func updateLabelPosition(offsetX: float):
	nameLabel.pivot_offset = nameLabel.size * 0.5
	var basePos = Vector2(0, characterBaseRect.size.y * 0.5 + nameLabel.size.y)
	basePos.x -= nameLabel.size.x / 6
	basePos.y += nameLabel.size.y * 1.5
	basePos.x += offsetX
	nameLabel.position = basePos

func setFacingFromTable(direction: String):
	var offsetX: float = 0
	match direction:
		"top":
			rotation = 0
		"bottom":
			rotation = PI
		"left":
			rotation = -PI / 2
			offsetX = characterBaseRect.size.x
		"right":
			rotation = PI / 2
			offsetX = -characterBaseRect.size.x
	nameLabel.rotation = -rotation
	updateLabelPosition(offsetX)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if characterBaseRect.get_global_rect().has_point(event.position):
				emit_signal("playerSelected", peerID)

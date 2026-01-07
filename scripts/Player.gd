extends Control

@onready var colorRect: ColorRect = $ColorRect
@onready var nameLabel: Label = $Label

func setup(name: String, color: Color):
	nameLabel.text = name
	colorRect.color = color

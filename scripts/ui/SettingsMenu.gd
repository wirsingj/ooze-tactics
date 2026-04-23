extends Control

@onready var back_button: Button = $Center/Panel/Margin/VBox/BackButton
@onready var graphics_style_option: OptionButton = $Center/Panel/Margin/VBox/GraphicsRow/GraphicsStyleOption

const STYLE_2D: String = "2d"
const STYLE_3D: String = "3d"

func _ready() -> void:
	_populate_graphics_style_options()
	graphics_style_option.item_selected.connect(_on_graphics_style_selected)
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _populate_graphics_style_options() -> void:
	graphics_style_option.clear()
	graphics_style_option.add_item("Legacy 2D (Atlas)")
	graphics_style_option.set_item_metadata(0, STYLE_2D)
	graphics_style_option.add_item("Cave 3D (Live)")
	graphics_style_option.set_item_metadata(1, STYLE_3D)
	var run_flow = get_node_or_null("/root/RunFlow")
	var style: String = STYLE_3D
	if run_flow != null and run_flow.has_method("get_graphics_style"):
		style = String(run_flow.call("get_graphics_style"))
	var target_index: int = 0 if style == STYLE_2D else 1
	graphics_style_option.select(target_index)

func _on_graphics_style_selected(index: int) -> void:
	var style: String = String(graphics_style_option.get_item_metadata(index))
	var run_flow = get_node_or_null("/root/RunFlow")
	if run_flow != null and run_flow.has_method("set_graphics_style"):
		run_flow.call("set_graphics_style", style)

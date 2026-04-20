extends Control

@onready var title_label: Label = $Center/Panel/Margin/VBox/TitleLabel
@onready var message_label: Label = $Center/Panel/Margin/VBox/MessageLabel
@onready var continue_button: Button = $Center/Panel/Margin/VBox/ContinueButton
@onready var auto_timer: Timer = $AutoTimer

func _ready() -> void:
	var run_flow: Node = _run_flow()
	title_label.text = run_flow.result_title if not run_flow.result_title.is_empty() else "Result"
	message_label.text = run_flow.result_message
	continue_button.text = run_flow.result_button_text

	continue_button.pressed.connect(_go_next)
	auto_timer.timeout.connect(_go_next)

	if run_flow.result_auto_advance and run_flow.result_delay_seconds > 0.0:
		auto_timer.start(run_flow.result_delay_seconds)

func _go_next() -> void:
	var next_scene: String = _run_flow().result_next_scene
	if next_scene.is_empty():
		next_scene = "res://scenes/MainMenu.tscn"
	get_tree().change_scene_to_file(next_scene)

func _run_flow() -> Node:
	return get_node("/root/RunFlow")

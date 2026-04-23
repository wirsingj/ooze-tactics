extends Control

const MENU_BG_PATH: String = "res://assets/ui/main_menu_background.png"
const FALLBACK_BG_PATH: String = "res://assets/ui/menu_background_fallback.png"

const BTN_NORMAL_PATH: String = "res://assets/ui/menu_button_normal.png"
const BTN_HOVER_PATH: String = "res://assets/ui/menu_button_hover.png"
const BTN_PRESSED_PATH: String = "res://assets/ui/menu_button_pressed.png"
const BTN_SELECTED_PATH: String = "res://assets/ui/menu_button_selected.png"
const MENU_FONT_PATH: String = "res://assets/fonts/PressStart2P-Regular.ttf"

@onready var background: TextureRect = $Background
@onready var top_spacer: Control = $Center/VBox/TopSpacer
@onready var buttons_panel: PanelContainer = $Center/VBox/ButtonsPanel
@onready var start_button: Button = $Center/VBox/ButtonsPanel/ButtonsRow/StartButton
@onready var dev_start_button: Button = $Center/VBox/ButtonsPanel/ButtonsRow/DevStartButton
@onready var settings_button: Button = $Center/VBox/ButtonsPanel/ButtonsRow/SettingsButton
@onready var exit_button: Button = $Center/VBox/ButtonsPanel/ButtonsRow/ExitButton

@onready var dev_overlay: ColorRect = $DevOverlay
@onready var player_team_spin: SpinBox = $DevOverlay/DevPanelCenter/DevPanel/DevMargin/DevVBox/TeamRow/PlayerTeamSize
@onready var enemy_team_spin: SpinBox = $DevOverlay/DevPanelCenter/DevPanel/DevMargin/DevVBox/TeamRow/EnemyTeamSize
@onready var immortal_check: CheckBox = $DevOverlay/DevPanelCenter/DevPanel/DevMargin/DevVBox/ImmortalCheck
@onready var spectator_check: CheckBox = $DevOverlay/DevPanelCenter/DevPanel/DevMargin/DevVBox/SpectatorCheck
@onready var dev_confirm_button: Button = $DevOverlay/DevPanelCenter/DevPanel/DevMargin/DevVBox/DevButtons/DevConfirmButton
@onready var dev_cancel_button: Button = $DevOverlay/DevPanelCenter/DevPanel/DevMargin/DevVBox/DevButtons/DevCancelButton

func _ready() -> void:
	_apply_background()
	_apply_menu_theme()
	_connect_buttons()
	_update_layout_for_window()
	dev_overlay.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout_for_window()

func _connect_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	dev_start_button.pressed.connect(_on_dev_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	dev_confirm_button.pressed.connect(_on_dev_confirm_pressed)
	dev_cancel_button.pressed.connect(_on_dev_cancel_pressed)

func _apply_background() -> void:
	if ResourceLoader.exists(MENU_BG_PATH):
		background.texture = load(MENU_BG_PATH)
	elif ResourceLoader.exists(FALLBACK_BG_PATH):
		background.texture = load(FALLBACK_BG_PATH)

func _apply_menu_theme() -> void:
	var theme := Theme.new()
	var font := _load_runtime_font(MENU_FONT_PATH)
	if font != null:
		theme.set_default_font(font)
	theme.set_default_font_size(13)

	var normal := _make_stylebox(BTN_NORMAL_PATH, 14, 8)
	var hover := _make_stylebox(BTN_HOVER_PATH, 14, 8)
	var pressed := _make_stylebox(BTN_PRESSED_PATH, 14, 8)
	var selected := _make_stylebox(BTN_SELECTED_PATH, 14, 8)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", selected)
	theme.set_color("font_color", "Button", Color(0.95, 0.92, 0.84))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.98, 0.9))
	theme.set_color("font_pressed_color", "Button", Color(0.92, 0.9, 0.84))
	theme.set_color("font_color", "Label", Color(0.95, 0.94, 0.87))
	theme.set_color("font_color", "CheckBox", Color(0.95, 0.94, 0.87))

	self.theme = theme
	if buttons_panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = Color(0.02, 0.02, 0.03, 0.50)
		panel_style.border_color = Color(0.78, 0.58, 0.24, 0.72)
		panel_style.set_border_width_all(2)
		panel_style.corner_radius_top_left = 8
		panel_style.corner_radius_top_right = 8
		panel_style.corner_radius_bottom_left = 8
		panel_style.corner_radius_bottom_right = 8
		panel_style.set_content_margin(SIDE_LEFT, 10.0)
		panel_style.set_content_margin(SIDE_TOP, 10.0)
		panel_style.set_content_margin(SIDE_RIGHT, 10.0)
		panel_style.set_content_margin(SIDE_BOTTOM, 10.0)
		buttons_panel.add_theme_stylebox_override("panel", panel_style)
	for button in [start_button, dev_start_button, settings_button, exit_button, dev_confirm_button, dev_cancel_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 14)

func _update_layout_for_window() -> void:
	if top_spacer == null:
		return
	# Keep button panel below the title and in the lower third on most window sizes.
	var h: float = size.y
	top_spacer.custom_minimum_size.y = clampf(h * 0.58, 260.0, 680.0)

func _make_stylebox(texture_path: String, margin: int, content: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	if ResourceLoader.exists(texture_path):
		style.texture = load(texture_path)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.set_content_margin(SIDE_LEFT, content)
	style.set_content_margin(SIDE_TOP, content)
	style.set_content_margin(SIDE_RIGHT, content)
	style.set_content_margin(SIDE_BOTTOM, content)
	return style

func _load_runtime_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var font_file := FontFile.new()
	if font_file.load_dynamic_font(path) != OK:
		return null
	return font_file

func _on_start_pressed() -> void:
	_run_flow().begin_run()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_dev_start_pressed() -> void:
	player_team_spin.value = float(_run_flow().dev_player_team_size)
	enemy_team_spin.value = float(_run_flow().dev_enemy_team_size)
	immortal_check.button_pressed = bool(_run_flow().dev_player_immortal)
	spectator_check.button_pressed = bool(_run_flow().dev_spectator_mode)
	dev_overlay.visible = true

func _on_dev_confirm_pressed() -> void:
	var player_team_size: int = int(player_team_spin.value)
	var enemy_team_size: int = int(enemy_team_spin.value)
	var immortal: bool = immortal_check.button_pressed
	var spectator: bool = spectator_check.button_pressed
	_run_flow().begin_dev_run(player_team_size, enemy_team_size, immortal, spectator)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_dev_cancel_pressed() -> void:
	dev_overlay.visible = false

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/SettingsMenu.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _run_flow() -> Node:
	return get_node("/root/RunFlow")

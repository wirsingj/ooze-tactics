extends Node2D

# Scene-level orchestrator for input, queueing, turn commits, and UI refresh.

const TILE_SIZE: int = 44
const MIN_RENDER_TILE_SIZE: int = 12
const ANIM_FRAME_TIME: float = 0.18
const ENEMY_FLASH_DURATION: float = 0.65
const TURN_PULSE_BATCH_MIN: int = 2
const TURN_PULSE_BATCH_MAX: int = 4
const TURN_PULSE_MIN_DURATION: float = 0.08
const TURN_PULSE_MAX_DURATION: float = 0.12
const TURN_PULSE_BATCH_GAP: float = 0.05
const TURN_PULSE_END_PAUSE: float = 0.14
const TURN_PULSE_MAX_TOTAL: float = 2.0
const TURN_PULSE_MAX_TILES: int = 40
const SPECTATOR_STEP_DELAY: float = 0.26
const MIN_EXPAND_ADJACENT: int = 1
const PLAY_REGION_PANEL_GAP: float = 8.0
const PLAY_REGION_VISUAL_INSET: float = 8.0
const ACTION_VALIDATOR_SCRIPT: GDScript = preload("res://scripts/systems/ActionValidator.gd")
const TURN_RESOLVER_SCRIPT: GDScript = preload("res://scripts/systems/TurnResolver.gd")
const OOZE_AI_SCRIPT: GDScript = preload("res://scripts/systems/OozeAI.gd")
const ENEMY_FEEDBACK_SCRIPT: GDScript = preload("res://scripts/systems/EnemyFeedback.gd")
const WORLD_RENDER_LAYER_SCRIPT: GDScript = preload("res://scripts/ui/WorldRenderLayer.gd")
const SLIME_LAYER_SHADER: Shader = preload("res://assets/shaders/slime_layer.gdshader")
const ACTION_BUTTON_HINTS: Dictionary = {
	"basic": "Basic: cheap expansion tile.",
	"melee": "Melee: frontline breaker, strongest in contact.",
	"ranged": "Ranged: fires from behind, weaker while engaged.",
	"defense": "Defense: durable frontline holder.",
	"gather": "Gather: economy tile, strongest on resources.",
	"end_turn": "End Turn: resolve staged actions.",
	"clear_queue": "Clear Queue: remove all staged actions.",
	"menu": "Menu: return-to-menu options.",
	"dev_upgrade": "Dev Upgrade: open run upgrade picker.",
}

var tick_system: TickSystem = TickSystem.new()
var ai: RefCounted = OOZE_AI_SCRIPT.new()
var generator: LevelGenerator = LevelGenerator.new()
var director: LevelDirector = LevelDirector.new()
var renderer: BoardRenderer = BoardRenderer.new()
var intent_planner: IntentPlanner = IntentPlanner.new()
var validator = ACTION_VALIDATOR_SCRIPT.new()
var turn_resolver = TURN_RESOLVER_SCRIPT.new()
var enemy_feedback = ENEMY_FEEDBACK_SCRIPT.new()

var room_templates: Array = []
var state: GameState

var queued_actions: Array = []
var enemy_intent_actions: Array = []
var recent_enemy_actions: Array = []
var recent_enemy_failed_actions: Array = []
var preview_action_serial: int = 1

var selected_tile: Vector2i = Vector2i(-1, -1)
var hovered_tile: Vector2i = Vector2i(-1, -1)
var selected_tile_type: String = "basic"
var run_over: bool = false
var pending_left_click_active: bool = false
var pending_left_click_tile: Vector2i = Vector2i(-1, -1)
var pending_left_click_spectator: bool = false

var valid_place_targets: Array = []
var valid_convert_targets: Array = []
var hover_preview_action: Dictionary = {}
var hover_invalid_reason: String = ""

var status_message: String = ""
var status_timer: float = 0.0
var button_hover_description: String = ""
var hover_hint_bindings: Array[Dictionary] = []

var anim_timer: float = 0.0
var anim_frame: int = 0
var enemy_flash_timer: float = 0.0
var pulse_batches: Array = []
var pulse_batch_index: int = -1
var pulse_batch_timer: float = 0.0
var pulse_batch_duration: float = TURN_PULSE_MAX_DURATION
var pulse_gap_timer: float = 0.0
var pulse_finish_pause: float = 0.0
var pulse_active: bool = false
var pending_outcome: Dictionary = {}
var pending_victory_outcome: Dictionary = {}
var pending_ui_refresh: bool = false
var spectator_turn_delay: float = 0.0
var turn_speed_multiplier: float = 1.0
var spectator_paused: bool = false
var active_owner_id: int = GameState.PLAYER_ID
var actor_cycle_order: Array = []
var actor_cycle_index: int = 0
var actor_round_index: int = 0
var owner_display_numbers: Dictionary = {}
var slime_shader_time: float = 0.0

var board_origin: Vector2 = Vector2(16, 64)
var board_clip_rect: Rect2 = Rect2(16, 64, 960, 560)
var _last_board_region_rect: Rect2 = Rect2(-1, -1, -1, -1)
var _render_tile_size: float = float(TILE_SIZE)
var world_background_layer: WorldRenderLayer = null
var world_slime_layer: WorldRenderLayer = null
var world_emissive_layer: WorldRenderLayer = null
var world_overlay_layer: WorldRenderLayer = null
var world_3d_enabled: bool = true

var _button_style_normal: StyleBoxTexture = null
var _button_style_hover: StyleBoxTexture = null
var _button_style_pressed: StyleBoxTexture = null
var _button_style_selected: StyleBoxTexture = null
var upgrade_choices: Array = []

@onready var ui_root: Control = $CanvasLayer/UI
@onready var board_region: Control = $CanvasLayer/UI/BoardRegion
@onready var world_3d_host: SubViewportContainer = $CanvasLayer/UI/BoardRegion/World3DHost
@onready var world_3d_viewport: SubViewport = $CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport
@onready var world_3d_root: World3DRenderer = $CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport/World3DRoot
@onready var top_panel: Control = $CanvasLayer/UI/TopPanel
@onready var right_panel: Control = $CanvasLayer/UI/RightPanel
@onready var bottom_panel: Control = $CanvasLayer/UI/BottomPanel
@onready var player_label: Label = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TopRow/PlayerLabel
@onready var turn_label: Label = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TopRow/TurnLabel
@onready var enemy_label: Label = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TopRow/EnemyLabel
@onready var left_team_status_label: RichTextLabel = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TeamStatusRow/LeftTeamStatus
@onready var right_team_status_label: RichTextLabel = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TeamStatusRow/RightTeamStatus
@onready var pause_button: Button = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TopRow/TopRightControls/PauseButton
@onready var speed_1_button: Button = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TopRow/TopRightControls/Speed1Button
@onready var speed_4_button: Button = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TopRow/TopRightControls/Speed4Button
@onready var speed_8_button: Button = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/TopRow/TopRightControls/Speed8Button
@onready var actor_bar: RichTextLabel = $CanvasLayer/UI/TopPanel/TopMargin/TopVBox/ActorBar

@onready var energy_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/EnergyLabel
@onready var queue_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/QueueLabel
@onready var mode_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/ModeLabel
@onready var debug_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/DebugLabel

@onready var basic_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ActionGroups/ExpansionGroup/ExpansionMargin/BasicButton
@onready var melee_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ActionGroups/CombatGroup/CombatMargin/CombatButtons/MeleeButton
@onready var ranged_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ActionGroups/CombatGroup/CombatMargin/CombatButtons/RangedButton
@onready var gather_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ActionGroups/EconomyGroup/EconomyMargin/GatherButton
@onready var defense_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ActionGroups/CombatGroup/CombatMargin/CombatButtons/DefenseButton
@onready var end_turn_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ControlsColumn/EndTurnButton
@onready var clear_queue_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ControlsColumn/ClearQueueButton
@onready var return_menu_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ControlsColumn/ReturnMenuButton
@onready var dev_upgrade_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ControlsColumn/DevUpgradeButton

@onready var log_label: RichTextLabel = $CanvasLayer/UI/RightPanel/RightMargin/Log
@onready var menu_confirm_overlay: ColorRect = $CanvasLayer/UI/MenuConfirmOverlay
@onready var menu_confirm_button: Button = $CanvasLayer/UI/MenuConfirmOverlay/Center/Panel/Margin/VBox/ButtonRow/ConfirmButton
@onready var menu_cancel_button: Button = $CanvasLayer/UI/MenuConfirmOverlay/Center/Panel/Margin/VBox/ButtonRow/CancelButton
@onready var upgrade_overlay: ColorRect = $CanvasLayer/UI/UpgradeOverlay
@onready var upgrade_header_label: Label = $CanvasLayer/UI/UpgradeOverlay/Center/Panel/Margin/VBox/HeaderLabel
@onready var upgrade_hint_label: Label = $CanvasLayer/UI/UpgradeOverlay/Center/Panel/Margin/VBox/HintLabel
@onready var upgrade_button_1: Button = $CanvasLayer/UI/UpgradeOverlay/Center/Panel/Margin/VBox/ChoiceRow/ChoiceButton1
@onready var upgrade_button_2: Button = $CanvasLayer/UI/UpgradeOverlay/Center/Panel/Margin/VBox/ChoiceRow/ChoiceButton2
@onready var upgrade_button_3: Button = $CanvasLayer/UI/UpgradeOverlay/Center/Panel/Margin/VBox/ChoiceRow/ChoiceButton3

func _ready() -> void:
	renderer.tile_size = _render_tile_size
	turn_resolver.tick_system = tick_system
	_setup_world_layers()
	_setup_3d_presentation()
	_apply_ui_theme()
	upgrade_overlay.visible = false
	_load_data()
	_run_flow().ensure_run()
	_start_level()
	_update_board_layout(true)
	_wire_ui()
	_recompute_action_context()
	_apply_control_mode_state()
	_refresh_ui()
	_queue_world_redraw()

func _process(delta: float) -> void:
	_update_board_layout()
	_sync_hover_hint_from_mouse()
	var using_3d: bool = _use_3d_world()
	var spectator_hard_pause: bool = _is_spectator_mode() and spectator_paused
	var pacing_delta: float = 0.0 if spectator_hard_pause else delta * turn_speed_multiplier

	var needs_redraw: bool = false
	if using_3d and world_3d_root != null:
		world_3d_root.tick_visual(pacing_delta if pacing_delta > 0.0 else delta)

	if pacing_delta > 0.0 and not using_3d:
		anim_timer += pacing_delta
		if anim_timer >= ANIM_FRAME_TIME:
			anim_timer = 0.0
			anim_frame = (anim_frame + 1) % 3
			needs_redraw = true

		if enemy_flash_timer > 0.0:
			enemy_flash_timer = maxf(0.0, enemy_flash_timer - pacing_delta)
			needs_redraw = true

	if status_timer > 0.0:
		status_timer = maxf(0.0, status_timer - delta)
		if status_timer <= 0.0 and status_message.begins_with("Invalid"):
			status_message = ""
			_refresh_ui()

	if pacing_delta > 0.0 and _update_turn_pulse(pacing_delta):
		if not using_3d:
			needs_redraw = true

	if pacing_delta > 0.0 and _is_spectator_mode() and not spectator_paused and not run_over and not _is_modal_overlay_open() and not pulse_active:
		spectator_turn_delay = maxf(0.0, spectator_turn_delay - pacing_delta)
		if spectator_turn_delay <= 0.0:
			_run_next_spectator_turn()
			if using_3d:
				_queue_world_redraw()
			else:
				needs_redraw = true

	if needs_redraw:
		_update_slime_shader_time(pacing_delta)
		_queue_world_redraw()

func _draw() -> void:
	# World rendering is split into dedicated child layers so slime can use a
	# material shader without affecting ground or UI overlays.
	if world_background_layer == null or world_slime_layer == null or world_emissive_layer == null or world_overlay_layer == null:
		_draw_world_background(self)
		_draw_world_slime(self)
		_draw_world_emissive(self)
		_draw_world_overlay(self)

func _setup_world_layers() -> void:
	if world_background_layer != null and world_slime_layer != null and world_emissive_layer != null and world_overlay_layer != null:
		return

	world_background_layer = WORLD_RENDER_LAYER_SCRIPT.new()
	world_background_layer.name = "WorldBackgroundLayer"
	world_background_layer.controller = self
	world_background_layer.layer_kind = "background"
	world_background_layer.z_index = 0
	add_child(world_background_layer)

	world_slime_layer = WORLD_RENDER_LAYER_SCRIPT.new()
	world_slime_layer.name = "WorldSlimeLayer"
	world_slime_layer.controller = self
	world_slime_layer.layer_kind = "slime"
	world_slime_layer.z_index = 1
	world_slime_layer.material = _build_slime_material()
	add_child(world_slime_layer)

	world_emissive_layer = WORLD_RENDER_LAYER_SCRIPT.new()
	world_emissive_layer.name = "WorldEmissiveLayer"
	world_emissive_layer.controller = self
	world_emissive_layer.layer_kind = "emissive"
	world_emissive_layer.z_index = 2
	world_emissive_layer.material = _build_emissive_material()
	add_child(world_emissive_layer)

	world_overlay_layer = WORLD_RENDER_LAYER_SCRIPT.new()
	world_overlay_layer.name = "WorldOverlayLayer"
	world_overlay_layer.controller = self
	world_overlay_layer.layer_kind = "overlay"
	world_overlay_layer.z_index = 3
	add_child(world_overlay_layer)

func _build_slime_material() -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SLIME_LAYER_SHADER
	mat.set_shader_parameter("rim_strength", 0.28)
	mat.set_shader_parameter("interior_lift", 0.14)
	mat.set_shader_parameter("directional_strength", 0.14)
	mat.set_shader_parameter("variation_strength", 0.11)
	mat.set_shader_parameter("soft_edge_strength", 0.10)
	mat.set_shader_parameter("emissive_strength", 0.045)
	mat.set_shader_parameter("rim_light_strength", 0.08)
	mat.set_shader_parameter("bloom_strength", 0.045)
	mat.set_shader_parameter("bloom_radius", 0.06)
	mat.set_shader_parameter("effect_boost", 1.10)
	mat.set_shader_parameter("u_time", 0.0)
	return mat

func _build_emissive_material() -> CanvasItemMaterial:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return mat

func _update_slime_shader_time(delta: float) -> void:
	if world_slime_layer == null:
		return
	if not world_slime_layer.material is ShaderMaterial:
		return
	slime_shader_time += delta
	(world_slime_layer.material as ShaderMaterial).set_shader_parameter("u_time", slime_shader_time)

func _draw_world_background(canvas: Node2D) -> void:
	if _use_3d_world():
		return
	if state == null:
		return
	renderer.draw_world_background(
		canvas,
		state,
		board_origin,
		board_clip_rect,
		valid_place_targets,
		valid_convert_targets
	)

func _draw_world_slime(canvas: Node2D) -> void:
	if _use_3d_world():
		return
	if state == null:
		return
	renderer.draw_world_slime(
		canvas,
		state,
		board_origin,
		board_clip_rect,
		queued_actions,
		enemy_intent_actions,
		hover_preview_action,
		anim_frame,
		_current_pulse_tiles(),
		_current_pulse_alpha()
	)

func _draw_world_emissive(canvas: Node2D) -> void:
	if _use_3d_world():
		return
	if state == null:
		return
	renderer.draw_world_emissive(
		canvas,
		state,
		board_origin,
		board_clip_rect,
		anim_frame
	)

func _draw_world_overlay(canvas: Node2D) -> void:
	if _use_3d_world():
		return
	if state == null:
		return
	var enemy_flash_alpha: float = 0.0
	if ENEMY_FLASH_DURATION > 0.0:
		enemy_flash_alpha = enemy_flash_timer / ENEMY_FLASH_DURATION
	renderer.draw_world_overlay(
		canvas,
		state,
		board_origin,
		board_clip_rect,
		selected_tile,
		hovered_tile,
		queued_actions,
		hover_invalid_reason,
		recent_enemy_actions,
		enemy_flash_alpha
	)

func _queue_world_redraw() -> void:
	if _use_3d_world():
		_sync_3d_world()
		return
	if world_background_layer != null:
		world_background_layer.queue_redraw()
	if world_slime_layer != null:
		world_slime_layer.queue_redraw()
	if world_emissive_layer != null:
		world_emissive_layer.queue_redraw()
	if world_overlay_layer != null:
		world_overlay_layer.queue_redraw()

func _setup_3d_presentation() -> void:
	if not _use_3d_world():
		return
	if world_3d_host != null:
		world_3d_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
		world_3d_host.stretch = false
		world_3d_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world_3d_host.visible = true
	if world_3d_viewport != null:
		if world_3d_viewport.world_3d == null:
			world_3d_viewport.world_3d = World3D.new()
		world_3d_viewport.transparent_bg = false
	if world_3d_root != null:
		world_3d_root.configure(renderer)
	if world_background_layer != null:
		world_background_layer.visible = false
	if world_slime_layer != null:
		world_slime_layer.visible = false
	if world_emissive_layer != null:
		world_emissive_layer.visible = false
	if world_overlay_layer != null:
		world_overlay_layer.visible = false

func _use_3d_world() -> bool:
	return world_3d_enabled and world_3d_root != null and world_3d_host != null and world_3d_viewport != null

func _sync_3d_world() -> void:
	if not _use_3d_world() or state == null:
		return
	world_3d_root.sync_world(
		state,
		selected_tile,
		hovered_tile,
		queued_actions,
		hover_preview_action,
		hover_invalid_reason,
		recent_enemy_actions,
		anim_frame
	)

func _handle_3d_camera_input(event: InputEvent) -> bool:
	if not _use_3d_world():
		return false
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var inside_board: bool = board_clip_rect.has_point(mouse_pos)
	var board_local: Vector2 = mouse_pos - board_clip_rect.position
	return world_3d_root.handle_camera_input(event, board_local, inside_board)

func _clear_pending_left_click() -> void:
	pending_left_click_active = false
	pending_left_click_tile = Vector2i(-1, -1)
	pending_left_click_spectator = false

func _unhandled_input(event: InputEvent) -> void:
	if _use_3d_world() and not _is_modal_overlay_open():
		if _handle_3d_camera_input(event):
			if event is InputEventMouseButton:
				var camera_mouse_event: InputEventMouseButton = event
				if camera_mouse_event.button_index == MOUSE_BUTTON_LEFT and not camera_mouse_event.pressed:
					_clear_pending_left_click()
			return

	if run_over or _is_modal_overlay_open():
		_clear_pending_left_click()
		return

	if _is_spectator_mode():
		if event is InputEventMouseMotion:
			hovered_tile = _mouse_to_tile(get_local_mouse_position())
			_recompute_hover_context()
			_refresh_ui()
			_queue_world_redraw()
			return
		if pulse_active:
			_clear_pending_left_click()
			return
		if event is InputEventMouseButton:
			var spectator_mouse: InputEventMouseButton = event
			if spectator_mouse.button_index == MOUSE_BUTTON_LEFT:
				if spectator_mouse.pressed:
					pending_left_click_active = true
					pending_left_click_spectator = true
					pending_left_click_tile = _mouse_to_tile(get_local_mouse_position())
				else:
					if not pending_left_click_active or not pending_left_click_spectator:
						return
					var consume_drag_release: bool = _use_3d_world() and world_3d_root != null and world_3d_root.should_consume_left_release()
					var spectate_tile: Vector2i = _mouse_to_tile(get_local_mouse_position())
					if spectate_tile == Vector2i(-1, -1):
						spectate_tile = pending_left_click_tile
					_clear_pending_left_click()
					if consume_drag_release:
						return
					if spectate_tile != Vector2i(-1, -1) and _try_dev_heart_defeat(spectate_tile):
						_refresh_ui()
						_queue_world_redraw()
		return

	if event is InputEventMouseMotion:
		hovered_tile = _mouse_to_tile(get_local_mouse_position())
		_recompute_hover_context()
		_refresh_ui()
		_queue_world_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		var pressed_event: InputEventMouseButton = event
		if pressed_event.button_index == MOUSE_BUTTON_LEFT:
			pending_left_click_active = true
			pending_left_click_spectator = false
			pending_left_click_tile = _mouse_to_tile(get_local_mouse_position())
			return

	if event is InputEventMouseButton and not event.pressed:
		var release_event: InputEventMouseButton = event
		if release_event.button_index == MOUSE_BUTTON_LEFT:
			if not pending_left_click_active or pending_left_click_spectator:
				return
			var consume_drag_release: bool = _use_3d_world() and world_3d_root != null and world_3d_root.should_consume_left_release()
			var tile: Vector2i = _mouse_to_tile(get_local_mouse_position())
			if tile == Vector2i(-1, -1):
				tile = pending_left_click_tile
			_clear_pending_left_click()
			if consume_drag_release or tile == Vector2i(-1, -1):
				return
			selected_tile = tile
			if _try_dev_heart_defeat(tile):
				_recompute_action_context()
				_refresh_ui()
				_queue_world_redraw()
				return
			var outcome: Dictionary = _queue_action_from_click(tile)
			if not bool(outcome.get("ok", false)):
				_set_status("Invalid: %s" % String(outcome.get("reason", "unknown")), 2.2)
			elif not String(outcome.get("message", "")).is_empty():
				_set_status(String(outcome["message"]), 1.4)
			_recompute_action_context()
			_refresh_ui()
			_queue_world_redraw()
			return

	if event is InputEventMouseButton and event.pressed:
		var right_event: InputEventMouseButton = event
		if right_event.button_index == MOUSE_BUTTON_RIGHT:
			var tile: Vector2i = _mouse_to_tile(get_local_mouse_position())
			if tile == Vector2i(-1, -1):
				return
			selected_tile = tile
			if not _remove_player_action_for_tile(tile):
				_set_status("No queued action on that tile", 1.4)
			_recompute_action_context()
			_refresh_ui()
			_queue_world_redraw()

func _wire_ui() -> void:
	basic_button.pressed.connect(_set_mode.bind("basic"))
	melee_button.pressed.connect(_set_mode.bind("melee"))
	ranged_button.pressed.connect(_set_mode.bind("ranged"))
	gather_button.pressed.connect(_set_mode.bind("gather"))
	defense_button.pressed.connect(_set_mode.bind("defense"))
	pause_button.pressed.connect(_toggle_spectator_pause)
	speed_1_button.pressed.connect(_set_turn_speed.bind(1.0))
	speed_4_button.pressed.connect(_set_turn_speed.bind(4.0))
	speed_8_button.pressed.connect(_set_turn_speed.bind(8.0))

	end_turn_button.pressed.connect(_resolve_turn)
	clear_queue_button.pressed.connect(_clear_queue)
	return_menu_button.pressed.connect(_open_menu_confirm)
	dev_upgrade_button.pressed.connect(_open_dev_upgrade_picker)
	menu_confirm_button.pressed.connect(_confirm_return_to_menu)
	menu_cancel_button.pressed.connect(_close_menu_confirm)
	upgrade_button_1.pressed.connect(_on_upgrade_choice_pressed.bind(0))
	upgrade_button_2.pressed.connect(_on_upgrade_choice_pressed.bind(1))
	upgrade_button_3.pressed.connect(_on_upgrade_choice_pressed.bind(2))

	_bind_hover_hint(basic_button, String(ACTION_BUTTON_HINTS.get("basic", "")))
	_bind_hover_hint(melee_button, String(ACTION_BUTTON_HINTS.get("melee", "")))
	_bind_hover_hint(ranged_button, String(ACTION_BUTTON_HINTS.get("ranged", "")))
	_bind_hover_hint(defense_button, String(ACTION_BUTTON_HINTS.get("defense", "")))
	_bind_hover_hint(gather_button, String(ACTION_BUTTON_HINTS.get("gather", "")))
	_bind_hover_hint(end_turn_button, String(ACTION_BUTTON_HINTS.get("end_turn", "")))
	_bind_hover_hint(clear_queue_button, String(ACTION_BUTTON_HINTS.get("clear_queue", "")))
	_bind_hover_hint(return_menu_button, String(ACTION_BUTTON_HINTS.get("menu", "")))
	_bind_hover_hint(dev_upgrade_button, String(ACTION_BUTTON_HINTS.get("dev_upgrade", "")))

func _bind_hover_hint(button: Control, hint_text: String) -> void:
	button.tooltip_text = hint_text
	button.mouse_entered.connect(_set_button_hover_description.bind(hint_text))
	button.mouse_exited.connect(_clear_button_hover_description)
	hover_hint_bindings.append({
		"control": button,
		"hint": hint_text,
	})

func _sync_hover_hint_from_mouse() -> void:
	if _is_modal_overlay_open():
		if not button_hover_description.is_empty():
			button_hover_description = ""
			_refresh_ui()
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var hover_hint: String = ""
	for binding in hover_hint_bindings:
		var control: Control = binding.get("control", null) as Control
		if control == null or not is_instance_valid(control):
			continue
		if not control.is_visible_in_tree():
			continue
		if control.get_global_rect().has_point(mouse_pos):
			hover_hint = String(binding.get("hint", ""))
			break

	if hover_hint != button_hover_description:
		button_hover_description = hover_hint
		_refresh_ui()

func _set_button_hover_description(message: String) -> void:
	button_hover_description = message
	_refresh_ui()

func _clear_button_hover_description() -> void:
	button_hover_description = ""
	_refresh_ui()

func _apply_ui_theme() -> void:
	var ui_theme: Theme = Theme.new()
	var font: Font = _load_runtime_font("res://assets/fonts/PressStart2P-Regular.ttf")
	if font != null:
		ui_theme.set_default_font(font)
	ui_theme.set_default_font_size(11)

	var panel_style: StyleBoxTexture = _make_stylebox_texture(renderer.make_ui_skin("ui_panel_tile"), 10, 8)
	panel_style.modulate_color = Color(1.0, 1.0, 1.0, 1.0)
	ui_theme.set_stylebox("panel", "PanelContainer", panel_style)

	_button_style_normal = _make_stylebox_texture(renderer.make_ui_skin("ui_button_tile"), 8, 6)
	_button_style_normal.modulate_color = Color(0.94, 0.94, 0.94, 1.0)
	_button_style_hover = _make_stylebox_texture(renderer.make_ui_skin("ui_button_hover_tile"), 8, 6)
	_button_style_hover.modulate_color = Color(1.02, 1.02, 1.02, 1.0)
	_button_style_pressed = _make_stylebox_texture(renderer.make_ui_skin("ui_button_pressed_tile"), 8, 6)
	_button_style_pressed.modulate_color = Color(0.98, 0.98, 0.98, 1.0)
	_button_style_selected = _make_stylebox_texture(renderer.make_ui_skin("ui_button_selected"), 8, 6)
	_button_style_selected.modulate_color = Color(1.0, 1.0, 1.0, 1.0)

	ui_theme.set_stylebox("normal", "Button", _button_style_normal)
	ui_theme.set_stylebox("hover", "Button", _button_style_hover)
	ui_theme.set_stylebox("pressed", "Button", _button_style_pressed)
	ui_theme.set_stylebox("focus", "Button", _button_style_hover)

	ui_theme.set_color("font_color", "Label", Color(0.96, 0.94, 0.86))
	ui_theme.set_color("default_color", "RichTextLabel", Color(0.94, 0.93, 0.86))
	ui_theme.set_color("font_color", "Button", Color(0.97, 0.95, 0.88))
	ui_theme.set_color("icon_normal_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	ui_theme.set_color("icon_hover_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	ui_theme.set_color("icon_pressed_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	ui_theme.set_color("icon_focus_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	ui_theme.set_color("icon_disabled_color", "Button", Color(1.0, 1.0, 1.0, 0.95))
	ui_theme.set_constant("line_separation", "RichTextLabel", 2)
	var rich_empty: StyleBoxEmpty = StyleBoxEmpty.new()
	ui_theme.set_stylebox("normal", "RichTextLabel", rich_empty)
	ui_theme.set_stylebox("focus", "RichTextLabel", rich_empty)

	ui_root.theme = ui_theme
	top_panel.add_theme_stylebox_override("panel", _stylebox_modulated(panel_style, Color(0.97, 0.95, 0.92, 1.0)))
	right_panel.add_theme_stylebox_override("panel", _stylebox_modulated(panel_style, Color(0.93, 0.92, 0.89, 1.0)))
	bottom_panel.add_theme_stylebox_override("panel", _stylebox_modulated(panel_style, Color(0.95, 0.93, 0.90, 1.0)))

	basic_button.icon = renderer.make_ui_icon("basic", 34)
	melee_button.icon = renderer.make_ui_icon("melee", 34)
	ranged_button.icon = renderer.make_ui_icon("ranged", 34)
	gather_button.icon = renderer.make_ui_icon("gather", 34)
	defense_button.icon = renderer.make_ui_icon("defense", 34)

	for button in [basic_button, melee_button, ranged_button, gather_button, defense_button]:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = false
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_constant_override("h_separation", 4)
		button.clip_text = false
		button.focus_mode = Control.FOCUS_CLICK

	for speed_button in [speed_1_button, speed_4_button, speed_8_button, pause_button]:
		speed_button.add_theme_font_size_override("font_size", 10)
		speed_button.focus_mode = Control.FOCUS_CLICK

	for utility_button in [clear_queue_button, return_menu_button, dev_upgrade_button]:
		utility_button.add_theme_font_size_override("font_size", 10)
		utility_button.focus_mode = Control.FOCUS_CLICK

	for choice_button in [upgrade_button_1, upgrade_button_2, upgrade_button_3]:
		choice_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choice_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice_button.clip_text = false
		choice_button.custom_minimum_size = Vector2(0, 82)
		choice_button.add_theme_font_size_override("font_size", 10)
		choice_button.focus_mode = Control.FOCUS_CLICK

	var endturn_style: StyleBoxTexture = _make_stylebox_texture(renderer.make_ui_skin("ui_button_endturn"), 8, 6)
	endturn_style.modulate_color = Color(0.96, 0.96, 0.96, 1.0)
	var endturn_hover: StyleBoxTexture = _make_stylebox_texture(renderer.make_ui_skin("ui_button_endturn_hover"), 8, 6)
	endturn_hover.modulate_color = Color(1.02, 1.02, 1.02, 1.0)
	var endturn_pressed: StyleBoxTexture = _make_stylebox_texture(renderer.make_ui_skin("ui_button_endturn_pressed"), 8, 6)
	endturn_pressed.modulate_color = Color(0.98, 0.98, 0.98, 1.0)
	var endturn_disabled: StyleBoxTexture = _stylebox_modulated(endturn_style, Color(0.72, 0.72, 0.72, 0.92))
	end_turn_button.add_theme_stylebox_override("normal", endturn_style)
	end_turn_button.add_theme_stylebox_override("hover", endturn_hover)
	end_turn_button.add_theme_stylebox_override("pressed", endturn_pressed)
	end_turn_button.add_theme_stylebox_override("focus", endturn_style)
	end_turn_button.add_theme_stylebox_override("disabled", endturn_disabled)
	end_turn_button.focus_mode = Control.FOCUS_CLICK

	energy_label.add_theme_font_size_override("font_size", 13)
	energy_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 1.0))
	queue_label.add_theme_font_size_override("font_size", 11)
	queue_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.82, 1.0))
	mode_label.add_theme_font_size_override("font_size", 10)
	mode_label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.74, 1.0))
	debug_label.add_theme_font_size_override("font_size", 10)
	debug_label.add_theme_color_override("font_color", Color(0.7, 0.73, 0.7, 1.0))
	left_team_status_label.add_theme_font_size_override("normal_font_size", 9)
	right_team_status_label.add_theme_font_size_override("normal_font_size", 9)
	left_team_status_label.add_theme_constant_override("line_separation", 1)
	right_team_status_label.add_theme_constant_override("line_separation", 1)

func _set_mode(tile_type: String) -> void:
	selected_tile_type = tile_type
	_set_status("Mode: %s" % selected_tile_type.to_upper(), 1.0)
	_recompute_action_context()
	_refresh_ui()
	_queue_world_redraw()

func _clear_queue() -> void:
	queued_actions.clear()
	_set_status("Queue cleared", 1.0)
	_recompute_action_context()
	_refresh_ui()
	_queue_world_redraw()

func _open_dev_upgrade_picker() -> void:
	var run_flow = _run_flow()
	if not bool(run_flow.get("dev_mode")):
		return
	if _is_spectator_mode() or run_over or pulse_active or _is_modal_overlay_open():
		return
	_open_upgrade_overlay(false)

func _toggle_spectator_pause() -> void:
	if not _is_spectator_mode():
		return
	spectator_paused = not spectator_paused
	_set_status("Spectator %s" % ("paused" if spectator_paused else "resumed"), 1.0)
	_refresh_speed_controls()
	_refresh_ui()

func _set_turn_speed(multiplier: float) -> void:
	turn_speed_multiplier = clampf(multiplier, 1.0, 8.0)
	_set_status("Speed x%d" % int(turn_speed_multiplier), 0.9)
	_refresh_speed_controls()
	_refresh_ui()

func _refresh_speed_controls() -> void:
	if pause_button == null:
		return
	pause_button.text = "RESUME" if spectator_paused else "PAUSE"
	pause_button.tooltip_text = "Pause AI turn progression and turn-result animation"
	speed_1_button.tooltip_text = "Playback speed x1"
	speed_4_button.tooltip_text = "Playback speed x4"
	speed_8_button.tooltip_text = "Playback speed x8"
	_set_control_button_state(speed_1_button, is_equal_approx(turn_speed_multiplier, 1.0))
	_set_control_button_state(speed_4_button, is_equal_approx(turn_speed_multiplier, 4.0))
	_set_control_button_state(speed_8_button, is_equal_approx(turn_speed_multiplier, 8.0))
	_set_control_button_state(pause_button, _is_spectator_mode() and spectator_paused)

func _set_control_button_state(button: Button, selected: bool) -> void:
	if button == null:
		return
	if _button_style_normal == null or _button_style_hover == null or _button_style_pressed == null or _button_style_selected == null:
		return
	if selected:
		button.add_theme_stylebox_override("normal", _button_style_selected)
		button.add_theme_stylebox_override("hover", _button_style_selected)
		button.add_theme_stylebox_override("pressed", _stylebox_modulated(_button_style_selected, Color(0.92, 0.92, 0.92, 1.0)))
		button.add_theme_stylebox_override("focus", _button_style_selected)
	else:
		button.add_theme_stylebox_override("normal", _button_style_normal)
		button.add_theme_stylebox_override("hover", _button_style_hover)
		button.add_theme_stylebox_override("pressed", _button_style_pressed)
		button.add_theme_stylebox_override("focus", _button_style_hover)

func _open_menu_confirm() -> void:
	if _is_upgrade_overlay_open():
		return
	menu_confirm_overlay.visible = true

func _close_menu_confirm() -> void:
	menu_confirm_overlay.visible = false

func _confirm_return_to_menu() -> void:
	_close_upgrade_overlay()
	_run_flow().clear_pending_upgrade_choices()
	menu_confirm_overlay.visible = false
	run_over = true
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _is_upgrade_overlay_open() -> bool:
	return upgrade_overlay != null and upgrade_overlay.visible

func _is_modal_overlay_open() -> bool:
	return menu_confirm_overlay.visible or _is_upgrade_overlay_open()

func _load_data() -> void:
	room_templates = _load_json_array("res://data/rooms/templates.json")

func _load_json_array(path: String) -> Array:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	return []

func _start_level() -> void:
	run_over = false
	var run_flow = _run_flow()
	var level_index: int = run_flow.current_level
	var level_seed: int = run_flow.get_level_seed()
	var level_options: Dictionary = run_flow.build_level_options()
	# Runtime currently builds levels from room templates + options only.
	state = generator.build_level(level_index, level_seed, room_templates, [], level_options)
	state.card_modifiers = run_flow.get_run_modifiers()
	queued_actions.clear()
	recent_enemy_actions.clear()
	recent_enemy_failed_actions.clear()
	enemy_intent_actions.clear()
	hovered_tile = Vector2i(-1, -1)
	_clear_pending_left_click()
	pulse_batches.clear()
	pulse_batch_index = -1
	pulse_batch_timer = 0.0
	pulse_gap_timer = 0.0
	pulse_finish_pause = 0.0
	pulse_active = false
	pending_outcome.clear()
	pending_victory_outcome.clear()
	pending_ui_refresh = false
	spectator_turn_delay = 0.0
	spectator_paused = false
	upgrade_choices.clear()
	_close_upgrade_overlay()
	actor_round_index = 0
	_initialize_owner_display_numbers()
	_setup_actor_cycle()
	_refresh_enemy_intents()
	if _use_3d_world():
		# Camera reset contract: only explicit new-level startup may request a camera reset.
		# Turn updates and normal renderer sync paths must preserve user camera state.
		world_3d_root.reset_startup_contract()
	_update_board_layout(true)
	_recompute_action_context()
	_apply_control_mode_state()

func _queue_action_from_click(tile: Vector2i) -> Dictionary:
	if state == null or not state.is_inside(tile):
		return {"ok": false, "reason": "out of bounds"}

	var clicked: Dictionary = state.get_block_at(tile)
	if clicked.is_empty():
		return _queue_place_action(tile, selected_tile_type)

	if int(clicked["owner"]) != GameState.PLAYER_ID:
		return {"ok": false, "reason": "not owned"}

	if _should_upgrade_from_click(clicked, selected_tile_type):
		return _queue_upgrade_action(clicked)
	return _queue_convert_action(clicked, selected_tile_type)

func _should_upgrade_from_click(block: Dictionary, requested_type: String) -> bool:
	var tile_type: String = String(block.get("tile_type", "basic"))
	if tile_type == "basic":
		return false
	if requested_type != tile_type:
		return false
	return int(block.get("upgrade_tier", Combat.SPECIALIZATION_TIER)) < Combat.MAX_UPGRADE_TIER

func _queue_place_action(tile: Vector2i, tile_type: String) -> Dictionary:
	if not Combat.TILE_RULES.has(tile_type):
		return {"ok": false, "reason": "unknown tile type"}

	var removed_existing: Array = _remove_player_place_actions_for_tile(tile)
	if not removed_existing.is_empty():
		var had_same_type: bool = false
		for existing in removed_existing:
			if String(existing.get("tile_type", "basic")) == tile_type:
				had_same_type = true
				break
		if had_same_type:
			return {"ok": true, "message": "Placement removed"}

	var plan: Dictionary = _build_player_queue_plan()
	var check: Dictionary = _validate_place_target(tile, tile_type, plan)
	if not bool(check["ok"]):
		_restore_removed_actions(removed_existing)
		return check

	var candidate: Dictionary = _build_place_candidate(tile, tile_type)
	var apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate)
	if not bool(apply_check.get("ok", false)):
		_restore_removed_actions(removed_existing)
		return {"ok": false, "reason": String(apply_check.get("reason", "conflict in turn resolution"))}

	queued_actions.append(candidate)
	return {"ok": true}

func _queue_convert_action(block: Dictionary, to_type: String) -> Dictionary:
	if not Combat.TILE_RULES.has(to_type):
		return {"ok": false, "reason": "unknown tile type"}

	var block_id: int = int(block["id"])
	var removed_existing: Array = _remove_player_convert_actions_for_block(block_id)
	if not removed_existing.is_empty():
		var had_same_type: bool = false
		for existing in removed_existing:
			if String(existing.get("to_type", "basic")) == to_type:
				had_same_type = true
				break
		if had_same_type:
			return {"ok": true, "message": "Conversion removed"}

	var plan: Dictionary = _build_player_queue_plan()
	var check: Dictionary = _validate_convert_target(block, to_type, plan)
	if not bool(check["ok"]):
		_restore_removed_actions(removed_existing)
		return check

	var from_type: String = String(block.get("tile_type", "basic"))
	var candidate: Dictionary = _build_convert_candidate(block_id, from_type, to_type)
	var apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate)
	if not bool(apply_check.get("ok", false)):
		_restore_removed_actions(removed_existing)
		return {"ok": false, "reason": String(apply_check.get("reason", "conflict in turn resolution"))}

	queued_actions.append(candidate)
	return {"ok": true}

func _queue_upgrade_action(block: Dictionary) -> Dictionary:
	var block_id: int = int(block["id"])
	var removed_existing: Array = _remove_player_convert_actions_for_block(block_id)
	if not removed_existing.is_empty():
		var had_upgrade: bool = false
		for existing in removed_existing:
			if String(existing.get("type", "")) == "upgrade_tile":
				had_upgrade = true
				break
		if had_upgrade:
			return {"ok": true, "message": "Upgrade removed"}

	var plan: Dictionary = _build_player_queue_plan()
	var check: Dictionary = _validate_upgrade_target(block, plan)
	if not bool(check.get("ok", false)):
		_restore_removed_actions(removed_existing)
		return check

	var tile_type: String = String(block.get("tile_type", "basic"))
	var cost: int = int(check.get("cost", 0))
	var candidate: Dictionary = _build_upgrade_candidate(block_id, tile_type, cost, plan)
	var apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate)
	if not bool(apply_check.get("ok", false)):
		_restore_removed_actions(removed_existing)
		return {"ok": false, "reason": String(apply_check.get("reason", "conflict in turn resolution"))}

	queued_actions.append(candidate)
	return {"ok": true, "message": "%s upgraded queued" % tile_type.to_upper()}

func _remove_player_place_actions_for_tile(tile: Vector2i) -> Array:
	var removed: Array = []
	for i in range(queued_actions.size() - 1, -1, -1):
		var action: Dictionary = queued_actions[i]
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		if String(action.get("type", "")) != "place_tile":
			continue
		if action.get("target", Vector2i(-1, -1)) != tile:
			continue
		removed.append(action)
		queued_actions.remove_at(i)
	removed.reverse()
	return removed

func _remove_player_convert_actions_for_block(block_id: int) -> Array:
	var removed: Array = []
	for i in range(queued_actions.size() - 1, -1, -1):
		var action: Dictionary = queued_actions[i]
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		var action_type: String = String(action.get("type", ""))
		if action_type != "convert_tile" and action_type != "upgrade_tile":
			continue
		if int(action.get("block_id", -1)) != block_id:
			continue
		removed.append(action)
		queued_actions.remove_at(i)
	removed.reverse()
	return removed

func _restore_removed_actions(removed_actions: Array) -> void:
	if removed_actions.is_empty():
		return
	for action in removed_actions:
		queued_actions.append(action)

func _remove_player_action_for_tile(tile: Vector2i) -> bool:
	var removed: bool = false
	for i in range(queued_actions.size() - 1, -1, -1):
		var action: Dictionary = queued_actions[i]
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue

		var kind: String = String(action.get("type", "pass"))
		if kind == "place_tile":
			var t: Vector2i = action.get("target", Vector2i(-1, -1))
			if t == tile:
				queued_actions.remove_at(i)
				removed = true
		elif kind == "convert_tile":
			var block_id: int = int(action.get("block_id", -1))
			if state.blocks.has(block_id) and state.blocks[block_id]["pos"] == tile:
				queued_actions.remove_at(i)
				removed = true
		elif kind == "upgrade_tile":
			var upgrade_block_id: int = int(action.get("block_id", -1))
			if state.blocks.has(upgrade_block_id) and state.blocks[upgrade_block_id]["pos"] == tile:
				queued_actions.remove_at(i)
				removed = true

	if removed:
		_set_status("Removed queued action", 1.0)
	return removed

func _try_dev_heart_defeat(tile: Vector2i) -> bool:
	var run_flow = _run_flow()
	if not bool(run_flow.get("dev_mode")):
		return false
	if state == null or not state.is_inside(tile):
		return false

	var block: Dictionary = state.get_block_at(tile)
	if block.is_empty():
		return false
	var owner_id: int = int(block.get("owner", 0))
	if owner_id == GameState.PLAYER_ID:
		return false
	if not bool(block.get("is_heart", false)):
		return false
	if not state.are_hostile(GameState.PLAYER_ID, owner_id):
		return false

	_dev_eliminate_owner(owner_id)
	_set_status("Dev: owner %d heart collapsed" % owner_id, 1.2)
	_refresh_enemy_intents()

	var outcome: Dictionary = director.check_victory_or_loss(state)
	var status: String = String(outcome.get("status", "ongoing"))
	if status == "victory":
		_apply_outcome(outcome)
	elif status == "loss":
		_apply_outcome(outcome)
	return true

func _dev_eliminate_owner(owner_id: int) -> void:
	for block in state.get_owner_blocks(owner_id):
		state.remove_block(int(block["id"]))
	if state.players.has(owner_id):
		state.players[owner_id]["alive"] = false
		state.players[owner_id]["nutrients"] = 0
	state.last_log.insert(0, "DEV: owner %d eliminated via heart click" % owner_id)

func _build_player_queue_plan() -> Dictionary:
	return validator.build_owner_plan(state, queued_actions, GameState.PLAYER_ID)

func _resolve_turn() -> void:
	if run_over or pulse_active or _is_modal_overlay_open():
		return
	if _is_spectator_mode():
		return
	end_turn_button.release_focus()

	var min_adjacent: int = _current_min_adjacent()
	var resolution: Dictionary = turn_resolver.resolve_turn(
		state,
		queued_actions,
		enemy_intent_actions,
		min_adjacent,
		_tile_cost("basic")
	)
	_apply_resolution_result(resolution, GameState.PLAYER_ID, true)

func _run_next_spectator_turn() -> void:
	if state == null or run_over or pulse_active:
		return
	if not _ensure_active_actor_for_spectator_turn():
		return

	var acting_owner_id: int = active_owner_id
	var actions: Array = ai.choose_actions(state, acting_owner_id, _min_adjacent_for_owner(acting_owner_id))
	if actions.is_empty():
		actions = [{"type": "pass", "owner": acting_owner_id}]

	var resolution: Dictionary = turn_resolver.resolve_turn(
		state,
		actions,
		[],
		_min_adjacent_for_owner(acting_owner_id),
		_tile_cost("basic")
	)
	_apply_resolution_result(resolution, acting_owner_id, false)

func _apply_resolution_result(resolution: Dictionary, acting_owner: int, include_enemy_feedback: bool) -> void:
	var previous_state: GameState = state.copy_state() if state != null else null
	var next_state: GameState = resolution.get("state", state)
	var report: Dictionary = resolution.get("report", {})
	var pulse_tiles: Array = _collect_resolution_pulse_tiles(previous_state, next_state, report)

	state = next_state
	queued_actions.clear()

	recent_enemy_actions = resolution.get("applied_enemy_actions", [])
	recent_enemy_failed_actions = resolution.get("failed_enemy_actions", [])
	enemy_flash_timer = ENEMY_FLASH_DURATION if recent_enemy_actions.size() > 0 else 0.0

	if include_enemy_feedback:
		_append_enemy_action_summary(recent_enemy_actions, recent_enemy_failed_actions)
	else:
		_append_actor_action_summary(acting_owner, report)

	_recompute_action_context()
	_refresh_enemy_intents()
	_start_turn_pulse(pulse_tiles)
	active_owner_id = acting_owner

	var outcome: Dictionary = director.check_victory_or_loss(state)
	if String(outcome.get("status", "ongoing")) != "ongoing":
		pending_outcome = outcome
	else:
		pending_outcome.clear()
	pending_ui_refresh = true

	_refresh_ui()
	_queue_world_redraw()

func _append_actor_action_summary(owner_id: int, report: Dictionary) -> void:
	var applied_count: int = 0
	for action in report.get("applied_actions", []):
		if int(action.get("owner", -1)) == owner_id:
			applied_count += 1
	if applied_count > 0:
		state.last_log.insert(0, "Slime %d acted (%d actions)" % [_owner_display_number(owner_id), applied_count])
	else:
		state.last_log.insert(0, "Slime %d held" % _owner_display_number(owner_id))

func _collect_resolution_pulse_tiles(previous_state: GameState, next_state: GameState, report: Dictionary) -> Array:
	var ordered: Array = []
	var seen: Dictionary = {}
	if previous_state == null or next_state == null:
		return ordered

	for action in report.get("applied_actions", []):
		_append_unique_tile(ordered, seen, _action_target_tile(action, previous_state, next_state))

	for block_id_variant in previous_state.blocks.keys():
		var block_id: int = int(block_id_variant)
		var prev_block: Dictionary = previous_state.blocks[block_id]
		var prev_tile: Vector2i = prev_block.get("pos", Vector2i(-1, -1))
		if not next_state.blocks.has(block_id):
			_append_unique_tile(ordered, seen, prev_tile)
			continue
		if bool(prev_block.get("is_heart", false)):
			var prev_hp: int = int(prev_block.get("hp", 0))
			var next_hp: int = int(next_state.blocks[block_id].get("hp", prev_hp))
			if next_hp < prev_hp:
				_append_unique_tile(ordered, seen, prev_tile)

	if next_state.door_hp < previous_state.door_hp:
		_append_unique_tile(ordered, seen, next_state.door_tile)

	if ordered.size() > TURN_PULSE_MAX_TILES:
		return ordered.slice(0, TURN_PULSE_MAX_TILES)
	return ordered

func _append_unique_tile(out: Array, seen: Dictionary, tile: Vector2i) -> void:
	if tile == Vector2i(-1, -1):
		return
	var key: String = "%d,%d" % [tile.x, tile.y]
	if seen.has(key):
		return
	seen[key] = true
	out.append(tile)

func _start_turn_pulse(changed_tiles: Array) -> void:
	pulse_batches = _build_pulse_batches(changed_tiles)
	pulse_batch_index = -1
	pulse_batch_timer = 0.0
	pulse_gap_timer = 0.0
	pulse_finish_pause = TURN_PULSE_END_PAUSE
	pulse_batch_duration = TURN_PULSE_MAX_DURATION
	pulse_active = true

	if pulse_batches.is_empty():
		pulse_finish_pause = 0.12
		return

	while _pulse_total_duration(pulse_batches.size(), TURN_PULSE_MIN_DURATION) > TURN_PULSE_MAX_TOTAL and pulse_batches.size() > 1:
		pulse_batches.pop_back()

	var allowed_per_batch: float = (
		TURN_PULSE_MAX_TOTAL
		- TURN_PULSE_END_PAUSE
		- float(maxi(0, pulse_batches.size() - 1)) * TURN_PULSE_BATCH_GAP
	) / maxf(1.0, float(pulse_batches.size()))
	pulse_batch_duration = clampf(allowed_per_batch, TURN_PULSE_MIN_DURATION, TURN_PULSE_MAX_DURATION)
	pulse_batch_index = 0
	pulse_batch_timer = pulse_batch_duration

func _build_pulse_batches(changed_tiles: Array) -> Array:
	var batches: Array = []
	if changed_tiles.is_empty():
		return batches

	var tile_count: int = changed_tiles.size()
	var max_batches: int = int(floor((TURN_PULSE_MAX_TOTAL - TURN_PULSE_END_PAUSE + TURN_PULSE_BATCH_GAP) / (TURN_PULSE_MIN_DURATION + TURN_PULSE_BATCH_GAP)))
	max_batches = maxi(1, max_batches)
	var batch_size: int = 1 if tile_count == 1 else clampi(int(ceil(float(tile_count) / float(max_batches))), TURN_PULSE_BATCH_MIN, TURN_PULSE_BATCH_MAX)

	var idx: int = 0
	while idx < tile_count:
		var batch: Array = []
		for _i in range(batch_size):
			if idx >= tile_count:
				break
			batch.append(changed_tiles[idx])
			idx += 1
		if not batch.is_empty():
			batches.append(batch)
	return batches

func _pulse_total_duration(batch_count: int, per_batch_duration: float) -> float:
	if batch_count <= 0:
		return TURN_PULSE_END_PAUSE
	return (
		float(batch_count) * per_batch_duration
		+ float(maxi(0, batch_count - 1)) * TURN_PULSE_BATCH_GAP
		+ TURN_PULSE_END_PAUSE
	)

func _update_turn_pulse(delta: float) -> bool:
	if not pulse_active:
		return false

	if pulse_batch_index >= 0 and pulse_batch_index < pulse_batches.size():
		if pulse_batch_timer > 0.0:
			pulse_batch_timer = maxf(0.0, pulse_batch_timer - delta)
			if pulse_batch_timer > 0.0:
				return true
			if pulse_batch_index >= pulse_batches.size() - 1:
				pulse_batch_index = -1
				pulse_finish_pause = TURN_PULSE_END_PAUSE
				return true
			pulse_gap_timer = TURN_PULSE_BATCH_GAP
			return true

		if pulse_gap_timer > 0.0:
			pulse_gap_timer = maxf(0.0, pulse_gap_timer - delta)
			if pulse_gap_timer > 0.0:
				return true
			pulse_batch_index += 1
			pulse_batch_timer = pulse_batch_duration
		return true

	pulse_finish_pause = maxf(0.0, pulse_finish_pause - delta)
	if pulse_finish_pause > 0.0:
		return true

	pulse_active = false
	pulse_batches.clear()
	pulse_batch_index = -1
	pulse_batch_timer = 0.0
	pulse_gap_timer = 0.0
	if pending_ui_refresh:
		if _is_spectator_mode():
			_advance_active_actor()
			spectator_turn_delay = SPECTATOR_STEP_DELAY
		pending_ui_refresh = false
		_refresh_ui()
		_queue_world_redraw()
	if not pending_outcome.is_empty():
		_apply_outcome(pending_outcome)
		pending_outcome.clear()
	return true

func _current_pulse_tiles() -> Array:
	if not pulse_active:
		return []
	if pulse_gap_timer > 0.0:
		return []
	if pulse_batch_index < 0 or pulse_batch_index >= pulse_batches.size():
		return []
	return pulse_batches[pulse_batch_index]

func _current_pulse_alpha() -> float:
	if not pulse_active:
		return 0.0
	if pulse_gap_timer > 0.0:
		return 0.0
	if pulse_batch_index < 0 or pulse_batch_index >= pulse_batches.size():
		return 0.0
	if pulse_batch_duration <= 0.0:
		return 0.8
	var t: float = 1.0 - clampf(pulse_batch_timer / pulse_batch_duration, 0.0, 1.0)
	return 0.35 + (1.0 - absf(t * 2.0 - 1.0)) * 0.65

func _action_target_tile(action: Dictionary, previous_state: GameState, next_state: GameState) -> Vector2i:
	var kind: String = String(action.get("type", ""))
	if kind == "place_tile":
		return action.get("target", Vector2i(-1, -1))
	if kind == "convert_tile" or kind == "upgrade_tile":
		var block_id: int = int(action.get("block_id", -1))
		if previous_state != null and previous_state.blocks.has(block_id):
			return previous_state.blocks[block_id]["pos"]
		if next_state != null and next_state.blocks.has(block_id):
			return next_state.blocks[block_id]["pos"]
	return Vector2i(-1, -1)

func _apply_outcome(outcome: Dictionary) -> void:
	var status: String = String(outcome.get("status", "ongoing"))
	if status == "victory":
		var run_flow = _run_flow()
		if run_flow.should_offer_upgrade_after_victory(state.level_index, _is_spectator_mode()):
			pending_victory_outcome = outcome.duplicate(true)
			run_over = true
			_open_upgrade_overlay(true)
			return
		run_over = true
		run_flow.clear_pending_upgrade_choices()
		run_flow.prepare_victory(state.level_index, _outcome_reason_text(String(outcome.get("reason", ""))))
		get_tree().change_scene_to_file("res://scenes/RunResult.tscn")
	elif status == "loss":
		_close_upgrade_overlay()
		pending_victory_outcome.clear()
		_run_flow().clear_pending_upgrade_choices()
		run_over = true
		_run_flow().prepare_defeat(_outcome_reason_text(String(outcome.get("reason", ""))))
		get_tree().change_scene_to_file("res://scenes/RunResult.tscn")

func _open_upgrade_overlay(victory_gate: bool) -> void:
	if state == null:
		return
	var run_flow = _run_flow()
	upgrade_choices = run_flow.draw_upgrade_choices(3)
	if upgrade_choices.is_empty():
		if victory_gate and not pending_victory_outcome.is_empty():
			var reason: String = _outcome_reason_text(String(pending_victory_outcome.get("reason", "")))
			run_flow.prepare_victory(state.level_index, reason)
			pending_victory_outcome.clear()
			get_tree().change_scene_to_file("res://scenes/RunResult.tscn")
		return

	queued_actions.clear()
	_recompute_action_context()
	upgrade_header_label.text = "Choose Evolution"
	upgrade_hint_label.text = "Pick 1 of 3 run upgrades."
	_upgrade_button_setup(upgrade_button_1, 0)
	_upgrade_button_setup(upgrade_button_2, 1)
	_upgrade_button_setup(upgrade_button_3, 2)
	upgrade_overlay.visible = true
	_set_status("Upgrade ready: choose one", 1.5)
	_refresh_ui()
	_queue_world_redraw()

func _close_upgrade_overlay() -> void:
	if upgrade_overlay != null:
		upgrade_overlay.visible = false
	upgrade_choices.clear()

func _upgrade_button_setup(button: Button, index: int) -> void:
	if button == null:
		return
	if index < 0 or index >= upgrade_choices.size():
		button.visible = false
		button.disabled = true
		button.text = ""
		return
	var choice: Dictionary = upgrade_choices[index]
	button.visible = true
	button.disabled = false
	button.text = _upgrade_choice_text(choice)
	button.tooltip_text = String(choice.get("description", ""))

func _upgrade_choice_text(choice: Dictionary) -> String:
	var choice_name: String = String(choice.get("name", "Upgrade"))
	var description: String = String(choice.get("description", ""))
	return "%s\n%s" % [choice_name, description]

func _on_upgrade_choice_pressed(choice_index: int) -> void:
	if choice_index < 0 or choice_index >= upgrade_choices.size():
		return
	var choice: Dictionary = upgrade_choices[choice_index]
	var run_flow = _run_flow()
	var result: Dictionary = run_flow.apply_upgrade_choice(String(choice.get("id", "")))
	if not bool(result.get("ok", false)):
		_set_status("Upgrade apply failed", 1.6)
		return

	state.card_modifiers = run_flow.get_run_modifiers()
	state.last_log.insert(0, "Upgrade: %s" % String(choice.get("name", "Picked")))
	_set_status("Upgrade picked: %s" % String(choice.get("name", "Upgrade")), 1.6)
	_close_upgrade_overlay()
	_recompute_action_context()
	_refresh_ui()
	_queue_world_redraw()

	if not pending_victory_outcome.is_empty():
		var reason: String = _outcome_reason_text(String(pending_victory_outcome.get("reason", "")))
		pending_victory_outcome.clear()
		run_over = true
		run_flow.prepare_victory(state.level_index, reason)
		get_tree().change_scene_to_file("res://scenes/RunResult.tscn")
		return
	run_over = false

func _refresh_enemy_intents() -> void:
	if _is_spectator_mode():
		enemy_intent_actions.clear()
		return
	var min_by_owner: Dictionary = {}
	for owner_id in state.players.keys():
		var owner_int: int = int(owner_id)
		if owner_int == GameState.PLAYER_ID:
			continue
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		if not bool(state.players[owner_id].get("ai_controlled", true)):
			continue
		min_by_owner[owner_int] = _min_adjacent_for_owner(owner_int)
	enemy_intent_actions = intent_planner.build_enemy_intents(state, ai, min_by_owner, _current_min_adjacent())

func _setup_actor_cycle() -> void:
	actor_round_index = 0
	if _is_spectator_mode():
		_start_new_actor_round()
		spectator_turn_delay = SPECTATOR_STEP_DELAY
	else:
		_rebuild_actor_cycle()
		active_owner_id = GameState.PLAYER_ID

func _rebuild_actor_cycle() -> void:
	actor_cycle_order = _build_actor_cycle_order()
	if actor_cycle_order.is_empty():
		active_owner_id = GameState.PLAYER_ID
		actor_cycle_index = 0
		return
	var idx: int = actor_cycle_order.find(active_owner_id)
	if idx < 0:
		actor_cycle_index = 0
	else:
		actor_cycle_index = idx
	active_owner_id = actor_cycle_order[actor_cycle_index]

func _build_actor_cycle_order() -> Array:
	if state == null:
		return []
	var owners: Array = []
	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if owner_id == GameState.PLAYER_ID:
			continue
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		if not bool(state.players[owner_id].get("ai_controlled", true)):
			continue
		if state.get_owner_blocks(owner_id).is_empty():
			continue
		owners.append(owner_id)
	owners.sort_custom(func(a: int, b: int) -> bool:
		var ta: int = state.get_owner_team(a)
		var tb: int = state.get_owner_team(b)
		if ta != tb:
			return ta < tb
		return a < b
	)
	return owners

func _start_new_actor_round() -> void:
	var owners: Array = _build_actor_cycle_order()
	if owners.is_empty():
		actor_cycle_order.clear()
		actor_cycle_index = 0
		active_owner_id = GameState.PLAYER_ID
		return
	var round_seed: int = int(state.run_seed) + int(state.level_index * 4099) + int(actor_round_index * 7919)
	# Spectator order is randomized per round but deterministic for a given seed.
	actor_cycle_order = _shuffle_owner_order(owners, round_seed)
	actor_cycle_index = 0
	active_owner_id = int(actor_cycle_order[0])
	actor_round_index += 1

func _shuffle_owner_order(owners: Array, order_seed: int) -> Array:
	var shuffled: Array = owners.duplicate()
	if shuffled.size() <= 1:
		return shuffled
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = order_seed
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled

func _ensure_active_actor_for_spectator_turn() -> bool:
	for _attempt in range(0, 2):
		if actor_cycle_order.is_empty():
			_start_new_actor_round()
			if actor_cycle_order.is_empty():
				return false

		while actor_cycle_index < actor_cycle_order.size():
			var owner_id_candidate: int = int(actor_cycle_order[actor_cycle_index])
			if _is_owner_valid_actor(owner_id_candidate):
				active_owner_id = owner_id_candidate
				return true
			actor_cycle_index += 1

		_start_new_actor_round()
	return false

func _advance_active_actor() -> void:
	if not _is_spectator_mode():
		active_owner_id = GameState.PLAYER_ID
		return
	actor_cycle_index += 1
	if actor_cycle_index >= actor_cycle_order.size():
		_start_new_actor_round()
		return
	_ensure_active_actor_for_spectator_turn()

func _is_owner_valid_actor(owner_id: int) -> bool:
	if not state.players.has(owner_id):
		return false
	if not bool(state.players[owner_id].get("alive", true)):
		return false
	if not bool(state.players[owner_id].get("ai_controlled", true)):
		return false
	return not state.get_owner_blocks(owner_id).is_empty()

func _refresh_ui() -> void:
	if state == null:
		return

	_apply_control_mode_state()
	_refresh_speed_controls()

	var player_hp: int = state.get_total_hp(GameState.PLAYER_ID)
	var player_hearts: int = state.count_heart_tiles(GameState.PLAYER_ID)
	var player_energy: int = int(state.players[GameState.PLAYER_ID]["nutrients"])
	if _is_spectator_mode():
		player_label.text = "SPECTATOR MODE"
		enemy_label.text = ""
	else:
		player_label.text = "PLAYER HP %d  HEART %d" % [player_hp, player_hearts]
		enemy_label.text = _enemy_header_text()
	var door_text: String = "DOOR %d/%d" % [maxi(0, state.door_hp), maxi(1, state.door_max_hp)]
	turn_label.text = "TURN %d/%d  |  LEVEL %d  |  %s" % [state.turn_index, state.turn_limit, state.level_index, door_text]
	_refresh_team_status_panels()
	_refresh_actor_bar()

	energy_label.text = "ENERGY %d   STALL %d/3   SUPPORT R2   STABILITY 0/1/2+" % [player_energy, state.stall_counter]
	var upgrade_count: int = int(_run_flow().picked_upgrades.size())
	var queued_place_count: int = 0
	var queued_convert_count: int = 0
	var queued_upgrade_count: int = 0
	for action in queued_actions:
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		match String(action.get("type", "")):
			"place_tile":
				queued_place_count += 1
			"convert_tile":
				queued_convert_count += 1
			"upgrade_tile":
				queued_upgrade_count += 1
	queue_label.text = "QUEUE %d   PLACE %d   CONVERT %d   TILE-UPG %d   RUN-UPG %d" % [
		queued_actions.size(),
		queued_place_count,
		queued_convert_count,
		queued_upgrade_count,
		upgrade_count
	]

	var mode_text: String = "MODE %s | Same-type non-basic click queues tile-upgrade." % selected_tile_type.to_upper()
	if _is_spectator_mode():
		mode_text = "SPECTATOR | AI autoplay enabled | Dev heart-click defeat active"
	if not button_hover_description.is_empty():
		mode_text = "%s | %s" % [mode_text, button_hover_description]
	mode_label.text = _fit_line(mode_text, 86)

	var debug_text: String = _debug_hint_text()
	if not status_message.is_empty():
		debug_text = "Status: %s | %s" % [status_message, debug_text]
	debug_label.text = _fit_line(debug_text, 90)

	_refresh_action_button_labels()
	_refresh_log()

func _enemy_header_text() -> String:
	var enemy_hp: int = 0
	var enemy_energy: int = 0
	var enemy_hearts: int = 0
	for owner_id in state.players.keys():
		var owner_int: int = int(owner_id)
		if owner_int == GameState.PLAYER_ID:
			continue
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		if not state.are_hostile(GameState.PLAYER_ID, owner_int):
			continue
		enemy_energy += int(state.players[owner_id]["nutrients"])
		enemy_hp += state.get_total_hp(owner_int)
		enemy_hearts += state.count_heart_tiles(owner_int)
	return "ENEMY HP %d  HEART %d  ENERGY %d" % [enemy_hp, enemy_hearts, enemy_energy]

func _refresh_team_status_panels() -> void:
	if state == null:
		return
	var left_entries: Array = _team_status_entries(false)
	var right_entries: Array = _team_status_entries(true)
	left_team_status_label.text = _team_status_text(left_entries, false)
	right_team_status_label.text = _team_status_text(right_entries, true)

func _team_status_entries(hostile_to_player: bool) -> Array:
	var owners: Array = []
	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		if state.get_owner_blocks(owner_id).is_empty():
			continue
		var hostile: bool = state.are_hostile(GameState.PLAYER_ID, owner_id)
		if hostile != hostile_to_player:
			continue
		owners.append(owner_id)
	owners.sort_custom(func(a, b) -> bool:
		var oa: int = int(a)
		var ob: int = int(b)
		var ta: int = state.get_owner_team(oa)
		var tb: int = state.get_owner_team(ob)
		if ta != tb:
			return ta < tb
		return _owner_display_number(oa) < _owner_display_number(ob)
	)

	var entries: Array = []
	for owner_id_variant in owners:
		var owner_id: int = int(owner_id_variant)
		var owner_color: Color = renderer.owner_tint_for_ui(state, owner_id)
		var owner_label: String = "Slime %d" % _owner_display_number(owner_id)
		if owner_id == GameState.PLAYER_ID and not _is_spectator_mode():
			owner_label = "Player"
		entries.append({
			"label": owner_label,
			"color_hex": owner_color.to_html(false),
			"hp": state.get_total_hp(owner_id),
			"hearts": state.count_heart_tiles(owner_id),
			"energy": int(state.players[owner_id].get("nutrients", 0)),
			"active": _is_spectator_mode() and owner_id == active_owner_id,
		})
	return entries

func _team_status_text(entries: Array, right_aligned: bool) -> String:
	var lines: Array[String] = []
	if entries.is_empty():
		var empty_line: String = "[color=#787567]no teams[/color]"
		if right_aligned:
			return "[right]%s[/right]" % empty_line
		return empty_line

	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var line: String = "[color=#%s]■[/color] %s HP %d  H %d  E %d" % [
			String(entry.get("color_hex", "ffffff")),
			String(entry.get("label", "Team")),
			int(entry.get("hp", 0)),
			int(entry.get("hearts", 0)),
			int(entry.get("energy", 0)),
		]
		if bool(entry.get("active", false)):
			line = "[b]> %s <[/b]" % line
		if right_aligned:
			line = "[right]%s[/right]" % line
		lines.append(line)
	return "\n".join(lines)

func _refresh_actor_bar() -> void:
	if actor_bar == null:
		return
	var owners: Array = _ordered_owner_display_list()
	if owners.is_empty():
		actor_bar.text = ""
		return

	var parts: Array[String] = []
	for owner_id_entry in owners:
		var owner_id: int = int(owner_id_entry)
		var label: String = "Slime %d" % _owner_display_number(owner_id)
		var is_active: bool = owner_id == active_owner_id
		var owner_color: Color = renderer.owner_tint_for_ui(state, owner_id)
		var color_hex: String = owner_color.to_html(false)
		var text: String = "[color=#%s]%s[/color]" % [color_hex, label]
		if is_active:
			var active_color: String = owner_color.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.38).to_html(false)
			text = "[b][color=#%s]> %s <[/color][/b]" % [active_color, label]
		parts.append(text)

	actor_bar.text = "[center]%s[/center]" % "   ".join(parts)

func _ordered_owner_display_list() -> Array:
	var owners: Array = []
	if state == null:
		return owners
	if _is_spectator_mode() and not actor_cycle_order.is_empty():
		for owner_id_entry in actor_cycle_order:
			var owner_id: int = int(owner_id_entry)
			if _is_owner_valid_actor(owner_id):
				owners.append(owner_id)
		return owners

	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if owner_id == GameState.PLAYER_ID and _is_spectator_mode():
			continue
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		if state.get_owner_blocks(owner_id).is_empty():
			continue
		owners.append(owner_id)
	owners.sort()
	return owners

func _owner_display_number(owner_id: int) -> int:
	if owner_display_numbers.has(owner_id):
		return int(owner_display_numbers[owner_id])
	return owner_id

func _initialize_owner_display_numbers() -> void:
	owner_display_numbers.clear()
	var owners: Array = _stable_owner_display_list()
	var idx: int = 1
	for owner_id in owners:
		owner_display_numbers[int(owner_id)] = idx
		idx += 1

func _stable_owner_display_list() -> Array:
	var owners: Array = []
	if state == null:
		return owners
	for owner_id_variant in state.players.keys():
		var owner_id: int = int(owner_id_variant)
		if owner_id == GameState.PLAYER_ID and _is_spectator_mode():
			continue
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		if state.get_owner_blocks(owner_id).is_empty():
			continue
		owners.append(owner_id)
	owners.sort()
	return owners

func _apply_control_mode_state() -> void:
	var spectator: bool = _is_spectator_mode()
	var modal_open: bool = _is_modal_overlay_open()
	var dev_mode: bool = bool(_run_flow().get("dev_mode"))
	for button in [basic_button, melee_button, ranged_button, gather_button, defense_button]:
		button.disabled = spectator or modal_open
	end_turn_button.disabled = spectator or pulse_active or modal_open
	clear_queue_button.disabled = spectator or modal_open
	pause_button.visible = spectator
	pause_button.disabled = run_over or modal_open
	return_menu_button.disabled = modal_open
	dev_upgrade_button.visible = dev_mode and not spectator
	dev_upgrade_button.disabled = modal_open or pulse_active or run_over or spectator
	if not spectator:
		spectator_paused = false
	if spectator:
		queued_actions.clear()

func _is_spectator_mode() -> bool:
	return state != null and bool(state.spectator_mode)

func _refresh_action_button_labels() -> void:
	basic_button.text = _button_text("Basic", _tile_cost("basic"))
	melee_button.text = _button_text("Melee", _tile_cost("melee"))
	ranged_button.text = _button_text("Ranged", _tile_cost("ranged"))
	gather_button.text = _button_text("Gather", _tile_cost("gather"))
	defense_button.text = _button_text("Defense", _tile_cost("defense"))
	_apply_tile_button_selection()

func _button_text(label: String, cost: int) -> String:
	return "%s\nCost %d" % [label, cost]

func _refresh_log() -> void:
	var lines: Array[String] = []
	var recent: Array[String] = state.last_log
	var start: int = maxi(0, recent.size() - 6)
	for i in range(start, recent.size()):
		lines.append("- %s" % recent[i])
	if lines.is_empty():
		lines.append("- Select a tile type, queue actions, then End Turn")
	log_label.text = "\n".join(lines)

func _recompute_action_context() -> void:
	_recompute_valid_targets()
	_recompute_hover_context()

func _recompute_valid_targets() -> void:
	valid_place_targets.clear()
	valid_convert_targets.clear()

	if state == null:
		return

	var plan: Dictionary = _build_player_queue_plan()

	for y in range(state.height):
		for x in range(state.width):
			var tile: Vector2i = Vector2i(x, y)
			var place_check: Dictionary = _validate_place_target(tile, selected_tile_type, plan)
			if not bool(place_check.get("ok", false)):
				continue
			var place_candidate: Dictionary = _build_place_candidate(tile, selected_tile_type)
			# Keep highlight truth aligned with final resolution ordering.
			var place_apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, place_candidate)
			if bool(place_apply_check.get("ok", false)):
				valid_place_targets.append(tile)

	for block in state.get_owner_blocks(GameState.PLAYER_ID):
		if _should_upgrade_from_click(block, selected_tile_type):
			var upgrade_check: Dictionary = _validate_upgrade_target(block, plan)
			if not bool(upgrade_check.get("ok", false)):
				continue
			var upgrade_candidate: Dictionary = _build_upgrade_candidate(
				int(block["id"]),
				String(block.get("tile_type", "basic")),
				int(upgrade_check.get("cost", 0)),
				plan
			)
			var upgrade_apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, upgrade_candidate)
			if bool(upgrade_apply_check.get("ok", false)):
				valid_convert_targets.append(block["pos"])
			continue

		var convert_check: Dictionary = _validate_convert_target(block, selected_tile_type, plan)
		if not bool(convert_check.get("ok", false)):
			continue
		var from_type: String = String(block.get("tile_type", "basic"))
		var convert_candidate: Dictionary = _build_convert_candidate(int(block["id"]), from_type, selected_tile_type)
		# Keep highlight truth aligned with final resolution ordering.
		var convert_apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, convert_candidate)
		if bool(convert_apply_check.get("ok", false)):
			valid_convert_targets.append(block["pos"])

func _recompute_hover_context() -> void:
	hover_preview_action.clear()
	hover_invalid_reason = ""

	if state == null:
		return

	var plan: Dictionary = _build_player_queue_plan()

	if hovered_tile == Vector2i(-1, -1) or not state.is_inside(hovered_tile):
		return

	var hovered_block: Dictionary = state.get_block_at(hovered_tile)
	if hovered_block.is_empty():
		var hover_place_check: Dictionary = _validate_place_target(hovered_tile, selected_tile_type, plan)
		if bool(hover_place_check.get("ok", false)):
			var candidate_place: Dictionary = _build_place_candidate(hovered_tile, selected_tile_type)
			# Hover promise must match queue/resolve promise.
			var apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate_place)
			if bool(apply_check.get("ok", false)):
				hover_preview_action = candidate_place
			else:
				hover_invalid_reason = String(apply_check.get("reason", "conflict in turn resolution"))
		else:
			hover_invalid_reason = String(hover_place_check.get("reason", "invalid"))
	elif int(hovered_block["owner"]) == GameState.PLAYER_ID:
		if _should_upgrade_from_click(hovered_block, selected_tile_type):
			var hover_upgrade_check: Dictionary = _validate_upgrade_target(hovered_block, plan)
			if bool(hover_upgrade_check.get("ok", false)):
				var candidate_upgrade: Dictionary = _build_upgrade_candidate(
					int(hovered_block["id"]),
					String(hovered_block.get("tile_type", "basic")),
					int(hover_upgrade_check.get("cost", 0)),
					plan
				)
				var upgrade_apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate_upgrade)
				if bool(upgrade_apply_check.get("ok", false)):
					hover_preview_action = candidate_upgrade
				else:
					hover_invalid_reason = String(upgrade_apply_check.get("reason", "conflict in turn resolution"))
			else:
				hover_invalid_reason = String(hover_upgrade_check.get("reason", "invalid"))
		else:
			var hover_convert_check: Dictionary = _validate_convert_target(hovered_block, selected_tile_type, plan)
			if bool(hover_convert_check.get("ok", false)):
				var from_type: String = String(hovered_block.get("tile_type", "basic"))
				var candidate_convert: Dictionary = _build_convert_candidate(int(hovered_block["id"]), from_type, selected_tile_type)
				# Hover promise must match queue/resolve promise.
				var convert_apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate_convert)
				if bool(convert_apply_check.get("ok", false)):
					hover_preview_action = candidate_convert
				else:
					hover_invalid_reason = String(convert_apply_check.get("reason", "conflict in turn resolution"))
			else:
				hover_invalid_reason = String(hover_convert_check.get("reason", "invalid"))
	else:
		hover_invalid_reason = "not owned"

func _validate_place_target(tile: Vector2i, tile_type: String, plan: Dictionary) -> Dictionary:
	return validator.validate_place_target(
		state,
		GameState.PLAYER_ID,
		tile,
		tile_type,
		_current_min_adjacent(),
		_tile_cost(tile_type),
		plan
	)

func _validate_convert_target(block: Dictionary, to_type: String, plan: Dictionary) -> Dictionary:
	return validator.validate_convert_target(state, GameState.PLAYER_ID, block, to_type, plan)

func _validate_upgrade_target(block: Dictionary, plan: Dictionary) -> Dictionary:
	return validator.validate_upgrade_target(state, GameState.PLAYER_ID, block, plan)

func _find_player_place_action_index(tile: Vector2i) -> int:
	for i in range(queued_actions.size()):
		var action: Dictionary = queued_actions[i]
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		if String(action.get("type", "")) != "place_tile":
			continue
		if action.get("target", Vector2i(-1, -1)) == tile:
			return i
	return -1

func _find_player_convert_action_index(block_id: int) -> int:
	for i in range(queued_actions.size()):
		var action: Dictionary = queued_actions[i]
		if int(action.get("owner", 0)) != GameState.PLAYER_ID:
			continue
		if String(action.get("type", "")) != "convert_tile":
			continue
		if int(action.get("block_id", -1)) == block_id:
			return i
	return -1

func _mouse_to_tile(mouse_pos: Vector2) -> Vector2i:
	if state == null:
		return Vector2i(-1, -1)
	if not board_clip_rect.has_point(mouse_pos):
		return Vector2i(-1, -1)
	if _use_3d_world():
		var viewport_mouse: Vector2 = mouse_pos - board_clip_rect.position
		return world_3d_root.viewport_to_tile(viewport_mouse)
	var local: Vector2 = mouse_pos - board_origin
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)

	var tx: int = int(local.x / _render_tile_size)
	var ty: int = int(local.y / _render_tile_size)
	var tile: Vector2i = Vector2i(tx, ty)
	if not state.is_inside(tile):
		return Vector2i(-1, -1)
	return tile

func _tile_cost(tile_type: String) -> int:
	var cost: int = int(Combat.TILE_RULES[tile_type]["cost"])
	if tile_type == "basic":
		# Modifier hook is dormant in current run flow but intentionally retained.
		cost = maxi(1, cost + int(state.card_modifiers.get("grow_cost_delta", 0)))
	return cost

func _build_place_candidate(tile: Vector2i, tile_type: String) -> Dictionary:
	return {
		"type": "place_tile",
		"owner": GameState.PLAYER_ID,
		"target": tile,
		"tile_type": tile_type,
		"cost": _tile_cost(tile_type),
		"min_adjacent": _current_min_adjacent(),
		"_preview_id": _next_preview_id(),
	}

func _build_convert_candidate(block_id: int, from_type: String, to_type: String) -> Dictionary:
	var from_tier: int = 0
	if state.blocks.has(block_id):
		from_tier = int(state.blocks[block_id].get("upgrade_tier", 0))
	return {
		"type": "convert_tile",
		"owner": GameState.PLAYER_ID,
		"block_id": block_id,
		"to_type": to_type,
		"energy_delta": Combat.conversion_energy_delta(from_type, to_type, from_tier),
		"_preview_id": _next_preview_id(),
	}

func _build_upgrade_candidate(block_id: int, tile_type: String, cost: int, plan: Dictionary) -> Dictionary:
	var planned_type_count: int = int(plan.get("planned_upgrade_counts", {}).get(tile_type, 0))
	var planned_total_count: int = int(plan.get("planned_upgrade_total", 0))
	return {
		"type": "upgrade_tile",
		"owner": GameState.PLAYER_ID,
		"block_id": block_id,
		"tile_type": tile_type,
		"cost": cost,
		"planned_type_count": planned_type_count,
		"planned_total_count": planned_total_count,
		"_preview_id": _next_preview_id(),
	}

func _current_min_adjacent() -> int:
	return _min_adjacent_for_owner(GameState.PLAYER_ID)

func _min_adjacent_for_owner(_owner_id: int) -> int:
	return MIN_EXPAND_ADJACENT

func _next_preview_id() -> String:
	var value: String = "preview_%d" % preview_action_serial
	preview_action_serial += 1
	return value

func _apply_tile_button_selection() -> void:
	_set_tile_button_state(basic_button, selected_tile_type == "basic")
	_set_tile_button_state(melee_button, selected_tile_type == "melee")
	_set_tile_button_state(ranged_button, selected_tile_type == "ranged")
	_set_tile_button_state(gather_button, selected_tile_type == "gather")
	_set_tile_button_state(defense_button, selected_tile_type == "defense")

func _set_tile_button_state(button: Button, selected: bool) -> void:
	_set_control_button_state(button, selected)

func _make_stylebox_texture(texture: Texture2D, margin: int, content: int) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.draw_center = true
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.set_content_margin(SIDE_LEFT, content)
	style.set_content_margin(SIDE_TOP, content)
	style.set_content_margin(SIDE_RIGHT, content)
	style.set_content_margin(SIDE_BOTTOM, content)
	return style

func _stylebox_modulated(base_style: StyleBoxTexture, color: Color) -> StyleBoxTexture:
	var out: StyleBoxTexture = base_style.duplicate() as StyleBoxTexture
	out.modulate_color = color
	return out

func _load_runtime_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var font_file: FontFile = FontFile.new()
	var err: Error = font_file.load_dynamic_font(path)
	if err != OK:
		return null
	return font_file

func _set_status(message: String, duration: float) -> void:
	status_message = message
	status_timer = duration

func _debug_hint_text() -> String:
	if state == null:
		return ""

	if hovered_tile == Vector2i(-1, -1) or not state.is_inside(hovered_tile):
		var support_delta: int = int(state.card_modifiers.get("placement_support_delta", 0))
		var open_support: int = maxi(1, GameState.MIN_SUPPORT_FOR_PLACEMENT + support_delta)
		var corridor_support: int = maxi(1, GameState.MIN_SUPPORT_FOR_PLACEMENT - GameState.CORRIDOR_SUPPORT_DISCOUNT + support_delta)
		return "Hover board tiles for details | Placement support >= %d (corridors: %d)." % [
			open_support,
			corridor_support
		]

	var hovered_block: Dictionary = state.get_block_at(hovered_tile)
	if not hovered_block.is_empty():
		var owner_id: int = int(hovered_block.get("owner", 0))
		var tile_type: String = String(hovered_block.get("tile_type", "basic"))
		var hp: int = int(hovered_block.get("hp", 0))
		var max_hp: int = int(hovered_block.get("max_hp", hp))
		var tier: int = int(hovered_block.get("upgrade_tier", 0))
		var age: int = int(hovered_block.get("age", 0))
		var support: int = state.count_owned_within_manhattan(owner_id, hovered_tile, 2)
		var label: String = "Tile (%d,%d): %s #%d %s HP %d/%d U%d S%d %s" % [
			hovered_tile.x,
			hovered_tile.y,
			_owner_relation_label(owner_id),
			_owner_display_number(owner_id),
			_tile_type_label(tile_type),
			hp,
			max_hp,
			tier,
			support,
			_stability_label(age),
		]
		if bool(hovered_block.get("is_heart", false)):
			label += " heart"
		if owner_id == GameState.PLAYER_ID and tile_type != "basic" and tier < Combat.MAX_UPGRADE_TIER:
			var plan: Dictionary = _build_player_queue_plan()
			var upgrade_check: Dictionary = _validate_upgrade_target(hovered_block, plan)
			if bool(upgrade_check.get("ok", false)):
				label += " | upg cost %d" % int(upgrade_check.get("cost", 0))
		return label

	var ground_text: String = "Ground (%d,%d): empty" % [hovered_tile.x, hovered_tile.y]
	if not hover_invalid_reason.is_empty():
		return "%s | %s" % [ground_text, hover_invalid_reason]
	if not hover_preview_action.is_empty():
		return "%s | action preview valid" % ground_text
	return ground_text

func _owner_relation_label(owner_id: int) -> String:
	if owner_id == GameState.PLAYER_ID:
		return "Player"
	if state.are_hostile(GameState.PLAYER_ID, owner_id):
		return "Enemy"
	return "Ally"

func _tile_type_label(tile_type: String) -> String:
	match tile_type:
		"basic":
			return "Basic"
		"gather":
			return "Gather"
		"defense":
			return "Defense"
		"melee":
			return "Melee"
		"ranged":
			return "Ranged"
		_:
			return tile_type.capitalize()

func _stability_label(age: int) -> String:
	if age <= 0:
		return "fragile"
	if age == 1:
		return "normal"
	return "reinforced"

func _update_board_layout(force: bool = false) -> void:
	if state == null or board_region == null:
		return

	var region: Rect2 = _play_region_rect()
	var fit_tile: int = int(floor(minf(float(TILE_SIZE), minf(region.size.x / float(state.width), region.size.y / float(state.height)))))
	fit_tile = maxi(MIN_RENDER_TILE_SIZE, fit_tile)
	var next_tile_size: float = float(fit_tile)
	var tile_size_changed: bool = not is_equal_approx(next_tile_size, _render_tile_size)

	if not force and region == _last_board_region_rect and not tile_size_changed:
		return

	_last_board_region_rect = region
	board_clip_rect = region
	_render_tile_size = next_tile_size
	renderer.tile_size = _render_tile_size

	var map_size: Vector2 = Vector2(state.width * _render_tile_size, state.height * _render_tile_size)
	var centered_x: float = region.position.x + maxf(0.0, floor((region.size.x - map_size.x) * 0.5))
	var centered_y: float = region.position.y + maxf(0.0, floor((region.size.y - map_size.y) * 0.5))

	board_origin = Vector2(centered_x, centered_y)
	if _use_3d_world():
		_update_3d_layout(region)
	_queue_world_redraw()

func _update_3d_layout(region: Rect2) -> void:
	if not _use_3d_world() or board_region == null:
		return
	var board_region_rect: Rect2 = board_region.get_global_rect()
	var local_pos: Vector2 = region.position - board_region_rect.position
	world_3d_host.position = local_pos
	world_3d_host.size = region.size
	board_clip_rect = Rect2(region.position, region.size)
	var viewport_size: Vector2i = Vector2i(maxi(64, int(round(region.size.x))), maxi(64, int(round(region.size.y))))
	if world_3d_viewport.size != viewport_size:
		world_3d_viewport.size = viewport_size
	world_3d_root.set_viewport_size(viewport_size)

func _play_region_rect() -> Rect2:
	var region: Rect2 = board_region.get_global_rect()
	var pad: float = PLAY_REGION_VISUAL_INSET

	var left: float = region.position.x + pad
	var top: float = region.position.y + pad
	var right: float = region.end.x - pad
	var bottom: float = region.end.y - pad

	# Hard-clamp against actual panel bounds so render bleed never intrudes.
	if top_panel != null:
		top = maxf(top, top_panel.get_global_rect().end.y + PLAY_REGION_PANEL_GAP)
	if right_panel != null:
		right = minf(right, right_panel.get_global_rect().position.x - PLAY_REGION_PANEL_GAP)
	if bottom_panel != null:
		bottom = minf(bottom, bottom_panel.get_global_rect().position.y - PLAY_REGION_PANEL_GAP)

	# BoardRegion already reserves UI space, but keep a robust minimum draw area.
	# Keep a valid minimum draw area even on very small windows.
	right = maxf(right, left + 64.0)
	bottom = maxf(bottom, top + 64.0)

	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _append_enemy_action_summary(applied_actions: Array, failed_actions: Array) -> void:
	state.last_log.insert(0, enemy_feedback.build_turn_line(applied_actions, failed_actions))

func _outcome_reason_text(reason: String) -> String:
	match reason:
		"door_destroyed":
			return "Door destroyed"
		"all_enemy_hearts_destroyed":
			return "All enemy hearts destroyed"
		"all_player_hearts_destroyed":
			return "All player hearts destroyed"
		"all_player_team_hearts_destroyed":
			return "All allied hearts destroyed"
		"stall_lock":
			return "Stall lock"
		"turn_limit":
			return "Turn limit reached"
		_:
			return reason if not reason.is_empty() else "Outcome reached"

func _run_flow():
	return get_node("/root/RunFlow")

func _fit_line(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return "%s..." % text.substr(0, max_chars - 3)

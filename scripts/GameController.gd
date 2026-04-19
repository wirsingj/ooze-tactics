extends Node2D

# Scene-level orchestrator for input, queueing, turn commits, and UI refresh.

const TILE_SIZE: int = 32
const MAX_LEVELS: int = 5
const ANIM_FRAME_TIME: float = 0.18
const ENEMY_FLASH_DURATION: float = 0.65
const MIN_EXPAND_ADJACENT: int = 1
const ACTION_VALIDATOR_SCRIPT: GDScript = preload("res://scripts/systems/ActionValidator.gd")
const TURN_RESOLVER_SCRIPT: GDScript = preload("res://scripts/systems/TurnResolver.gd")
const ENEMY_FEEDBACK_SCRIPT: GDScript = preload("res://scripts/systems/EnemyFeedback.gd")

var tick_system: TickSystem = TickSystem.new()
var ai: EnemyAI = EnemyAI.new()
var cards: CardSystem = CardSystem.new()
var generator: LevelGenerator = LevelGenerator.new()
var director: LevelDirector = LevelDirector.new()
var renderer: BoardRenderer = BoardRenderer.new()
var intent_planner: IntentPlanner = IntentPlanner.new()
var validator = ACTION_VALIDATOR_SCRIPT.new()
var turn_resolver = TURN_RESOLVER_SCRIPT.new()
var enemy_feedback = ENEMY_FEEDBACK_SCRIPT.new()

var room_templates: Array = []
var enemy_defs: Array = []
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

var valid_place_targets: Array = []
var valid_convert_targets: Array = []
var hover_preview_action: Dictionary = {}
var hover_invalid_reason: String = ""

var status_message: String = ""
var status_timer: float = 0.0

var anim_timer: float = 0.0
var anim_frame: int = 0
var enemy_flash_timer: float = 0.0

var board_origin: Vector2 = Vector2(16, 64)
var board_clip_rect: Rect2 = Rect2(16, 64, 960, 560)
var _last_board_region_rect: Rect2 = Rect2(-1, -1, -1, -1)

var _button_style_normal: StyleBoxTexture = null
var _button_style_hover: StyleBoxTexture = null
var _button_style_pressed: StyleBoxTexture = null
var _button_style_selected: StyleBoxTexture = null

@onready var ui_root: Control = $CanvasLayer/UI
@onready var board_region: Control = $CanvasLayer/UI/BoardRegion
@onready var player_label: Label = $CanvasLayer/UI/TopPanel/TopMargin/TopRow/PlayerLabel
@onready var turn_label: Label = $CanvasLayer/UI/TopPanel/TopMargin/TopRow/TurnLabel
@onready var enemy_label: Label = $CanvasLayer/UI/TopPanel/TopMargin/TopRow/EnemyLabel

@onready var energy_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/EnergyLabel
@onready var queue_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/QueueLabel
@onready var mode_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/ModeLabel
@onready var debug_label: Label = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/StatsColumn/DebugLabel

@onready var basic_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/TileButtons/BasicButton
@onready var melee_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/TileButtons/MeleeButton
@onready var ranged_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/TileButtons/RangedButton
@onready var gather_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/TileButtons/GatherButton
@onready var defense_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/TileButtons/DefenseButton
@onready var end_turn_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ControlsColumn/EndTurnButton
@onready var skip_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ControlsColumn/SkipButton
@onready var clear_queue_button: Button = $CanvasLayer/UI/BottomPanel/BottomMargin/BottomRow/ControlsColumn/ClearQueueButton

@onready var log_label: RichTextLabel = $CanvasLayer/UI/RightPanel/RightMargin/Log

@onready var card_panel: PanelContainer = $CanvasLayer/UI/CardPanel
@onready var card_buttons: Array = [
	$CanvasLayer/UI/CardPanel/CardMargin/CardVBox/Card1,
	$CanvasLayer/UI/CardPanel/CardMargin/CardVBox/Card2,
	$CanvasLayer/UI/CardPanel/CardMargin/CardVBox/Card3,
]

func _ready() -> void:
	renderer.tile_size = TILE_SIZE
	turn_resolver.tick_system = tick_system
	_apply_ui_theme()
	_load_data()
	_start_run(1337)
	_update_board_layout(true)
	_wire_ui()
	_recompute_action_context()
	_refresh_ui()
	queue_redraw()

func _process(delta: float) -> void:
	_update_board_layout()

	var needs_redraw: bool = false
	anim_timer += delta
	if anim_timer >= ANIM_FRAME_TIME:
		anim_timer = 0.0
		anim_frame = (anim_frame + 1) % 3
		needs_redraw = true

	if enemy_flash_timer > 0.0:
		enemy_flash_timer = maxf(0.0, enemy_flash_timer - delta)
		needs_redraw = true

	if status_timer > 0.0:
		status_timer = maxf(0.0, status_timer - delta)
		if status_timer <= 0.0 and status_message.begins_with("Invalid"):
			status_message = ""
			_refresh_ui()

	if needs_redraw:
		queue_redraw()

func _draw() -> void:
	var enemy_flash_alpha: float = 0.0
	if ENEMY_FLASH_DURATION > 0.0:
		enemy_flash_alpha = enemy_flash_timer / ENEMY_FLASH_DURATION

	renderer.draw_world(
		self,
		state,
		board_origin,
		board_clip_rect,
		selected_tile,
		hovered_tile,
		queued_actions,
		enemy_intent_actions,
		valid_place_targets,
		valid_convert_targets,
		hover_preview_action,
		hover_invalid_reason,
		recent_enemy_actions,
		enemy_flash_alpha,
		anim_frame
	)

func _unhandled_input(event: InputEvent) -> void:
	if run_over or card_panel.visible:
		return

	if event is InputEventMouseMotion:
		hovered_tile = _mouse_to_tile(get_local_mouse_position())
		_recompute_hover_context()
		_refresh_ui()
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		var mouse_event: InputEventMouseButton = event
		var tile: Vector2i = _mouse_to_tile(get_local_mouse_position())
		if tile == Vector2i(-1, -1):
			return

		selected_tile = tile
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var outcome: Dictionary = _queue_action_from_click(tile)
			if not bool(outcome.get("ok", false)):
				_set_status("Invalid: %s" % String(outcome.get("reason", "unknown")), 2.2)
			elif not String(outcome.get("message", "")).is_empty():
				_set_status(String(outcome["message"]), 1.4)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if not _remove_player_action_for_tile(tile):
				_set_status("No queued action on that tile", 1.4)

		_recompute_action_context()
		_refresh_ui()
		queue_redraw()

func _wire_ui() -> void:
	basic_button.pressed.connect(_set_mode.bind("basic"))
	melee_button.pressed.connect(_set_mode.bind("melee"))
	ranged_button.pressed.connect(_set_mode.bind("ranged"))
	gather_button.pressed.connect(_set_mode.bind("gather"))
	defense_button.pressed.connect(_set_mode.bind("defense"))

	end_turn_button.pressed.connect(_resolve_turn)
	skip_button.pressed.connect(_skip_turn)
	clear_queue_button.pressed.connect(_clear_queue)

func _apply_ui_theme() -> void:
	var theme: Theme = Theme.new()
	var font: Font = _load_runtime_font("res://assets/fonts/PressStart2P-Regular.ttf")
	if font != null:
		theme.set_default_font(font)
	theme.set_default_font_size(11)

	var panel_style: StyleBoxTexture = _make_stylebox_texture(renderer.make_ui_skin("ui_panel_tile"), 10, 8)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	_button_style_normal = _make_stylebox_texture(renderer.make_ui_skin("ui_button_tile"), 8, 6)
	_button_style_hover = _make_stylebox_texture(renderer.make_ui_skin("ui_button_tile"), 8, 6)
	_button_style_hover.modulate_color = Color(1.08, 1.08, 1.08, 1.0)
	_button_style_pressed = _make_stylebox_texture(renderer.make_ui_skin("ui_button_tile"), 8, 6)
	_button_style_pressed.modulate_color = Color(0.88, 0.88, 0.88, 1.0)
	_button_style_selected = _make_stylebox_texture(renderer.make_ui_skin("ui_button_selected"), 8, 6)

	theme.set_stylebox("normal", "Button", _button_style_normal)
	theme.set_stylebox("hover", "Button", _button_style_hover)
	theme.set_stylebox("pressed", "Button", _button_style_pressed)
	theme.set_stylebox("focus", "Button", _button_style_hover)

	theme.set_color("font_color", "Label", Color(0.95, 0.94, 0.86))
	theme.set_color("default_color", "RichTextLabel", Color(0.93, 0.92, 0.84))
	theme.set_color("font_color", "Button", Color(0.96, 0.96, 0.90))
	theme.set_constant("line_separation", "RichTextLabel", 2)

	ui_root.theme = theme

	basic_button.icon = renderer.make_ui_icon("basic")
	melee_button.icon = renderer.make_ui_icon("melee")
	ranged_button.icon = renderer.make_ui_icon("ranged")
	gather_button.icon = renderer.make_ui_icon("gather")
	defense_button.icon = renderer.make_ui_icon("defense")

	for button in [basic_button, melee_button, ranged_button, gather_button, defense_button]:
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = false
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.clip_text = true

	var endturn_style: StyleBoxTexture = _make_stylebox_texture(renderer.make_ui_skin("ui_button_endturn"), 8, 6)
	end_turn_button.add_theme_stylebox_override("normal", endturn_style)
	end_turn_button.add_theme_stylebox_override("hover", _stylebox_modulated(endturn_style, Color(1.08, 1.08, 1.08, 1.0)))
	end_turn_button.add_theme_stylebox_override("pressed", _stylebox_modulated(endturn_style, Color(0.9, 0.9, 0.9, 1.0)))

func _set_mode(tile_type: String) -> void:
	selected_tile_type = tile_type
	_set_status("Mode: %s" % selected_tile_type.to_upper(), 1.0)
	_recompute_action_context()
	_refresh_ui()
	queue_redraw()

func _skip_turn() -> void:
	queued_actions.clear()
	_recompute_action_context()
	_resolve_turn()

func _clear_queue() -> void:
	queued_actions.clear()
	_set_status("Queue cleared", 1.0)
	_recompute_action_context()
	_refresh_ui()
	queue_redraw()

func _load_data() -> void:
	room_templates = _load_json_array("res://data/rooms/templates.json")
	enemy_defs = _load_json_array("res://data/enemies/archetypes.json")

func _load_json_array(path: String) -> Array:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	return []

func _start_run(seed: int) -> void:
	run_over = false
	state = generator.build_level(1, seed, room_templates, enemy_defs, [])
	queued_actions.clear()
	recent_enemy_actions.clear()
	recent_enemy_failed_actions.clear()
	hovered_tile = Vector2i(-1, -1)
	_refresh_enemy_intents()
	_update_board_layout(true)
	_recompute_action_context()

func _queue_action_from_click(tile: Vector2i) -> Dictionary:
	if state == null or not state.is_inside(tile):
		return {"ok": false, "reason": "out of bounds"}

	var clicked: Dictionary = state.get_block_at(tile)
	if clicked.is_empty():
		return _queue_place_action(tile, selected_tile_type)

	if int(clicked["owner"]) != GameState.PLAYER_ID:
		return {"ok": false, "reason": "not owned"}

	return _queue_convert_action(clicked, selected_tile_type)

func _queue_place_action(tile: Vector2i, tile_type: String) -> Dictionary:
	if not Combat.TILE_RULES.has(tile_type):
		return {"ok": false, "reason": "unknown tile type"}

	var existing_index: int = _find_player_place_action_index(tile)
	if existing_index >= 0:
		var existing: Dictionary = queued_actions[existing_index]
		if String(existing.get("tile_type", "basic")) == tile_type:
			queued_actions.remove_at(existing_index)
			return {"ok": true, "message": "Placement removed"}
		queued_actions.remove_at(existing_index)

	var plan: Dictionary = _build_player_queue_plan()
	var check: Dictionary = _validate_place_target(tile, tile_type, plan)
	if not bool(check["ok"]):
		return check

	var candidate: Dictionary = _build_place_candidate(tile, tile_type)
	var apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate)
	if not bool(apply_check.get("ok", false)):
		return {"ok": false, "reason": String(apply_check.get("reason", "conflict in turn resolution"))}

	queued_actions.append(candidate)
	return {"ok": true}

func _queue_convert_action(block: Dictionary, to_type: String) -> Dictionary:
	if not Combat.TILE_RULES.has(to_type):
		return {"ok": false, "reason": "unknown tile type"}

	var block_id: int = int(block["id"])
	var existing_index: int = _find_player_convert_action_index(block_id)
	if existing_index >= 0:
		var existing: Dictionary = queued_actions[existing_index]
		if String(existing.get("to_type", "basic")) == to_type:
			queued_actions.remove_at(existing_index)
			return {"ok": true, "message": "Conversion removed"}
		queued_actions.remove_at(existing_index)

	var plan: Dictionary = _build_player_queue_plan()
	var check: Dictionary = _validate_convert_target(block, to_type, plan)
	if not bool(check["ok"]):
		return check

	var from_type: String = String(block.get("tile_type", "basic"))
	var candidate: Dictionary = _build_convert_candidate(block_id, from_type, to_type)
	var apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate)
	if not bool(apply_check.get("ok", false)):
		return {"ok": false, "reason": String(apply_check.get("reason", "conflict in turn resolution"))}

	queued_actions.append(candidate)
	return {"ok": true}

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

	if removed:
		_set_status("Removed queued action", 1.0)
	return removed

func _build_player_queue_plan() -> Dictionary:
	var plan: Dictionary = validator.build_owner_plan(state, queued_actions, GameState.PLAYER_ID)
	# Keep backward-compatible key name for existing helper calls.
	plan["planned_player_tiles"] = plan.get("planned_tiles", {})
	return plan

func _resolve_turn() -> void:
	if run_over:
		return

	var min_adjacent: int = _current_min_adjacent()
	var resolution: Dictionary = turn_resolver.resolve_turn(
		state,
		queued_actions,
		enemy_intent_actions,
		min_adjacent,
		_tile_cost("basic")
	)
	state = resolution.get("state", state)
	queued_actions.clear()

	recent_enemy_actions = resolution.get("applied_enemy_actions", [])
	recent_enemy_failed_actions = resolution.get("failed_enemy_actions", [])
	enemy_flash_timer = ENEMY_FLASH_DURATION if recent_enemy_actions.size() > 0 else 0.0
	_append_enemy_action_summary(recent_enemy_actions, recent_enemy_failed_actions)

	_refresh_enemy_intents()
	_recompute_action_context()

	var outcome: Dictionary = director.check_victory_or_loss(state)
	if String(outcome["status"]) == "victory":
		_open_card_reward()
	elif String(outcome["status"]) == "loss":
		run_over = true
		turn_label.text = "RUN FAILED"

	_refresh_ui()
	queue_redraw()

func _open_card_reward() -> void:
	var options: Array = cards.draw_choices(state, 3)
	if options.size() < 3:
		run_over = true
		turn_label.text = "RUN COMPLETE"
		return

	card_panel.visible = true
	for i in range(3):
		var card: Dictionary = options[i]
		var button: Button = card_buttons[i]
		button.text = "%s\n%s" % [String(card.get("name", "Card")), String(card.get("desc", ""))]
		_disconnect_button(button)
		button.pressed.connect(_on_card_pressed.bind(card))

func _disconnect_button(button: Button) -> void:
	for conn in button.pressed.get_connections():
		var callable_ref: Callable = conn["callable"]
		button.pressed.disconnect(callable_ref)

func _on_card_pressed(card: Dictionary) -> void:
	cards.apply_card(state, card)
	card_panel.visible = false

	if state.level_index >= MAX_LEVELS:
		run_over = true
		turn_label.text = "RUN COMPLETE"
		return

	var carry: Array = _extract_player_shape()
	var next_level: int = state.level_index + 1
	var next_seed: int = state.run_seed + 17
	state = generator.build_level(next_level, next_seed, room_templates, enemy_defs, carry)
	_update_board_layout(true)
	_refresh_enemy_intents()
	_recompute_action_context()
	_refresh_ui()
	queue_redraw()

func _extract_player_shape() -> Array:
	var out: Array = []
	for block in state.get_owner_blocks(GameState.PLAYER_ID):
		var pos: Vector2i = block["pos"]
		out.append({
			"pos": [pos.x, pos.y],
			"core": bool(block.get("core", false)),
			"max_hp": int(block.get("max_hp", 8)),
			"tile_type": String(block.get("tile_type", "basic")),
			"defense": int(block.get("defense", 0)),
			"damage": int(block.get("damage", 0)),
			"range": int(block.get("range", 1)),
			"gather_bonus": int(block.get("gather_bonus", 0)),
			"age": int(block.get("age", 2)),
		})
	return out

func _refresh_enemy_intents() -> void:
	var min_by_owner: Dictionary = {}
	for owner_id in state.players.keys():
		var owner_int: int = int(owner_id)
		if owner_int == GameState.PLAYER_ID:
			continue
		min_by_owner[owner_int] = _min_adjacent_for_owner(owner_int)
	enemy_intent_actions = intent_planner.build_enemy_intents(state, ai, min_by_owner, _current_min_adjacent())

func _refresh_ui() -> void:
	if state == null:
		return

	var player_hp: int = state.get_total_hp(GameState.PLAYER_ID)
	var player_energy: int = int(state.players[GameState.PLAYER_ID]["nutrients"])
	player_label.text = "PLAYER HP %d" % player_hp
	turn_label.text = "TURN %d  |  LEVEL %d" % [state.turn_index, state.level_index]
	enemy_label.text = _enemy_header_text()

	energy_label.text = "ENERGY %d   STALL %d/3   SUPPORT R2   STABILITY 0/1/2+" % [player_energy, state.stall_counter]
	queue_label.text = "QUEUE %d   PLACE %d   CONVERT %d" % [queued_actions.size(), valid_place_targets.size(), valid_convert_targets.size()]

	var mode_text: String = "MODE %s | Unsupported pushes are fragile. End Turn: convert -> place -> melee -> ranged -> economy -> age" % selected_tile_type.to_upper()
	mode_label.text = _fit_line(mode_text, 68)

	var debug_text: String = _debug_hint_text()
	if not status_message.is_empty():
		debug_text = "Status: %s | %s" % [status_message, debug_text]
	debug_label.text = _fit_line(debug_text, 72)

	_refresh_action_button_labels()
	_refresh_log()

func _enemy_header_text() -> String:
	var enemy_hp: int = 0
	var enemy_energy: int = 0
	for owner_id in state.players.keys():
		if int(owner_id) == GameState.PLAYER_ID:
			continue
		enemy_energy += int(state.players[owner_id]["nutrients"])
		enemy_hp += state.get_total_hp(int(owner_id))
	return "ENEMY HP %d  ENERGY %d" % [enemy_hp, enemy_energy]

func _refresh_action_button_labels() -> void:
	basic_button.text = _button_text("Basic", _tile_cost("basic"))
	melee_button.text = _button_text("Melee", _tile_cost("melee"))
	ranged_button.text = _button_text("Ranged", _tile_cost("ranged"))
	gather_button.text = _button_text("Gather", _tile_cost("gather"))
	defense_button.text = _button_text("Defense", _tile_cost("defense"))
	_apply_tile_button_selection()

func _button_text(label: String, cost: int) -> String:
	return "%s\nE %d" % [label, cost]

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
			var place_apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, place_candidate)
			if bool(place_apply_check.get("ok", false)):
				valid_place_targets.append(tile)

	for block in state.get_owner_blocks(GameState.PLAYER_ID):
		var convert_check: Dictionary = _validate_convert_target(block, selected_tile_type, plan)
		if not bool(convert_check.get("ok", false)):
			continue
		var from_type: String = String(block.get("tile_type", "basic"))
		var convert_candidate: Dictionary = _build_convert_candidate(int(block["id"]), from_type, selected_tile_type)
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
			var apply_check: Dictionary = validator.predict_candidate_application(state, queued_actions, enemy_intent_actions, candidate_place)
			if bool(apply_check.get("ok", false)):
				hover_preview_action = candidate_place
			else:
				hover_invalid_reason = String(apply_check.get("reason", "conflict in turn resolution"))
		else:
			hover_invalid_reason = String(hover_place_check.get("reason", "invalid"))
	elif int(hovered_block["owner"]) == GameState.PLAYER_ID:
		var hover_convert_check: Dictionary = _validate_convert_target(hovered_block, selected_tile_type, plan)
		if bool(hover_convert_check.get("ok", false)):
			var from_type: String = String(hovered_block.get("tile_type", "basic"))
			var candidate_convert: Dictionary = _build_convert_candidate(int(hovered_block["id"]), from_type, selected_tile_type)
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
	var local: Vector2 = mouse_pos - board_origin
	if local.x < 0 or local.y < 0:
		return Vector2i(-1, -1)

	var tx: int = int(local.x / TILE_SIZE)
	var ty: int = int(local.y / TILE_SIZE)
	var tile: Vector2i = Vector2i(tx, ty)
	if not state.is_inside(tile):
		return Vector2i(-1, -1)
	return tile

func _tile_cost(tile_type: String) -> int:
	var cost: int = int(Combat.TILE_RULES[tile_type]["cost"])
	if tile_type == "basic":
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
	return {
		"type": "convert_tile",
		"owner": GameState.PLAYER_ID,
		"block_id": block_id,
		"to_type": to_type,
		"energy_delta": Combat.conversion_energy_delta(from_type, to_type),
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
	if _button_style_normal == null or _button_style_selected == null:
		return
	if selected:
		button.add_theme_stylebox_override("normal", _button_style_selected)
	else:
		button.add_theme_stylebox_override("normal", _button_style_normal)

func _make_stylebox_texture(texture: Texture2D, margin: int, content: int) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
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

	if hovered_tile == Vector2i(-1, -1):
		return "Placement requires support >= %d in radius 2." % GameState.MIN_SUPPORT_FOR_PLACEMENT

	if state.is_inside(hovered_tile):
		var hovered_block: Dictionary = state.get_block_at(hovered_tile)
		if not hovered_block.is_empty() and int(hovered_block.get("owner", 0)) == GameState.PLAYER_ID:
			var support: int = state.count_owned_within_manhattan(GameState.PLAYER_ID, hovered_tile, 2)
			var age: int = int(hovered_block.get("age", 0))
			return "Tile (%d,%d): support %d | stability %s" % [hovered_tile.x, hovered_tile.y, support, _stability_label(age)]

	if hover_invalid_reason.is_empty():
		if not hover_preview_action.is_empty():
			return "Hover (%d,%d): valid" % [hovered_tile.x, hovered_tile.y]
		return "Hover (%d,%d)" % [hovered_tile.x, hovered_tile.y]
	return "Hover (%d,%d): %s" % [hovered_tile.x, hovered_tile.y, hover_invalid_reason]

func _stability_label(age: int) -> String:
	if age <= 0:
		return "fragile"
	if age == 1:
		return "normal"
	return "reinforced"

func _update_board_layout(force: bool = false) -> void:
	if state == null or board_region == null:
		return

	var region: Rect2 = board_region.get_global_rect()
	if not force and region == _last_board_region_rect:
		return

	_last_board_region_rect = region
	board_clip_rect = region

	var map_size: Vector2 = Vector2(state.width * TILE_SIZE, state.height * TILE_SIZE)
	var centered_x: float = region.position.x + maxf(0.0, floor((region.size.x - map_size.x) * 0.5))
	var centered_y: float = region.position.y + maxf(0.0, floor((region.size.y - map_size.y) * 0.5))

	board_origin = Vector2(centered_x, centered_y)
	queue_redraw()

func _append_enemy_action_summary(applied_actions: Array, failed_actions: Array) -> void:
	state.last_log.insert(0, enemy_feedback.build_turn_line(applied_actions, failed_actions))

func _fit_line(text: String, max_chars: int) -> String:
	if text.length() <= max_chars:
		return text
	return "%s..." % text.substr(0, max_chars - 3)

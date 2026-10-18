extends Node

const MAX_LEVELS: int = 5
const DEFAULT_TURN_LIMIT: int = 50
const DEFAULT_DOOR_HP: int = 32
const NORMAL_PLAYER_ENERGY: int = 10
const NORMAL_ENEMY_ENERGY: int = 9
const DEV_PLAYER_ENERGY: int = 500
const DEV_DEFAULT_TEAM_SIZE: int = 1
const DEV_MAX_TEAM_SIZE: int = 4
const SETTINGS_PATH: String = "user://settings.cfg"
const GRAPHICS_STYLE_2D: String = "2d"
const GRAPHICS_STYLE_3D: String = "3d"
const GRAPHICS_STYLE_COLONY: String = "colony"

const UPGRADE_POOL: Array = [
	{
		"id": "melee_damage_plus_1",
		"name": "Razor Tendons",
		"description": "+1 melee damage",
		"weight": 3,
		"effects": {"melee_damage_bonus": 1},
	},
	{
		"id": "energy_per_turn_plus_1",
		"name": "Metabolic Surge",
		"description": "+1 energy per turn",
		"weight": 3,
		"effects": {"income_flat": 1},
	},
	{
		"id": "support_cap_plus_1",
		"name": "Dense Matrix",
		"description": "+1 support defense cap",
		"weight": 2,
		"effects": {"support_bonus_cap_bonus": 1},
	},
	{
		"id": "ranged_splash_radius_plus_1",
		"name": "Splatter Jets",
		"description": "Ranged splash radius +1",
		"weight": 2,
		"effects": {"ranged_splash_radius_bonus": 1},
	},
	{
		"id": "defense_guard_plus_1",
		"name": "Thicker Carapace",
		"description": "Defense guard cap +1",
		"weight": 2,
		"effects": {"defense_guard_cap_bonus": 1},
	},
	{
		"id": "gather_bonus_plus_1",
		"name": "Digestive Enzymes",
		"description": "Gather income +1",
		"weight": 2,
		"effects": {"gather_income_bonus": 1},
	},
	{
		"id": "soft_support_requirements",
		"name": "Flexible Membrane",
		"description": "Placement support required -1",
		"weight": 1,
		"effects": {"placement_support_delta": -1},
	},
]

const LEVEL_SETUPS: Dictionary = {
	1: {
		"name": "Awakening",
		"theme": "Onboarding",
		"description": "Simple chamber: spread, gather energy, and destroy the enemy hearts or break the door.",
		"player_clusters": 1,
		"ally_ai_count": 0,
		"enemy_clusters": 1,
		"player_energy_bonus": 8,
		"enemy_energy_bonus": 0,
		"player_income_delta": 2,
		"player_max_actions": 5,
		"enemy_income_delta": 1,
		"enemy_max_actions": 2,
		"player_heart_max": 1,
		"enemy_heart_max": 1,
		"player_cluster_size_min": 5,
		"player_cluster_size_max": 5,
		"enemy_cluster_size_min": 4,
		"enemy_cluster_size_max": 4,
		"turn_limit": 30,
		"door_hp": 12,
	},
	2: {
		"name": "Narrow Halls",
		"theme": "Chokepoints",
		"description": "A split corridor fight where walls force contact through narrow lanes.",
		"player_clusters": 1,
		"ally_ai_count": 0,
		"enemy_clusters": 1,
		"player_energy_bonus": 6,
		"enemy_energy_bonus": 1,
		"player_income_delta": 2,
		"player_max_actions": 5,
		"enemy_income_delta": 2,
		"enemy_max_actions": 3,
		"player_heart_max": 1,
		"enemy_heart_max": 1,
		"player_cluster_size_min": 5,
		"player_cluster_size_max": 6,
		"enemy_cluster_size_min": 4,
		"enemy_cluster_size_max": 5,
		"turn_limit": 36,
		"door_hp": 14,
	},
	3: {
		"name": "Forked Vault",
		"theme": "Multi-front",
		"description": "Multiple enemy hearts pressure separate fronts and reward smart territory choices.",
		"player_clusters": 1,
		"ally_ai_count": 0,
		"enemy_clusters": 2,
		"player_energy_bonus": 6,
		"enemy_energy_bonus": 0,
		"player_income_delta": 2,
		"player_max_actions": 5,
		"enemy_income_delta": 1,
		"enemy_max_actions": 2,
		"player_heart_max": 2,
		"enemy_heart_max": 1,
		"player_cluster_size_min": 5,
		"player_cluster_size_max": 6,
		"enemy_cluster_size_min": 4,
		"enemy_cluster_size_max": 5,
		"turn_limit": 44,
		"door_hp": 18,
	},
	4: {
		"name": "Starving Gallery",
		"theme": "Pressure",
		"description": "Lower margin for delay, with a risky fallen adventurer offering an extra evolution.",
		"player_clusters": 1,
		"ally_ai_count": 0,
		"enemy_clusters": 2,
		"player_energy_bonus": 7,
		"enemy_energy_bonus": 1,
		"player_income_delta": 2,
		"player_max_actions": 5,
		"enemy_income_delta": 1,
		"enemy_max_actions": 3,
		"player_heart_max": 2,
		"enemy_heart_max": 1,
		"player_cluster_size_min": 5,
		"player_cluster_size_max": 6,
		"enemy_cluster_size_min": 4,
		"enemy_cluster_size_max": 5,
		"turn_limit": 44,
		"door_hp": 20,
		"loot_upgrade": true,
	},
	5: {
		"name": "The Sealed Heart",
		"theme": "Miniboss",
		"description": "A tighter arena around a reinforced enemy heart with upgraded defenders.",
		"player_clusters": 1,
		"ally_ai_count": 0,
		"enemy_clusters": 1,
		"player_energy_bonus": 8,
		"enemy_energy_bonus": 4,
		"player_income_delta": 2,
		"player_max_actions": 5,
		"enemy_income_delta": 3,
		"enemy_max_actions": 4,
		"player_heart_max": 2,
		"enemy_heart_max": 1,
		"player_cluster_size_min": 6,
		"player_cluster_size_max": 6,
		"enemy_cluster_size_min": 3,
		"enemy_cluster_size_max": 3,
		"turn_limit": 50,
		"door_hp": 18,
		"miniboss": true,
		"boss_core_hp_bonus": 9,
	},
}

var run_active: bool = false
var dev_mode: bool = false
var enemies_allied: bool = true
var current_level: int = 1
var run_seed: int = 1337
var dev_player_team_size: int = DEV_DEFAULT_TEAM_SIZE
var dev_enemy_team_size: int = DEV_DEFAULT_TEAM_SIZE
var dev_player_immortal: bool = false
var dev_spectator_mode: bool = false
var run_modifiers: Dictionary = {}
var picked_upgrades: Array = []
var pending_upgrade_choices: Array = []
var upgrade_pick_count: int = 0
var upgrade_draw_serial: int = 0

var result_title: String = ""
var result_message: String = ""
var result_next_scene: String = "res://scenes/MainMenu.tscn"
var result_button_text: String = "Continue"
var result_auto_advance: bool = false
var result_delay_seconds: float = 1.4
var graphics_style: String = GRAPHICS_STYLE_COLONY

func _ready() -> void:
	_load_user_settings()

func begin_run() -> void:
	run_active = true
	dev_mode = false
	enemies_allied = true
	dev_player_team_size = DEV_DEFAULT_TEAM_SIZE
	dev_enemy_team_size = DEV_DEFAULT_TEAM_SIZE
	dev_player_immortal = false
	dev_spectator_mode = false
	current_level = 1
	run_seed = int(Time.get_unix_time_from_system()) + int(Time.get_ticks_msec() % 100000)
	_reset_progression_state()
	_clear_result()

func begin_dev_run(player_team_size: int, enemy_team_size: int, immortal: bool, spectator: bool) -> void:
	run_active = true
	dev_mode = true
	# Dev panel uses explicit team-vs-team sizing.
	enemies_allied = true
	dev_player_team_size = clampi(player_team_size, 1, DEV_MAX_TEAM_SIZE)
	dev_enemy_team_size = clampi(enemy_team_size, 1, DEV_MAX_TEAM_SIZE)
	dev_player_immortal = immortal
	dev_spectator_mode = spectator
	current_level = 1
	run_seed = int(Time.get_unix_time_from_system()) + int(Time.get_ticks_msec() % 100000)
	_reset_progression_state()
	_clear_result()

func ensure_run() -> void:
	if run_active:
		return
	begin_run()

func get_level_setup(level_index: int = -1) -> Dictionary:
	var query_level: int = level_index
	if query_level <= 0:
		query_level = current_level
	if LEVEL_SETUPS.has(query_level):
		return LEVEL_SETUPS[query_level].duplicate(true)
	return LEVEL_SETUPS[MAX_LEVELS].duplicate(true)

func build_level_options() -> Dictionary:
	var setup: Dictionary = get_level_setup(current_level)
	var player_clusters: int = int(setup.get("player_clusters", 1))
	var ally_ai_count: int = int(setup.get("ally_ai_count", 0))
	var enemy_clusters: int = int(setup.get("enemy_clusters", 1))

	if dev_mode:
		player_clusters = 0 if dev_spectator_mode else 1
		ally_ai_count = dev_player_team_size if dev_spectator_mode else maxi(0, dev_player_team_size - 1)
		enemy_clusters = dev_enemy_team_size

	var base_player_energy: int = NORMAL_PLAYER_ENERGY + current_level
	base_player_energy += int(setup.get("player_energy_bonus", 0))
	if dev_mode:
		base_player_energy = DEV_PLAYER_ENERGY

	var base_enemy_energy: int = NORMAL_ENEMY_ENERGY + current_level
	base_enemy_energy += int(setup.get("enemy_energy_bonus", 0))
	var turn_limit: int = int(setup.get("turn_limit", DEFAULT_TURN_LIMIT))
	if dev_mode and dev_spectator_mode:
		turn_limit = 0
	return {
		"player_cluster_count": player_clusters,
		"ally_ai_count": ally_ai_count,
		"enemy_cluster_count": enemy_clusters,
		"player_start_energy": base_player_energy,
		"ally_start_energy": base_player_energy,
		"enemy_start_energy": base_enemy_energy,
		"ai_tactical_search": true,
		"player_income_delta": int(setup.get("player_income_delta", 0)),
		"ally_income_delta": int(setup.get("ally_income_delta", setup.get("player_income_delta", 0))),
		"enemy_income_delta": int(setup.get("enemy_income_delta", 0)),
		"player_max_actions": int(setup.get("player_max_actions", 3)),
		"ally_max_actions": int(setup.get("ally_max_actions", setup.get("player_max_actions", 3))),
		"enemy_max_actions": int(setup.get("enemy_max_actions", 3)),
		"player_heart_max": int(setup.get("player_heart_max", 3)),
		"ally_heart_max": int(setup.get("ally_heart_max", setup.get("player_heart_max", 3))),
		"enemy_heart_max": int(setup.get("enemy_heart_max", 3)),
		"player_cluster_size_min": int(setup.get("player_cluster_size_min", 3)),
		"player_cluster_size_max": int(setup.get("player_cluster_size_max", 6)),
		"ally_cluster_size_min": int(setup.get("ally_cluster_size_min", setup.get("player_cluster_size_min", 3))),
		"ally_cluster_size_max": int(setup.get("ally_cluster_size_max", setup.get("player_cluster_size_max", 5))),
		"enemy_cluster_size_min": int(setup.get("enemy_cluster_size_min", 3)),
		"enemy_cluster_size_max": int(setup.get("enemy_cluster_size_max", 6)),
		"enemies_allied": enemies_allied,
		"dev_player_immortal": dev_player_immortal,
		"dev_spectator_mode": dev_spectator_mode,
		"turn_limit": turn_limit,
		"door_hp": int(setup.get("door_hp", DEFAULT_DOOR_HP)),
		"use_curated_vertical_slice": true,
		"level_theme": String(setup.get("theme", "")),
		"level_description": String(setup.get("description", "")),
		"loot_upgrade": bool(setup.get("loot_upgrade", false)),
		"miniboss": bool(setup.get("miniboss", false)),
		"boss_core_hp_bonus": int(setup.get("boss_core_hp_bonus", 0)),
	}

func get_level_seed() -> int:
	return run_seed + (current_level * 101)

func prepare_victory(level_index: int, reason: String) -> void:
	var safe_reason: String = reason
	if safe_reason.is_empty():
		safe_reason = "objective complete"

	if level_index < MAX_LEVELS:
		current_level = level_index + 1
		var next_setup: Dictionary = get_level_setup(current_level)
		result_title = "LEVEL %d COMPLETE" % level_index
		result_message = "%s\nNext: Level %d (%s)" % [safe_reason.capitalize(), current_level, String(next_setup.get("name", ""))]
		result_next_scene = "res://scenes/Main.tscn"
		result_button_text = "Next Level"
		result_auto_advance = true
		result_delay_seconds = 1.4
		return

	run_active = false
	result_title = "VERTICAL SLICE COMPLETE"
	result_message = "The sealed heart is dissolved.\nFive levels cleared; the full 10-level run structure is ready to expand."
	result_next_scene = "res://scenes/MainMenu.tscn"
	result_button_text = "Main Menu"
	result_auto_advance = false
	result_delay_seconds = 0.0

func prepare_defeat(reason: String) -> void:
	run_active = false
	var safe_reason: String = reason
	if safe_reason.is_empty():
		safe_reason = "objective failed"
	result_title = "DEFEAT"
	result_message = safe_reason.capitalize()
	result_next_scene = "res://scenes/MainMenu.tscn"
	result_button_text = "Main Menu"
	result_auto_advance = false
	result_delay_seconds = 0.0

func _clear_result() -> void:
	result_title = ""
	result_message = ""
	result_next_scene = "res://scenes/MainMenu.tscn"
	result_button_text = "Continue"
	result_auto_advance = false
	result_delay_seconds = 0.0

func get_graphics_style() -> String:
	return graphics_style if graphics_style in [GRAPHICS_STYLE_2D, GRAPHICS_STYLE_3D, GRAPHICS_STYLE_COLONY] else GRAPHICS_STYLE_COLONY

func is_graphics_style_3d() -> bool:
	return get_graphics_style() == GRAPHICS_STYLE_3D

func set_graphics_style(style: String) -> void:
	var normalized: String = style.to_lower()
	graphics_style = normalized if normalized in [GRAPHICS_STYLE_2D, GRAPHICS_STYLE_3D, GRAPHICS_STYLE_COLONY] else GRAPHICS_STYLE_COLONY
	_save_user_settings()

func _load_user_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(SETTINGS_PATH)
	if err != OK:
		graphics_style = GRAPHICS_STYLE_COLONY
		return
	var stored: String = String(cfg.get_value("video", "graphics_style", GRAPHICS_STYLE_COLONY)).to_lower()
	graphics_style = stored if stored in [GRAPHICS_STYLE_2D, GRAPHICS_STYLE_3D, GRAPHICS_STYLE_COLONY] else GRAPHICS_STYLE_COLONY

func _save_user_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("video", "graphics_style", get_graphics_style())
	cfg.save(SETTINGS_PATH)

func should_offer_upgrade_after_victory(level_index: int, spectator_mode: bool = false) -> bool:
	if spectator_mode:
		return false
	return level_index < MAX_LEVELS

func get_run_modifiers() -> Dictionary:
	return run_modifiers.duplicate(true)

func draw_upgrade_choices(n: int = 3) -> Array:
	if not pending_upgrade_choices.is_empty():
		return pending_upgrade_choices.duplicate(true)

	var choice_count: int = clampi(n, 1, mini(3, UPGRADE_POOL.size()))
	var weighted: Array = _build_weighted_upgrade_pool()
	var selected_ids: Dictionary = {}
	var choices: Array = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _upgrade_draw_seed()
	upgrade_draw_serial += 1

	var attempts: int = 0
	var max_attempts: int = maxi(32, weighted.size() * 6)
	while choices.size() < choice_count and attempts < max_attempts and not weighted.is_empty():
		attempts += 1
		var entry: Dictionary = weighted[rng.randi_range(0, weighted.size() - 1)]
		var upgrade_id: String = String(entry.get("id", ""))
		if upgrade_id.is_empty() or selected_ids.has(upgrade_id):
			continue
		selected_ids[upgrade_id] = true
		choices.append(entry.duplicate(true))

	if choices.size() < choice_count:
		for entry_variant in UPGRADE_POOL:
			var fallback_entry: Dictionary = entry_variant
			var fallback_id: String = String(fallback_entry.get("id", ""))
			if fallback_id.is_empty() or selected_ids.has(fallback_id):
				continue
			selected_ids[fallback_id] = true
			choices.append(fallback_entry.duplicate(true))
			if choices.size() >= choice_count:
				break

	pending_upgrade_choices = choices.duplicate(true)
	return pending_upgrade_choices.duplicate(true)

func apply_upgrade_choice(upgrade_id: String) -> Dictionary:
	var selected_upgrade: Dictionary = {}
	if not pending_upgrade_choices.is_empty():
		for choice_variant in pending_upgrade_choices:
			var choice: Dictionary = choice_variant
			if String(choice.get("id", "")) == upgrade_id:
				selected_upgrade = choice.duplicate(true)
				break
	if selected_upgrade.is_empty():
		selected_upgrade = _upgrade_definition_by_id(upgrade_id)
	if selected_upgrade.is_empty():
		return {"ok": false, "reason": "unknown upgrade"}

	var effects: Dictionary = selected_upgrade.get("effects", {})
	for key_variant in effects.keys():
		var key: String = String(key_variant)
		var delta: int = int(effects[key_variant])
		run_modifiers[key] = int(run_modifiers.get(key, 0)) + delta

	picked_upgrades.append({
		"id": String(selected_upgrade.get("id", "")),
		"name": String(selected_upgrade.get("name", "")),
		"level": current_level,
	})
	upgrade_pick_count += 1
	pending_upgrade_choices.clear()

	return {
		"ok": true,
		"upgrade": selected_upgrade,
		"modifiers": run_modifiers.duplicate(true),
	}

func clear_pending_upgrade_choices() -> void:
	pending_upgrade_choices.clear()

func _reset_progression_state() -> void:
	run_modifiers.clear()
	picked_upgrades.clear()
	pending_upgrade_choices.clear()
	upgrade_pick_count = 0
	upgrade_draw_serial = 0

func _build_weighted_upgrade_pool() -> Array:
	var weighted: Array = []
	for entry_variant in UPGRADE_POOL:
		var entry: Dictionary = entry_variant
		var weight: int = maxi(1, int(entry.get("weight", 1)))
		for _i in range(weight):
			weighted.append(entry)
	return weighted

func _upgrade_draw_seed() -> int:
	return int(run_seed) + int(current_level * 1237) + int(upgrade_pick_count * 3571) + int(upgrade_draw_serial * 73)

func _upgrade_definition_by_id(upgrade_id: String) -> Dictionary:
	for entry_variant in UPGRADE_POOL:
		var entry: Dictionary = entry_variant
		if String(entry.get("id", "")) == upgrade_id:
			return entry.duplicate(true)
	return {}

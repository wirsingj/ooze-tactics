extends RefCounted
class_name Economy

# Economy intentionally favors resources/gather tiles over pure tile count.

const BASE_TURN_ENERGY: int = 2
const RESOURCE_CAPTURE_BURST: int = 2
const GATHER_BASE_INCOME: int = 1
const GATHER_RESOURCE_BONUS: int = 1

func claim_resource_bursts(state: GameState) -> Dictionary:
	var bursts: Dictionary = {}
	for owner_id in state.players.keys():
		bursts[owner_id] = 0

	for node in state.resource_nodes:
		if bool(node.get("consumed", false)):
			continue

		var block: Dictionary = state.get_block_at(node["pos"])
		if block.is_empty():
			continue

		var owner: int = int(block["owner"])
		node["consumed"] = true
		node["consumed_by"] = owner
		node["captured_turn"] = state.turn_index
		bursts[owner] = int(bursts.get(owner, 0)) + RESOURCE_CAPTURE_BURST

		if String(block.get("tile_type", "basic")) == "gather":
			block["gather_bonus"] = GATHER_RESOURCE_BONUS
			state.blocks[int(block["id"])] = block

	return bursts

func compute_income_and_upkeep(state: GameState) -> Dictionary:
	var income_by_owner: Dictionary = {}
	var upkeep_by_owner: Dictionary = {}

	# Player run upgrades feed through card_modifiers for deterministic economy math.
	var income_flat: int = int(state.card_modifiers.get("income_flat", 0))
	var gather_income_bonus: int = int(state.card_modifiers.get("gather_income_bonus", 0))

	for owner_id in state.players.keys():
		var is_alive: bool = bool(state.players[owner_id].get("alive", true))
		var base_income: int = BASE_TURN_ENERGY if is_alive else 0
		base_income = maxi(0, base_income + int(state.players[owner_id].get("income_delta", 0)))
		if int(owner_id) == GameState.PLAYER_ID and is_alive:
			base_income += income_flat
		income_by_owner[owner_id] = base_income
		upkeep_by_owner[owner_id] = 0

	for block in state.blocks.values():
		var owner: int = int(block["owner"])
		if not bool(state.players.get(owner, {}).get("alive", true)):
			continue
		if String(block.get("tile_type", "basic")) == "gather":
			var bonus: int = int(block.get("gather_bonus", 0))
			if bonus > 0 and not _gather_bonus_active_this_turn(state, block):
				bonus = 0
			var gather_income: int = GATHER_BASE_INCOME + bonus + int(block.get("gather_upgrade_bonus", 0))
			if owner == GameState.PLAYER_ID:
				gather_income += gather_income_bonus
			income_by_owner[owner] = int(income_by_owner[owner]) + gather_income

	var deltas: Dictionary = {}
	for owner_id in state.players.keys():
		deltas[owner_id] = int(income_by_owner[owner_id]) - int(upkeep_by_owner[owner_id])

	return {
		"income": income_by_owner,
		"upkeep": upkeep_by_owner,
		"delta": deltas,
	}

func apply_income_and_upkeep(state: GameState, report: Dictionary, bursts: Dictionary = {}) -> void:
	for owner_id in state.players.keys():
		if not bool(state.players[owner_id].get("alive", true)):
			continue
		var delta: int = int(report["delta"].get(owner_id, 0)) + int(bursts.get(owner_id, 0))
		state.players[owner_id]["nutrients"] = int(state.players[owner_id]["nutrients"]) + delta

func _gather_bonus_active_this_turn(state: GameState, block: Dictionary) -> bool:
	var node: Dictionary = state.get_resource_node_at(block["pos"])
	if node.is_empty():
		return true
	if not bool(node.get("consumed", false)):
		return false
	if int(node.get("captured_turn", -99999)) == state.turn_index:
		return false
	return true

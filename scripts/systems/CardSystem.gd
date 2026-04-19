extends RefCounted
class_name CardSystem

var cards: Array = []

func _init(path: String = "res://data/cards/cards.json") -> void:
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_ARRAY:
        cards = parsed

func draw_choices(run_state: GameState, n: int = 3) -> Array:
    var seed = int(run_state.run_seed) + int(run_state.turn_index) + int(run_state.level_index) * 97
    var rng = RandomNumberGenerator.new()
    rng.seed = seed

    var weighted: Array = []
    for card in cards:
        var weight = int(card.get("weight", 1))
        for i in range(maxi(1, weight)):
            weighted.append(card)

    var choices: Array = []
    var seen: Dictionary = {}
    while choices.size() < n and weighted.size() > 0:
        var idx = rng.randi_range(0, weighted.size() - 1)
        var c: Dictionary = weighted[idx]
        var id = String(c.get("id", ""))
        if id.is_empty() or seen.has(id):
            weighted.remove_at(idx)
            continue
        seen[id] = true
        choices.append(c)
    return choices

func apply_card(run_state: GameState, card: Dictionary) -> void:
    var effect = String(card.get("effect", ""))
    var amount = float(card.get("amount", 0.0))

    run_state.card_modifiers[String(card.get("id", "unknown"))] = true

    match effect:
        "base_damage_mult":
            run_state.card_modifiers["base_damage_mult"] = float(run_state.card_modifiers.get("base_damage_mult", 1.0)) * amount
        "income_flat":
            run_state.card_modifiers["income_flat"] = int(run_state.card_modifiers.get("income_flat", 0)) + int(amount)
        "grow_cost_delta":
            run_state.card_modifiers["grow_cost_delta"] = int(run_state.card_modifiers.get("grow_cost_delta", 0)) + int(amount)
        "core_hp_flat":
            var core = run_state.get_core(GameState.PLAYER_ID)
            if not core.is_empty():
                core["hp"] = int(core["hp"]) + int(amount)
                core["max_hp"] = int(core["max_hp"]) + int(amount)
                run_state.blocks[int(core["id"])] = core
        _:
            pass



extends RefCounted
class_name EnemyFeedback

# Formats concise, truthful enemy-action summaries from applied outcomes only.

func build_turn_line(applied_enemy_actions: Array, failed_enemy_actions: Array) -> String:
	var attempted: int = applied_enemy_actions.size() + failed_enemy_actions.size()
	if attempted <= 0:
		return "Enemy ooze waits"

	var placed: int = 0
	var converted: int = 0
	var upgraded: int = 0
	for action in applied_enemy_actions:
		var kind: String = String(action.get("type", "pass"))
		if kind == "place_tile":
			placed += 1
		elif kind == "convert_tile":
			converted += 1
		elif kind == "upgrade_tile":
			upgraded += 1

	var line: String = "Enemy ooze grew %d/%d: spread %d, evolved %d, strengthened %d" % [
		applied_enemy_actions.size(),
		attempted,
		placed,
		converted,
		upgraded,
	]
	if not failed_enemy_actions.is_empty():
		line += " | %d blocked" % failed_enemy_actions.size()
	return line

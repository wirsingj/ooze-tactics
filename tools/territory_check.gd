extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: GameState = preload("res://scripts/systems/TerritoryScenario.gd").build(1337)
	var turn = preload("res://scripts/systems/TerritoryTurn.gd").new()
	var rows: Array = []
	var max_ms: int = 0
	var failed: int = 0
	for i in range(40):
		var started: int = Time.get_ticks_msec()
		var intents: Array = turn.ai_orders(state,true)
		var result: Dictionary = turn.resolve(state,intents)
		state = result.state
		var elapsed: int = Time.get_ticks_msec()-started
		max_ms = maxi(max_ms,elapsed)
		failed += state.last_resolution_report.failed_actions.size()
		var roles: Dictionary = {}
		for block in state.blocks.values():
			roles[block.tile_type] = int(roles.get(block.tile_type,0))+1
		rows.append({"turn":state.turn_index,"blocks":state.blocks.size(),"roles":roles,"scores":state.team_scores.duplicate(),"orders":intents.size(),"actions":result.actions.size(),"ms":elapsed,"outcome":result.outcome})
		if i%5==4 or result.outcome.status!="ongoing":
			print(JSON.stringify(rows[-1]))
		if result.outcome.status!="ongoing":
			break
		await process_frame
	var hashes: Dictionary = {}
	for file in ["models/GameState.gd","systems/TerritoryScenario.gd","systems/TerritoryRules.gd","systems/TerritoryOrders.gd","systems/TerritoryAI.gd","systems/TerritoryTurn.gd","systems/Combat.gd","systems/Economy.gd","systems/TickSystem.gd","systems/LevelDirector.gd"]:
		hashes[file] = FileAccess.get_sha256("res://scripts/"+file)
	var record: Dictionary = {"seed":1337,"board":[state.width,state.height],"engine":Engine.get_version_info().string,"source_sha256":hashes,"max_turn_ms":max_ms,"failed_actions":failed,"limits":"One fixed-layout all-AI Territory War match using normal global turns; stops on a terminal outcome or after 40 turns. The stored seed does not vary this map. No human balance or visual acceptance.","turns":rows}
	FileAccess.open("res://docs/validation/territory_war.json",FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	quit(0 if failed==0 else 1)

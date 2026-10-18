extends SceneTree

# Reproducible campaign entry; optional equal-budget 2v2 test fixture.
func _initialize() -> void:
	call_deferred("_launch")

func _launch() -> void:
	root.size = Vector2i(1600,900)
	root.title = "Ooze Tactics - Living Colony Gameplay"
	var flow: Node = root.get_node("RunFlow")
	flow.graphics_style = "colony"
	flow.begin_run()
	flow.run_seed = 1337
	change_scene_to_file("res://scenes/Main.tscn")
	await scene_changed
	if "--2v2" in OS.get_cmdline_user_args():
		var main: Node = current_scene
		main.state = preload("res://tools/ai/PressureScenario.gd").build(1337)
		flow.current_level = 3
		main._initialize_owner_display_numbers()
		main._setup_actor_cycle()
		main._refresh_enemy_intents()
		main._update_board_layout(true)
		main._recompute_action_context()
		main._refresh_ui()
		main._queue_world_redraw()
		main._set_status("2v2 pressure test: equal budgets; three actions per colony.",8.0)
		root.title = "Ooze Tactics - 2v2 Pressure Test"
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/validation/colony_2v2_v1.png" if "--2v2" in OS.get_cmdline_user_args() else "res://docs/validation/colony_gameplay_v1.png"
		var error: Error = root.get_texture().get_image().save_png(path)
		print("Colony gameplay capture: ", error_string(error))
		quit(0 if error==OK else 1)

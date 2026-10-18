extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600,900)
	change_scene_to_file("res://scenes/MainMenu.tscn")
	await scene_changed
	await process_frame
	var launch: Button = current_scene.territory_button
	assert(Rect2(Vector2.ZERO,Vector2(root.size)).encloses(launch.get_global_rect()),"Territory War fits in the main menu")
	_mouse(launch.get_global_rect().get_center(),true)
	_mouse(launch.get_global_rect().get_center(),false)
	await scene_changed
	await process_frame
	var game: Control = current_scene
	var original_count: int = game.state.blocks.size()
	var map_image: Image = game.minimap.map_texture.get_image()
	assert(map_image.get_pixel(35,42)!=map_image.get_pixel(224,42),"Minimap texture preserves faction ownership")
	var painted_state: GameState = game.minimap.painted_state
	game.focus_tile(Vector2i(35,42),true)
	assert(game.minimap.painted_state==painted_state,"Camera motion reuses the map snapshot")
	var start: Vector2 = game.view.global_position+game.view.project(Vector2(28,35))
	var end: Vector2 = game.view.global_position+game.view.project(Vector2(43,50))
	_mouse(start,true)
	var drag := InputEventMouseMotion.new()
	drag.position = end
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(drag)
	_mouse(end,false)
	assert(game.selection==Rect2i(28,35,16,16),"Dragging on the actual board selects the group")
	var gather_button: Button = game.buttons[4]
	_mouse(gather_button.get_global_rect().get_center(),true)
	_mouse(gather_button.get_global_rect().get_center(),false)
	assert(game.preview.size()==1,"Group Gather chooses only the well")
	assert(game.detail.position.y+game.detail.get_minimum_size().y<game.buttons[5].position.y,"Instructions fit above End Turn")
	game.selection = Rect2i()
	game._new_front()
	game._select_role("basic")
	game._queue_order(Vector2i(75,42),Rect2i(),true)
	assert(game.orders.size()==2 and game.preview.size()>10,"Front orders expose many planned changes (orders=%d, preview=%d)" % [game.orders.size(),game.preview.size()])
	assert(game.state.blocks.size()==original_count,"UI preview preserves simulation")
	await game._end_turn()
	assert(game.state.turn_index==1 and game.orders.size()==1 and game.orders[0].tile_type=="gather","End Turn resolves once and keeps the unfinished well front active")
	assert(game.state.last_resolution_report.failed_actions.is_empty(),"UI orders resolve legally")
	assert(game.state.blocks.size()>original_count,"The player and AI grow in normal batched play")
	assert(game.minimap.painted_state==game.state and game.minimap.painted_state!=painted_state,"A resolved turn refreshes the minimap snapshot")
	game._overview()
	assert(game.view.viewport_to_tile(game.view.project(Vector2(130,80)))==Vector2i(130,80),"Large-map picking agrees at overview")
	game.focus_tile(Vector2i(35,42),true)
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name()=="headless":
			printerr("A rendered capture requires a display; tests completed headlessly")
			quit(1)
			return
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/validation/territory_gameplay_v1.png")==OK)
	print("TERRITORY GAMEPLAY CHECKS PASSED")
	quit()

func _mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event)

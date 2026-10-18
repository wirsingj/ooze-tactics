extends SceneTree

const VIEW = preload("res://scripts/ui/ColonyRenderer.gd")
const ART = preload("res://scripts/ui/ColonyArt.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _run() -> void:
	var flow: Node = root.get_node("RunFlow")
	flow.graphics_style = "colony"
	flow.begin_run()
	flow.run_seed = 1337
	var main: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.colony_enabled and not main._use_3d_world(), "Campaign selects colony presentation")
	var view: Control = main.colony_view
	var state: GameState = main.state
	var advance: Vector2 = view.project(Vector2(8,5))-view.project(Vector2(3,5))
	check(advance.x>0 and advance.y<0, "Campaign advance projects bottom-left to top-right")
	for y in range(state.height):
		for x in range(state.width):
			var tile := Vector2i(x,y)
			var screen: Vector2 = view.global_position+view.project(Vector2(tile))
			check(main._mouse_to_tile(screen)==tile, "Campaign picking must agree with projected tile %s" % tile)
	var outside: Vector2 = main.board_clip_rect.position-Vector2.ONE
	check(main._mouse_to_tile(outside)==Vector2i(-1,-1), "HUD/outside clicks do not select board tiles")
	var anchor: Vector2 = view.project(Vector2(5,5))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	view.handle_camera_input(wheel,anchor,true)
	check(view.project(Vector2(5,5)).distance_to(anchor)<0.01, "Zoom stays under pointer")
	view.pan += Vector2(30,-15)
	view._layout()
	check(view.viewport_to_tile(view.project(Vector2(6,5)))==Vector2i(6,5), "Picking survives zoom and pan")
	var zoom_before: float = view.zoom
	main._queue_world_redraw()
	check(is_equal_approx(view.zoom,zoom_before), "Hover/context refresh preserves camera")

	var fixture := GameState.new()
	fixture.width = 14
	fixture.height = 12
	fixture.run_seed = 2026
	fixture.add_owner(2,"Enemy",20)
	fixture.add_owner(3,"Ally",20,GameState.TEAM_PLAYER)
	fixture.add_owner(4,"Enemy 2",20)
	fixture.set_walls([[12,10]])
	for y in range(2,8):
		for x in range(2,9):
			fixture.spawn_block(1,Vector2i(x,y),x==2 and y==2,8,"basic")
	var ranged: int = fixture.spawn_block(1,Vector2i(9,5),false,8,"ranged")
	fixture.spawn_block(2,Vector2i(10,5),true,8,"basic")
	fixture.spawn_block(3,Vector2i(4,9),true,8,"basic")
	fixture.spawn_block(4,Vector2i(9,9),true,8,"basic")
	view.zoom = 1.0
	view.pan = Vector2.ZERO
	var original: String = str(fixture.blocks)+str(fixture.players)
	view.sync_world(fixture,{})
	view._process(0.1)
	check(view.cells.size()==46, "All occupied cells render beyond the study's 32-cell limit")
	check(view.map_image.get_pixel(12,10).a==0.0, "Blocked terrain masks tissue")
	check(view.map_image.get_pixel(9,5).r!=view.map_image.get_pixel(10,5).r, "Hostile tissue uses separate ownership")
	check(ART.hue(fixture,1)!=ART.hue(fixture,3) and ART.hue(fixture,2)!=ART.hue(fixture,4), "Allies and enemies retain distinct palettes")
	check(str(fixture.blocks)+str(fixture.players)==original, "Rendering and animation do not mutate simulation")
	var grown: GameState = fixture.copy_state()
	var new_id: int = grown.spawn_block(1,Vector2i(8,8),false,8,"gather")
	view.sync_world(grown,{})
	check(view.cells[Vector2i(8,8)].fill==0.0, "New tissue begins as growth")
	view._process(0.2)
	check(view.cells[Vector2i(8,8)].fill>0.0 and view.cells[Vector2i(8,8)].fill<1.0, "Growth interpolates")
	view._process(1.0)
	grown.blocks[new_id].hp = 0
	grown.remove_dead_blocks()
	view.sync_world(grown,{})
	check(view.cells.has(Vector2i(8,8)), "Lost tissue survives briefly for retreat")
	view._process(1.0)
	check(not view.cells.has(Vector2i(8,8)) and not view.organs.has(new_id), "Retreat removes retired tissue and organ")
	var full_state: GameState = fixture.copy_state()
	var compact_state: GameState = fixture.copy_state()
	var full: Dictionary = Combat.new().resolve_with_report([],full_state,false,false)
	var compact: Dictionary = Combat.new().resolve_with_report([],compact_state,false,true)
	check(str(full_state.blocks)==str(compact_state.blocks), "Attack reporting does not change combat outcomes")
	check(not compact.has("attack_events"), "Compact evaluation omits presentation events")
	var matching: Array = full.attack_events.filter(func(e): return e.source_id==ranged)
	check(matching.size()==1 and matching[0].from==Vector2i(9,5) and matching[0].to==Vector2i(10,5), "Reported shot comes from the actual targeting decision")
	view.sync_world(full_state,{})
	view.show_resolution(full)
	check(not view.strikes.is_empty(), "Actual attacks reach the live presentation")
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("COLONY CHECKS PASSED: campaign picking, camera, ownership, growth/loss, read-only rendering, actual combat events")
	else:
		for failure in failures:
			printerr(failure)
	quit(0 if failures.is_empty() else 1)

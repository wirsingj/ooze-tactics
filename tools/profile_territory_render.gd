extends SceneTree

# Real rendered frames, including canvas submission. Headless timings cannot
# catch draw-call bottlenecks. This helper never changes saved game settings.
var game: Control
var rows: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Rendering profile requires a display; omit --headless")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var capture_size := Vector2i(1600,900)
	if args.has("--size") and args.find("--size")+1<args.size():
		var dimensions: PackedStringArray = args[args.find("--size")+1].split("x")
		if dimensions.size()==2:
			capture_size = Vector2i(int(dimensions[0]),int(dimensions[1]))
	root.size = capture_size
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	change_scene_to_file("res://scenes/TerritoryWar.tscn")
	await scene_changed
	game = current_scene
	var turns: int = 0
	if args.has("--turns") and args.find("--turns")+1<args.size():
		turns = clampi(int(args[args.find("--turns")+1]),0,30)
	for i in range(turns):
		var result: Dictionary = game.turn.resolve(game.state,game.turn.ai_orders(game.state,true))
		game.state = result.state
		if i%5==4:
			print("Prepared turn %d: %d tiles" % [game.state.turn_index,game.state.blocks.size()])
		if result.outcome.status!="ongoing":
			break
		await process_frame
	if turns>0:
		game._refresh()
		game.focus_tile(Vector2i(48,42),true)
	await _sample("opening_idle",false)
	game.view.tissue.hide()
	await _sample("opening_without_tissue",false)
	game.view.tissue.show()
	_hide_terrain()
	await _sample("opening_without_terrain",false)
	_show_terrain()
	game.view.zoom = 2.0
	game.view.pan = Vector2.ZERO
	game.view._layout()
	await _sample("mid_zoom_idle",false)
	_hide_terrain()
	await _sample("mid_zoom_without_terrain",false)
	_show_terrain()
	await _sample("mid_zoom_pan",true)
	game._overview()
	await _sample("overview_idle",false)
	await _sample("overview_pan",true)
	var out: String = "res://docs/validation/territory_render_profile.json"
	if args.has("--out") and args.find("--out")+1<args.size():
		out = args[args.find("--out")+1]
	var hashes: Dictionary = {}
	for path in ["scripts/ui/ColonyRenderer.gd","scripts/ui/TerritoryController.gd","assets/shaders/colony_floor.gdshader","assets/shaders/colony_board.gdshader","tools/profile_territory_render.gd"]:
		hashes[path] = FileAccess.get_sha256("res://"+path)
	var record := {"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":[capture_size.x,capture_size.y],"vsync":false,"turn":game.state.turn_index,"tiles":game.state.blocks.size(),"source_sha256":hashes,"limits":"Short uncapped desktop samples at a fixed turn; opening_idle means the first focus view (central front for developed states). Isolation rows deliberately hide one layer. Wall-frame intervals are authoritative; asynchronous render timers can lag very slow frames. No cross-device or full-match performance claim.","samples":rows,"failures":failures}
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	if args.has("--capture"):
		if args.has("--overview"):
			game._overview()
		else:
			game.focus_tile(Vector2i(48,42) if turns>0 else Vector2i(35,42),true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.trim_suffix(".json")+".png")
	quit(0 if failures.is_empty() else 1)

func _hide_terrain() -> void:
	if game.view.get("terrain")!=null:
		game.view.terrain.hide()
	else:
		RenderingServer.canvas_item_clear(game.view.get_canvas_item())

func _show_terrain() -> void:
	if game.view.get("terrain")!=null:
		game.view.terrain.show()
	else:
		game.view.queue_redraw()

func _sample(label: String, pan_camera: bool) -> void:
	await create_timer(0.3).timeout
	var samples: Array[float] = []
	var cpu: float = 0
	var gpu: float = 0
	var draws: float = 0
	var started: int = Time.get_ticks_usec()
	var previous: int = started
	while Time.get_ticks_usec()-started<1800000:
		if pan_camera:
			game.view.pan.x += 2 if samples.size()%80<40 else -2
			game.view._layout()
			game.minimap.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		samples.append(float(now-previous)/1000.0)
		previous = now
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	samples.sort()
	var mean: float = float(previous-started)/1000.0/samples.size()
	var row := {"phase":label,"frames":samples.size(),"mean_ms":mean,"fps":1000.0/mean,"p50_ms":samples[samples.size()/2],"p95_ms":samples[mini(samples.size()-1,int(samples.size()*0.95))],"render_cpu_ms":cpu/samples.size(),"render_gpu_ms":gpu/samples.size(),"draw_calls":draws/samples.size()}
	if not label.contains("without") and row.draw_calls>2000:
		failures.append("Excessive canvas submissions in "+label)
	rows.append(row)
	print(JSON.stringify(row))

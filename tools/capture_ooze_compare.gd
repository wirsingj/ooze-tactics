extends SceneTree

const DEFAULT_OUT_PATH: String = "res://tools/visual_compare/capture.png"
const DEFAULT_TURNS: int = 18

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = _parse_options()
	var out_path: String = String(options.get("out_path", DEFAULT_OUT_PATH))
	var turns_to_run: int = int(options.get("turns_to_run", DEFAULT_TURNS))
	var camera_yaw: float = float(options.get("camera_yaw", 0.0))
	var camera_pitch: float = float(options.get("camera_pitch", 48.0))
	var camera_distance: float = float(options.get("camera_distance", 26.0))

	var run_flow: Node = root.get_node_or_null("/root/RunFlow")
	if run_flow == null or not run_flow.has_method("set_graphics_style"):
		push_error("RunFlow.set_graphics_style API unavailable")
		quit(9)
		return
	run_flow.call("set_graphics_style", "3d")
	if run_flow.has_method("begin_dev_run"):
		run_flow.call("begin_dev_run", 1, 1, false, true)

	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	root.add_child(packed.instantiate())
	var controller: Node = root.get_node_or_null("Main")
	if controller == null:
		push_error("Main controller node not found")
		quit(2)
		return

	var world_viewport: SubViewport = root.get_node_or_null("Main/CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport")
	var world_root: Node = root.get_node_or_null("Main/CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport/World3DRoot")
	if world_viewport == null or world_root == null:
		push_error("World3D viewport/root not found")
		quit(3)
		return

	var ready: bool = await _wait_until_ready(controller)
	if not ready:
		push_error("Scene did not reach render-ready state")
		quit(4)
		return

	await _advance_turns(controller, turns_to_run)

	if world_root.has_method("validate_wall_blocking_contract"):
		var wall_check: Dictionary = world_root.call("validate_wall_blocking_contract")
		print("wall_blocking_ok=%s" % str(wall_check.get("ok", false)))
		if not bool(wall_check.get("ok", false)):
			push_error("Wall blocking contract failed: %s" % JSON.stringify(wall_check))
			quit(10)
			return
	if world_root.has_method("validate_render_truth_contract"):
		var render_truth: Dictionary = world_root.call("validate_render_truth_contract")
		print("render_truth_ok=%s" % str(render_truth.get("ok", false)))
		if not bool(render_truth.get("ok", false)):
			push_error("Render truth contract failed: %s" % JSON.stringify(render_truth))
			quit(11)
			return
	if world_root.has_method("get_performance_counters"):
		print("world3d_perf_counters=%s" % JSON.stringify(world_root.call("get_performance_counters")))
	print("board_topology_cache_stats=%s" % JSON.stringify(BoardTopology.cache_stats()))

	if world_root.has_method("apply_capture_camera_preset"):
		world_root.call("apply_capture_camera_preset", camera_yaw, camera_pitch, camera_distance)
	controller.call("_queue_world_redraw")
	for _i in range(8):
		await process_frame

	RenderingServer.force_draw(false)
	await process_frame

	var image: Image = _capture_image(world_viewport)
	if image == null or image.is_empty():
		push_error("Captured image is empty")
		quit(6)
		return

	var abs_out: String = ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var save_err: int = image.save_png(abs_out)
	if save_err != OK:
		push_error("Failed to save capture: %s (err=%d)" % [abs_out, save_err])
		quit(7)
		return
	if not _file_has_bytes(abs_out):
		push_error("Capture file was saved but is empty: %s" % abs_out)
		quit(8)
		return

	_print_capture_metadata(abs_out)
	quit(0)

func _parse_options() -> Dictionary:
	var options: Dictionary = {
		"out_path": DEFAULT_OUT_PATH,
		"turns_to_run": DEFAULT_TURNS,
		"camera_yaw": 0.0,
		"camera_pitch": 48.0,
		"camera_distance": 26.0,
	}
	var args: Array = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size():
			options["out_path"] = String(args[i + 1])
		elif args[i] == "--turns" and i + 1 < args.size():
			options["turns_to_run"] = maxi(1, int(args[i + 1]))
		elif args[i] == "--yaw" and i + 1 < args.size():
			options["camera_yaw"] = float(args[i + 1])
		elif args[i] == "--pitch" and i + 1 < args.size():
			options["camera_pitch"] = float(args[i + 1])
		elif args[i] == "--distance" and i + 1 < args.size():
			options["camera_distance"] = maxf(4.0, float(args[i + 1]))
	return options

func _wait_until_ready(controller: Node) -> bool:
	for _i in range(260):
		await process_frame
		var state_obj: Object = controller.get("state")
		if state_obj == null:
			continue
		var width: int = int(state_obj.get("width"))
		var height: int = int(state_obj.get("height"))
		var blocks: Dictionary = state_obj.get("blocks")
		if width <= 0 or height <= 0 or blocks.is_empty():
			continue
		if not bool(controller.call("_use_3d_world")):
			continue
		return true
	return false

func _advance_turns(controller: Node, turns_to_run: int) -> void:
	var actor_counts: Dictionary = {}
	for _turn in range(turns_to_run):
		if bool(controller.get("run_over")):
			break
		var spectator_mode: bool = bool(controller.call("_is_spectator_mode"))
		if spectator_mode:
			controller.call("_ensure_active_actor_for_spectator_turn")
			var acting_owner_id: int = int(controller.get("active_owner_id"))
			controller.call("_run_next_spectator_turn")
			if controller.has_method("clear_turn_pulse_for_capture"):
				controller.call("clear_turn_pulse_for_capture")
			controller.call("_advance_active_actor")
			var actor_key: String = str(acting_owner_id)
			actor_counts[actor_key] = int(actor_counts.get(actor_key, 0)) + 1
		else:
			controller.call("_resolve_turn")
			if controller.has_method("clear_turn_pulse_for_capture"):
				controller.call("clear_turn_pulse_for_capture")
		controller.call("_queue_world_redraw")
		await process_frame
	if not actor_counts.is_empty():
		print("capture_actor_counts=", JSON.stringify(actor_counts))

func _file_has_bytes(abs_path: String) -> bool:
	var file: FileAccess = FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return false
	return file.get_length() > 0

func _capture_image(world_viewport: SubViewport) -> Image:
	if world_viewport != null:
		var world_tex: Texture2D = world_viewport.get_texture()
		if world_tex != null and world_tex.get_rid().is_valid():
			var world_image: Image = world_tex.get_image()
			if world_image != null and not world_image.is_empty():
				return world_image
	var root_tex: Texture2D = root.get_texture()
	if root_tex != null and root_tex.get_rid().is_valid():
		var root_image: Image = root_tex.get_image()
		if root_image != null and not root_image.is_empty():
			return root_image
	return null

func _print_capture_metadata(abs_path: String) -> void:
	var sha256: String = FileAccess.get_sha256(abs_path)
	var modified_unix: int = int(FileAccess.get_modified_time(abs_path))
	print("frame_abs_path=%s" % abs_path)
	print("frame_sha256=%s" % sha256)
	print("frame_last_write_utc=%s" % _format_utc_timestamp(modified_unix))

func _format_utc_timestamp(unix_time: int) -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		int(dt.get("year", 1970)),
		int(dt.get("month", 1)),
		int(dt.get("day", 1)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]

extends SceneTree

const DEFAULT_OUT_PATH: String = "res://tools/visual_compare/capture.png"
const DEFAULT_TURNS: int = 18

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var options: Dictionary = _parse_options()
	var out_path: String = String(options.get("out_path", DEFAULT_OUT_PATH))
	var turns_to_run: int = int(options.get("turns_to_run", DEFAULT_TURNS))

	var run_flow: Node = root.get_node_or_null("/root/RunFlow")
	if run_flow != null:
		if run_flow.has_method("set_graphics_style"):
			run_flow.call("set_graphics_style", "3d")
		else:
			run_flow.set("graphics_style", "3d")

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

	if world_root.has_method("apply_capture_camera_preset"):
		world_root.call("apply_capture_camera_preset")
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
	}
	var args: Array = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size():
			options["out_path"] = String(args[i + 1])
		elif args[i] == "--turns" and i + 1 < args.size():
			options["turns_to_run"] = maxi(1, int(args[i + 1]))
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
	for _turn in range(turns_to_run):
		if bool(controller.get("run_over")):
			break
		controller.call("_resolve_turn")
		if controller.has_method("clear_turn_pulse_for_capture"):
			controller.call("clear_turn_pulse_for_capture")
		controller.call("_queue_world_redraw")
		await process_frame

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

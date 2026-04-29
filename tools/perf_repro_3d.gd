extends SceneTree

const DEFAULT_TURNS: int = 20
const CHECKPOINTS: Array[int] = [1, 5, 10, 20]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var turns_to_run: int = _parse_turns()
	var run_flow: Node = root.get_node_or_null("/root/RunFlow")
	if run_flow == null or not run_flow.has_method("set_graphics_style"):
		push_error("RunFlow.set_graphics_style API unavailable")
		quit(9)
		return
	run_flow.call("set_graphics_style", "3d")

	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return
	root.add_child(packed.instantiate())

	var controller: Node = root.get_node_or_null("Main")
	var world_root: Node = root.get_node_or_null("Main/CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport/World3DRoot")
	if controller == null or world_root == null:
		push_error("Main controller or World3DRoot not found")
		quit(2)
		return
	if not await _wait_until_ready(controller):
		push_error("Scene did not reach 3D-ready state")
		quit(3)
		return

	if world_root.has_method("reset_performance_counters"):
		world_root.call("reset_performance_counters")
	_print_checkpoint("turn_0", controller, world_root)

	for turn in range(1, turns_to_run + 1):
		if bool(controller.get("run_over")):
			break
		controller.call("_resolve_turn")
		if controller.has_method("clear_turn_pulse_for_capture"):
			controller.call("clear_turn_pulse_for_capture")
		controller.call("_queue_world_redraw")
		for _i in range(3):
			await process_frame
		if CHECKPOINTS.has(turn) or turn == turns_to_run:
			_print_checkpoint("turn_%d" % turn, controller, world_root)

	_print_camera_motion_probe(controller, world_root)
	quit(0)

func _parse_turns() -> int:
	var turns: int = DEFAULT_TURNS
	var args: Array = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--turns" and i + 1 < args.size():
			turns = maxi(1, int(args[i + 1]))
	return turns

func _wait_until_ready(controller: Node) -> bool:
	for _i in range(260):
		await process_frame
		var state_obj: Object = controller.get("state")
		if state_obj == null:
			continue
		if not bool(controller.call("_use_3d_world")):
			continue
		return true
	return false

func _print_checkpoint(label: String, controller: Node, world_root: Node) -> void:
	var state_obj: Object = controller.get("state")
	var block_count: int = 0
	var turn_count: int = 0
	if state_obj != null:
		var blocks: Dictionary = state_obj.get("blocks")
		block_count = blocks.size()
		turn_count = int(state_obj.get("turn_index")) if state_obj.get("turn_index") != null else 0
	var counters: Dictionary = {}
	if world_root.has_method("get_performance_counters"):
		counters = world_root.call("get_performance_counters")
	print("perf_checkpoint=%s turn=%d blocks=%d counters=%s" % [label, turn_count, block_count, JSON.stringify(counters)])

func _print_camera_motion_probe(controller: Node, world_root: Node) -> void:
	if world_root.has_method("reset_performance_counters"):
		world_root.call("reset_performance_counters")
	var before: Dictionary = world_root.call("get_performance_counters") if world_root.has_method("get_performance_counters") else {}
	for _i in range(60):
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.relative = Vector2(5.0, 2.0)
		world_root.call("handle_camera_input", motion, Vector2(400.0, 300.0), true)
		world_root.call("tick_visual", 1.0 / 60.0)
	var after: Dictionary = world_root.call("get_performance_counters") if world_root.has_method("get_performance_counters") else {}
	print("perf_camera_probe_before=%s" % JSON.stringify(before))
	print("perf_camera_probe_after=%s" % JSON.stringify(after))

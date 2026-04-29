extends SceneTree

const DEFAULT_TURNS: int = 100
const CHECKPOINTS: Array[int] = [1, 20, 40, 60, 80, 100]

var _style: String = "3d"
var _turn_target: int = DEFAULT_TURNS
var _speed: float = 8.0
var _dynamic_rendering: bool = true
var _growth_animation: bool = true
var _autoplay: bool = true
var _player_team_size: int = 1
var _enemy_team_size: int = 1
var _run_seed: int = 1337
var _frames: int = 0
var _frame_time_accum_ms: float = 0.0
var _frame_time_max_ms: float = 0.0
var _recent_frame_times_ms: Array[float] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_parse_args()
	_prepare_run_flow()
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return
	root.add_child(packed.instantiate())

	var controller: Node = root.get_node_or_null("Main")
	if controller == null:
		push_error("Main controller not found")
		quit(2)
		return
	if not await _wait_until_ready(controller):
		push_error("Scene did not reach ready state")
		quit(3)
		return

	controller.call("_set_turn_speed", _speed)
	if not _autoplay:
		controller.set("spectator_paused", true)
	if controller.get("ai") != null and controller.get("ai").has_method("set_profiling_enabled"):
		controller.get("ai").call("set_profiling_enabled", true)
	if controller.has_method("reset_performance_counters"):
		controller.call("reset_performance_counters")

	var world_root: Node = _world_root(controller)
	if world_root != null:
		if world_root.has_method("set_perf_dynamic_rendering_enabled"):
			world_root.call("set_perf_dynamic_rendering_enabled", _dynamic_rendering)
		if world_root.has_method("set_perf_growth_animation_enabled"):
			world_root.call("set_perf_growth_animation_enabled", _growth_animation)
		if world_root.has_method("reset_performance_counters"):
			world_root.call("reset_performance_counters")

	if BoardTopology != null:
		BoardTopology.clear_cache()

	_print_checkpoint("turn_0", controller, world_root)
	if not _autoplay:
		await _run_idle_probe(controller, world_root)
		quit(0)
		return

	var checkpoint_index: int = 0
	var max_frames: int = 20000
	while _frames < max_frames:
		var turn_index: int = _turn_index(controller)
		while checkpoint_index < CHECKPOINTS.size() and turn_index >= CHECKPOINTS[checkpoint_index]:
			_print_checkpoint("turn_%d" % CHECKPOINTS[checkpoint_index], controller, world_root)
			checkpoint_index += 1
		if turn_index >= _turn_target:
			break
		if bool(controller.get("run_over")):
			print("perf_run_over_at_turn=%d" % turn_index)
			break
		await _profile_one_frame()

	_print_checkpoint("final", controller, world_root)
	quit(0)

func _parse_args() -> void:
	var args: Array = OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg: String = String(args[i])
		if arg == "--style" and i + 1 < args.size():
			_style = String(args[i + 1]).to_lower()
		elif arg == "--turns" and i + 1 < args.size():
			_turn_target = maxi(1, int(args[i + 1]))
		elif arg == "--speed" and i + 1 < args.size():
			_speed = clampf(float(args[i + 1]), 1.0, 8.0)
		elif arg == "--dynamic" and i + 1 < args.size():
			_dynamic_rendering = _arg_bool(args[i + 1])
		elif arg == "--growth-animation" and i + 1 < args.size():
			_growth_animation = _arg_bool(args[i + 1])
		elif arg == "--autoplay" and i + 1 < args.size():
			_autoplay = _arg_bool(args[i + 1])
		elif arg == "--player-team" and i + 1 < args.size():
			_player_team_size = clampi(int(args[i + 1]), 1, 4)
		elif arg == "--enemy-team" and i + 1 < args.size():
			_enemy_team_size = clampi(int(args[i + 1]), 1, 4)
		elif arg == "--seed" and i + 1 < args.size():
			_run_seed = int(args[i + 1])

func _arg_bool(value: Variant) -> bool:
	var text: String = String(value).to_lower()
	return text == "1" or text == "true" or text == "yes" or text == "on"

func _prepare_run_flow() -> void:
	var run_flow: Node = root.get_node_or_null("/root/RunFlow")
	if run_flow == null:
		return
	if run_flow.has_method("set_graphics_style"):
		run_flow.call("set_graphics_style", _style)
	if run_flow.has_method("begin_dev_run"):
		run_flow.call("begin_dev_run", _player_team_size, _enemy_team_size, false, true)
	run_flow.set("run_seed", _run_seed)

func _wait_until_ready(controller: Node) -> bool:
	for _i in range(360):
		await process_frame
		var state_obj: Object = controller.get("state")
		if state_obj == null:
			continue
		if _style == "3d" and not bool(controller.call("_use_3d_world")):
			continue
		return true
	return false

func _run_idle_probe(controller: Node, world_root: Node) -> void:
	for _i in range(600):
		await _profile_one_frame()
	_print_checkpoint("idle_600_frames", controller, world_root)

func _profile_one_frame() -> void:
	var start_usec: int = Time.get_ticks_usec()
	await process_frame
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	_frames += 1
	_frame_time_accum_ms += elapsed_ms
	_frame_time_max_ms = maxf(_frame_time_max_ms, elapsed_ms)
	_recent_frame_times_ms.append(elapsed_ms)
	if _recent_frame_times_ms.size() > 120:
		_recent_frame_times_ms.pop_front()

func _print_checkpoint(label: String, controller: Node, world_root: Node) -> void:
	var state_obj: Object = controller.get("state")
	var blocks: int = 0
	var logs: int = 0
	if state_obj != null:
		blocks = (state_obj.get("blocks") as Dictionary).size()
		logs = (state_obj.get("last_log") as Array).size()
	var payload: Dictionary = {
		"label": label,
		"style": _style,
		"turn": _turn_index(controller),
		"frames": _frames,
		"blocks": blocks,
		"last_log_entries": logs,
		"avg_frame_wall_ms": _frame_time_accum_ms / maxf(1.0, float(_frames)),
		"max_frame_wall_ms": _frame_time_max_ms,
		"recent_120_avg_frame_wall_ms": _recent_average(),
		"scene_counts": _scene_counts(controller),
		"controller": controller.call("get_performance_counters") if controller.has_method("get_performance_counters") else {},
		"world3d": world_root.call("get_performance_counters") if world_root != null and world_root.has_method("get_performance_counters") else {},
		"ai": controller.get("ai").call("get_profiling_snapshot") if controller.get("ai") != null and controller.get("ai").has_method("get_profiling_snapshot") else {},
		"board_topology": BoardTopology.cache_stats(),
	}
	print("perf_x8_checkpoint=%s" % JSON.stringify(payload))

func _recent_average() -> float:
	if _recent_frame_times_ms.is_empty():
		return 0.0
	var total: float = 0.0
	for value in _recent_frame_times_ms:
		total += value
	return total / float(_recent_frame_times_ms.size())

func _turn_index(controller: Node) -> int:
	var state_obj: Object = controller.get("state")
	if state_obj == null:
		return 0
	return int(state_obj.get("turn_index"))

func _world_root(controller: Node) -> Node:
	return controller.get_node_or_null("CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport/World3DRoot")

func _scene_counts(root_node: Node) -> Dictionary:
	var counts: Dictionary = {
		"total_nodes": 0,
		"timer_nodes": 0,
		"tween_nodes": 0,
		"animation_players": 0,
		"mesh_instances_3d": 0,
		"multi_mesh_instances_3d": 0,
		"lights_3d": 0,
		"control_nodes": 0,
		"signal_connections": 0,
	}
	_count_scene_recursive(root_node, counts)
	return counts

func _count_scene_recursive(node: Node, counts: Dictionary) -> void:
	if node == null:
		return
	counts["total_nodes"] = int(counts["total_nodes"]) + 1
	if node is Timer:
		counts["timer_nodes"] = int(counts["timer_nodes"]) + 1
	if node is AnimationPlayer:
		counts["animation_players"] = int(counts["animation_players"]) + 1
	if node is MeshInstance3D:
		counts["mesh_instances_3d"] = int(counts["mesh_instances_3d"]) + 1
	if node is MultiMeshInstance3D:
		counts["multi_mesh_instances_3d"] = int(counts["multi_mesh_instances_3d"]) + 1
	if node is Light3D:
		counts["lights_3d"] = int(counts["lights_3d"]) + 1
	if node is Control:
		counts["control_nodes"] = int(counts["control_nodes"]) + 1
	counts["signal_connections"] = int(counts["signal_connections"]) + _connection_count(node)
	for child in node.get_children():
		_count_scene_recursive(child, counts)

func _connection_count(node: Node) -> int:
	var total: int = 0
	for signal_info in node.get_signal_list():
		var signal_name: StringName = signal_info.get("name", &"")
		total += node.get_signal_connection_list(signal_name).size()
	return total

extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out_path := "res://tools/visual_compare/live_imported_lategame.png"
	var turns_to_run: int = 36
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
		if args[i] == "--turns" and i + 1 < args.size():
			turns_to_run = maxi(1, int(args[i + 1]))

	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := packed.instantiate()
	root.add_child(main)

	var controller: Node = root.get_node_or_null("Main")
	if controller == null:
		push_error("Main controller node not found")
		quit(2)
		return

	var world_root: Node = root.get_node_or_null("Main/CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport/World3DRoot")
	if world_root == null:
		push_error("World3D root not found")
		quit(3)
		return

	var ready: bool = false
	for _i in range(260):
		await process_frame
		var state_obj: Object = controller.get("state")
		if state_obj == null:
			continue
		var width: int = int(state_obj.get("width"))
		var height: int = int(state_obj.get("height"))
		if width <= 0 or height <= 0:
			continue
		var blocks: Dictionary = state_obj.get("blocks")
		if blocks.is_empty():
			continue
		ready = true
		break
	if not ready:
		push_error("Scene did not reach render-ready state")
		quit(4)
		return

	# Seed early expansion so the turn simulation reaches readable mid/late board states.
	var state_obj: Object = controller.get("state")
	if state_obj != null:
		var owner_ids: Array = state_obj.get("players").keys()
		owner_ids.sort()
		for owner_id_variant in owner_ids:
			var owner_id: int = int(owner_id_variant)
			var core: Dictionary = state_obj.call("get_core", owner_id)
			if core.is_empty():
				continue
			var center: Vector2i = core.get("pos", Vector2i(-1, -1))
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var tile := center + Vector2i(dx, dy)
					if abs(dx) + abs(dy) > 4:
						continue
					if tile == center:
						continue
					if not bool(state_obj.call("is_inside", tile)):
						continue
					if bool(state_obj.call("is_blocked", tile)):
						continue
					if bool(state_obj.call("is_reclaim_blocked", tile)):
						continue
					var existing: Dictionary = state_obj.call("get_block_at", tile)
					if not existing.is_empty():
						continue
					state_obj.call("spawn_block", owner_id, tile, false, 10, "basic")
		controller.call("_queue_world_redraw")
	for _j in range(16):
		await process_frame

	# Fast-forward actual live turn resolution.
	for _turn in range(turns_to_run):
		if bool(controller.get("run_over")):
			break
		controller.call("_resolve_turn")
		controller.set("pulse_active", false)
		controller.set("pulse_batches", [])
		controller.set("pulse_batch_index", -1)
		controller.set("pulse_batch_timer", 0.0)
		controller.set("pulse_gap_timer", 0.0)
		controller.set("pulse_finish_pause", 0.0)
		controller.call("_queue_world_redraw")
		await process_frame

	# Stable framing for comparisons.
	world_root.set("_camera_pan_offset", Vector3.ZERO)
	world_root.set("_camera_yaw", deg_to_rad(-34.0))
	world_root.set("_camera_yaw_target", deg_to_rad(-34.0))
	world_root.set("_camera_pitch", deg_to_rad(48.0))
	world_root.set("_camera_pitch_target", deg_to_rad(48.0))
	world_root.set("_camera_distance", 26.0)
	world_root.set("_camera_distance_target", 26.0)
	world_root.set("_camera_initialized", true)
	world_root.call("_update_camera_transform", true)

	for _k in range(10):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame

	var tex: Texture2D = root.get_texture()
	if tex == null:
		push_error("Root viewport texture unavailable")
		quit(5)
		return
	var image: Image = tex.get_image()
	if image == null or image.is_empty():
		push_error("Captured image is empty")
		quit(6)
		return

	var abs_out := ProjectSettings.globalize_path(out_path)
	DirAccess.make_dir_recursive_absolute(abs_out.get_base_dir())
	var err := image.save_png(abs_out)
	if err != OK:
		push_error("Failed to save capture: %s (err=%d)" % [abs_out, err])
		quit(7)
		return

	var final_state: Object = controller.get("state")
	var turn_index: int = int(final_state.get("turn_index")) if final_state != null else -1
	print("Saved late capture -> %s (turn_index=%d)" % [abs_out, turn_index])
	quit(0)

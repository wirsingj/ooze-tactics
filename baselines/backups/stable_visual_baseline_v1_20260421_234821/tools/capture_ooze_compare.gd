extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var out_path := ""
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size():
			out_path = args[i + 1]
	if out_path.is_empty():
		out_path = "res://tools/visual_compare/capture.png"

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
		quit(6)
		return

	var world_vp: SubViewport = root.get_node_or_null("Main/CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport")
	var world_root: Node = root.get_node_or_null("Main/CanvasLayer/UI/BoardRegion/World3DHost/World3DViewport/World3DRoot")
	if world_vp == null or world_root == null:
		push_error("World3D viewport/root not found")
		quit(2)
		return

	# Let startup contracts, layout, and world sync complete deterministically.
	var ready: bool = false
	for _i in range(220):
		await process_frame
		var state_obj: Object = controller.get("state")
		if state_obj == null:
			continue
		var width: int = int(state_obj.get("width"))
		var height: int = int(state_obj.get("height"))
		var blocks: Dictionary = state_obj.get("blocks")
		if width <= 0 or height <= 0 or blocks.is_empty():
			continue
		var wr_state: Object = world_root.get("_state")
		if wr_state == null:
			continue
		ready = true
		break
	if not ready:
		push_error("Scene did not reach render-ready state")
		quit(7)
		return

	# Expand owned territory in a deterministic way so ooze continuity is visible
	# from standard gameplay framing in before/after comparisons.
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
					var manhattan: int = abs(dx) + abs(dy)
					if manhattan > 4:
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

	for _j in range(20):
		await process_frame

	# Force a stable gameplay framing for deterministic comparisons.
	world_root.set("_camera_pan_offset", Vector3.ZERO)
	world_root.set("_camera_yaw", deg_to_rad(-34.0))
	world_root.set("_camera_yaw_target", deg_to_rad(-34.0))
	world_root.set("_camera_pitch", deg_to_rad(48.0))
	world_root.set("_camera_pitch_target", deg_to_rad(48.0))
	world_root.set("_camera_distance", 26.0)
	world_root.set("_camera_distance_target", 26.0)
	world_root.set("_camera_initialized", true)
	world_root.call("_update_camera_transform", true)
	for _k in range(8):
		await process_frame

	var dyn_root: Node = world_root.get_node_or_null("DynamicRoot")
	var cam: Camera3D = world_root.get_node_or_null("TacticalCamera3D")
	var cam_target: Vector3 = world_root.get("_camera_base_target")
	print("DEBUG dynamic_children=", 0 if dyn_root == null else dyn_root.get_child_count())
	print("DEBUG use_3d=", controller.call("_use_3d_world"))
	print("DEBUG cam_target=", cam_target)
	if cam != null:
		print("DEBUG cam_pos=", cam.global_position, " cam_basis=", cam.global_basis)
	if dyn_root != null:
		for idx in range(mini(3, dyn_root.get_child_count())):
			var child := dyn_root.get_child(idx)
			if child is Node3D:
				print("DEBUG dynamic_child_", idx, "=", child.name, " pos=", (child as Node3D).global_position)

	RenderingServer.force_draw(false)
	await process_frame

	var tex: Texture2D = root.get_texture()
	if tex == null:
		push_error("Root viewport texture unavailable")
		quit(3)
		return

	var image: Image = tex.get_image()
	if image == null or image.is_empty():
		push_error("Captured image is empty")
		quit(4)
		return

	var abs_out := ProjectSettings.globalize_path(out_path)
	var dir := abs_out.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var err := image.save_png(abs_out)
	if err != OK:
		push_error("Failed to save capture: %s (err=%d)" % [abs_out, err])
		quit(5)
		return

	print("Saved capture -> %s" % abs_out)
	quit(0)

extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var style: String = "3d"
	var args: Array = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--style" and i + 1 < args.size():
			style = String(args[i + 1]).to_lower()

	var run_flow: Node = root.get_node_or_null("/root/RunFlow")
	if run_flow == null:
		push_error("RunFlow autoload not found")
		quit(2)
		return
	if run_flow.has_method("set_graphics_style"):
		run_flow.call("set_graphics_style", style)

	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		push_error("Failed to load Main.tscn")
		quit(3)
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	for _i in range(40):
		await process_frame
	var controller: Node = root.get_node_or_null("Main")
	if controller == null:
		push_error("Main node not found")
		quit(4)
		return
	var using_3d: bool = bool(controller.call("_use_3d_world"))
	var effective_style: String = "3d" if using_3d else "2d"
	print("graphics_style_requested=%s effective=%s" % [style, effective_style])
	quit(0)

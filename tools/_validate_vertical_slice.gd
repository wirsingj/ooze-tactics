extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/visual/VerticalSliceBoard.tscn")
	if packed == null:
		push_error("load failed")
		quit(1)
		return
	root.add_child(packed.instantiate())
	await process_frame
	print("VerticalSliceBoard load OK")
	quit(0)

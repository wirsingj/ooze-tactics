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
	for _i in range(5):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var tex: Texture2D = root.get_texture()
	if tex == null:
		push_error("no tex")
		quit(2)
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		push_error("empty")
		quit(3)
		return
	var out := ProjectSettings.globalize_path("res://tools/visual_compare/vertical_slice_hero.png")
	var err := img.save_png(out)
	if err != OK:
		push_error("save failed")
		quit(4)
		return
	print("saved:", out)
	quit(0)

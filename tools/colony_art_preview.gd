extends SceneTree

const STAGE = preload("res://tools/visual/ColonyArtStage.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.title = "Ooze Tactics - Living Colony Art Study"
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var stage = STAGE.new()
	root.add_child(stage)
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await process_frame
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var capture: Image = root.get_texture().get_image()
		var error: Error = capture.save_png("res://docs/validation/colony_art_preview_v1.png")
		print("Colony art capture: ", error_string(error))
		quit(0 if error == OK else 1)

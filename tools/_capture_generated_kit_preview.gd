extends SceneTree

const SCENE_PATH := "res://scenes/visual/GeneratedKitPreview.tscn"
const OUTPUT_PATH := "res://tools/visual_compare/generated_kit_preview.png"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if packed == null:
		push_error("load failed: %s" % SCENE_PATH)
		quit(1)
		return
	root.add_child(packed.instantiate())
	for _i in range(6):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var tex: Texture2D = root.get_texture()
	if tex == null:
		push_error("no viewport texture")
		quit(2)
		return
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		push_error("empty image")
		quit(3)
		return
	var out_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var err := img.save_png(out_path)
	if err != OK:
		push_error("save failed: %s" % out_path)
		quit(4)
		return
	print("saved:", out_path)
	quit(0)

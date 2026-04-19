extends RefCounted
class_name AtlasCatalog

# Lightweight runtime atlas registry loaded from atlas.json.

var atlas_texture: Texture2D = null
var tile_size: int = 32
var atlas_size: Vector2i = Vector2i.ZERO
var sprites: Dictionary = {}

func _init(atlas_png_path: String = "res://assets/atlas/atlas.png", meta_path: String = "res://assets/atlas/atlas.json") -> void:
	atlas_texture = _load_png_texture(atlas_png_path)
	_load_meta(meta_path)

func has_sprite(name: String) -> bool:
	return sprites.has(name)

func region(name: String) -> Rect2:
	if not sprites.has(name):
		return Rect2(0, 0, tile_size, tile_size)
	var info: Dictionary = sprites[name]
	return Rect2(float(info.get("x", 0)), float(info.get("y", 0)), float(info.get("w", tile_size)), float(info.get("h", tile_size)))

func make_texture(name: String) -> Texture2D:
	if atlas_texture == null or not sprites.has(name):
		return null
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = atlas_texture
	at.region = region(name)
	return at

func draw(canvas: CanvasItem, name: String, dest: Rect2, modulate: Color = Color.WHITE) -> void:
	if atlas_texture == null or not sprites.has(name):
		canvas.draw_rect(dest, Color(1.0, 0.0, 1.0, 0.35), true)
		return
	canvas.draw_texture_rect_region(atlas_texture, dest, region(name), modulate)

func _load_meta(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var meta: Dictionary = parsed
	tile_size = int(meta.get("tile_size", tile_size))

	var size_raw: Array = meta.get("atlas_size", [tile_size, tile_size])
	if size_raw.size() >= 2:
		atlas_size = Vector2i(int(size_raw[0]), int(size_raw[1]))

	var sprite_dict: Variant = meta.get("sprites", {})
	if typeof(sprite_dict) == TYPE_DICTIONARY:
		sprites = sprite_dict

func _load_png_texture(path: String) -> Texture2D:
	var resource_tex: Texture2D = load(path) as Texture2D
	if resource_tex != null:
		return resource_tex

	var image: Image = Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

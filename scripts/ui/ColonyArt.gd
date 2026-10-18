extends RefCounted

const SHADER = preload("res://assets/shaders/colony_palette.gdshader")
const PATH = "res://assets/art/colony-v1/"
const ROLES = ["core", "melee", "ranged", "defense", "gather"]
static var sources: Dictionary = {}

static func source(role: String) -> Dictionary:
	if sources.has(role):
		return sources[role]
	var texture: Texture2D = load(PATH + role + ".png")
	var img: Image = texture.get_image()
	var low := Vector2i(img.get_width(), img.get_height())
	var high := Vector2i.ZERO
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if img.get_pixel(x, y).a >= 0.8:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y))
	var region := Rect2(Vector2(low), Vector2(high-low+Vector2i(4,4))).grow(12).intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	sources[role] = {"texture": texture, "region": region}
	return sources[role]

static func organ(role: String, hue: float, phase: float = 0.0) -> Sprite2D:
	var entry: Dictionary = source(role)
	var sprite := Sprite2D.new()
	sprite.texture = entry.texture
	sprite.region_enabled = true
	sprite.region_rect = entry.region
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("faction_hue", hue)
	mat.set_shader_parameter("role", ROLES.find(role))
	mat.set_shader_parameter("phase", phase)
	var texture_size: Vector2 = sprite.texture.get_size()
	mat.set_shader_parameter("source_region", Vector4(sprite.region_rect.position.x / texture_size.x, sprite.region_rect.position.y / texture_size.y, sprite.region_rect.size.x / texture_size.x, sprite.region_rect.size.y / texture_size.y))
	sprite.material = mat
	return sprite

static func icon(role: String) -> Texture2D:
	if role == "basic":
		return load(PATH+"tissue.png")
	var entry: Dictionary = source(role)
	var atlas := AtlasTexture.new()
	atlas.atlas = entry.texture
	atlas.region = entry.region
	return atlas

static func hue(state: GameState, owner: int) -> float:
	if owner == GameState.PLAYER_ID:
		return 0.41
	var peers: Array = []
	var hostile: bool = state.are_hostile(GameState.PLAYER_ID, owner)
	for id in state.players:
		if id != GameState.PLAYER_ID and state.are_hostile(GameState.PLAYER_ID, id) == hostile:
			peers.append(id)
	peers.sort()
	var index: int = maxi(0, peers.find(owner))
	var palette: Array = [0.98, 0.77, 0.94, 0.83, 0.90, 0.73] if hostile else [0.57, 0.49, 0.36, 0.61, 0.44, 0.53]
	return float(palette[index % palette.size()])

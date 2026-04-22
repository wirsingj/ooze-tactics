extends SceneTree

const OUT_DIR: String = "res://assets/world3d/generated"
const STONE_SIZE: int = 512
const SLIME_SIZE: int = 512

func _init() -> void:
	var abs_dir: String = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)

	_generate_stone_set("stone", STONE_SIZE)
	_generate_slime_detail("slime_detail", SLIME_SIZE)

	print("[world3d-assets] Generated textures in %s" % OUT_DIR)
	quit(0)

func _generate_stone_set(prefix: String, size: int) -> void:
	var albedo: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var roughness: Image = Image.create(size, size, false, Image.FORMAT_RF)
	var height: PackedFloat32Array = PackedFloat32Array()
	height.resize(size * size)

	for y in range(size):
		for x in range(size):
			var uv: Vector2 = Vector2(float(x) / float(size), float(y) / float(size))
			var n0: float = _fbm(uv * 7.5)
			var n1: float = _fbm(uv * 14.0 + Vector2(13.7, 4.1))
			var n2: float = _fbm(uv * 27.0 + Vector2(29.3, 17.9))
			var ridge: float = 1.0 - absf(n1 * 2.0 - 1.0)
			var crack_mask: float = smoothstep(0.68, 0.95, ridge)
			var wet_mask: float = smoothstep(0.55, 0.90, n2)

			var base_mix: float = clampf(n0 * 0.70 + n1 * 0.30, 0.0, 1.0)
			var col: Color = Color(0.08, 0.07, 0.065, 1.0).lerp(Color(0.20, 0.17, 0.14, 1.0), base_mix)
			col = col.lerp(Color(0.05, 0.045, 0.04, 1.0), crack_mask * 0.35)
			col = col.lerp(Color(0.11, 0.10, 0.09, 1.0), wet_mask * 0.22)
			albedo.set_pixel(x, y, col)

			var rough: float = clampf(0.86 - wet_mask * 0.42 + crack_mask * 0.05 + n0 * 0.06, 0.15, 1.0)
			roughness.set_pixel(x, y, Color(rough, 0.0, 0.0, 1.0))

			var h: float = clampf(base_mix * 0.7 + crack_mask * 0.18 - wet_mask * 0.08, 0.0, 1.0)
			height[y * size + x] = h

	var normal: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var h_l: float = _height_sample(height, size, x - 1, y)
			var h_r: float = _height_sample(height, size, x + 1, y)
			var h_d: float = _height_sample(height, size, x, y - 1)
			var h_u: float = _height_sample(height, size, x, y + 1)
			var dx: float = (h_l - h_r) * 0.55
			var dy: float = (h_d - h_u) * 0.55
			var n: Vector3 = Vector3(dx, 1.0, dy).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5, 1.0))

	albedo.save_png("%s/%s_albedo.png" % [OUT_DIR, prefix])
	roughness.save_png("%s/%s_roughness.png" % [OUT_DIR, prefix])
	normal.save_png("%s/%s_normal.png" % [OUT_DIR, prefix])

func _generate_slime_detail(prefix: String, size: int) -> void:
	var detail: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var uv: Vector2 = Vector2(float(x) / float(size), float(y) / float(size))
			var n0: float = _fbm(uv * 9.0)
			var n1: float = _fbm(uv * 18.0 + Vector2(5.7, 19.3))
			var blobs: float = smoothstep(0.50, 0.83, n0 * 0.58 + n1 * 0.42)
			var micro: float = smoothstep(0.62, 0.92, _fbm(uv * 28.0 + Vector2(23.1, 4.9)))
			var v: float = clampf(blobs * 0.72 + micro * 0.28, 0.0, 1.0)
			detail.set_pixel(x, y, Color(v, v, v, 1.0))
	detail.save_png("%s/%s.png" % [OUT_DIR, prefix])

func _height_sample(data: PackedFloat32Array, size: int, x: int, y: int) -> float:
	var sx: int = ((x % size) + size) % size
	var sy: int = ((y % size) + size) % size
	return data[sy * size + sx]

func _fbm(p: Vector2) -> float:
	var value: float = 0.0
	var amp: float = 0.5
	var freq: float = 1.0
	for _i in range(5):
		value += amp * _noise(p * freq)
		freq *= 2.0
		amp *= 0.5
	return value

func _noise(p: Vector2) -> float:
	var i: Vector2 = Vector2(floor(p.x), floor(p.y))
	var f: Vector2 = Vector2(p.x - floor(p.x), p.y - floor(p.y))
	var a: float = _hash(i)
	var b: float = _hash(i + Vector2(1.0, 0.0))
	var c: float = _hash(i + Vector2(0.0, 1.0))
	var d: float = _hash(i + Vector2(1.0, 1.0))
	var u: Vector2 = f * f * (Vector2.ONE * 3.0 - 2.0 * f)
	return lerp(lerp(a, b, u.x), lerp(c, d, u.x), u.y)

func _hash(p: Vector2) -> float:
	var v: float = sin(p.dot(Vector2(127.1, 311.7))) * 43758.5453123
	return v - floor(v)

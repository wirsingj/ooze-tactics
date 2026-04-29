extends RefCounted
class_name World3DAssets

var manifest: Dictionary = {}
var scene_cache: Dictionary = {}
var geometry_registry: Dictionary = {}
var geometry_variants: Dictionary = {}
var geometry_normalize: Dictionary = {}
var texture_registry: Dictionary = {}

func load_manifest(path: String) -> void:
	manifest.clear()
	geometry_registry.clear()
	geometry_variants.clear()
	geometry_normalize.clear()
	texture_registry.clear()
	scene_cache.clear()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("World3D asset manifest missing: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("World3D asset manifest invalid JSON dictionary: %s" % path)
		return

	manifest = parsed
	var textures_variant: Variant = manifest.get("textures", {})
	if typeof(textures_variant) == TYPE_DICTIONARY:
		var textures: Dictionary = textures_variant
		for key_variant in textures.keys():
			var key: String = String(key_variant)
			var value: Variant = textures[key_variant]
			if typeof(value) == TYPE_STRING:
				var texture_path: String = String(value)
				if not texture_path.is_empty():
					texture_registry[key] = texture_path
			elif typeof(value) == TYPE_DICTIONARY:
				var entry: Dictionary = value
				var entry_path: String = String(entry.get("path", ""))
				if not entry_path.is_empty():
					texture_registry[key] = entry_path

	var geometry_variant: Variant = manifest.get("geometry", {})
	if typeof(geometry_variant) != TYPE_DICTIONARY:
		return
	var geometry: Dictionary = geometry_variant
	for key_variant in geometry.keys():
		var key: String = String(key_variant)
		var entry_variant: Variant = geometry[key_variant]
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_variant
		var geometry_path: String = String(entry.get("path", ""))
		if geometry_path.is_empty():
			continue
		geometry_registry[key] = geometry_path

		var variants: Array[String] = []
		var variants_variant: Variant = entry.get("variants", [])
		if typeof(variants_variant) == TYPE_ARRAY:
			for variant_entry in variants_variant:
				if typeof(variant_entry) != TYPE_STRING:
					continue
				var variant_path: String = String(variant_entry)
				if not variant_path.is_empty():
					variants.append(variant_path)
		if not variants.is_empty():
			geometry_variants[key] = variants

		var normalize: Dictionary = {}
		var normalize_variant: Variant = entry.get("normalize", {})
		if typeof(normalize_variant) == TYPE_DICTIONARY:
			var normalize_entry: Dictionary = normalize_variant
			if normalize_entry.has("scale"):
				normalize["scale"] = _manifest_vec3(normalize_entry.get("scale"), Vector3.ONE)
			if normalize_entry.has("rotation_degrees"):
				normalize["rotation_degrees"] = _manifest_vec3(normalize_entry.get("rotation_degrees"), Vector3.ZERO)
			if normalize_entry.has("offset"):
				normalize["offset"] = _manifest_vec3(normalize_entry.get("offset"), Vector3.ZERO)
		if not normalize.is_empty():
			geometry_normalize[key] = normalize

func texture_path_for(key: String) -> String:
	return String(texture_registry.get(key, ""))

func asset_paths_for(key: String) -> Array[String]:
	var paths: Array[String] = []
	var primary: String = String(geometry_registry.get(key, ""))
	if not primary.is_empty():
		paths.append(primary)
	if geometry_variants.has(key):
		var variants: Array = geometry_variants[key]
		for variant_entry in variants:
			var variant_path: String = String(variant_entry)
			if variant_path.is_empty() or paths.has(variant_path):
				continue
			paths.append(variant_path)
	return paths

func asset_scene_for_path(path: String) -> PackedScene:
	if path.is_empty():
		return null
	if scene_cache.has(path):
		return scene_cache[path] as PackedScene
	var scene: PackedScene = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		scene = res as PackedScene
	if scene == null and path.to_lower().ends_with(".glb"):
		scene = _runtime_scene_from_gltf(path)
	scene_cache[path] = scene
	return scene

func asset_scene_for(key: String) -> PackedScene:
	var paths: Array[String] = asset_paths_for(key)
	for path in paths:
		var scene: PackedScene = asset_scene_for_path(path)
		if scene != null:
			return scene
	return null

func asset_variant_path_for_transform(key: String, tf: Transform3D) -> String:
	var paths: Array[String] = asset_paths_for(key)
	if paths.is_empty():
		return ""
	if paths.size() == 1:
		return paths[0]
	var ox: int = int(round(tf.origin.x * 100.0))
	var oy: int = int(round(tf.origin.y * 100.0))
	var oz: int = int(round(tf.origin.z * 100.0))
	var variant_seed: int = ox * 73856093 + oy * 19349663 + oz * 83492791 + hash(key) * 31
	var idx: int = int(abs(variant_seed) % paths.size())
	for offset in range(paths.size()):
		var candidate: String = paths[(idx + offset) % paths.size()]
		if asset_scene_for_path(candidate) != null:
			return candidate
	return paths[0]

func has_asset_scene(key: String) -> bool:
	return asset_scene_for(key) != null

func instantiate_asset_scene(key: String, path_override: String = "") -> Node3D:
	var scene: PackedScene = asset_scene_for_path(path_override) if not path_override.is_empty() else asset_scene_for(key)
	if scene == null:
		return null
	var instance: Node = scene.instantiate()
	var node3d: Node3D = instance as Node3D
	if node3d != null:
		return node3d
	var holder: Node3D = Node3D.new()
	holder.name = "%sAssetRoot" % key.capitalize()
	holder.add_child(instance)
	return holder

func normalized_asset_transform(key: String, base_tf: Transform3D) -> Transform3D:
	if not geometry_normalize.has(key):
		return base_tf
	var normalize: Dictionary = geometry_normalize[key]
	var normalize_scale: Vector3 = normalize.get("scale", Vector3.ONE)
	var rotation_deg: Vector3 = normalize.get("rotation_degrees", Vector3.ZERO)
	var local_offset: Vector3 = normalize.get("offset", Vector3.ZERO)
	var local_basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(rotation_deg.x),
		deg_to_rad(rotation_deg.y),
		deg_to_rad(rotation_deg.z)
	)).scaled(normalize_scale)
	return base_tf * Transform3D(local_basis, local_offset)

func _manifest_vec3(value: Variant, fallback: Vector3) -> Vector3:
	if typeof(value) != TYPE_ARRAY:
		return fallback
	var arr: Array = value
	if arr.size() < 3:
		return fallback
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))

func _runtime_scene_from_gltf(res_path: String) -> PackedScene:
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if not FileAccess.file_exists(abs_path):
		return null
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	var err: int = doc.append_from_file(abs_path, state)
	if err != OK:
		push_warning("Failed to read GLB asset %s (err=%d)" % [res_path, err])
		return null
	var root: Node = doc.generate_scene(state)
	var root3d: Node3D = root as Node3D
	if root3d == null:
		if root != null:
			root.queue_free()
		return null
	var scene: PackedScene = PackedScene.new()
	err = scene.pack(root3d)
	if err != OK:
		push_warning("Failed to pack GLB asset %s (err=%d)" % [res_path, err])
		root3d.queue_free()
		return null
	root3d.queue_free()
	return scene

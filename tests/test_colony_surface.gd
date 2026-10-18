extends SceneTree

# Samples the production shader through a real renderer, not a CPU copy of its geometry.
const ORIGIN = Vector2(90,200)
const STEP = Vector2(24,13)
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func point(tile: Vector2) -> Vector2i:
	return Vector2i(ORIGIN+Vector2((tile.x+tile.y)*STEP.x,(tile.y-tile.x)*STEP.y))

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		printerr("Surface checks need a real renderer; omit --headless")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600,400)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var map := Image.create(10,10,false,Image.FORMAT_RGBA8)
	map.fill(Color(0,0,0,1))
	for tile in [Vector2i(2,2),Vector2i(3,2),Vector2i(2,3),Vector2i(3,3),Vector2i(6,2),Vector2i(6,5),Vector2i(7,6),Vector2i(2,6)]:
		map.set_pixelv(tile,Color(1.0/255.0,1,0.5,1))
	map.set_pixel(3,6,Color(2.0/255.0,1,0.9,1))
	map.set_pixel(3,4,Color(0,0,0,0))
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/colony_board.gdshader")
	material.set_shader_parameter("colony_map",ImageTexture.create_from_image(map))
	material.set_shader_parameter("board_size",Vector2(10,10))
	material.set_shader_parameter("canvas_size",Vector2(viewport.size))
	material.set_shader_parameter("origin",ORIGIN)
	material.set_shader_parameter("step_size",STEP)
	var white := Image.create(1,1,false,Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	material.set_shader_parameter("tissue_texture",ImageTexture.create_from_image(white))
	var rect := ColorRect.new()
	rect.size = Vector2(viewport.size)
	rect.material = material
	viewport.add_child(rect)
	for clock_value in [0.0,1.6]:
		material.set_shader_parameter("clock",clock_value)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = viewport.get_texture().get_image()
		for x in range(-2,3):
			for y in range(-2,3):
				if frame.get_pixelv(point(Vector2(2.5,2.5))+Vector2i(x,y)).a<0.98:
					failures.append("A connected four-tile intersection has a hole")
		for sample in [Vector2(6.48,2.48),Vector2(6.5,5.5),Vector2(3,3.6),Vector2(2.5,6)]:
			if frame.get_pixelv(point(sample)).a>0.05:
				failures.append("Tissue crosses an isolated corner, diagonal, wall, or foreign border at %s" % sample)
	# The batched floor must still distinguish actual blocked cells and align
	# with tissue/picking at gameplay and overview scale.
	var floor_material := ShaderMaterial.new()
	floor_material.shader = preload("res://assets/shaders/colony_floor.gdshader")
	floor_material.set_shader_parameter("colony_map",ImageTexture.create_from_image(map))
	floor_material.set_shader_parameter("board_size",Vector2(10,10))
	floor_material.set_shader_parameter("canvas_size",Vector2(viewport.size))
	floor_material.set_shader_parameter("origin",ORIGIN)
	rect.material = floor_material
	for scale_ in [1.0,0.5]:
		floor_material.set_shader_parameter("step_size",STEP*scale_)
		floor_material.set_shader_parameter("overview",scale_<1.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = viewport.get_texture().get_image()
		var ground: Color = frame.get_pixelv(Vector2i(ORIGIN+(Vector2(point(Vector2(2,2)))-ORIGIN)*scale_))
		var rock: Color = frame.get_pixelv(Vector2i(ORIGIN+(Vector2(point(Vector2(3,4)))-ORIGIN)*scale_))
		var outside: Color = frame.get_pixelv(Vector2i(ORIGIN+(Vector2(point(Vector2(-1,0)))-ORIGIN)*scale_))
		if ground.a<0.99 or ground.g<0.12 or rock.b<ground.b+0.025 or outside.g>ground.g-0.025:
			failures.append("Batched terrain loses floor, rock, or board bounds at scale %s" % scale_)
	for failure in failures:
		printerr(failure)
	print("RENDERED COLONY SURFACE: ", "PASSED" if failures.is_empty() else "FAILED")
	quit(0 if failures.is_empty() else 1)

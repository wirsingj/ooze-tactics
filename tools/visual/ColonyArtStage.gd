extends Node2D

# Presentation-only study. It does not load or mutate a campaign state.
const PALETTE_SHADER = preload("res://assets/shaders/colony_palette.gdshader")
const TERRITORY_SHADER = preload("res://assets/shaders/colony_territory.gdshader")
const ART_PATH = "res://assets/art/colony-v1/"
const ROLES = ["core", "melee", "ranged", "defense", "gather"]
const ROLE_TITLES = ["HEART / pulse", "MELEE / coil", "RANGED / pressure", "DEFENSE / brace", "GATHER / feed"]
const HUES = [0.41, 0.57, 0.98, 0.77]
const FACTIONS = ["ALLY / VERDANT", "ALLY / TIDAL", "ENEMY / CRIMSON", "ENEMY / VIOLET"]
const CELLS = [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1),Vector2i(2,0),Vector2i(0,2),Vector2i(0,-2)]
const ROLE_CELLS = [Vector2i(0,0), Vector2i(2,0), Vector2i(0,-2), Vector2i(-1,1), Vector2i(0,2)]
const ROLE_HEIGHTS = [128.0, 118.0, 96.0, 80.0, 92.0]
const ORIGINS = [Vector2(405,297),Vector2(1195,297),Vector2(405,601),Vector2(1195,601)]

var art: Dictionary = {}
var materials: Array[ShaderMaterial] = []
var territory_materials: Array[ShaderMaterial] = []
var ticks: float = 0.0
var motion: bool = true
var reaching: bool = false
var mono: bool = false
var action_left: float = 0.0
var status: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101515"))
	for role in ROLES:
		var tex: Texture2D = load(ART_PATH+role+".png")
		art[role] = {"texture": tex, "region": _solid_bounds(tex.get_image())}
	for index in range(4):
		_make_colony(index)
	_make_ui()
	queue_redraw()

func _solid_bounds(img: Image) -> Rect2:
	# Alpha bounds are display metadata; the generated PNG remains untouched.
	var low := Vector2i(img.get_width(), img.get_height())
	var high := Vector2i.ZERO
	for y in range(0,img.get_height(),4):
		for x in range(0,img.get_width(),4):
			if img.get_pixel(x,y).a >= 0.80:
				low = low.min(Vector2i(x,y))
				high = high.max(Vector2i(x,y))
	return Rect2(Vector2(low), Vector2(high-low+Vector2i(4,4))).grow(12).intersection(Rect2(Vector2.ZERO,Vector2(img.get_size())))

func _project(cell: Vector2i) -> Vector2:
	return Vector2(float(cell.x-cell.y)*42.0,float(cell.x+cell.y)*22.0)

func _make_colony(index: int) -> void:
	var sheet := ColorRect.new()
	sheet.position = ORIGINS[index]-Vector2(300,150)
	sheet.size = Vector2(600,300)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = TERRITORY_SHADER
	mat.set_shader_parameter("tissue_texture",load(ART_PATH+"tissue.png"))
	mat.set_shader_parameter("faction_hue", HUES[index])
	var centers := PackedVector2Array()
	var fingers := PackedVector4Array()
	for cell in CELLS:
		var center: Vector2 = _project(cell)+Vector2(300,150)
		centers.append(center)
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cell+direction in CELLS:
				continue
			var normal: Vector2 = (_project(direction)*Vector2(1,2)).normalized()
			var base: Vector2 = center+normal*37.0/Vector2(1,2)
			fingers.append(Vector4(base.x,base.y,normal.x,normal.y))
	mat.set_shader_parameter("center_count",centers.size())
	mat.set_shader_parameter("finger_count",fingers.size())
	centers.resize(32)
	fingers.resize(64)
	mat.set_shader_parameter("centers",centers)
	mat.set_shader_parameter("fingers",fingers)
	mat.set_shader_parameter("growth_center",_project(Vector2i(2,1))+Vector2(300,150))
	sheet.material=mat
	territory_materials.append(mat)
	add_child(sheet)
	var ordering := [2,0,1,3,4]
	for role_index in ordering:
		_make_organ(role_index,ORIGINS[index]+_project(ROLE_CELLS[role_index]),ROLE_HEIGHTS[role_index],HUES[index])

func _make_organ(role_index: int, root_point: Vector2, height: float, hue: float) -> void:
	var entry: Dictionary=art[ROLES[role_index]]
	var rect: Rect2=entry["region"]
	var sprite := Sprite2D.new()
	sprite.texture=entry["texture"]
	sprite.region_enabled=true
	sprite.region_rect=rect
	sprite.centered=false
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var factor: float=height/rect.size.y
	sprite.scale=Vector2.ONE*factor
	sprite.position=root_point-Vector2(rect.size.x*factor*0.5,height*0.87)
	var mat := ShaderMaterial.new()
	mat.shader=PALETTE_SHADER
	mat.set_shader_parameter("faction_hue",hue)
	mat.set_shader_parameter("role",role_index)
	mat.set_shader_parameter("phase",float(role_index)*1.37)
	sprite.material=mat
	materials.append(mat)
	add_child(sprite)

func _label(text: String, position_: Vector2, size_: int, color: Color) -> Label:
	var label := Label.new()
	label.text=text
	label.position=position_
	label.add_theme_font_size_override("font_size",size_)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(text: String, x: float, callback: Callable) -> Button:
	var button := Button.new()
	button.text=text
	button.position=Vector2(x,41)
	button.size=Vector2(145,36)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _make_ui() -> void:
	_label("OOZE TACTICS",Vector2(34,23),15,Color("9fafa9"))
	_label("A living colony",Vector2(32,46),31,Color("e5e8d6"))
	_label("One sprite family. Four faction palettes. Connected tissue.",Vector2(34,94),16,Color("96a69e"))
	var pause := _button("Pause motion",951,func(): motion=not motion)
	pause.pressed.connect(func(): pause.text="Pause motion" if motion else "Resume motion")
	_button("Reach / retreat",1106,func(): reaching=not reaching)
	_button("Role pulse",1261,func(): action_left=1.6)
	var gray := _button("Grayscale",1416,func(): mono=not mono)
	gray.pressed.connect(func(): gray.text="Restore color" if mono else "Grayscale")
	for index in range(4):
		var top: Vector2=ORIGINS[index]+Vector2(-354,-151)
		_label(FACTIONS[index],top,15,Color.from_hsv(HUES[index],0.36,0.88))
		_label("Shared source art / hue shift in shader",top+Vector2(0,23),12,Color("7d8d87"))
	for index in range(5):
		var x: float=155.0+float(index)*317.0
		_make_organ(index,Vector2(x,841),90.0,0.47)
		_label(ROLE_TITLES[index],Vector2(x-89,859),13,Color("bccbc1"))
	status=_label("Presentation study  |  cosmetic motion; no campaign simulation",Vector2(34,706),13,Color("899c91"))

func _process(delta: float) -> void:
	if motion:
		ticks+=delta
		action_left=maxf(0.0,action_left-delta)
	var pulse: float=sin((1.6-action_left)/1.6*PI) if action_left>0.0 else 0.0
	for mat in materials:
		mat.set_shader_parameter("clock",ticks)
		mat.set_shader_parameter("action",pulse)
		mat.set_shader_parameter("grayscale",mono)
	for mat in territory_materials:
		mat.set_shader_parameter("clock",ticks)
		mat.set_shader_parameter("extension",(sin(ticks*0.8)*0.5+0.5) if reaching else 0.0)
		mat.set_shader_parameter("grayscale",mono)

func _draw() -> void:
	draw_rect(Rect2(0,0,1600,900),Color("101515"))
	draw_line(Vector2(32,125),Vector2(1568,125),Color("35413c"),1.0)
	draw_line(Vector2(32,735),Vector2(1568,735),Color("35413c"),1.0)
	for index in range(4):
		var rect := Rect2(ORIGINS[index]+Vector2(-373,-165),Vector2(746,275))
		draw_style_box(_panel_style(),rect)
		for y in range(-2,3):
			for x in range(-2,3):
				var p: Vector2=ORIGINS[index]+_project(Vector2i(x,y))
				var points := PackedVector2Array([p+Vector2(-42,0),p+Vector2(0,-22),p+Vector2(42,0),p+Vector2(0,22)])
				var value: float=0.105+float(posmod(x*7+y*3,5))*0.006
				draw_colored_polygon(points,Color(value,value*1.06,value*0.98))
				draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),Color("27312b"),1.0)

func _panel_style() -> StyleBoxFlat:
	var panel := StyleBoxFlat.new()
	panel.bg_color=Color("151d1b")
	panel.border_color=Color("293930")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	return panel

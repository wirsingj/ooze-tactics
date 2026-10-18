extends Control

# A presentation of GameState only. Picking returns the same integer tiles used
# by the rules; cosmetic growth never changes placement or combat eligibility.
const ART = preload("res://scripts/ui/ColonyArt.gd")
const TISSUE = preload("res://assets/shaders/colony_board.gdshader")
const FLOOR = preload("res://assets/shaders/colony_floor.gdshader")
const ROLE_HEIGHTS = {"core": 1.80, "melee": 1.58, "ranged": 1.22, "defense": 0.92, "gather": 1.14}
const INVALID = Vector2i(-1, -1)

var state: GameState
var context: Dictionary = {}
var origin := Vector2.ZERO
var step_size := Vector2(36, 18)
var zoom: float = 1.0
var pan := Vector2.ZERO
var dragging: bool = false
var clock: float = 0.0
var organs: Dictionary = {}
var cells: Dictionary = {}
var owner_indices: Dictionary = {}
var map_image: Image
var map_texture: ImageTexture
var floor_image: Image
var floor_key: String = ""
var tissue: ColorRect
var tissue_material: ShaderMaterial
var terrain: ColorRect
var terrain_material: ShaderMaterial
var landmarks: Node2D
var overlay: Node2D
var ghosts: Node2D
var effects: Array = []
var strikes: Array = []
var _signature: String = ""
var _map_identity: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	terrain = ColorRect.new()
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain_material = ShaderMaterial.new()
	terrain_material.shader = FLOOR
	terrain.material = terrain_material
	add_child(terrain)
	landmarks = Node2D.new()
	landmarks.draw.connect(_draw_landmarks)
	add_child(landmarks)
	tissue = ColorRect.new()
	tissue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tissue_material = ShaderMaterial.new()
	tissue_material.shader = TISSUE
	tissue_material.set_shader_parameter("tissue_texture", load(ART.PATH+"tissue.png"))
	tissue.material = tissue_material
	add_child(tissue)
	ghosts = Node2D.new()
	ghosts.z_index = 2000
	add_child(ghosts)
	overlay = Node2D.new()
	overlay.z_index = 3000
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	resized.connect(_layout)

func sync_world(next_state: GameState, next_context: Dictionary) -> void:
	if next_state == null or tissue == null:
		return
	var identity: String = "%d/%d/%d/%d" % [next_state.run_seed, next_state.level_index, next_state.width, next_state.height]
	var first: bool = identity != _map_identity
	if first:
		for entry in organs.values():
			entry.sprite.queue_free()
		organs.clear()
		cells.clear()
		effects.clear()
		strikes.clear()
		zoom = 1.0
		pan = Vector2.ZERO
		_map_identity = identity
		_signature = ""
	state = next_state
	context = next_context
	var signature: String = str(state.blocks) + str(state.wall_tiles)
	if signature != _signature:
		_signature = signature
		_sync_colony(first)
	_layout()
	_sync_ghosts()
	overlay.queue_redraw()

func _sync_colony(first: bool) -> void:
	owner_indices.clear()
	var ids: Array = state.players.keys()
	ids.sort()
	for i in range(ids.size()):
		owner_indices[ids[i]] = i+1
	for entry in cells.values():
		entry.target = 0.0
	for entry in organs.values():
		entry.alive = false
	for id in state.blocks:
		var block: Dictionary = state.blocks[id]
		var tile: Vector2i = block.pos
		var owner: int = int(block.owner)
		if not cells.has(tile) or int(cells[tile].owner) != owner:
			cells[tile] = {"owner": owner, "fill": 1.0 if first else 0.0, "target": 1.0}
		cells[tile].target = 1.0
		var role: String = "core" if block.core else String(block.tile_type)
		if role == "basic":
			continue
		if organs.has(id) and organs[id].role != role:
			organs[id].sprite.queue_free()
			organs.erase(id)
		if not organs.has(id):
			var sprite: Sprite2D = ART.organ(role, ART.hue(state, owner), float(id)*1.37)
			add_child(sprite)
			organs[id] = {"sprite": sprite, "role": role, "tile": tile, "fill": 1.0 if first else 0.0, "alive": true, "flash": 0.0, "action": 0.0}
		organs[id].alive = true
		organs[id].tile = tile
		organs[id].sprite.material.set_shader_parameter("faction_hue", ART.hue(state, owner))
	_update_map()
	queue_redraw()

func sync_context(next_context: Dictionary) -> void:
	context = next_context
	_sync_ghosts()
	overlay.queue_redraw()

func _update_map() -> void:
	if state == null:
		return
	var changed_size: bool = map_image == null or map_image.get_size() != Vector2i(state.width, state.height)
	var next_floor_key: String = "%d/%d/%d" % [state.width,state.height,state.wall_tiles.hash()]
	if floor_image==null or floor_key!=next_floor_key:
		floor_key = next_floor_key
		floor_image = Image.create(state.width,state.height,false,Image.FORMAT_RGBA8)
		floor_image.fill(Color(0,0,0,1))
		for key in state.wall_tiles:
			var xy: PackedStringArray = String(key).split(",")
			floor_image.set_pixel(int(xy[0]),int(xy[1]),Color(0,0,0,0))
	map_image = floor_image.duplicate()
	for tile in cells:
		var entry: Dictionary = cells[tile]
		map_image.set_pixelv(tile,Color(float(owner_indices.get(entry.owner,0))/255.0,float(entry.fill),ART.hue(state,int(entry.owner)),0 if state.is_blocked(tile) else 1))
	if changed_size or map_texture == null:
		map_texture = ImageTexture.create_from_image(map_image)
		tissue_material.set_shader_parameter("colony_map", map_texture)
		terrain_material.set_shader_parameter("colony_map", map_texture)
	else:
		map_texture.update(map_image)
	tissue_material.set_shader_parameter("board_size", Vector2(state.width,state.height))
	terrain_material.set_shader_parameter("board_size", Vector2(state.width,state.height))
	tissue_material.set_shader_parameter("tissue_span",Vector2(20,20) if state.territory_mode else Vector2.ZERO)

func _layout() -> void:
	if state == null or tissue == null:
		return
	var span: float = float(state.width+state.height)
	var half_width: float = minf((size.x-48.0)/span, (size.y-100.0)/(span*0.50))
	half_width = maxf(1.0 if state.territory_mode else 4.0, half_width)*zoom
	step_size = Vector2(half_width, half_width*0.50)
	var center := Vector2((state.width+state.height-2)*0.5*step_size.x, (state.height-state.width)*0.5*step_size.y)
	origin = size*0.5-center+Vector2(0,20)+pan
	terrain.size = size
	terrain_material.set_shader_parameter("canvas_size",size)
	terrain_material.set_shader_parameter("origin",origin)
	terrain_material.set_shader_parameter("step_size",step_size)
	terrain_material.set_shader_parameter("overview",state.territory_mode and step_size.x<4.0)
	tissue.size = size
	tissue_material.set_shader_parameter("canvas_size", size)
	tissue_material.set_shader_parameter("origin", origin)
	tissue_material.set_shader_parameter("step_size", step_size)
	for entry in organs.values():
		_position_organ(entry)
	landmarks.queue_redraw()
	if overlay != null:
		overlay.queue_redraw()

func project(tile: Vector2) -> Vector2:
	return origin+Vector2((tile.x+tile.y)*step_size.x, (tile.y-tile.x)*step_size.y)

func unproject(point: Vector2) -> Vector2:
	var p: Vector2 = (point-origin)/step_size
	return Vector2((p.x-p.y)*0.5,(p.y+p.x)*0.5)

func viewport_to_tile(point: Vector2) -> Vector2i:
	if state == null or not Rect2(Vector2.ZERO,size).has_point(point):
		return INVALID
	var cell := Vector2i((unproject(point)+Vector2(0.5,0.5)).floor())
	return cell if state.is_inside(cell) else INVALID

func handle_camera_input(event: InputEvent, point: Vector2, inside: bool) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = event.pressed and inside
			return inside or not event.pressed
		if inside and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var anchor: Vector2 = unproject(point)
			zoom = clampf(zoom*(1.15 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.15),0.65,24.0 if state.territory_mode else 3.5)
			_layout()
			pan += point-project(anchor)
			_layout()
			_sync_ghosts()
			return true
	if event is InputEventMouseMotion and dragging:
		pan += event.relative
		_layout()
		_sync_ghosts()
		return true
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		zoom = 1.0
		pan = Vector2.ZERO
		_layout()
		_sync_ghosts()
		return true
	return false

func _position_organ(entry: Dictionary) -> void:
	var sprite: Sprite2D = entry.sprite
	var height: float = float(ROLE_HEIGHTS[entry.role])*step_size.x
	var scale_factor: float = height/sprite.region_rect.size.y
	var fill: float = maxf(0.02,float(entry.fill))
	sprite.scale = Vector2(scale_factor,scale_factor*(0.55+0.45*fill))
	sprite.position = project(Vector2(entry.tile))-Vector2(sprite.region_rect.size.x*sprite.scale.x*0.5,height*(0.55+0.45*fill)*0.87)
	sprite.z_index = 10+int(entry.tile.y-entry.tile.x+state.width)*2
	sprite.material.set_shader_parameter("opacity", fill)

func _action_tile(action: Dictionary) -> Vector2i:
	if action.has("target"):
		return action.target
	var block: Dictionary = state.blocks.get(int(action.get("block_id", -1)), {})
	return block.get("pos", INVALID)

func _sync_ghosts() -> void:
	if ghosts == null or state == null:
		return
	for child in ghosts.get_children():
		child.free()
	var actions: Array = context.get("queued", []).duplicate()
	var hover: Dictionary = context.get("preview", {})
	var already_queued: bool = false
	for action in actions:
		if not hover.is_empty() and _action_tile(action) == _action_tile(hover):
			already_queued = true
	if not hover.is_empty() and not already_queued:
		actions.append(hover)
	for action in actions:
		var tile: Vector2i = _action_tile(action)
		var role: String = String(action.get("to_type",action.get("tile_type","basic")))
		if not state.is_inside(tile) or role not in ART.ROLES:
			continue
		var sprite: Sprite2D = ART.organ(role, ART.hue(state,int(action.get("owner",1))))
		ghosts.add_child(sprite)
		_position_organ({"sprite":sprite,"role":role,"tile":tile,"fill":1.0})
		sprite.material.set_shader_parameter("opacity", 0.40)
		sprite.material.set_shader_parameter("clock", clock)

func show_resolution(report: Dictionary) -> void:
	for attack in report.get("attack_events", []):
		var strike: Dictionary = attack.duplicate()
		strike.time = 0.9
		strikes.append(strike)
		if organs.has(attack.source_id):
			organs[attack.source_id].action = 1.0
			organs[attack.source_id].sprite.flip_h = project(Vector2(attack.to)).x < project(Vector2(attack.from)).x
	for event in report.get("combat_events", []):
		effects.append({"tile":event.tile,"text":"Dissolved" if event.kind=="dissolved" else "-%d" % int(event.amount),"time":1.6,"color":Color("ffd39a")})
		for entry in organs.values():
			if entry.tile == event.tile:
				entry.flash = 1.0
	for action in report.get("applied_actions", []):
		var tile: Vector2i = _action_tile(action)
		for entry in organs.values():
			if entry.tile == tile:
				entry.action = 1.0

func _process(delta: float) -> void:
	if state == null:
		return
	clock += delta
	tissue_material.set_shader_parameter("clock", clock)
	var changed: bool = false
	for tile in cells.keys():
		var entry: Dictionary = cells[tile]
		if not is_equal_approx(float(entry.fill),float(entry.target)):
			entry.fill = move_toward(float(entry.fill),float(entry.target),delta*2.6)
			changed = true
		if float(entry.fill)<=0.0 and float(entry.target)==0.0:
			cells.erase(tile)
	if changed:
		_update_map()
	for id in organs.keys():
		var entry: Dictionary = organs[id]
		entry.fill = move_toward(float(entry.fill),1.0 if entry.alive else 0.0,delta*2.6)
		entry.flash = maxf(0.0,float(entry.flash)-delta*2.0)
		entry.action = maxf(0.0,float(entry.action)-delta*1.4)
		if float(entry.fill)<=0.0 and not entry.alive:
			entry.sprite.queue_free()
			organs.erase(id)
			continue
		_position_organ(entry)
		entry.sprite.material.set_shader_parameter("clock", clock)
		entry.sprite.material.set_shader_parameter("damage_flash", entry.flash)
		entry.sprite.material.set_shader_parameter("action", sin(float(entry.action)*PI))
	var animate_overlay: bool = not effects.is_empty() or not strikes.is_empty()
	for effect in effects:
		effect.time -= delta
	effects = effects.filter(func(effect): return effect.time>0.0)
	for strike in strikes:
		strike.time -= delta
	strikes = strikes.filter(func(strike): return strike.time>0.0)
	if animate_overlay:
		overlay.queue_redraw()

func _diamond(tile: Vector2i, scale_: float = 1.0) -> PackedVector2Array:
	var p: Vector2 = project(Vector2(tile))
	return PackedVector2Array([p+Vector2(-step_size.x,0)*scale_,p+Vector2(0,-step_size.y)*scale_,p+Vector2(step_size.x,0)*scale_,p+Vector2(0,step_size.y)*scale_])

func _outline(canvas: CanvasItem, tile: Vector2i, color: Color, scale_: float = 0.94, width: float = 1.5) -> void:
	var points: PackedVector2Array = _diamond(tile,scale_)
	points.append(points[0])
	canvas.draw_polyline(points,color,width,true)

func _draw_landmarks() -> void:
	if state == null:
		return
	for resource in state.resource_nodes:
		if resource.get("consumed",false):
			continue
		var p: Vector2 = project(Vector2(resource.pos))
		var r: float = maxf(3.0,step_size.x*0.18)
		var color := Color("c7a453")
		if state.territory_mode and int(resource.get("controller",0))>0:
			color = Color.from_hsv(ART.hue(state,int(resource.controller)),0.5,1.0)
		landmarks.draw_colored_polygon(PackedVector2Array([p+Vector2(-r,0),p+Vector2(0,-r*1.4),p+Vector2(r,0),p+Vector2(0,r*0.6)]),color)
		if state.territory_mode:
			landmarks.draw_arc(p,r*2,0,TAU,16,color,2)
	if state.is_inside(state.entrance_tile):
		_outline(landmarks,state.entrance_tile,Color("749da1"),0.65)
	if state.door_hp>0 and state.is_inside(state.door_tile):
		var p: Vector2 = project(Vector2(state.door_tile))
		var r: float = step_size.x*0.46
		landmarks.draw_rect(Rect2(p-Vector2(r,step_size.x),Vector2(r*2.0,step_size.x)),Color("554b35"))
		landmarks.draw_rect(Rect2(p-Vector2(r*0.65,step_size.x*0.84),Vector2(r*1.3,step_size.x*0.84)),Color("e1b662"),false,2.0)

func _draw_overlay() -> void:
	if state == null:
		return
	var font: Font = ThemeDB.fallback_font
	var area: Rect2i = context.get("selection",Rect2i())
	if area.has_area():
		var start: Vector2 = Vector2(area.position)-Vector2(0.5,0.5)
		var end: Vector2 = Vector2(area.end)-Vector2(0.5,0.5)
		var points := PackedVector2Array([project(start),project(Vector2(end.x,start.y)),project(end),project(Vector2(start.x,end.y)),project(start)])
		overlay.draw_colored_polygon(points,Color(0.55,0.95,0.8,0.12))
		overlay.draw_polyline(points,Color("c3f4d4"),2)
	for order in context.get("orders",[]):
		_outline(overlay,order.target,Color("f0cb72"),1.3,2)
	for tile in context.get("valid", []):
		_outline(overlay,tile,Color(0.43,0.82,0.62,0.55),0.73,1.0)
	for tile in context.get("convert", []):
		_outline(overlay,tile,Color(0.45,0.8,0.96,0.6),0.86,1.0)
	var number: int = 0
	for action in context.get("queued", []):
		var tile: Vector2i = _action_tile(action)
		if not state.is_inside(tile):
			continue
		number += 1
		_outline(overlay,tile,Color("ffdf8b"),0.88,2.0)
		overlay.draw_string(font,project(Vector2(tile))+Vector2(-4,5),str(number),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("ffe6ac"))
	for action in context.get("intents", []):
		var tile: Vector2i = _action_tile(action)
		if state.is_inside(tile):
			_outline(overlay,tile,Color("e58291"),0.65,1.5)
	var hovered: Vector2i = context.get("hover",INVALID)
	var selected: Vector2i = context.get("selected",INVALID)
	if state.is_inside(selected):
		_outline(overlay,selected,Color("ffdfa0"),0.98,2.0)
	if state.is_inside(hovered):
		_outline(overlay,hovered,Color("f4f5dc") if String(context.get("invalid","")).is_empty() else Color("ec8f82"),1.0,2.0)
	for block in state.blocks.values():
		if int(block.hp)<int(block.max_hp) or block.pos==hovered or block.pos==selected:
			var p: Vector2 = project(Vector2(block.pos))+Vector2(-step_size.x*0.35,step_size.y*0.62)
			var width: float = step_size.x*0.7
			overlay.draw_rect(Rect2(p,Vector2(width,3)),Color("17211e"))
			overlay.draw_rect(Rect2(p,Vector2(width*clampf(float(block.hp)/maxf(1.0,float(block.max_hp)),0,1),3)),Color.from_hsv(ART.hue(state,int(block.owner)),0.45,0.95))
		var tier: int = int(block.get("upgrade_tier",0))
		if tier>0:
			var p: Vector2 = project(Vector2(block.pos))+Vector2(0,step_size.y*0.80)
			for i in range(tier):
				overlay.draw_circle(p+Vector2((i-(tier-1)*0.5)*5.0,0),1.6,Color("ffdb87"))
	if state.door_hp>0 and state.is_inside(state.door_tile):
		overlay.draw_string(font,project(Vector2(state.door_tile))+Vector2(-20,-step_size.x-6),"EXIT · %d" % state.door_hp,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e6c88c"))
	for strike in strikes:
		var start: Vector2 = project(Vector2(strike.from))-Vector2(0,step_size.x*0.6)
		var end: Vector2 = project(Vector2(strike.to))-Vector2(0,step_size.x*0.35)
		var progress: float = clampf((0.9-float(strike.time))/0.6,0,1)
		var color := Color.from_hsv(ART.hue(state,int(strike.owner)),0.4,1.0,minf(1.0,float(strike.time)*4.0))
		if strike.kind=="ranged":
			var point: Vector2 = start.lerp(end,progress)-Vector2(0,sin(progress*PI)*step_size.x*0.7)
			overlay.draw_line(point-Vector2(5,2),point,color,2.0,true)
			overlay.draw_circle(point,3.5,color)
		else:
			overlay.draw_line(start,start.lerp(end,sin(progress*PI*0.5)),color,2.5,true)
		if progress>=0.9:
			overlay.draw_arc(end,5.0+(1.0-float(strike.time)/0.3)*7.0,0,TAU,16,color,1.5,true)
	for effect in effects:
		var p: Vector2 = project(Vector2(effect.tile))+Vector2(-15,-step_size.x-(1.6-float(effect.time))*22)
		var color: Color = effect.color
		color.a = minf(1.0,float(effect.time)*3.0)
		overlay.draw_string_outline(font,p,effect.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,4,Color(0.05,0.08,0.07,color.a))
		overlay.draw_string(font,p,effect.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)
	overlay.draw_string(font,Vector2(12,size.y-12),"Scroll to zoom  ·  Middle-drag to pan  ·  Home to fit",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("829a90"))

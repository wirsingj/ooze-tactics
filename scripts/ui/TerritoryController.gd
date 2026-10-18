extends Control

const SCENARIO = preload("res://scripts/systems/TerritoryScenario.gd")
const RULES = preload("res://scripts/systems/TerritoryRules.gd")
const VIEW = preload("res://scripts/ui/ColonyRenderer.gd")
const ROLES = {"basic":"Advance","defense":"Defense","melee":"Melee","ranged":"Ranged","gather":"Harvest"}
const ROLE_HELP = {
	"basic":"Direct a broad front toward an area. It keeps spreading each turn until that area is occupied. Growth is shared across your active fronts; energy is reserved for organs.",
	"defense":"Hold a front with armored organs that block enemy shots and protect adjacent tissue. Drag a group first to choose its exposed edge.",
	"melee":"Breach enemy armor with attacks reaching 2 tiles along a row or column. Group orders prioritize the fighting edge.",
	"ranged":"Fire up to 8 tiles through clear ground. Group orders prefer positions behind the front. Adjacent enemies suppress these organs.",
	"gather":"Secure the area around a well, then extract from it. A narrow connection alone produces nothing. This front stays active until the well is secured."
}
var state: GameState
var turn = preload("res://scripts/systems/TerritoryTurn.gd").new()
var view: Control
var hud: Label
var detail: Label
var status: Label
var minimap: Control
var orders: Array = []
var preview: Array = []
var selected_role: String = "basic"
var selection := Rect2i()
var drag_start := Vector2.ZERO
var drag_tile := Vector2i(-1,-1)
var selecting: bool = false
var finished: bool = false
var resolving: bool = false
var buttons: Array[Button] = []
var plan_buttons: Array[Button] = []
var cancel_buttons: Array[Button] = []
var plans_title: Label
var new_front_button: Button
var active_order: int = -1
var preview_cost: int = 0
var preview_growth: int = 0
var plan_notices: Array = []
var right_dragging: bool = false
var right_start := Vector2.ZERO
var right_moved: bool = false
var side_width: float = 230.0
var painted_world: GameState

class MiniMap:
	extends Control
	var game: Control
	var painted_state: GameState
	var map_texture: ImageTexture
	func sync_world(s: GameState) -> void:
		if painted_state==s:
			return
		painted_state = s
		var pixels := Image.create(s.width,s.height,false,Image.FORMAT_RGBA8)
		pixels.fill(Color("0a1718"))
		var colors: Dictionary = {}
		for owner in s.players:
			colors[owner] = Color.from_hsv(preload("res://scripts/ui/ColonyArt.gd").hue(s,owner),0.7,0.95)
		for block in s.blocks.values():
			pixels.set_pixelv(block.pos,colors[block.owner])
		if map_texture==null or map_texture.get_size()!=Vector2(s.width,s.height):
			map_texture = ImageTexture.create_from_image(pixels)
		else:
			map_texture.update(pixels)
		queue_redraw()
	func _draw() -> void:
		if game.state==null:
			return
		var s: GameState = game.state
		var scale_: Vector2 = size/Vector2(s.width,s.height)
		if map_texture!=null:
			draw_texture_rect(map_texture,Rect2(Vector2.ZERO,size),false)
		for node in s.resource_nodes:
			draw_circle(Vector2(node.pos)*scale_,2.5,Color("e9ca75"))
		var corners := PackedVector2Array()
		for p in [Vector2.ZERO,Vector2(game.view.size.x,0),game.view.size,Vector2(0,game.view.size.y),Vector2.ZERO]:
			corners.append(game.view.unproject(p)*scale_)
		draw_polyline(corners,Color("d9f6e3"),1)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			game.focus_tile(Vector2i(event.position/size*Vector2(game.state.width,game.state.height)),false)
			accept_event()

func _ready() -> void:
	state = SCENARIO.build()
	_fit_window()
	_build_ui()
	resized.connect(_layout)
	get_window().size_changed.connect(_layout)
	_layout()
	_refresh()
	_home_view()

func _fit_window() -> void:
	if DisplayServer.get_name()=="headless":
		return
	var window := get_window()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	var fitting: Vector2i = (usable.size-Vector2i(40,80)).max(Vector2i(800,560))
	if window.size.x>fitting.x or window.size.y>fitting.y:
		window.size = window.size.min(fitting)
		window.position = usable.position+(usable.size-window.size)/2

func _button(text_: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	add_child(button)
	return button

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1214")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	view = VIEW.new()
	add_child(view)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size",20)
	add_child(hud)
	status = Label.new()
	status.add_theme_font_size_override("font_size",15)
	status.add_theme_color_override("font_color",Color("e9cf8d"))
	add_child(status)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",14)
	add_child(detail)
	minimap = MiniMap.new()
	minimap.game = self
	minimap.clip_contents = true
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(minimap)
	var number: int = 0
	for role in ROLES:
		number += 1
		var button := _button("%d  %s" % [number,ROLES[role]],_select_role.bind(role))
		button.toggle_mode = true
		button.tooltip_text = ROLE_HELP[role]+"\nDrag a group first for a priced role assignment. Existing organs are preserved."
		buttons.append(button)
	for entry in [["End Turn  [Enter]",_end_turn],["Clear Plans",_clear],["Overview  [Home]",_overview],["Your Colony  [C]",_home_view],["Menu",func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")]]:
		buttons.append(_button(entry[0],entry[1]))
	plans_title = Label.new()
	plans_title.text = "YOUR FRONTS"
	plans_title.add_theme_color_override("font_color",Color("a9c3b6"))
	add_child(plans_title)
	for i in range(RULES.ORDER_LIMIT):
		var button := _button("",_select_plan.bind(i))
		button.toggle_mode = true
		plan_buttons.append(button)
		cancel_buttons.append(_button("×",_remove_plan.bind(i)))
	new_front_button = _button("+ Add front  [Shift-click]",_new_front)

func _layout() -> void:
	if view==null:
		return
	# Godot keeps the configured 1600×900 logical canvas when the desktop
	# window is smaller. Fit the HUD to the visible client area as well, or the
	# minimap and action buttons are cut off at the right and bottom edges.
	var page := size
	if DisplayServer.get_name()!="headless":
		page = page.min(Vector2(get_window().size))
	side_width = clampf(page.x*0.17,200,250)
	var side_x: float = page.x-side_width-12
	view.position = Vector2(12,92)
	view.size = Vector2(maxf(300,side_x-24),maxf(250,page.y-172))
	hud.position = Vector2(16,14)
	hud.add_theme_font_size_override("font_size",20 if page.x>=1200 else 16)
	status.position = Vector2(16,52)
	status.size = Vector2(page.x-32,34)
	status.clip_text = true
	minimap.position = Vector2(side_x,96)
	minimap.size = Vector2(side_width,clampf(page.y*0.14,90,140))
	plans_title.position = Vector2(side_x,minimap.position.y+minimap.size.y+14)
	for i in range(3):
		plan_buttons[i].position = Vector2(side_x,plans_title.position.y+26+i*34)
		plan_buttons[i].size = Vector2(side_width-36,30)
		cancel_buttons[i].position = plan_buttons[i].position+Vector2(side_width-32,0)
		cancel_buttons[i].size = Vector2(32,30)
	new_front_button.position = Vector2(side_x,plans_title.position.y+132)
	new_front_button.size = Vector2(side_width,30)
	detail.position = Vector2(side_x,new_front_button.position.y+42)
	detail.size = Vector2(side_width,maxf(30,page.y-224-detail.position.y))
	detail.text = "Occupy 60% of a well’s zone.\nSecured allied wells within 60 tiles add +2 income per link.\nFronts continue each turn.\n\nClick: redirect selected front.\nShift-click: add another.\nDrag a group → choose a role.\n\nWASD / right-drag: pan.\nScroll: zoom. Minimap: jump."
	if detail.size.y<190:
		detail.text = "Linked wells within 60 tiles: +2 income/link.\nFronts continue each turn.\nShift-click adds another.\nDrag group → choose role.\nWASD / right-drag: pan."
	if detail.size.y<95:
		detail.text = "Linked wells: +2 income/link.\nShift-click: add front.\nWASD / right-drag: pan."
	for i in range(5):
		buttons[i].position = Vector2(12+i*(view.size.x/5),page.y-66)
		buttons[i].size = Vector2(view.size.x/5-5,52)
		buttons[i].add_theme_font_size_override("font_size",16 if page.x>=1200 else 13)
	for i in range(5,10):
		buttons[i].position = Vector2(side_x,page.y-208+(i-5)*39)
		buttons[i].size = Vector2(side_width,34)

func focus_tile(tile: Vector2i, closer: bool) -> void:
	if closer:
		view.zoom = 7.0
	view._layout()
	view.pan += view.size*0.5-view.project(Vector2(tile))
	view._layout()
	minimap.queue_redraw()

func _home_view() -> void:
	focus_tile(Vector2i(48,42),true)

func _overview() -> void:
	view.zoom = 1.0
	view.pan = Vector2.ZERO
	view._layout()
	minimap.queue_redraw()

func _select_role(role: String) -> void:
	selected_role = role
	if selection.has_area() and role!="basic":
		_queue_order(selection.get_center(),selection,true)
		selection = Rect2i()
	else:
		_refresh(false)

func _new_front() -> void:
	active_order = -1
	selection = Rect2i()
	_refresh(false)
	status.text = "Choose a destination for a new front. Existing fronts will keep their orders."

func _select_plan(index: int) -> void:
	if index>=orders.size():
		return
	active_order = index
	selected_role = orders[index].tile_type
	focus_tile(orders[index].target,false)
	_refresh(false)

func _remove_plan(index: int) -> void:
	if index<0 or index>=orders.size() or resolving:
		return
	orders.remove_at(index)
	active_order = mini(index,orders.size()-1)
	_refresh()

func _queue_order(target: Vector2i, area: Rect2i = Rect2i(), add_front: bool = false) -> void:
	if finished or resolving or not state.players[1].alive:
		return
	if not state.is_inside(target) or state.is_blocked(target):
		status.text = "Choose open ground or a well."
		return
	var role: String = selected_role
	if not area.has_area() and role in ["basic","gather"]:
		var best: float = INF
		var site: Vector2i = target
		for node in state.resource_nodes:
			var distance: float = Vector2(node.pos).distance_to(Vector2(target))
			if distance<best:
				best = distance
				site = node.pos
		if role=="gather" or best<=RULES.SITE_RADIUS+2:
			target = site
			role = "gather"
	var order: Dictionary = {"type":"territory_order","owner":1,"tile_type":role,"target":target}
	if area.has_area():
		order.selection = area
	if not add_front and active_order>=0 and active_order<orders.size():
		orders[active_order] = order
	elif orders.size()<RULES.ORDER_LIMIT:
		orders.append(order)
		active_order = orders.size()-1
	else:
		status.text = "Three fronts are active. Select one to redirect it, or use × to cancel."
		return
	selected_role = role
	_refresh()

func _clear() -> void:
	orders.clear()
	active_order = -1
	selection = Rect2i()
	_refresh()

func _end_turn() -> void:
	if finished or resolving:
		return
	resolving = true
	status.text = "Resolving fronts…"
	await get_tree().process_frame
	var committed: Array = orders.duplicate(true)
	committed.append_array(turn.ai_orders(state))
	var result: Dictionary = turn.resolve(state,committed)
	state = result.state
	orders = orders.filter(func(order): return not turn.orders.is_complete(state,order))
	active_order = mini(active_order,orders.size()-1)
	selection = Rect2i()
	finished = result.outcome.status!="ongoing"
	resolving = false
	_refresh()
	view.show_resolution(state.last_resolution_report)
	if finished:
		status.text = "VICTORY — territory secured" if result.outcome.status=="victory" else "DEFEAT — the rival colonies control the battlefield"

func _refresh(replan: bool = true) -> void:
	if replan:
		var planned: Dictionary = turn.orders.expand(state,orders)
		preview = planned.actions
		preview_cost = int(state.players[1].nutrients)-int(planned.state.players[1].nutrients)
		preview_growth = int(planned.growth.get(1,0))
		plan_notices = planned.notices
	var income: int = int(Economy.new().compute_income_and_upkeep(state).delta[1])
	hud.text = "TERRITORY WAR  ·  Turn %d  ·  Energy %d (+%d)  ·  Control %d : %d / %d" % [state.turn_index,state.players[1].nutrients,income,state.team_scores[1],state.team_scores[2],RULES.WIN_SCORE]
	status.text = "%s  ·  Next turn: spread %d/%d, %d organs  ·  Energy cost %d" % [ROLES[selected_role],preview_growth,RULES.GROWTH_LIMIT,preview.size()-preview_growth,preview_cost]
	if orders.is_empty():
		status.text = "Choose a destination. Fronts keep advancing each turn. Drag a group to assign organs."
	elif not plan_notices.is_empty() and preview.is_empty():
		status.text = String(plan_notices[0])+" — redirect this front or secure its connection."
	for i in range(5):
		buttons[i].set_pressed_no_signal(ROLES.keys()[i]==selected_role)
	for i in range(3):
		var exists: bool = i<orders.size()
		plan_buttons[i].visible = exists
		cancel_buttons[i].visible = exists
		if exists:
			var order: Dictionary = orders[i]
			var ongoing: bool = order.tile_type in ["basic","gather"] and not order.has("selection")
			plan_buttons[i].text = "%d  %s%s" % [i+1,ROLES[order.tile_type]," ↻" if ongoing else " · once"]
			plan_buttons[i].set_pressed_no_signal(i==active_order)
			plan_buttons[i].tooltip_text = "Select this front, then click to redirect it."
	new_front_button.disabled = orders.size()>=RULES.ORDER_LIMIT
	buttons[5].disabled = finished or resolving
	var display_orders: Array = orders.duplicate(true)
	for i in range(display_orders.size()):
		display_orders[i].label = "%d  %s" % [i+1,ROLES[display_orders[i].tile_type]]
		display_orders[i].active = i==active_order
	var context: Dictionary = {"queued":preview,"selection":selection,"orders":display_orders}
	if painted_world==state:
		view.sync_context(context)
	else:
		painted_world = state
		view.sync_world(state,context)
	minimap.sync_world(state)
	minimap.queue_redraw()

func _process(delta: float) -> void:
	if view==null or resolving or not get_window().has_focus():
		return
	var direction := Vector2(float(Input.is_key_pressed(KEY_A))-float(Input.is_key_pressed(KEY_D)),float(Input.is_key_pressed(KEY_W))-float(Input.is_key_pressed(KEY_S)))
	if direction.length_squared()>0:
		view.pan += direction.normalized()*750.0*delta
		view._layout()
		view._sync_ghosts()
		minimap.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if view==null or resolving:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
			_end_turn()
			get_viewport().set_input_as_handled()
			return
		if event.keycode>=KEY_1 and event.keycode<=KEY_5:
			_select_role(ROLES.keys()[event.keycode-KEY_1])
			return
		if event.keycode==KEY_C:
			_home_view()
			return
		if event.keycode==KEY_ESCAPE:
			selection = Rect2i()
			active_order = -1
			_refresh(false)
			return
	var local: Vector2 = get_global_mouse_position()-view.global_position
	if event is InputEventMouse:
		local = event.position-view.global_position
	var inside: bool = Rect2(Vector2.ZERO,view.size).has_point(local)
	if view.handle_camera_input(event,local,inside):
		minimap.queue_redraw()
		return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT:
			if event.pressed and inside:
				right_dragging = true
				right_start = local
				right_moved = false
			elif not event.pressed and right_dragging:
				right_dragging = false
				if not right_moved:
					if selection.has_area():
						selection = Rect2i()
						_refresh(false)
					else:
						_remove_plan(active_order)
			return
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and inside:
				selecting = true
				drag_start = local
				drag_tile = view.viewport_to_tile(local)
			elif not event.pressed and selecting:
				selecting = false
				var tile: Vector2i = view.viewport_to_tile(local)
				if tile.x<0 or drag_tile.x<0:
					return
				if drag_start.distance_to(local)>6:
					selection = Rect2i(drag_tile.min(tile),(drag_tile-tile).abs()+Vector2i.ONE)
					_refresh(false)
					status.text = "Group selected. Choose Defense, Melee, Ranged, or Harvest to preview an assignment."
				else:
					selection = Rect2i()
					_queue_order(tile,Rect2i(),event.shift_pressed)
	if event is InputEventMouseMotion:
		if right_dragging:
			right_moved = right_moved or right_start.distance_to(local)>4
			if right_moved:
				view.pan += event.relative
				view._layout()
				view._sync_ghosts()
				minimap.queue_redraw()
		elif selecting:
			var tile: Vector2i = view.viewport_to_tile(local)
			if tile.x>=0 and drag_tile.x>=0:
				selection = Rect2i(drag_tile.min(tile),(drag_tile-tile).abs()+Vector2i.ONE)
				view.context.selection = selection
				view.overlay.queue_redraw()

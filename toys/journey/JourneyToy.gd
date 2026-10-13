# Journey toy: one long sideways route through three regions, built on the jump toy.
# Movement, bash and tuning are the jump toy's own (movement_tuning.json, unchanged).
# Added here: region colors and parallax sky, region banners, camera lead,
# automatic checkpoints on safe ground, an end card and a journey log.
extends "res://toys/movement/MovementToy.gd"
const JOURNEY_PATH: String = "res://toys/journey/journey.json"
var journey: Dictionary
var regions: Array = []
var region_index: int = -1
var region_entered_ms: int = 0
var region_seconds: Dictionary = {}
var floor_time: float = 0
var lead_offset: float = 0
var finished: bool = false
var surface_tiles: Array[Rect2] = []
var water_spans: Array[Vector2] = []
var sky: Node2D
var ambient: Node2D
var banner: Label
var banner_sub: Label
var banner_tween: Tween
var end_panel: PanelContainer
var end_label: Label
var hint: Label

func _ready() -> void:
	var path: String = OS.get_environment("JOURNEY_TEST_CONFIG")
	if path.is_empty(): path = JOURNEY_PATH
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("regions") is Array or parsed.regions.is_empty() or not parsed.get("room") is String:
		push_error("journey.json needs room and a non-empty regions list")
		get_tree().quit(1)
		return
	journey = parsed
	regions = journey.regions
	room_directory = path.get_base_dir()
	room_filter = PackedStringArray([journey.room])
	super._ready()
	DisplayServer.window_set_title("여행 구간 — 한 줄로 이어진 길")
	log_data["regions"] = {}
	rooms_finished.connect(_finish)
	_build_journey_ui()
	_enter_region(0)

func load_room(index: int, reload_room: bool = false) -> void:
	super.load_room(index,reload_room)
	if regions.is_empty(): return
	_dress_room()

# Recolor tiles by region and lay a grass strip on every walkable top edge.
func _dress_room() -> void:
	var tile: float = tuning.tile_size
	var lines: PackedStringArray = FileAccess.get_file_as_string(room_directory+"/"+rooms[room_index]).strip_edges(false,true).split("\n")
	surface_tiles.clear()
	water_spans.clear()
	for row: int in lines.size():
		var line: String = lines[row].trim_suffix("\r")
		for col: int in line.length():
			if line[col] != "#": continue
			var above: String = lines[row-1].trim_suffix("\r")[col] if row > 0 and col < lines[row-1].trim_suffix("\r").length() else "."
			if above != "#": surface_tiles.append(Rect2(Vector2(col,row)*tile,Vector2(tile,tile)))
	# Gaps in the bottom row are pits; region one shows them as water.
	var bottom: String = lines[lines.size()-1].trim_suffix("\r")
	var start: int = -1
	for col: int in bottom.length()+1:
		var open: bool = col < bottom.length() and bottom[col] != "#"
		if open and start < 0: start = col
		elif not open and start >= 0:
			water_spans.append(Vector2(start,col)*tile)
			start = -1
	for body: Node in geometry.get_children():
		if not body is StaticBody2D: continue
		var one_way: bool = false
		for child: Node in body.get_children():
			if child is CollisionShape2D: one_way = child.one_way_collision
		for child: Node in body.get_children():
			if child is Polygon2D: child.color = blended(body.position.x,"platform" if one_way else "ground")
	for rect: Rect2 in surface_tiles:
		var grass: Polygon2D = Polygon2D.new()
		var top: float = rect.position.y
		grass.polygon = PackedVector2Array([Vector2(rect.position.x,top),Vector2(rect.end.x,top),Vector2(rect.end.x,top+5),Vector2(rect.position.x,top+5)])
		grass.color = blended(rect.get_center().x,"grass")
		geometry.add_child(grass)

func region_at(x: float) -> int:
	var tile_x: float = x/float(tuning.tile_size)
	var found: int = 0
	for index: int in regions.size():
		if tile_x >= float(regions[index].from_tile): found = index
	return found

# Colors cross-fade over blend_tiles around each region boundary.
func blended(x: float, key: String) -> Color:
	var tile_x: float = x/float(tuning.tile_size)
	var half: float = float(journey.get("blend_tiles",14))/2
	var index: int = region_at(x)
	var color: Color = Color(str(regions[index][key]))
	if index+1 < regions.size():
		var edge: float = float(regions[index+1].from_tile)
		if tile_x > edge-half: color = color.lerp(Color(str(regions[index+1][key])),clampf((tile_x-(edge-half))/(half*2),0,0.5))
	if index > 0:
		var edge: float = float(regions[index].from_tile)
		if tile_x < edge+half: color = Color(str(regions[index-1][key])).lerp(color,clampf(0.5+(tile_x-edge)/(half*2),0.5,1))
	return color

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if finished or respawning or not is_instance_valid(player): return
	_auto_checkpoint(delta)
	var index: int = region_at(player.position.x)
	if index != region_index: _enter_region(index)

# Save the spot after standing briefly on ground that supports both feet.
func _auto_checkpoint(delta: float) -> void:
	if not player.is_on_floor() or player.state == GatePlayer.State.DASH or is_instance_valid(motion.target):
		floor_time = 0
		return
	floor_time += delta
	if floor_time < float(journey.get("checkpoint_floor_time",0.15)): return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var feet: float = player.position.y+player.body_size.y/2+4
	for side: float in [-1.0,1.0]:
		var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query.position = Vector2(player.position.x+side*(player.body_size.x/2+6),feet)
		if space.intersect_point(query).is_empty(): return
	checkpoint = player.position

func _enter_region(index: int) -> void:
	var now: int = Time.get_ticks_msec()
	if region_index >= 0:
		var name: String = regions[region_index].name
		region_seconds[name] = float(region_seconds.get(name,0))+(now-region_entered_ms)/1000.0
	region_entered_ms = now
	var first: bool = region_index < 0 or index > region_index and not log_data.regions.has(regions[index].name)
	region_index = index
	if not log_data.regions.has(regions[index].name): log_data.regions[regions[index].name] = 0
	if first:
		if index > 0: Sfx.play("checkpoint")
		banner.text = regions[index].name
		banner_sub.text = regions[index].subtitle
		if is_instance_valid(banner_tween): banner_tween.kill()
		banner.get_parent().modulate.a = 0
		banner_tween = create_tween().set_ignore_time_scale(true)
		banner_tween.tween_property(banner.get_parent(),"modulate:a",1.0,0.8)
		banner_tween.tween_interval(2.2)
		banner_tween.tween_property(banner.get_parent(),"modulate:a",0.0,1.2)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(player) or regions.is_empty(): return
	var viewport: Vector2 = get_viewport_rect().size
	var half: Vector2 = viewport/camera.zoom.x/2
	var target: float = float(journey.get("camera_lead",110))*player.facing
	lead_offset = lerpf(lead_offset,target,clampf(float(journey.get("camera_lead_speed",2.5))*delta,0,1))
	if room_size.x > half.x*2: camera.position.x = clampf(camera.position.x+lead_offset,half.x,room_size.x-half.x)
	sky.queue_redraw()
	ambient.queue_redraw()

func _draw() -> void:
	if not regions.is_empty():
		var tile: float = float(tuning.tile_size)
		for span: Vector2 in water_spans:
			var level: float = room_size.y-tile*3.6
			draw_rect(Rect2(span.x,level,span.y-span.x,room_size.y-level+tile*4),blended((span.x+span.y)/2,"water"))
	super._draw()

func _finish() -> void:
	if finished: return
	finished = true
	_enter_region(region_index)
	player.controls.set_blocked(true)
	player.velocity = Vector2.ZERO
	var total: float = (Time.get_ticks_msec()-started)/1000.0
	var parts: PackedStringArray = []
	for region: Dictionary in regions:
		parts.append("%s %.0f초" % [region.name,float(region_seconds.get(region.name,0))])
	end_label.text = "고개 너머\n\n%d분 %02d초 · 떨어짐 %d번 · 튕기기 %d번\n%s\n\nEnter 또는 버튼으로 처음부터" % [int(total)/60,int(total)%60,log_data.deaths,log_data.bash_count," · ".join(parts)]
	end_panel.show()
	write_log()

func _restart() -> void:
	get_tree().reload_current_scene()

func _unhandled_key_input(event: InputEvent) -> void:
	if finished and event.is_pressed() and not event.is_echo() and event.keycode in [KEY_ENTER,KEY_KP_ENTER]:
		_restart()
		return
	super._unhandled_key_input(event)

func _build_journey_ui() -> void:
	# The jump toy's debug lines stay available on F2/Tab, but the route shows only the buttons.
	for child: Node in status.get_parent().get_children():
		if child is Label: child.hide()
		elif child is Control: child.modulate.a = 0.55
	var back: CanvasLayer = CanvasLayer.new()
	back.layer = -10
	add_child(back)
	sky = JourneySky.new()
	sky.world = self
	back.add_child(sky)
	ambient = JourneyAmbient.new()
	ambient.world = self
	ambient.z_index = 20
	add_child(ambient)
	var front: CanvasLayer = CanvasLayer.new()
	front.layer = 5
	add_child(front)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.position.y = 90
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.modulate.a = 0
	front.add_child(box)
	banner = Label.new()
	banner.add_theme_font_size_override("font_size",44)
	banner.add_theme_color_override("font_shadow_color",Color(0,0,0,0.5))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(banner)
	banner_sub = Label.new()
	banner_sub.add_theme_font_size_override("font_size",20)
	banner_sub.add_theme_color_override("font_shadow_color",Color(0,0,0,0.5))
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(banner_sub)
	box.resized.connect(func() -> void: box.position.x = (get_viewport_rect().size.x-box.size.x)/2)
	hint = Label.new()
	hint.text = "→ 쭉 가면 된다 · Space 점프 · Shift 대시 · K 튕기기 · 떨어지면 방금 밟은 땅에서 다시"
	hint.add_theme_color_override("font_shadow_color",Color(0,0,0,0.6))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20,get_viewport_rect().size.y-40)
	front.add_child(hint)
	var hint_tween: Tween = create_tween().set_ignore_time_scale(true)
	hint_tween.tween_interval(12)
	hint_tween.tween_property(hint,"modulate:a",0.0,2)
	end_panel = PanelContainer.new()
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	front.add_child(end_panel)
	var column: VBoxContainer = VBoxContainer.new()
	end_panel.add_child(column)
	end_label = Label.new()
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size",22)
	column.add_child(end_label)
	var again: Button = Button.new()
	again.text = "처음부터"
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(_restart)
	column.add_child(again)
	end_panel.resized.connect(func() -> void: end_panel.position = (get_viewport_rect().size-end_panel.size)/2)
	end_panel.hide()

func write_log() -> void:
	if log_data.is_empty() or logged or regions.is_empty(): return
	var path: String = OS.get_environment("JOURNEY_TEST_LOG")
	if path.is_empty(): path = "user://toy_journey_log.jsonl"
	var file: FileAccess = FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if not file:
		push_error("Cannot write journey log")
		return
	var now: int = Time.get_ticks_msec()
	var seconds: Dictionary = region_seconds.duplicate()
	if not finished and region_index >= 0:
		var name: String = regions[region_index].name
		seconds[name] = float(seconds.get(name,0))+(now-region_entered_ms)/1000.0
	file.seek_end()
	file.store_line(JSON.stringify({"started_at":log_data.started_at,"finished":finished,"duration_sec":(now-started)/1000.0,"reached":regions[maxi(region_index,0)].name,"region_sec":seconds,"falls":log_data.deaths,"bash_count":log_data.bash_count,"wall_jump_count":log_data.wall_jump_count,"f7_reloads":log_data.f7_reloads}))
	file.flush()
	logged = true

# Screen-space sky and two parallax hill bands, colored by where the camera is.
class JourneySky extends Node2D:
	var world: Node2D
	func _draw() -> void:
		var size: Vector2 = get_viewport_rect().size
		var center: Vector2 = world.camera.get_screen_center_position()
		var top: Color = world.blended(center.x,"sky_top")
		var bottom: Color = world.blended(center.x,"sky_bottom")
		var bands: int = 24
		for i: int in bands:
			draw_rect(Rect2(0,size.y*i/bands,size.x,size.y/bands+1),top.lerp(bottom,float(i)/(bands-1)))
		var zoom: float = world.camera.zoom.x
		var vertical: float = (center.y-world.room_size.y*0.6)*zoom
		_hills(size,center.x*zoom*0.18,size.y*0.62-vertical*0.15,46,world.blended(center.x,"hill_far"),0.006,0.013)
		_hills(size,center.x*zoom*0.42,size.y*0.78-vertical*0.35,38,world.blended(center.x,"hill_near"),0.011,0.023)
	func _hills(size: Vector2, offset: float, base: float, amplitude: float, color: Color, f1: float, f2: float) -> void:
		# Thin quads per column: no triangulation, safe when the band dips below the screen.
		var step: float = 8
		var x: float = 0
		var height: Callable = func(at: float) -> float: return base-amplitude*(0.6*sin((at+offset)*f1)+0.4*sin((at+offset)*f2+1.7))
		while x <= size.x:
			var a: float = height.call(x)
			var b: float = height.call(x+step)
			var bottom: float = maxf(size.y,maxf(a,b))+1
			draw_primitive(PackedVector2Array([Vector2(x,a),Vector2(x+step,b),Vector2(x+step,bottom),Vector2(x,bottom)]),PackedColorArray([color,color,color,color]),PackedVector2Array())
			x += step

# A few drifting specks in world space: water glints, fireflies, wind petals.
class JourneyAmbient extends Node2D:
	var world: Node2D
	func _draw() -> void:
		var center: Vector2 = world.camera.get_screen_center_position()
		var half: Vector2 = world.get_viewport_rect().size/world.camera.zoom.x/2
		var kind: String = str(world.regions[world.region_at(center.x)].ambient)
		var t: float = Time.get_ticks_msec()/1000.0
		for i: int in 34:
			var seed_x: float = fposmod(i*97.31,1.0)
			var seed_y: float = fposmod(i*53.77,1.0)
			var p: Vector2
			var color: Color
			var radius: float = 2
			match kind:
				"firefly":
					p = Vector2(fposmod(seed_x*half.x*2+sin(t*0.7+i)*30,half.x*2),fposmod(seed_y*half.y*2+cos(t*0.5+i*1.3)*20,half.y*2))
					color = Color(0.85,1,0.55,0.35+0.35*sin(t*2.3+i*2.1))
					radius = 2.4
				"petal":
					p = Vector2(fposmod(seed_x*half.x*2-t*(70+i*3),half.x*2),fposmod(seed_y*half.y*2+t*(18+i)+sin(t*1.5+i)*12,half.y*2))
					color = Color(1,0.86,0.82,0.55)
					radius = 2.2
				_:
					p = Vector2(fposmod(seed_x*half.x*2+t*6,half.x*2),half.y*2*(0.55+0.45*seed_y))
					color = Color(1,1,0.92,0.25+0.3*sin(t*3+i*1.7))
					radius = 1.6
			draw_circle(center-half+p,radius,color)

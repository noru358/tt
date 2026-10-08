extends "res://scripts/arena/TrainingArena.gd"
var boss: Node2D
var rules: Dictionary
var intro: float
var elapsed: float = 0
var ended: bool = false
var boss_hp: ProgressBar
var stagger_bar: ProgressBar
var player_hp: ProgressBar
var dash_bar: ProgressBar
var boss_label: Label
var intro_label: Label
var result_screen: PanelContainer
var run_token: String = ""
var debug_used: bool = false
var battle_canvas: CanvasLayer
func _ready() -> void:
	Feedback.debug_used = false
	debug_used = Tuning.combat_modified() or Feedback.invincible or not is_equal_approx(Feedback.base_speed,1)
	Tuning.changed.connect(func() -> void:
		if not ended: debug_used = true)
	process_physics_priority = 100
	run_token = str(Time.get_unix_time_from_system())+":"+str(Time.get_ticks_usec())
	rules = DataRegistry.documents["battle.json"]
	var data: Dictionary = DataRegistry.get_boss(GameState.selected_boss if GameState.progression_run else rules["boss_id"])
	arena = data["arena"].duplicate(true)
	arena["platform_thickness"] = rules["platform_thickness"]
	var camera: Camera2D = Camera2D.new()
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position = Vector2(960,540)
	add_child(camera)
	Feedback.camera = camera
	_static_rect(Rect2(0,arena["floor_y"],1920,1080-float(arena["floor_y"])),false)
	_static_rect(Rect2(-100,0,100+float(arena["left"]),1080),false)
	_static_rect(Rect2(arena["right"],0,2020-float(arena["right"]),1080),false)
	for platform: Dictionary in arena["platforms"]:
		_static_rect(Rect2(platform["x"],platform["y"],platform["w"],arena["platform_thickness"]),true)
	player = load("res://scenes/player/Player.tscn").instantiate()
	player.use_loadout = GameState.progression_run
	player.position = Vector2(rules["player_spawn"][0],rules["player_spawn"][1])
	add_child(player)
	boss = load("res://scenes/boss/Boss.tscn").instantiate()
	boss.data = data
	boss.position = Vector2(rules["boss_spawn"][0],rules["boss_spawn"][1])
	add_child(boss)
	intro = rules["intro_duration"]
	player.controls.set_blocked(true)
	_build_battle_ui()
	player.died.connect(func() -> void: finish(false))
	boss.died.connect(func() -> void: finish(true))
	debug_panel = load("res://scenes/ui/DebugPanel.tscn").instantiate()
	add_child(debug_panel)
	debug_panel.toolbar.position.y = 255
	debug_panel.weapon_bar.position.y = 320
	debug_panel.live_readout.position.y = 377
	debug_panel.practice_buttons["허수아비 공격"].hide()
	debug_panel.practice_buttons["다시 연습"].text = "다시 도전"
	debug_panel.practice_buttons["닫고 연습"].text = "재개"
	_add_hub_buttons()
	debug_panel.toggled.connect(func(open: bool) -> void:
		player.controls.set_blocked(open or intro > 0 or ended)
		if open:
			player.clear_action_intent()
			Feedback.clear_transients())
	if "--open-panel" in OS.get_cmdline_user_args() and not get_tree().has_meta("initial_panel_shown"):
		get_tree().set_meta("initial_panel_shown",true)
		debug_panel.toggle()
	if GameState.progression_run:
		for button: Button in debug_panel.quick_weapons.values(): button.disabled = true
		debug_panel.weapon_select.disabled = true
		debug_panel.weapon_bar.get_child(0).text = "장착은 허브에서 · 미리 사용은 연습에서"
	queue_redraw()
func _label(parent: Node, text: String, point: Vector2, font_size: int = 24) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size",font_size)
	parent.add_child(label)
	return label
func _bar(parent: Node, point: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.position = point
	bar.size = dimensions
	bar.show_percentage = false
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.13,0.17,0.22)
	bar.add_theme_stylebox_override("background",background)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill",fill)
	parent.add_child(bar)
	return bar
func _build_battle_ui() -> void:
	battle_canvas = CanvasLayer.new()
	add_child(battle_canvas)
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic"])
	theme.default_font = font
	theme.default_font_size = 24
	root.theme = theme
	battle_canvas.add_child(root)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.size = Vector2(1920,415)
	backdrop.color = Color(0.035,0.045,0.065,0.98)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	_label(root,("실제 게임 · "+boss.data["name"]) if GameState.progression_run else ("연습 모드 · "+boss.data["name"]+" / 보상 없음"),Vector2(44,22),32)
	hud = _label(root,"",Vector2(44,75))
	player_hp = _bar(root,Vector2(44,115),Vector2(510,18),Color(0.25,0.9,0.75))
	dash_bar = _bar(root,Vector2(44,148),Vector2(170,10),Color(0.4,0.7,1))
	_label(root,"대시",Vector2(230,136),20)
	boss_label = _label(root,"",Vector2(780,28),28)
	boss_hp = _bar(root,Vector2(780,78),Vector2(1096,30),Color(0.93,0.43,0.25))
	boss_hp.max_value = boss.data["max_hp"]
	for phase: Dictionary in boss.data["phases"]:
		if float(phase["hp_above"]) <= 0: continue
		var tick: ColorRect = ColorRect.new()
		tick.color = Color.WHITE
		tick.position = Vector2(1096*float(phase["hp_above"])-1,0)
		tick.size = Vector2(2,30)
		boss_hp.add_child(tick)
	stagger_bar = _bar(root,Vector2(780,122),Vector2(1096,10),Color(0.7,0.8,1))
	stagger_bar.max_value = boss.data["stagger"]["threshold"]
	status = _label(root,"",Vector2(780,145),22)
	_label(root,"A/D 이동 · Space 점프 · 방향 + Shift 대시 · J 유지 연속 공격 · 대시 중 W/S + J 상하 공격 · K 패리 · L 포션",Vector2(44,195),22)
	_label(root,"U / 패드 RB : 마법 활 충전 → 떼면 자동 조준 발사 · 대시 중 사용 가능   |   Tab / Esc : 조작감",Vector2(44,225),20)
	intro_label = _label(root,boss.data["name"],Vector2(790,440),72)
	result_screen = load("res://scenes/ui/ResultScreen.tscn").instantiate()
	root.add_child(result_screen)
	result_screen.retry_requested.connect(restart)
	result_screen.training_requested.connect(to_hub)
func _physics_process(delta: float) -> void:
	debug_used = debug_used or Feedback.debug_used or Feedback.invincible or not is_equal_approx(Feedback.base_speed,1)
	if intro > 0:
		intro = maxf(0,intro-delta)
		if intro <= 0:
			intro_label.hide()
			boss.enabled = true
			player.controls.set_blocked(false)
	elif not ended: elapsed += delta
	hud.text = "HP %s / %s   ·   포션 %d   ·   %.1f초" % [player.hp,player.p("max_hp"),player.potions,elapsed]
	player_hp.max_value = player.p("max_hp")
	player_hp.value = player.hp
	dash_bar.value = 100*(1-player.dash_cooldown/maxf(player.p("dash_cooldown"),0.001))
	boss_hp.value = boss.hp
	stagger_bar.value = boss.stagger
	boss_label.text = "%s    %s / %s    ·    PHASE %d" % [boss.data["name"],snappedf(boss.hp,0.1),boss.data["max_hp"],boss.phase_index+1]
	var kind: String = boss.runner.current.data["type"] if boss.runner.current != null else "대기"
	status.text = "스태거 %d / %d  ·  %s / %s  ·  %s×%s" % [boss.stagger,stagger_bar.max_value,boss.pattern_id,kind,Feedback.base_speed," · 무적" if Feedback.invincible else ""]
	if boss.stagger_time > 0: status.text = "무력화 %.1f초 · 받는 피해 ×%s" % [boss.stagger_time/boss.speed_mult,boss.data["stagger"]["damage_mult"]]
	if not ended and player.controls.just_pressed(&"retry") and player.controls.device_id == -1: restart()
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if ended and result_screen.input_ready and event.is_action_pressed("retry") and not event.is_echo():
		get_viewport().set_input_as_handled()
		restart()
func finish(won: bool) -> void:
	if ended: return
	debug_used = debug_used or Feedback.debug_used or Feedback.invincible or not is_equal_approx(Feedback.base_speed,1)
	ended = true
	debug_panel.toolbar.hide()
	debug_panel.weapon_bar.hide()
	debug_panel.live_readout.hide()
	debug_panel.set_process_input(false)
	boss.enabled = false
	boss.interrupt()
	player.controls.set_blocked(true)
	player.clear_action_intent()
	player.set_physics_process(false)
	player.queue_redraw()
	Feedback.clear_transients()
	var reward: Dictionary = {}
	if won and GameState.progression_run: reward = GameState.award_win(boss.data,elapsed,run_token,debug_used)
	result_screen.show_result(won,elapsed,boss.data["name"],reward,GameState.progression_run,debug_used)
func restart() -> void:
	if not GameState.pending_reward.is_empty(): return
	get_tree().paused = false
	Feedback.clear_transients()
	Feedback.set_speed(1,false)
	get_tree().change_scene_to_file.call_deferred("res://scenes/arena/BattleArena.tscn")

func to_training() -> void:
	GameState.progression_run = false
	get_tree().paused = false
	Feedback.clear_transients()
	Feedback.set_speed(1,false)
	get_tree().change_scene_to_file.call_deferred("res://scenes/arena/Arena.tscn")



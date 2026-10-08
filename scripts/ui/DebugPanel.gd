extends CanvasLayer
signal toggled(open: bool)
var panel: PanelContainer
var body: VBoxContainer
var status: Label
var balance_warning: Label
var parry_box: CheckBox
var controls: Dictionary = {}
var speed_index: int = 2
var syncing: bool = false
var is_open: bool = false
var tabs: TabContainer
var toolbar: HBoxContainer
var weapon_select: OptionButton
var weapon_tabs: TabContainer
var practice_buttons: Dictionary = {}
var tab_bodies: Dictionary = {}
var curtain: ColorRect
var last_weapon_id: String = ""
var weapon_bar: HBoxContainer
var quick_weapons: Dictionary = {}
var live_readout: Label
var input_counter: Label
const LABELS: Dictionary = {
	"move_speed":"이동 속도", "ground_accel":"지상 가속", "air_accel":"공중 가속", "gravity":"중력", "fall_gravity_mult":"낙하 중력 배율", "max_fall_speed":"최대 낙하 속도", "jump_velocity":"점프 속도", "jump_cut_mult":"점프 떼기 배율", "coyote_time":"코요테 타임", "jump_buffer":"점프 입력 버퍼", "dash_distance":"대시 거리", "dash_duration":"대시 시간", "dash_iframe":"대시 무적", "dash_cooldown":"대시 쿨다운", "perfect_dodge_window":"완벽 회피 판정", "parry_enabled":"패리 사용", "parry_window":"패리 판정 시간", "parry_whiff_recovery":"헛패리 후딜", "parry_cooldown":"패리 쿨다운", "hurt_iframe":"피격 무적", "hurt_knockback":"피격 넉백", "max_hp":"최대 HP", "potion_count":"포션 수", "potion_heal":"포션 회복", "potion_channel":"포션 사용 시간", "hurt_recovery":"피격 경직", "air_dash_count":"공중 대시 횟수",
	"hitstop_on_hit":"타격 히트스톱", "hitstop_on_parry":"패리 히트스톱", "hitstop_on_player_hurt":"피격 히트스톱", "shake_on_hit":"타격 흔들림", "shake_on_parry":"패리 흔들림", "shake_on_player_hurt":"피격 흔들림", "shake_decay":"흔들림 감쇠", "boss_hit_flash":"타깃 피격 섬광", "damage_numbers":"피해 숫자", "hitstop_time_scale":"히트스톱 속도"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	curtain = ColorRect.new()
	curtain.size = Vector2(1920,1080)
	curtain.color = Color(0.01,0.015,0.02,0.94)
	curtain.visible = false
	add_child(curtain)
	panel = PanelContainer.new()
	panel.position = Vector2(100,60)
	panel.size = Vector2(1720,960)
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Color(0.055,0.065,0.085,1.0)
	panel.add_theme_stylebox_override("panel",background)
	panel.visible = false
	add_child(panel)
	var theme: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic"])
	theme.default_font = font
	theme.default_font_size = 23
	panel.theme = theme
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "조작감 패널 · Tab / Esc 닫기 · 수치 변경 후 저장"
	column.add_child(title)
	balance_warning = Label.new()
	balance_warning.add_theme_color_override("font_color",Color(1,0.3,0.3))
	column.add_child(balance_warning)
	var buttons: HBoxContainer = HBoxContainer.new()
	column.add_child(buttons)
	for name: String in ["전체 저장","전체 기본값","닫고 연습"]:
		var button: Button = Button.new()
		button.text = name
		button.custom_minimum_size = Vector2(180,50)
		buttons.add_child(button)
		match name:
			"전체 저장": button.pressed.connect(func() -> void: Tuning.save_values())
			"전체 기본값": button.pressed.connect(Tuning.reset_defaults)
			"닫고 연습": button.pressed.connect(toggle)
		practice_buttons[name] = button
	var reset_save: Button = Button.new()
	reset_save.text = "진행 저장 초기화"
	buttons.add_child(reset_save)
	reset_save.pressed.connect(func() -> void:
		var dialog: ConfirmationDialog = ConfirmationDialog.new()
		dialog.dialog_text = "진행 저장을 초기화하고 허브로 이동할까요?\n기존 저장은 .bak 파일로 보존됩니다."
		dialog.confirmed.connect(func() -> void:
			if GameState.reset_progress():
				get_tree().paused = false
				get_tree().change_scene_to_file.call_deferred("res://scenes/hub/Hub.tscn"))
		add_child(dialog)
		dialog.popup_centered(Vector2i(800,220)))
	status = Label.new()
	status.text = "슬라이더 또는 숫자 직접 입력 · 이동 / 대시 / 공격 / 무기 / 방어 / 연출 / 허수아비"
	column.add_child(status)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	for name: String in ["이동·점프","대시","공격 반응","마법 활","무기 상세","방어·회복","연출","허수아비","골렘"]:
		tab_bodies[name] = _new_tab(tabs,name)
	for section: String in ["player","feedback"]:
		var defaults: Dictionary = Tuning.defaults[section]
		var ordered: Array = defaults.keys()
		if section == "player":
			ordered.erase("instant_move")
			ordered.push_front("instant_move")
		for key: String in ordered:
			var category: String = "이동·점프"
			if section == "feedback": category = "연출"
			elif key.begins_with("bow_"): category = "마법 활"
			elif key.begins_with("attack_"): category = "공격 반응"
			elif key.contains("dash") or key == "perfect_dodge_window": category = "대시"
			elif key.begins_with("defense_"): category = "방어·회복"
			elif key.begins_with("parry") or key.begins_with("hurt") or key.begins_with("potion") or key == "max_hp": category = "방어·회복"
			body = tab_bodies[category]
			_add_control(section,key,defaults[key])
	body = tab_bodies["골렘"]
	for key: String in Tuning.defaults["golem"]:
		if key != "moves": _add_control("golem",key,Tuning.defaults["golem"][key])
	for move_id: String in Tuning.defaults["golem"]["moves"]:
		_heading({"slam":"내려찍기","sweep":"휩쓸기","stomp":"발구르기"}[move_id])
		for key: String in Tuning.defaults["golem"]["moves"][move_id]:
			if key not in ["animation","source_windup"]: _add_control("golem/"+move_id,key,Tuning.defaults["golem"]["moves"][move_id][key])
	body = tab_bodies["무기 상세"]
	var weapon_note: Label = Label.new()
	weapon_note.text = "전투·연습 무기 선택 · 아래 각 무기의 모든 공격 수치를 편집합니다. 공격 전진 기본값은 30px입니다."
	body.add_child(weapon_note)
	weapon_select = OptionButton.new()
	for weapon: Dictionary in Tuning.weapons: weapon_select.add_item(weapon["name"])
	body.add_child(weapon_select)
	weapon_select.item_selected.connect(func(index: int) -> void:
		Tuning.set_value("practice","weapon_id",Tuning.weapons[index]["id"])
		weapon_tabs.current_tab = index)
	weapon_tabs = TabContainer.new()
	weapon_tabs.custom_minimum_size.y = 650
	body.add_child(weapon_tabs)
	for weapon: Dictionary in Tuning.defaults["weapons"]:
		body = _new_tab(weapon_tabs,weapon["name"])
		_add_control("weapons/"+weapon["id"],"combo_window",weapon["combo_window"])
		_add_weapon_flag(weapon)
		for i: int in weapon["combo"].size():
			_heading("지상 콤보 %d타" % (i+1))
			for key: String in weapon["combo"][i]: _add_control("weapons/%s/combo/%d" % [weapon["id"],i],key,weapon["combo"][i][key])
		for kind: String in ["air_attack","up_attack","down_attack"]:
			_heading({"air_attack":"공중 공격","up_attack":"위 공격","down_attack":"아래 공격 · 포고"}[kind])
			for key: String in weapon[kind]: _add_control("weapons/%s/%s" % [weapon["id"],kind],key,weapon[kind][key])
	body = tab_bodies["허수아비"]
	_heading("변경 즉시 적용 · 연습 상대의 공격 간격, 예고, 판정과 투사체")
	for key: String in Tuning.defaults["training"]["dummy"]:
		var value: Variant = Tuning.defaults["training"]["dummy"][key]
		if value is bool or value is float or value is int: _add_control("dummy",key,value)
	for key: String in ["hitbox_size","projectile_size"]:
		for axis: int in 2: _add_control("dummy","%s/%d" % [key,axis],Tuning.defaults["training"]["dummy"][key][axis])
	_build_toolbar(theme)
	_build_quick_weapons(theme)
	Tuning.changed.connect(_sync)
	Tuning.saved.connect(func(message: String) -> void: status.text = message)
	_sync()

func _build_quick_weapons(theme: Theme) -> void:
	weapon_bar = HBoxContainer.new()
	weapon_bar.position = Vector2(44,435)
	weapon_bar.theme = theme
	weapon_bar.add_theme_constant_override("separation",12)
	add_child(weapon_bar)
	var title: Label = Label.new()
	title.text = "사용할 무기"
	weapon_bar.add_child(title)
	for weapon: Dictionary in Tuning.weapons:
		var button: Button = Button.new()
		button.text = weapon["name"]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: Tuning.set_value("practice","weapon_id",weapon["id"]))
		weapon_bar.add_child(button)
		quick_weapons[weapon["id"]] = button
	var edit: Button = Button.new()
	edit.text = "무기 수치 편집"
	edit.focus_mode = Control.FOCUS_NONE
	edit.pressed.connect(func() -> void:
		tabs.current_tab = 4
		if not is_open: toggle())
	weapon_bar.add_child(edit)
	var save: Button = Button.new()
	save.text = "선택·수치 저장"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(func() -> void: Tuning.save_values())
	weapon_bar.add_child(save)
	live_readout = Label.new()
	live_readout.theme = theme
	live_readout.position = Vector2(44,492)
	live_readout.size.x = 1830
	live_readout.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	live_readout.add_theme_font_size_override("font_size",20)
	add_child(live_readout)
	input_counter = Label.new()
	input_counter.theme = theme
	input_counter.add_theme_font_size_override("font_size",18)
	add_child(input_counter)

func _process(_delta: float) -> void:
	if live_readout == null or not is_instance_valid(get_parent().player): return
	var player: GatePlayer = get_parent().player
	var input: PlayerInput = player.controls
	input_counter.visible = live_readout.visible
	input_counter.position = live_readout.position+Vector2(0,26)
	input_counter.text = "키 수신 누계  J %d  /  K %d  /  Shift %d  /  Space %d   ·   쿨다운 중 입력은 즉시 실행되지 않습니다" % [input.received.get(&"attack",0),input.received.get(&"parry",0),input.received.get(&"dash",0),input.received.get(&"jump",0)]
	var directions: String = ("←" if input.horizontal() < 0 else ("→" if input.horizontal() > 0 else "·")) + ("↑" if input.vertical() < 0 else ("↓" if input.vertical() > 0 else ""))
	var action: String = "이동 가능"
	if player.attack_running:
		var names: Dictionary = {"combo":"앞","air_attack":"공중 앞","up_attack":"위","down_attack":"아래"}
		action = names.get(player.attack_kind,"")+(" %d/4타" % (player.combo_index+1) if player.attack_kind == "combo" else "")+" 공격 · "+("준비" if not player.attack_spawned else ("후딜" if player._attack_recovery() else "타격"))
	if player.state == GatePlayer.State.DASH: action += " + 대시 이동"
	elif player.state == GatePlayer.State.HURT: action = "피격 경직"
	elif player.state == GatePlayer.State.PARRY: action = "헛패리 후딜" if player._whiff_locked() else "패리"
	elif player.state == GatePlayer.State.DEAD: action = "사망"
	if player.parry_age <= player.p("parry_window"): action += " + 패리 판정"
	action += " · "+player.bow.status_text()
	var dash: String = "대시 준비" if player.dash_cooldown <= 0 else "대시 %.2f초" % player.dash_cooldown
	if not player.is_on_floor() and player.dash_uses >= int(player.p("air_dash_count")): dash += " · 공중 횟수 소진"
	if Time.get_ticks_msec() < player.defense_note_until: dash += " / "+player.defense_note
	live_readout.text = "입력 %s  공격 %s  |  %s  |  %s  |  %s / 사거리 %s" % [directions,"누름" if input.pressed(&"attack") else "뗌",action,dash,player.weapon["name"],player.weapon["combo"][0]["reach"]]

func _new_tab(container: TabContainer, title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",10)
	scroll.add_child(list)
	return list

func _heading(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color",Color(0.35,0.9,0.82))
	body.add_child(label)

func _add_weapon_flag(weapon: Dictionary) -> void:
	var checkbox: CheckBox = CheckBox.new()
	checkbox.text = "이 무기의 후딜 대시 취소 허용 (전체 즉시 취소가 꺼졌을 때 적용)"
	body.add_child(checkbox)
	checkbox.toggled.connect(func(value: bool) -> void:
		if syncing: return
		Tuning.set_value("weapons/"+weapon["id"],"flags",["dash_cancel"] if value else []))
	controls["weapons/"+weapon["id"]+"/flags"] = {"control":checkbox,"row":checkbox,"section":"weapons/"+weapon["id"],"key":"flags"}

func _build_toolbar(theme: Theme) -> void:
	toolbar = HBoxContainer.new()
	toolbar.position = Vector2(44,365)
	toolbar.theme = theme
	toolbar.add_theme_constant_override("separation",12)
	add_child(toolbar)
	for title: String in ["조작감 패널 (Tab)","판정 보기","무적","허수아비 공격","0.25×","0.5×","1×","회복","다시 연습"]:
		var button: Button = Button.new()
		button.text = title
		button.custom_minimum_size.y = 54
		button.focus_mode = Control.FOCUS_NONE
		if title in ["판정 보기","무적","허수아비 공격"]: button.toggle_mode = true
		toolbar.add_child(button)
		practice_buttons[title] = button
		match title:
			"조작감 패널 (Tab)": button.pressed.connect(toggle)
			"판정 보기": button.toggled.connect(func(on: bool) -> void: Feedback.boxes_visible = on)
			"무적": button.toggled.connect(func(on: bool) -> void:
				Feedback.invincible = on
				Feedback.debug_used = true)
			"허수아비 공격": button.toggled.connect(func(on: bool) -> void:
				if not syncing: Tuning.set_value("dummy","enabled",on))
			"0.25×": button.pressed.connect(func() -> void: Feedback.set_speed(0.25))
			"0.5×": button.pressed.connect(func() -> void: Feedback.set_speed(0.5))
			"1×": button.pressed.connect(func() -> void: Feedback.set_speed(1.0))
			"회복": button.pressed.connect(func() -> void: get_parent().refill())
			"다시 연습": button.pressed.connect(func() -> void: get_parent().restart())

func _add_control(section: String, key: String, baseline: Variant) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size.y = 46
	body.add_child(row)
	var title: Label = Label.new()
	var extra: Dictionary = {"scale":"리그 표시 배율", "windup":"예비동작 (후속 시간 함께 이동)", "active_start":"판정 시작 (초)", "active_end":"판정 종료 (초)", "punish_end":"공격 기회 종료 (초)", "duration":"동작 전체 시간 (초)", "hitbox_x":"판정 왼쪽 X (리그 좌표)", "hitbox_y":"판정 위쪽 Y (리그 좌표)", "hitbox_width":"판정 너비", "hitbox_height":"판정 높이", "weakpoint_enabled":"공격 기회 중 앞주먹 약점 사용", "weakpoint_size":"약점 크기", "weakpoint_multiplier":"약점 피해 배율", "body_x":"몸통 피격 왼쪽 X", "body_y":"몸통 피격 위쪽 Y", "body_width":"몸통 피격 너비", "body_height":"몸통 피격 높이", "foot_zone":"발밑 범위 (리그 단위)", "foot_dwell":"발밑 체류 시간", "idle_min":"패턴 사이 대기 최소", "idle_max":"패턴 사이 대기 최대", "phase2_windup":"2페이즈 내려찍기 예비동작", "phase2_shockwave":"2페이즈 발구르기 충격파", "shockwave_speed":"충격파 속도", "shockwave_damage":"충격파 피해", "shockwave_height":"충격파 높이", "shake":"착지 흔들림", "parriable":"패리 가능", "bow_charge_time":"최대 충전 시간 (초)", "bow_cooldown":"발사 후 쿨다운 (초)", "bow_damage_min":"짧은 화살 피해", "bow_damage_max":"완충 화살 피해", "bow_speed_min":"짧은 화살 속도", "bow_speed_max":"완충 화살 속도", "bow_turn_rate":"유도 회전 속도 (rad/s)", "bow_lock_range":"자동 조준 거리", "bow_lifetime":"화살 수명 (초)", "bow_hit_size":"화살 판정 두께", "instant_move":"즉시 이동 · 가감속 무시", "ground_decel":"지상 정지 감속", "air_decel":"공중 정지 감속", "attack_move_mult":"공격 중 이동 배율", "defense_buffer":"방어 입력 보존 (초)", "defense_cancel_hurt":"피격 중 대시·패리 허용", "attack_during_dash":"대시 중 공격 허용", "dash_attack_continues_after_dash":"대시 중 시작한 공격을 대시 종료 후 유지", "dash_direction_grace":"중립 대시 방향 입력 유예 (초)", "attack_hold_repeat":"공격 누르고 있으면 연속 공격", "pogo_resets_air_dash":"포고 적중 시 공중 대시 회복", "attack_direction_chain":"공격 유지 중 방향 연계", "attack_buffer":"공격 밖 예약 수명 (초, 0=예약 없음)", "attack_cancel_on_jump":"점프로 공격 취소", "attack_cancel_on_dash":"대시로 공격 즉시 취소", "attack_release_clears_buffer":"키를 떼면 연계 예약 삭제 (짧은 탭은 꺼짐 권장)", "min_vulnerable_gap":"대시 최소 취약 구간", "parry_whiff_cancel":"헛패리 이동·공격·점프 취소 허용", "parry_whiff_dash_cancel":"헛패리 대시 취소 허용", "device_switch_axis":"패드 축 장치전환 임계값", "chain_at":"후딜 중 연계 허용 시점", "combo_window":"다음 콤보 입력 유예", "damage":"피해", "startup":"선딜 (초)", "active":"공격 판정 시간 (초)", "recovery":"후딜 (초)", "reach":"판정 가로 길이", "height":"판정 세로 길이", "knockback":"넉백", "lunge":"공격 자동 전진 거리 (0=없음)", "pogo_velocity":"포고 상승 속도", "enabled":"허수아비 공격 사용", "attack_interval":"공격 간격 (초)", "warning_time":"예고 시간 (초)", "hitbox_offset_y":"근접 판정 세로 위치", "hitbox_duration":"근접 판정 시간", "projectile_speed":"투사체 속도", "projectile_lifetime":"투사체 유지 시간", "parry_stagger":"패리 스태거 증가"}
	title.text = extra.get(key,LABELS.get(key,key))
	if key.begins_with("hitbox_size/"): title.text = "근접 판정 " + ("가로" if key.ends_with("0") else "세로")
	if key.begins_with("projectile_size/"): title.text = "투사체 " + ("가로" if key.ends_with("0") else "세로")
	title.tooltip_text = key
	title.custom_minimum_size.x = 440
	row.add_child(title)
	var id: String = section+"/"+key
	if baseline is bool:
		var toggle_box: CheckBox = CheckBox.new()
		toggle_box.text = "켬"
		row.add_child(toggle_box)
		toggle_box.toggled.connect(func(value: bool) -> void:
			if not syncing: Tuning.set_value(section,key,value))
		controls[id] = {"control":toggle_box,"row":row,"section":section,"key":key}
		if key == "parry_enabled": parry_box = toggle_box
	else:
		var slider: HSlider = HSlider.new()
		slider.custom_minimum_size.x = 550
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0
		if key in ["bow_charge_time","bow_speed_min","bow_speed_max","bow_lifetime","bow_hit_size","bow_lock_range"]: slider.min_value = 0.001
		slider.max_value = maxf(float(baseline)*3,300.0 if key == "lunge" else 1.0)
		if section.begins_with("weapons") and key in ["damage","active","reach","height","pogo_velocity"]: slider.min_value = 0.001
		if section == "dummy" and key not in ["hitbox_offset_y","parry_stagger"]: slider.min_value = 0.001
		if key in ["hitbox_offset_y","hitbox_x","hitbox_y","body_x","body_y"]:
			slider.max_value = maxf(absf(float(baseline))*3,500)
			slider.min_value = -slider.max_value
		if section.begins_with("golem") and key in ["scale","hitbox_width","hitbox_height","body_width","body_height","duration","foot_dwell","weakpoint_size","weakpoint_multiplier","phase2_windup","shockwave_speed","shockwave_damage","shockwave_height","idle_min","idle_max","foot_zone"]: slider.min_value = 0.001
		var integer: bool = key in ["max_hp","potion_count","air_dash_count","potion_heal","hurt_knockback","move_speed","ground_accel","air_accel","gravity","max_fall_speed","jump_velocity","dash_distance","shake_on_hit","shake_on_parry","shake_on_player_hurt","shake_decay"]
		slider.step = 1 if integer else 0.001
		row.add_child(slider)
		var value_label: SpinBox = SpinBox.new()
		value_label.custom_minimum_size.x = 190
		value_label.min_value = slider.min_value
		value_label.max_value = slider.max_value
		value_label.step = slider.step
		row.add_child(value_label)
		slider.value_changed.connect(func(value: float) -> void:
			if not syncing: Tuning.set_value(section,key,int(value) if integer else value))
		value_label.value_changed.connect(func(value: float) -> void:
			if not syncing: Tuning.set_value(section,key,int(value) if integer else value))
		controls[id] = {"control":slider,"row":row,"label":value_label,"section":section,"key":key}

func _sync() -> void:
	balance_warning.text = Tuning.balance_warning()
	balance_warning.visible = not balance_warning.text.is_empty()
	syncing = true
	for id: String in controls:
		var entry: Dictionary = controls[id]
		var values: Dictionary = Tuning.section_values(entry["section"])
		var key: String = entry["key"]
		var value: Variant = Tuning.value_at(entry["section"],key)
		if key == "flags": entry["control"].set_pressed_no_signal("dash_cancel" in values["flags"])
		elif entry["control"] is CheckBox: entry["control"].set_pressed_no_signal(value)
		else:
			entry["control"].set_value_no_signal(value)
			entry["label"].set_value_no_signal(value)
		if key.contains("parry") and key != "parry_enabled": entry["row"].visible = Tuning.player["parry_enabled"]
	var shown_weapon: String = get_parent().player.weapon["id"] if get_parent().player.use_loadout else Tuning.training["player"]["weapon_id"]
	for i: int in Tuning.weapons.size():
		if Tuning.weapons[i]["id"] == shown_weapon:
			weapon_select.select(i)
			if last_weapon_id != shown_weapon: weapon_tabs.current_tab = i
	last_weapon_id = shown_weapon
	for id: String in quick_weapons: quick_weapons[id].set_pressed_no_signal(id == last_weapon_id)
	practice_buttons["허수아비 공격"].set_pressed_no_signal(Tuning.training["dummy"]["enabled"])
	practice_buttons["무적"].set_pressed_no_signal(Feedback.invincible)
	practice_buttons["판정 보기"].set_pressed_no_signal(Feedback.boxes_visible)
	syncing = false

func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	curtain.visible = is_open
	toolbar.visible = not is_open
	weapon_bar.visible = not is_open
	live_readout.visible = not is_open
	get_tree().paused = is_open
	toggled.emit(is_open)
	if is_open: practice_buttons["닫고 연습"].grab_focus()

func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("tuning_panel") or event.is_action_pressed("pause")) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()

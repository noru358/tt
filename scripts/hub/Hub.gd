extends Control
const Calc = preload("res://scripts/stats/StatCalc.gd")
var practice_button: Button
var content: VBoxContainer
var craft_buttons: Dictionary = {}
var slot_selectors: Dictionary = {}
var boss_buttons: Dictionary = {}
var stats_label: Label
var status: Label
var refresh_queued: bool = false

func _ready() -> void:
	GameState.progression_run = false
	get_tree().paused = false
	Feedback.clear_transients()
	Feedback.set_speed(1,false)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic"])
	var theme: Theme = Theme.new()
	theme.default_font = font
	theme.default_font_size = 24
	self.theme = theme
	GameState.changed.connect(queue_refresh)
	Tuning.changed.connect(queue_refresh)
	if not GameState.save_blocked and GameState.pending_reward.is_empty(): GameState.save()
	_refresh()

func queue_refresh() -> void:
	if refresh_queued: return
	refresh_queued = true
	_refresh.call_deferred()

func label(parent: Node, text: String, size: int = 24) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size",size)
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable) -> Button:
	var node: Button = Button.new()
	node.text = text
	node.custom_minimum_size.y = 54
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func column(parent: Node, width: float) -> VBoxContainer:
	var node: VBoxContainer = VBoxContainer.new()
	node.custom_minimum_size.x = width
	node.add_theme_constant_override("separation",16)
	parent.add_child(node)
	return node

func _refresh() -> void:
	refresh_queued = false
	var focus_id: String = ""
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null: focus_id = str(focused.get_meta("focus_id",""))
	if is_instance_valid(content):
		remove_child(content)
		content.queue_free()
	craft_buttons.clear()
	slot_selectors.clear()
	boss_buttons.clear()
	content = VBoxContainer.new()
	content.position = Vector2(36,26)
	content.size = Vector2(1848,1024)
	content.add_theme_constant_override("separation",20)
	add_child(content)
	label(content,"GATE 1 / STEP 3    허브 → 보스 → 제작 → 다시 도전",36)
	status = label(content,"보상·제작·장착은 자동 저장됩니다.  마우스 / 방향키·Enter / 패드 방향·A",22)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not GameState.save_error.is_empty(): status.text = GameState.save_error
	if not GameState.pending_reward.is_empty(): button(content,"아직 저장되지 않은 전투 보상 · 저장 다시 시도",func() -> void:
		GameState.retry_reward()
		queue_refresh())
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",28)
	content.add_child(body)
	var inventory: VBoxContainer = column(body,310)
	label(inventory,"보유 재료",30)
	for material: Dictionary in DataRegistry.documents["materials.json"]:
		label(inventory,"%s   %d" % [material["name"],GameState.state["materials"][material["id"]]],25)
	var rewards: String = "보스 보상"
	for boss: Dictionary in DataRegistry.all_bosses():
		rewards += "\n"+boss["name"]
		for drop: Dictionary in boss["drops"]:
			rewards += "\n"+DataRegistry.get_material(drop["id"])["name"]+" "
			if drop.has("chance"): rewards += "%d%%" % (float(drop["chance"])*100)
			else: rewards += str(int(drop["min"]))+("~"+str(int(drop["max"])) if drop["min"] != drop["max"] else "")
	label(inventory,rewards+"\n\n사망해도 재료 유지\n제작 장비는 영구 보유",20)
	var recipes: VBoxContainer = column(body,770)
	label(recipes,"제작",30)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipes.add_child(scroll)
	var recipe_list: VBoxContainer = column(scroll,735)
	for item: Dictionary in DataRegistry.all_equipment():
		if not Tuning.player["parry_enabled"] and Calc.parry_only(item): continue
		var panel: VBoxContainer = column(recipe_list,700)
		panel.add_theme_constant_override("separation",5)
		label(panel,item["name"]+" · "+description(item),23)
		var recipe: PackedStringArray = []
		for id: String in item["recipe"]: recipe.append("%s %d/%d" % [DataRegistry.get_material(id)["name"],GameState.state["materials"][id],item["recipe"][id]])
		label(panel," / ".join(recipe),20)
		var owned: bool = item["id"] in GameState.state["owned"]
		var craft: Button = button(panel,"보유" if owned else "제작",func() -> void:
			GameState.craft(item["id"])
			queue_refresh())
		craft.disabled = not GameState.can_craft(item["id"])
		craft.set_meta("focus_id",item["id"])
		craft_buttons[item["id"]] = craft
	var loadout: VBoxContainer = column(body,680)
	label(loadout,"장착 · 현재 최종 수치",30)
	for slot: String in ["weapon","armor","charm"]:
		label(loadout,{"weapon":"무기","armor":"방어구","charm":"부적"}[slot],23)
		var select: OptionButton = OptionButton.new()
		select.add_item("낡은 검 (기본)" if slot == "weapon" else "미장착")
		select.set_item_metadata(0,"")
		for id: String in GameState.state["owned"]:
			var item: Dictionary = DataRegistry.get_equipment(id)
			if item["slot"] != slot: continue
			select.add_item(item["name"])
			select.set_item_metadata(select.item_count-1,id)
			if GameState.state["equipped"][slot] == id: select.select(select.item_count-1)
		select.item_selected.connect(func(index: int) -> void:
			GameState.equip(slot,select.get_item_metadata(index))
			queue_refresh())
		select.set_meta("focus_id",slot)
		loadout.add_child(select)
		slot_selectors[slot] = select
	var final: Dictionary = GameState.loadout()
	var stats: Dictionary = final["stats"]
	var weapon: Dictionary = Tuning.get_weapon(final["weapon_id"])
	stats_label = label(loadout,"%s\nHP %s   이동 %s   피해 ×%s\n대시 %spx / 무적 %.2f초\n포션 %d개 / 회복 %s\n패리 %s\n\n제작 후 이곳에서 장착하세요.\n미리 사용·수치 설정은 조작 연습에서." % [weapon["name"],stats["max_hp"],stats["move_speed"],stats["damage_mult"],stats["dash_distance"],stats["dash_iframe"],stats["potion_count"],stats["potion_heal"],("%.2f초" % stats["parry_window"]) if stats["parry_enabled"] else "꺼짐"],23)
	if not stats["parry_enabled"]: label(loadout,"패리 전용 제작 항목은 숨겨집니다.",21)
	label(content,"모드 선택 · 두 모드 모두 허브로 돌아올 수 있습니다",26)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation",14)
	content.add_child(footer)
	for boss: Dictionary in DataRegistry.all_bosses():
		var id: String = boss["id"]
		var unlocked: bool = id in GameState.state["unlocked"]
		var record: Dictionary = GameState.state["records"].get(id,{"kills":0,"best_time":0})
		var text: String = "실제 게임 · %s · %d회 / 최고 %s" % [boss["name"],record["kills"],("%.1f초" % record["best_time"]) if record["best_time"] > 0 else "—"]
		if not unlocked:
			var sources: PackedStringArray = []
			for source: Dictionary in DataRegistry.all_bosses():
				if id in source["unlocks"]: sources.append(source["name"])
			text += "\n"+" / ".join(sources)+" 처치 시 해금"
		else: text += "\n장착 장비 사용 · 보상/진행 저장"
		var fight: Button = button(footer,text,func() -> void: start_battle(id))
		fight.custom_minimum_size.x = 480
		fight.disabled = not unlocked or GameState.save_blocked or not GameState.pending_reward.is_empty()
		fight.set_meta("focus_id",id)
		boss_buttons[id] = fight
	practice_button = button(footer,"연습 모드\n자유 무기 · 보상 없음",func() -> void:
		GameState.progression_run = false
		get_tree().change_scene_to_file("res://scenes/arena/Arena.tscn"))
	button(footer,"진행 저장 초기화",confirm_reset)
	var to_focus: Control = boss_buttons.values()[0]
	if slot_selectors.has(focus_id): to_focus = slot_selectors[focus_id]
	elif craft_buttons.has(focus_id) and not craft_buttons[focus_id].disabled: to_focus = craft_buttons[focus_id]
	to_focus.grab_focus()

func description(item: Dictionary) -> String:
	var parts: PackedStringArray = []
	var names: Dictionary = {"max_hp":"HP","move_speed":"이동","damage_mult":"피해"}
	for key: String in item["modifiers"]:
		var mod: Dictionary = item["modifiers"][key]
		if mod.has("add"): parts.append("%s %+d" % [names.get(key,key),mod["add"]])
		if mod.has("mul"): parts.append("%s %+d%%" % [names.get(key,key),float(mod["mul"])*100])
	for effect: Dictionary in item["effects"]:
		match effect["type"]:
			"parry_window_bonus": parts.append("패리 +%.2f초" % effect["seconds"])
			"on_parry_heal": parts.append("패리 회복 %s" % effect["amount"])
			"on_perfect_dodge_damage_buff": parts.append("완벽회피 후 %.1f초 피해 ×%s" % [effect["duration"],effect["mult"]])
			"potion_bonus": parts.append("포션 +%s" % effect["count"])
	if item.has("weapon_id"):
		var weapon: Dictionary = Tuning.get_weapon(item["weapon_id"])
		parts.append("%d타 · 첫 타 피해 %s" % [weapon["combo"].size(),weapon["combo"][0]["damage"]])
	return " / ".join(parts)

func start_battle(id: String) -> void:
	if id not in GameState.state["unlocked"] or not DataRegistry._indexes["bosses"].has(id) or GameState.save_blocked or not GameState.pending_reward.is_empty(): return
	GameState.selected_boss = id
	GameState.progression_run = true
	get_tree().change_scene_to_file("res://scenes/arena/BattleArena.tscn")

func confirm_reset() -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.dialog_text = "보유 재료·제작 장비·장착·처치 기록을 초기화할까요?\n기존 저장은 .bak 파일로 보존됩니다."
	dialog.title = "진행 초기화"
	dialog.confirmed.connect(func() -> void:
		GameState.reset_progress()
		queue_refresh())
	add_child(dialog)
	dialog.popup_centered(Vector2i(800,230))

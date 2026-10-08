extends PanelContainer
signal retry_requested
signal training_requested
var heading: Label
var details: Label
var retry_button: Button
var return_button: Button
var save_retry: Button
var input_ready: bool = false
var input_wait: float = 0.0
func _ready() -> void:
	position = Vector2(510,340)
	size = Vector2(900,430)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04,0.06,0.09,0.98)
	style.set_content_margin_all(30)
	add_theme_stylebox_override("panel",style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	add_child(column)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size",42)
	column.add_child(heading)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size.x = 820
	column.add_child(details)
	retry_button = Button.new()
	retry_button.text = "다시 도전 · R / 패드 A"
	retry_button.custom_minimum_size.y = 58
	retry_button.pressed.connect(func() -> void:
		if input_ready: retry_requested.emit())
	column.add_child(retry_button)
	return_button = Button.new()
	return_button.pressed.connect(func() -> void:
		if input_ready: training_requested.emit())
	column.add_child(return_button)
	save_retry = Button.new()
	save_retry.text = "보상 저장 다시 시도"
	save_retry.pressed.connect(func() -> void:
		if not input_ready: return
		var drops: Dictionary = GameState.retry_reward()
		if GameState.pending_reward.is_empty():
			details.text = "보상 저장 완료 · "+reward_text(drops)
			save_retry.hide()
			retry_button.disabled = false)
	column.add_child(save_retry)
	hide()
func reward_text(drops: Dictionary) -> String:
	var text: PackedStringArray = []
	for id: String in drops: text.append("%s ×%d" % [DataRegistry.get_material(id)["name"],drops[id]])
	return " / ".join(text)
func show_result(won: bool, seconds: float, boss_name: String, drops: Dictionary = {}, progression: bool = false, debug_used: bool = false) -> void:
	heading.text = boss_name+" 격파" if won else "쓰러졌습니다"
	details.text = "전투 시간 %.1f초" % seconds
	if progression:
		details.text += "\n"+(reward_text(drops) if won else "재료와 장비는 그대로 유지됩니다.")
		if won and GameState.pending_reward.is_empty(): details.text += "\n획득 재료·처치 기록 저장 완료"
	else: details.text += "\n연습 전투 · 보상과 진행 기록은 지급하지 않습니다."
	if debug_used: details.text += "\n"+("디버그 사용 · 보상 지급 / 최고 기록 제외" if progression else "디버그 사용 · 연습 기록 없음")
	return_button.text = "허브로 돌아가기"
	save_retry.visible = not GameState.pending_reward.is_empty()
	retry_button.disabled = save_retry.visible
	if save_retry.visible: details.text += "\n보상 저장 실패 · 다시 시도하세요. "+GameState.save_error
	input_ready = false
	input_wait = float(DataRegistry.documents["battle.json"]["result_input_delay"])
	for button: Button in [retry_button,return_button,save_retry]:
		button.disabled = true
		button.release_focus()
	show()

func _process(delta: float) -> void:
	if not visible or input_ready: return
	input_wait = maxf(0,input_wait-delta)
	if input_wait > 0: return
	for action: StringName in PlayerInput.ACTIONS + [&"ui_accept"]:
		if Input.is_action_pressed(action): return
	input_ready = true
	retry_button.disabled = not GameState.pending_reward.is_empty()
	return_button.disabled = false
	save_retry.disabled = false
	if save_retry.visible: save_retry.grab_focus()
	else: retry_button.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and not input_ready and (event.is_action("ui_accept") or event.is_action("retry")):
		get_viewport().set_input_as_handled()

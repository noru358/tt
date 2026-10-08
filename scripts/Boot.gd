extends Control
const ERROR_SCREEN: PackedScene = preload("res://scenes/ui/DataErrorScreen.tscn")

func _ready() -> void:
	# CLI fixture routing exists only for reproducible Step 0 validation.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--test-data-root="):
			DataRegistry.load_all(argument.trim_prefix("--test-data-root="))
	if not DataRegistry.is_valid:
		add_child(ERROR_SCREEN.instantiate())
		print("DATA_INVALID\n" + "\n".join(DataRegistry.errors))
	else:
		if "--data-screen" in OS.get_cmdline_user_args(): _show_success()
		else:
			get_tree().change_scene_to_file.call_deferred("res://scenes/arena/Arena.tscn" if "--training" in OS.get_cmdline_user_args() else ("res://scenes/arena/BattleArena.tscn" if "--battle-preview" in OS.get_cmdline_user_args() else "res://scenes/hub/Hub.tscn"))
			return
	_capture_if_requested.call_deferred()

func _show_success() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	margin.add_child(column)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR"])
	column.add_theme_font_override("font", font)
	var title: Label = Label.new()
	title.text = "데이터 OK"
	title.add_theme_color_override("font_color", Color(0.36, 0.94, 0.70))
	title.add_theme_font_size_override("font_size", 58)
	column.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "GATE 1  /  STEP 0 — 골격과 데이터 로더"
	subtitle.add_theme_font_size_override("font_size", 30)
	column.add_child(subtitle)
	var table: GridContainer = GridContainer.new()
	table.columns = 2
	table.add_theme_constant_override("h_separation", 120)
	table.add_theme_constant_override("v_separation", 17)
	column.add_child(table)
	for file: String in DataRegistry.counts:
		var label: Label = Label.new()
		label.text = file
		label.add_theme_font_size_override("font_size", 27)
		table.add_child(label)
		var amount: Label = Label.new()
		var suffix: String = "개 필드" if file.begins_with("tuning/") else "개 항목"
		amount.text = "%d %s" % [DataRegistry.counts[file], suffix]
		if file.begins_with("bosses/"):
			var boss: Dictionary = DataRegistry.documents[file]
			amount.text = "1개 보스 · %d개 패턴 · %d개 phase" % [boss["patterns"].size(), boss["phases"].size()]
		amount.add_theme_font_size_override("font_size", 27)
		table.add_child(amount)
	var note: Label = Label.new()
	note.text = "%d개 JSON 검증 완료\n\n현재 단계는 여기까지입니다. 다음 지시 후 Step 1을 시작합니다.\n전투·이동·디버그 조작은 아직 구현하지 않았습니다." % DataRegistry.counts.size()
	note.add_theme_font_size_override("font_size", 25)
	note.add_theme_color_override("font_color", Color(0.65, 0.72, 0.82))
	column.add_child(note)
	print("DATA_OK " + JSON.stringify(DataRegistry.counts))

func _capture_if_requested() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var image: Image = get_viewport().get_texture().get_image()
			var result: Error = image.save_png(argument.trim_prefix("--capture="))
			print("CAPTURE_RESULT ", result)
			get_tree().quit(0 if result == OK else 1)

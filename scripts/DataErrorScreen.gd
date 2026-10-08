extends Control

func _ready() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.23, 0.015, 0.025)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR"])
	column.add_theme_font_override("font", font)
	var title: Label = Label.new()
	title.text = "데이터 오류 — 시작 차단 (%d건)" % DataRegistry.errors.size()
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.38, 0.38))
	column.add_child(title)
	var explanation: Label = Label.new()
	explanation.text = "JSON을 수정한 뒤 다시 실행하세요. 오류가 있으면 게임을 진행하지 않습니다."
	explanation.add_theme_font_size_override("font_size", 25)
	column.add_child(explanation)
	var list: RichTextLabel = RichTextLabel.new()
	list.name = "Errors"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_font_override("normal_font", font)
	list.add_theme_font_size_override("normal_font_size", 26)
	list.add_theme_color_override("default_color", Color(1.0, 0.72, 0.72))
	list.text = "\n\n".join(DataRegistry.errors)
	list.selection_enabled = true
	list.focus_mode = Control.FOCUS_ALL
	column.add_child(list)
	list.grab_focus()

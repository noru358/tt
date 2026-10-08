extends Node2D
var text: String
var tint: Color = Color.WHITE
var remaining: float
var rise: float
var total: float
var label: Label

func _ready() -> void:
	total = remaining
	label = Label.new()
	label.text = text
	label.position = Vector2(-70,-45)
	label.add_theme_font_size_override("font_size", 29)
	label.add_theme_color_override("font_color", tint)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic"])
	label.add_theme_font_override("font", font)
	add_child(label)

func _process(delta: float) -> void:
	remaining -= delta
	position.y -= rise * delta
	modulate.a = clampf(remaining / total, 0.0, 1.0)
	if remaining <= 0.0: queue_free()

class_name CombatHurtbox
extends Area2D
var combatant: Node2D
var team: String = ""
var box_size: Vector2

func _ready() -> void:
	add_to_group("hurtboxes")
	collision_layer = 0
	collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = box_size
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

func bounds() -> Rect2:
	return Rect2(global_position - box_size / 2.0, box_size)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if Feedback.boxes_visible: draw_rect(Rect2(-box_size/2.0, box_size), Color.GREEN, false, 2)

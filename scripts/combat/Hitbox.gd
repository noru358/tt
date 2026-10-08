class_name CombatHitbox
extends Area2D
var source: Node2D
var team: String = "enemy"
var box_size: Vector2
var damage: float
var knockback: float = 0.0
var parriable: bool = false
var duration: float
var elapsed: float = 0.0
var struck: Dictionary = {}
var reflected: bool = false
var attack_id: String = ""
var tint: Color = Color(1,0.25,0.2,0.3)

func _ready() -> void:
	add_to_group("hitboxes")
	collision_layer = 0
	collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = box_size
	var collider: CollisionShape2D = CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)

func _physics_process(delta: float) -> void:
	# Test at least once even if an active window is shorter than the physics tick.
	for node: Node in get_tree().get_nodes_in_group("hurtboxes"):
		var target: CombatHurtbox = node as CombatHurtbox
		if target.team == team or not is_instance_valid(target.combatant) or not target.box_size.x > 0 or struck.has(target.get_instance_id()) or struck.has(target.combatant.get_instance_id()): continue
		if target.overlaps(Rect2(global_position-box_size/2.0, box_size)):
			var outcome: String = target.combatant.receive_hit(self)
			if outcome == "reflected": break
			if outcome != "ignored":
				struck[target.get_instance_id()] = true
				struck[target.combatant.get_instance_id()] = true
			if outcome == "hit" and is_instance_valid(source) and source.has_method("dealt_hit"):
				source.dealt_hit(target.combatant, self)
	elapsed += delta
	if elapsed >= duration: queue_free()
	queue_redraw()

func reflect(_new_source: Node2D) -> bool:
	return false

func _draw() -> void:
	if team != "player": draw_rect(Rect2(-box_size/2.0, box_size), tint)
	if Feedback.boxes_visible: draw_rect(Rect2(-box_size/2.0, box_size), Color.RED, false, 3)

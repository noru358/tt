extends Node
var world: Node2D
var p: GatePlayer
var m: Node
var checks: int = 0
var failures: int = 0
var DT: float = 1.0/60
func check(ok: bool, note: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+note)
	if not ok: failures += 1
func step(direction: Vector2 = Vector2.ZERO, action: StringName = &"") -> void:
	await get_tree().physics_frame
	p.controls._current = {&"move_right":maxf(0,direction.x),&"move_left":maxf(0,-direction.x),&"aim_down":maxf(0,direction.y),&"aim_up":maxf(0,-direction.y)}
	p.controls._previous = p.controls._current.duplicate()
	p.controls._pressed_edges.clear()
	p.controls._press_directions.clear()
	if action != &"":
		p.controls._pressed_edges[action] = true
		p.controls._press_directions[action] = direction
	m.tick(DT)
func reset(at: Vector2 = Vector2(600,100)) -> void:
	Input.action_release("toy_bash")
	world.load_room(0)
	await get_tree().physics_frame
	p.position = at
	p.velocity = Vector2.ZERO
	for i: int in 2: await step()
func _ready() -> void:
	var hz: int = int(OS.get_environment("MOVEMENT_AUDIT_HZ"))
	if hz > 0:
		Engine.physics_ticks_per_second = hz
		DT = 1.0/hz
	world = preload("res://toys/movement/movement_toy.tscn").instantiate()
	add_child(world)
	p = world.player
	m = world.motion
	world.set_physics_process(false)
	p.set_physics_process(false)
	p.controls.set_physics_process(false)
	await reset()
	await step(Vector2.RIGHT,&"dash")
	for i: int in 5: await step(Vector2.RIGHT)
	await step(Vector2.LEFT,&"dash")
	for i: int in 7: await step()
	check(p.dash_uses == 2 and p.state == GatePlayer.State.DASH and p.dash_direction.x < 0,"early second dash retained with press direction")
	for i: int in 14: await step()
	await step(Vector2.RIGHT,&"dash")
	check(p.dash_uses == 2 and p.state != GatePlayer.State.DASH,"third dash rejected")
	await reset()
	var start_x: float = p.position.x
	await step(Vector2.RIGHT,&"dash")
	for i: int in 20:
		if p.state != GatePlayer.State.DASH: break
		await step(Vector2.RIGHT)
	print("DASH_DISPLACEMENT ",p.position.x-start_x)
	check(absf(p.position.x-start_x-float(world.tuning.dash_distance)) < 0.1,"dash actual travel equals tuning")
	await reset(Vector2(80,306))
	for i: int in 5: await step()
	await step(Vector2.RIGHT,&"dash")
	for i: int in 5: await step(Vector2.RIGHT)
	await step(Vector2.RIGHT,&"dash")
	for i: int in 7: await step(Vector2.RIGHT)
	check(p.state == GatePlayer.State.DASH and p.dash_uses == 2,"ground horizontal second dash interrupts first")
	await reset(Vector2(80,306))
	for i: int in 5: await step()
	await step(Vector2.RIGHT,&"dash")
	await step(Vector2.RIGHT,&"jump")
	check(p.velocity.y < 0 and p.state != GatePlayer.State.DASH,"ground dash can jump cancel")
	await reset()
	var hidden: Node2D = world._orb(Vector2(16,100),"o")
	p.position = Vector2(43,100)
	check(m.nearest() != hidden,"wall blocks bash acquisition")
	hidden.queue_free()
	await reset()
	var bullet: Node2D = world._orb(p.position+Vector2(10,0),"bullet")
	bullet.set_physics_process(false)
	bullet.velocity = Vector2.LEFT*float(world.tuning.projectile_speed)
	m.was_held = false
	Input.action_press("toy_bash")
	await step()
	var hp: float = p.hp
	var before: Vector2 = bullet.position
	bullet._physics_process(DT)
	check(p.hp == hp and bullet.position == before and not bullet.is_queued_for_deletion(),"held projectile neither moves nor damages player")
	if is_instance_valid(bullet): bullet.queue_free()
	await get_tree().process_frame
	await step()
	check(is_equal_approx(Engine.time_scale,Feedback.base_speed),"deleted bash target restores time scale")
	Input.action_release("toy_bash")
	await reset()
	await step(Vector2.RIGHT,&"dash")
	for i: int in 5: await step()
	await step(Vector2.LEFT,&"dash")
	world.load_room(0)
	for i: int in 15: await step()
	check(p.state != GatePlayer.State.DASH and p.dash_uses == 0,"room reload clears queued dash")
	world.respawn()
	world.load_room(0)
	await get_tree().create_timer(float(world.tuning.respawn_fade)+0.1,true,false,true).timeout
	check(is_zero_approx(world.fade.color.a) and not world.respawning,"reload during fade does not leave black overlay")
	# Direction/timing matrix: a brief second press must retain its own aim.
	for direction: Vector2 in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,-1),Vector2(-1,-1),Vector2(1,1),Vector2(-1,1)]:
		for delay: float in [0.02,0.08,0.16,0.20,0.24]:
			await reset()
			await step(Vector2.RIGHT,&"dash")
			for i: int in maxi(0,int(delay/DT)-1): await step()
			await step(direction,&"dash")
			for i: int in int(0.3/DT):
				if p.dash_uses == 2: break
				await step()
			check(p.dash_uses == 2 and p.dash_direction.is_equal_approx(direction.normalized()),"second dash direction=%s delay=%.2f" % [direction,delay])
	await reset()
	await step(Vector2.RIGHT,&"dash")
	await step(Vector2.LEFT,&"dash")
	world._command("튜닝 F1")
	world._command("튜닝 F1")
	for i: int in 20: await step()
	check(p.dash_uses == 2,"menu does not invent a third dash")
	await reset()
	await step(Vector2.RIGHT,&"dash")
	await step(Vector2.LEFT,&"dash")
	p.controls._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await step()
	p.controls._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	for i: int in 20: await step()
	check(p.dash_uses == 2,"focus change does not invent a third dash")
	print("MOVEMENT_AUDIT_RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(failures)

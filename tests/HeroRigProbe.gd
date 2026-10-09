# Saves captures of the hero rig poses to HERO_RIG_CAPTURES (needs a display): a pose board and a run/attack sequence.
extends Node2D
const BASE: Dictionary = {"facing":1,"vel":Vector2.ZERO,"floor":true,"wall":false,"dash":false,"dash_dir":Vector2.RIGHT,"swing_kind":"","swing_start":false,"hurt_start":false,"bash_hold":false,"aim":Vector2.UP,"launch":false,"launch_dir":Vector2(0.7,-0.7),"air_left":2,"height":200.0,"dead":false}
const POSES: Array = [
	["idle",{}],["run",{"vel":Vector2(230,0)}],["jump",{"floor":false,"vel":Vector2(100,-400)}],["fall",{"floor":false,"vel":Vector2(100,450),"air_left":1}],
	["dash",{"floor":false,"dash":true,"vel":Vector2(700,0),"air_left":1}],["wall",{"floor":false,"wall":true,"vel":Vector2(0,120)}],["bash aim",{"floor":false,"bash_hold":true}],["launch",{"floor":false,"launch":true,"vel":Vector2(400,-400),"air_left":0}],
	["swing side",{"swing":["side",0.45]}],["swing up",{"swing":["up",0.45]}],["swing down",{"floor":false,"swing":["down",0.45]}],["hurt",{"hurt":0.5}],
]
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("HERO_RIG_CAPTURES")+"/"+name+".png")

func make(state: Dictionary, at: Vector2) -> HeroRig:
	var rig: HeroRig = HeroRig.new()
	var s: Dictionary = BASE.duplicate()
	for key: String in state:
		if key in s: s[key] = state[key]
	rig.override = s
	rig.anchor = at
	add_child(rig)
	if state.has("swing"):
		rig.swing_kind = state.swing[0]
		rig.swing_t = state.swing[1]
	if state.has("hurt"): rig.hurt_t = state.hurt
	return rig

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.42,0.45,0.52))
	var rigs: Array = []
	for i: int in POSES.size():
		var at: Vector2 = Vector2(260+(i%4)*460,230+int(i/4)*350)
		var rig: HeroRig = make(POSES[i][1],at)
		rigs.append([rig,at])
		var label: Label = Label.new()
		label.text = POSES[i][0]
		label.position = at+Vector2(-60,110)
		add_child(label)
	# Freeze timed poses at their sample point, let the rest settle.
	for frame: int in 40:
		for pair: Array in rigs:
			var rig: HeroRig = pair[0]
			if rig.swing_t >= 0: rig.swing_t = POSES[rigs.find(pair)][1].swing[1]-1.0/60.0/HeroRig.SWING_TIME
			if rig.hurt_t >= 0: rig.hurt_t = 0.5-1.0/60.0/HeroRig.HURT_TIME
		await get_tree().process_frame
	await shot("poses")
	for pair: Array in rigs: pair[0].queue_free()
	for child: Node in get_children(): child.queue_free()
	await get_tree().process_frame
	# Sequence: run, then a side swing, one frame every 1/30 s.
	var rig: HeroRig = make({"vel":Vector2(230,0)},Vector2(960,560))
	for frame: int in 60:
		if frame == 30:
			rig.override.vel = Vector2.ZERO
			rig.swing_kind = "side"
			rig.swing_t = 0.0
		await get_tree().process_frame
		await get_tree().process_frame
		await shot("seq_%03d" % frame)
	get_tree().quit()

# Sound contract: every listed sound loads from assets/sfx, and the main events play one.
extends Node
var failures: int = 0
var checks: int = 0

func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+note)

func frames(count: int) -> void:
	for i: int in count: await get_tree().physics_frame

func _ready() -> void:
	for sound: String in Sfx.MIX:
		var stream: AudioStreamWAV = Sfx.streams.get(sound)
		check(stream != null and stream.get_length() > 0.05 and stream.get_length() < 3.0,"sound loads with a sane length: "+sound)
	check(Sfx.voices.size() == Sfx.VOICES,"voice pool exists")
	var toy: Node = preload("res://toys/golem_bash/golem_bash_toy.tscn").instantiate()
	add_child(toy)
	await frames(2)
	Feedback.invincible = false
	Sfx.played.clear()
	toy.player.hurt_iframe = 0
	toy.player.since_dash = INF
	toy.hurt_player(1,toy.player.position.x+10)
	check(Sfx.played.has("hurt"),"getting hit plays hurt")
	toy.player.hurt_iframe = 0
	toy.player.since_dash = 0
	toy.dodge_text_at = -INF
	toy.hurt_player(1,toy.player.position.x+10)
	check(Sfx.played.has("dodge"),"dash dodge plays dodge")
	Sfx.played.clear()
	toy.golem.begin_attack("slam")
	for i: int in 180:
		await frames(1)
		if Sfx.played.has("golem_slam"): break
	check(Sfx.played.has("golem_windup") and Sfx.played.has("golem_slam"),"slam plays windup then impact (%s)" % [Sfx.played])
	Sfx.played.clear()
	toy.golem.take_damage(100000)
	check(Sfx.played.has("golem_die") and Sfx.played.has("win"),"golem death plays collapse and win")
	print("SfxSuite RESULT checks=%d failures=%d" % [checks,failures])
	get_tree().quit(1 if failures > 0 else 0)

extends Node

func _ready() -> void:
	var mode: String = OS.get_environment("GATE1_PERSIST_MODE")
	if mode == "editor_write":
		var arena: Node = load("res://scenes/arena/Arena.tscn").instantiate()
		add_child(arena)
		Tuning.set_value("dummy","enabled",false)
		arena.debug_panel.controls["player/move_speed"]["control"].value = 780
		arena.debug_panel.controls["feedback/shake_on_hit"]["control"].value = 11
		arena.debug_panel.controls["weapons/sword_basic/combo/0/recovery"]["label"].value = 0.07
		arena.debug_panel.controls["dummy/attack_interval"]["label"].value = 4.5
		arena.debug_panel.weapon_select.item_selected.emit(2)
		var good: bool = Tuning.save_values()
		print("PERSIST_EDITOR_WRITE ",good)
		get_tree().quit(0 if good else 1)
	elif mode == "editor_read":
		var good: bool = Tuning.player["move_speed"] == 780 and Tuning.feedback["shake_on_hit"] == 11 and Tuning.defaults["player"]["move_speed"] == 520 and Tuning.get_weapon("sword_basic")["combo"][0]["recovery"] == 0.07 and Tuning.training["dummy"]["attack_interval"] == 4.5 and Tuning.training["player"]["weapon_id"] == "daggers_twin"
		print("PERSIST_EDITOR_FRESH_PROCESS ",good)
		get_tree().quit(0 if good else 1)
	elif mode == "override_read":
		Tuning.storage_override = OS.get_environment("GATE1_TEST_TUNING")
		var good: bool = Tuning.load_override() and Tuning.player["move_speed"] == 780
		print("PERSIST_OVERRIDE_FRESH_PROCESS ",good)
		get_tree().quit(0 if good else 1)
	elif mode == "full_override_read":
		Tuning.storage_override = OS.get_environment("GATE1_TEST_TUNING")
		var good: bool = Tuning.load_override() and Tuning.get_weapon("sword_basic")["combo"][0]["recovery"] == 0.04 and Tuning.training["dummy"]["attack_interval"] == 4.5 and Tuning.training["player"]["weapon_id"] == "greatsword_slab"
		print("PERSIST_FULL_PANEL_FRESH_PROCESS ",good)
		get_tree().quit(0 if good else 1)
	else:
		get_tree().quit(1)

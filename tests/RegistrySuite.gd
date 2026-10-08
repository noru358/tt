extends Node
var failures: int = 0
var checks: int = 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)
	else: print("PASS: " + description)

func _ready() -> void:
	check(DataRegistry.is_valid, "canonical startup")
	check(DataRegistry.get_boss("golem")["max_hp"] == 900, "boss lookup")
	check(DataRegistry.get_weapon("sword_basic")["combo"].size() == 4, "weapon lookup")
	check(DataRegistry.get_equipment("core_ward")["effects"].size() == 2, "equipment lookup")
	check(DataRegistry.get_material("wing_feather")["name"] == "날개 깃털", "material lookup")
	check(DataRegistry.all_equipment().size() == 5, "all equipment")
	var copy: Dictionary = DataRegistry.get_weapon("sword_basic")
	copy["combo"][0]["damage"] = -1
	check(DataRegistry.get_weapon("sword_basic")["combo"][0]["damage"] == 10, "query returns isolated deep copy")
	check(Tuning.player == DataRegistry.documents["tuning/player.json"], "tuning bootstrap")
	var expected_keys: Dictionary = {"move_left": KEY_LEFT, "move_right": KEY_RIGHT, "aim_up": KEY_UP, "aim_down": KEY_DOWN, "jump": KEY_SPACE, "dash": KEY_SHIFT, "attack": KEY_J, "parry": KEY_K, "potion": KEY_L, "pause": KEY_ESCAPE, "retry": KEY_R}
	for action: String in expected_keys:
		var found_key: bool = false
		var found_pad: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and event.physical_keycode == expected_keys[action]: found_key = true
			if event is InputEventJoypadButton: found_pad = true
		check(found_key and found_pad, "keyboard + pad bindings: " + action)
	var expected_pad: Dictionary = {"jump":JOY_BUTTON_A,"dash":JOY_BUTTON_B,"attack":JOY_BUTTON_X,"parry":JOY_BUTTON_LEFT_SHOULDER,"potion":JOY_BUTTON_Y,"pause":JOY_BUTTON_START}
	for action: String in expected_pad:
		var found: bool = false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == expected_pad[action]: found = true
		check(found,"exact standard pad binding: " + action)
	for i: int in range(1, 7):
		check(not InputMap.has_action("debug_f%d" % i), "F%d debug binding removed" % i)
	check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1920 and ProjectSettings.get_setting("display/window/size/viewport_height") == 1080, "logical resolution")
	check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items" and ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "stretch contract")
	var manifest_path: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="): manifest_path = argument.trim_prefix("--manifest=")
	check(not manifest_path.is_empty(), "fixture manifest supplied")
	if not manifest_path.is_empty():
		var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		for case: Dictionary in manifest:
			var valid: bool = DataRegistry.load_all(case["root"])
			var text: String = "\n".join(DataRegistry.errors)
			check(valid == case["valid"], case["name"] + ": validity")
			for expected: String in case["errors"]:
				check(text.contains(expected), case["name"] + ": " + expected)
			if not valid: check(DataRegistry.all_equipment().is_empty(), case["name"] + ": access blocked")
			if not valid: print("EXPECTED_ERRORS " + text.replace("\n", " | "))
	check(DataRegistry.load_all(), "restored canonical registry")
	print("SUITE_RESULT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

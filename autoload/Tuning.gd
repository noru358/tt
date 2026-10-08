extends Node
signal changed
signal saved(message: String)
var player: Dictionary = {}
var feedback: Dictionary = {}
var weapons: Array = []
var training: Dictionary = {}
var defaults: Dictionary = {}
var golem: Dictionary = {}
var storage_override: String = "" # Tests use an isolated path; never production user data.

func _ready() -> void:
	storage_override = OS.get_environment("GATE1_TEST_TUNING")
	if DataRegistry.is_valid:
		player = DataRegistry.documents["tuning/player.json"].duplicate(true)
		feedback = DataRegistry.documents["tuning/feedback.json"].duplicate(true)
		weapons = DataRegistry.documents["weapons.json"].duplicate(true)
		training = DataRegistry.documents["training.json"].duplicate(true)
		defaults = DataRegistry.documents["tuning_defaults.json"].duplicate(true)
		golem = DataRegistry.get_boss("golem")["cutout"].duplicate(true)
		load_override()

func override_path() -> String:
	return storage_override if not storage_override.is_empty() else "user://tuning_override.json"

func load_override() -> bool:
	if not FileAccess.file_exists(override_path()): return true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(override_path()))
	if data is Dictionary:
		if data.get("player") is Dictionary:
			var legacy: Dictionary = data["player"]
			if legacy.has("dash_keeps_attack") and not legacy.has("dash_attack_continues_after_dash"):
				legacy["dash_attack_continues_after_dash"] = legacy["dash_keeps_attack"]
			legacy.erase("dash_keeps_attack")
			legacy.erase("input_edge_lifetime")
		for section: String in ["player","feedback","training","golem"]:
			if not data.has(section): data[section] = defaults[section].duplicate(true)
			elif data[section] is Dictionary: _fill_missing(data[section],defaults[section])
		if not data.has("weapons"): data["weapons"] = defaults["weapons"].duplicate(true)
		if data.get("weapons") is Array:
			for base: Dictionary in defaults["weapons"]:
				var found: bool = false
				for entry: Variant in data["weapons"]:
					if not entry is Dictionary or entry.get("id") != base["id"]: continue
					found = true
					_fill_missing(entry,base)
					if entry.get("combo") is Array and not entry["combo"].is_empty():
						while entry["combo"].size() < base["combo"].size(): entry["combo"].append(base["combo"][entry["combo"].size()].duplicate(true))
				if not found: data["weapons"].append(base.duplicate(true))
	var before: int = DataRegistry.errors.size()
	DataRegistry._validate(data, DataRegistry.Schema.obj({"player":DataRegistry.Schema.player_schema(), "feedback":DataRegistry.Schema.feedback_schema(), "weapons":DataRegistry.Schema.weapons_schema(), "training":DataRegistry.Schema.training_schema(),"golem":DataRegistry.Schema.golem_schema()}), override_path(), "$")
	if before != DataRegistry.errors.size():
		DataRegistry.is_valid = false
		return false
	DataRegistry.validate_cutout(data["golem"],override_path())
	if before != DataRegistry.errors.size():
		DataRegistry.is_valid = false
		return false
	golem = data["golem"].duplicate(true)
	player = data["player"].duplicate(true)
	feedback = data["feedback"].duplicate(true)
	weapons = data["weapons"].duplicate(true)
	training = data["training"].duplicate(true)
	var ids: Array = weapons.map(func(item: Dictionary) -> String: return item["id"])
	var seen: Dictionary = {}
	for id: String in ids:
		if seen.has(id): DataRegistry._error(override_path(),"$.weapons","중복 weapon id: " + id)
		seen[id] = true
	if not training["player"]["weapon_id"] in ids:
		DataRegistry._error(override_path(),"$.training.player.weapon_id","존재하지 않는 weapon id")
	for equipment: Dictionary in DataRegistry.all_equipment():
		if equipment.has("weapon_id") and equipment["weapon_id"] not in ids:
			DataRegistry._error(override_path(),"$.weapons","장비가 참조하는 무기 누락: " + equipment["weapon_id"])
	if before != DataRegistry.errors.size():
		DataRegistry.is_valid = false
		return false
	changed.emit()
	return true

func set_value(section: String, key: String, value: Variant) -> void:
	var values: Dictionary = section_values(section)
	var previous: Dictionary = golem.duplicate(true) if section.begins_with("golem") else {}
	if key.contains("/"):
		var parts: PackedStringArray = key.split("/")
		values[parts[0]][int(parts[1])] = value
	else:
		if section.begins_with("golem/") and key == "windup":
			var shift: float = float(value)-float(values[key])
			for time_key: String in ["active_start","active_end","punish_end","duration"]: values[time_key] += shift
		values[key] = value
	if section.begins_with("golem"):
		var before: int = DataRegistry.errors.size()
		DataRegistry._validate(golem,DataRegistry.Schema.golem_schema(),"golem tuning","$")
		if DataRegistry.errors.size() == before: DataRegistry.validate_cutout(golem,"golem tuning")
		if DataRegistry.errors.size() != before:
			golem = previous
			DataRegistry.errors.resize(before)
			saved.emit("골렘 설정 거부: 시간 순서·범위 확인 (예비 ≤ 시작 < 종료 ≤ 기회 종료 ≤ 전체)")
	changed.emit()

func value_at(section: String, key: String) -> Variant:
	var values: Dictionary = section_values(section)
	if key.contains("/"):
		var parts: PackedStringArray = key.split("/")
		return values[parts[0]][int(parts[1])]
	return values[key]

func reset_defaults() -> void:
	golem = defaults["golem"].duplicate(true)
	player = defaults["player"].duplicate(true)
	feedback = defaults["feedback"].duplicate(true)
	weapons = defaults["weapons"].duplicate(true)
	training = defaults["training"].duplicate(true)
	changed.emit()

func get_weapon(id: String) -> Dictionary:
	for weapon: Dictionary in weapons:
		if weapon["id"] == id: return weapon
	return {}

func section_values(section: String) -> Dictionary:
	match section:
		"golem": return golem
		"player": return player
		"feedback": return feedback
		"dummy": return training["dummy"]
		"practice": return training["player"]
	var parts: PackedStringArray = section.split("/")
	if parts[0] == "golem" and parts.size() == 2: return golem["moves"][parts[1]]
	if parts[0] == "weapons":
		var weapon: Dictionary = get_weapon(parts[1])
		if parts.size() == 2: return weapon
		if parts[2] == "combo": return weapon["combo"][int(parts[3])]
		return weapon[parts[2]]
	return {}

func _write_json(path: String, data: Variant) -> Error:
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result != OK: return result
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))

func save_values() -> bool:
	var result: Error
	# The editor-capable executable has the editor feature; exported builds do not.
	if OS.has_feature("editor") and storage_override.is_empty():
		var boss_data: Dictionary = DataRegistry.get_boss("golem").duplicate(true)
		boss_data["cutout"] = golem.duplicate(true)
		result = _write_json("res://data/bosses/golem.json",boss_data)
		if result == OK: result = _write_json("res://data/tuning/player.json", player)
		if result == OK: result = _write_json("res://data/tuning/feedback.json", feedback)
		if result == OK: result = _write_json("res://data/weapons.json", weapons)
		if result == OK: result = _write_json("res://data/training.json", training)
		if result == OK and FileAccess.file_exists(override_path()):
			result = DirAccess.remove_absolute(ProjectSettings.globalize_path(override_path()))
		saved.emit("프로젝트 JSON 저장 완료" if result == OK else "저장 실패: %s" % result)
	else:
		result = _write_json(override_path(), {"player":player, "feedback":feedback,"weapons":weapons,"training":training,"golem":golem})
		saved.emit("런타임 튜닝 저장 완료" if result == OK else "저장 실패: %s" % result)
	return result == OK

func _fill_missing(target: Dictionary, base: Dictionary) -> void:
	for key: String in base:
		if not target.has(key):
			target[key] = base[key].duplicate(true) if base[key] is Dictionary or base[key] is Array else base[key]
		elif target[key] is Dictionary and base[key] is Dictionary:
			_fill_missing(target[key],base[key])
		elif target[key] is Array and base[key] is Array:
			for i: int in mini(target[key].size(),base[key].size()):
				if target[key][i] is Dictionary and base[key][i] is Dictionary: _fill_missing(target[key][i],base[key][i])

func balance_warning() -> String:
	if float(player["dash_cooldown"]) + 0.000001 < float(player["dash_iframe"])+float(player["min_vulnerable_gap"]):
		return "대시 경고 · 쿨다운 %.2f초 < 무적 %.2f초 + 취약 구간 %.2f초" % [player["dash_cooldown"],player["dash_iframe"],player["min_vulnerable_gap"]]
	return ""

func combat_modified() -> bool:
	return not same_values(golem,DataRegistry.get_boss("golem").get("cutout",defaults["golem"])) or not same_values(player,DataRegistry.documents["tuning/player.json"]) or not same_values(weapons,DataRegistry.documents["weapons.json"])

func same_values(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float): return float(a) == float(b)
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same_values(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i: int in a.size():
			if not same_values(a[i],b[i]): return false
		return true
	return a == b

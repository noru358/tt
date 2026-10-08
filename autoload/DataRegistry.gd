extends Node
## Fail-closed bootstrap. No partial data is exposed via the query API.
const Schema = preload("res://scripts/data/DataSchema.gd")
const REQUIRED_FILES: Array[String] = ["battle.json", "tuning/player.json", "tuning/feedback.json", "tuning_defaults.json", "training.json", "weapons.json", "equipment.json", "materials.json"]
var documents: Dictionary = {}
var errors: Array[String] = []
var counts: Dictionary = {}
var is_valid: bool = false
var _indexes: Dictionary = {}
var _structural_ok: Dictionary = {}

func _ready() -> void:
	load_all()

func load_all(base_path: String = "res://data") -> bool:
	documents.clear()
	errors.clear()
	counts.clear()
	_indexes = {"bosses": {}, "weapons": {}, "equipment": {}, "materials": {}}
	_structural_ok.clear()
	is_valid = false
	var files: Array[String] = []
	_scan(base_path, "", files)
	for required: String in REQUIRED_FILES:
		if required not in files:
			_error(required, "$", "필수 파일 누락")
	files.sort()
	for file: String in files:
		var handle: FileAccess = FileAccess.open(base_path.path_join(file), FileAccess.READ)
		if handle == null:
			_error(file, "$", "파일 읽기 실패 (%s)" % FileAccess.get_open_error())
			continue
		var source: String = handle.get_as_text()
		var parsed: Variant = JSON.parse_string(source)
		if parsed == null:
			var diagnostic: JSON = JSON.new()
			diagnostic.parse(source)
			_error(file, "$", "JSON 구문 오류 또는 null 루트 (line %s): %s" % [diagnostic.get_error_line(), diagnostic.get_error_message()])
			continue
		var schema: Dictionary = _schema_for(file)
		if schema.is_empty():
			_error(file, "$", "지원하지 않는 데이터 파일; 검증 스키마 필요")
			continue
		documents[file] = parsed
		_build_index(file, parsed)
		var before: int = errors.size()
		_validate(parsed, schema, file, "$")
		if errors.size() == before:
			_structural_ok[file] = true
			counts[file] = parsed.size()
	if _indexes["bosses"].is_empty(): _error("bosses", "$", "보스 데이터 최소1개 필요")
	_cross_references()
	_cross_validate()
	is_valid = errors.is_empty()
	return is_valid

func _scan(base: String, relative: String, out: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(base.path_join(relative))
	if directory == null:
		_error(relative, "$", "데이터 폴더 읽기 실패")
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if not entry.begins_with("."):
			var child: String = relative.path_join(entry)
			if directory.current_is_dir():
				_scan(base, child, out)
			elif entry.get_extension().to_lower() == "json":
				out.append(child)
		entry = directory.get_next()
	directory.list_dir_end()

func _schema_for(file: String) -> Dictionary:
	match file:
		"tuning/player.json": return Schema.player_schema()
		"tuning/feedback.json": return Schema.feedback_schema()
		"tuning_defaults.json": return Schema.obj({"player":Schema.player_schema(), "feedback":Schema.feedback_schema(), "weapons":Schema.weapons_schema(), "training":Schema.training_schema(), "golem":Schema.golem_schema()})
		"battle.json": return Schema.battle_schema()
		"training.json": return Schema.training_schema()
		"weapons.json": return Schema.weapons_schema()
		"equipment.json": return Schema.equipment_schema()
		"materials.json": return Schema.materials_schema()
	if file.begins_with("bosses/"):
		return Schema.boss_schema()
	return {}

func _error(file: String, path: String, message: String) -> void:
	errors.append("%s:%s:%s" % [file, path, message])

func _number(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))

func _validate(value: Variant, schema: Variant, file: String, path: String) -> void:
	if schema is String:
		var valid: bool = false
		match schema:
			"bool": valid = typeof(value) == TYPE_BOOL
			"number": valid = _number(value)
			"nonnegative", "positive", "ratio", "positive_int", "nonnegative_int":
				valid = _number(value)
				if valid:
					var n: float = float(value)
					valid = n >= 0.0
					if schema in ["positive", "positive_int"]: valid = n > 0.0
					if schema == "ratio": valid = n >= 0.0 and n <= 1.0
					if schema.ends_with("_int"): valid = valid and n == floor(n)
			"text", "id":
				valid = value is String and not value.is_empty()
				if valid and schema == "id":
					var regex: RegEx = RegEx.new()
					regex.compile("^[a-z][a-z0-9_]*$")
					valid = regex.search(value) != null
			"vector", "size", "color":
				var length: int = 4 if schema == "color" else 2
				if not value is Array or value.size() != length:
					_error(file, path, "%s: 숫자 배열 길이 %d 필요" % [schema, length])
					return
				for i: int in value.size():
					_validate(value[i], "ratio" if schema == "color" else ("positive" if schema == "size" else "number"), file, "%s[%d]" % [path, i])
				return
			"step", "effect":
				if not value is Dictionary or not value.get("type") is String:
					_error(file, path + ".type", "필수 문자열 type 누락 또는 타입 오류")
					return
				var typed_schema: Dictionary = Schema.step_schema(value["type"]) if schema == "step" else Schema.effect_schema(value["type"])
				if typed_schema.is_empty():
					_error(file, path + ".type", "알 수 없는 %s: %s" % [schema, value["type"]])
					return
				var before: int = errors.size()
				_validate(value, typed_schema, file, path)
				if errors.size() == before and schema == "step": _step_relations(value, file, path)
				return
		if not valid: _error(file, path, "%s 필요; 실제 %s (%s)" % [schema, type_string(typeof(value)), str(value)])
		return
	match schema["kind"]:
		"enum":
			if not value is String or value not in schema["values"]: _error(file, path, "허용값 %s; 실제 %s" % [schema["values"], value])
		"object":
			if not value is Dictionary:
				_error(file, path, "object 필요")
				return
			for key: String in schema["required"]:
				if not value.has(key): _error(file, path + "." + key, "필수 필드 누락")
			for key: String in value:
				if schema["required"].has(key): _validate(value[key], schema["required"][key], file, path + "." + key)
				elif schema["optional"].has(key): _validate(value[key], schema["optional"][key], file, path + "." + key)
				else: _error(file, path + "." + key, "알 수 없는 필드")
		"array":
			if not value is Array:
				_error(file, path, "array 필요")
				return
			if value.size() < schema["minimum"]: _error(file, path, "항목 최소 %d개 필요" % schema["minimum"])
			for i: int in value.size(): _validate(value[i], schema["item"], file, "%s[%d]" % [path, i])
		"map":
			if not value is Dictionary:
				_error(file, path, "id-keyed object 필요")
				return
			if value.size() < schema["minimum"]: _error(file, path, "항목 최소 %d개 필요" % schema["minimum"])
			for key: String in value:
				_validate(key, "id", file, path + "." + key)
				_validate(value[key], schema["value"], file, path + "." + key)

func _step_relations(value: Dictionary, file: String, path: String) -> void:
	if value["type"] == "telegraph" and value.has("target") == value.has("offset"):
		_error(file, path, "target 또는 offset 중 정확히 하나 필요")
	if value["type"] == "projectile" and value.has("parriable_indices"):
		if not value["parriable"]: _error(file, path + ".parriable_indices", "parriable=true 필요")
		var seen: Array = []
		for i: int in value["parriable_indices"].size():
			var index: int = int(value["parriable_indices"][i])
			if index >= int(value["count"]) or index in seen: _error(file, "%s.parriable_indices[%d]" % [path, i], "중복 또는 투사체 count 범위 초과")
			seen.append(index)

func _build_index(file: String, data: Variant) -> void:
	var group: String = "bosses" if file.begins_with("bosses/") else file.get_basename()
	if not _indexes.has(group): return
	if group != "bosses" and not data is Array: return
	var entries: Array = [data] if group == "bosses" else data
	for i: int in entries.size():
		if not entries[i] is Dictionary: continue
		var item: Dictionary = entries[i]
		if not item.get("id") is String or item["id"].is_empty(): continue
		if _indexes[group].has(item["id"]):
			_error(file, "$.id" if group == "bosses" else "$[%d].id" % i, "중복 id: " + item["id"])
		else: _indexes[group][item["id"]] = item

func _reference(group: String, id: String, file: String, path: String) -> void:
	if not _indexes[group].has(id): _error(file, path, "존재하지 않는 %s id: %s" % [group, id])

func _cross_references() -> void:
	var battle: Variant = documents.get("battle.json")
	if battle is Dictionary and battle.get("boss_id") is String:
		_reference("bosses",battle["boss_id"],"battle.json","$.boss_id")
	var defaults: Variant = documents.get("tuning_defaults.json")
	if defaults is Dictionary and defaults.get("weapons") is Array:
		var ids: Dictionary = {}
		for i: int in defaults["weapons"].size():
			var weapon: Variant = defaults["weapons"][i]
			if weapon is Dictionary and weapon.get("id") is String:
				if ids.has(weapon["id"]): _error("tuning_defaults.json","$.weapons[%d].id" % i,"중복 weapon id")
				ids[weapon["id"]] = true
		var preset_training: Variant = defaults.get("training")
		if preset_training is Dictionary and preset_training.get("player") is Dictionary:
			var preset_id: Variant = preset_training["player"].get("weapon_id")
			if preset_id is String and not ids.has(preset_id): _error("tuning_defaults.json","$.training.player.weapon_id","존재하지 않는 기본 weapon id")
	if documents.get("training.json") is Dictionary:
		var training: Dictionary = documents["training.json"]
		if training.get("player") is Dictionary and training["player"].get("weapon_id") is String:
			_reference("weapons",training["player"]["weapon_id"],"training.json","$.player.weapon_id")
	# Inspect readable references even if another field in the file is malformed.
	# Index IDs separately from valid payloads to avoid misleading missing-ID cascades.
	var equipment: Variant = documents.get("equipment.json")
	if equipment is Array:
		for i: int in equipment.size():
			var item: Variant = equipment[i]
			if not item is Dictionary: continue
			var path: String = "$[%d]" % i
			if item.get("recipe") is Dictionary:
				for material: String in item["recipe"]: _reference("materials", material, "equipment.json", path + ".recipe." + material)
			if item.get("weapon_id") is String: _reference("weapons", item["weapon_id"], "equipment.json", path + ".weapon_id")
	for file: String in documents:
		if not file.begins_with("bosses/") or not documents[file] is Dictionary: continue
		var boss: Dictionary = documents[file]
		if boss.get("drops") is Array:
			for i: int in boss["drops"].size():
				var drop: Variant = boss["drops"][i]
				if drop is Dictionary and drop.get("id") is String: _reference("materials", drop["id"], file, "$.drops[%d].id" % i)
		if boss.get("unlocks") is Array:
			for i: int in boss["unlocks"].size():
				if boss["unlocks"][i] is String: _reference("bosses", boss["unlocks"][i], file, "$.unlocks[%d]" % i)
		if boss.get("phases") is Array and boss.get("patterns") is Dictionary:
			for i: int in boss["phases"].size():
				var phase: Variant = boss["phases"][i]
				if not phase is Dictionary: continue
				var path: String = "$.phases[%d]" % i
				if phase.get("patterns") is Array:
					for j: int in phase["patterns"].size():
						var reference: Variant = phase["patterns"][j]
						if reference is Dictionary and reference.get("id") is String and not boss["patterns"].has(reference["id"]):
							_error(file, "%s.patterns[%d].id" % [path, j], "존재하지 않는 pattern id: " + reference["id"])
				if phase.get("enter_pattern") is String and not boss["patterns"].has(phase["enter_pattern"]):
					_error(file, path + ".enter_pattern", "존재하지 않는 pattern id: " + phase["enter_pattern"])

func _cross_validate() -> void:
	for file: String in _structural_ok:
		if file.begins_with("bosses/") and documents[file].has("cutout"): validate_cutout(documents[file]["cutout"],file)
	if _structural_ok.has("tuning_defaults.json"): validate_cutout(documents["tuning_defaults.json"]["golem"],"tuning_defaults.json")
	if _structural_ok.has("equipment.json"):
		var equipment: Array = documents["equipment.json"]
		for i: int in equipment.size():
			var item: Dictionary = equipment[i]
			var path: String = "$[%d]" % i
			if item["slot"] == "weapon" and not item.has("weapon_id"): _error("equipment.json", path + ".weapon_id", "weapon 슬롯에 필수")
			if item.has("weapon_id"):
				if item["slot"] != "weapon": _error("equipment.json", path + ".weapon_id", "weapon 슬롯만 사용 가능")
			for stat: String in item["modifiers"]:
				if stat != "damage_mult" and not Schema.player_schema()["required"].has(stat): _error("equipment.json", path + ".modifiers." + stat, "알 수 없는 스탯")
				if Schema.player_schema()["required"].get(stat) == "bool": _error("equipment.json", path + ".modifiers." + stat, "boolean 플래그는 산술 보정 불가")
				if item["modifiers"][stat].is_empty(): _error("equipment.json", path + ".modifiers." + stat, "add 또는 mul 필요")
				if item["modifiers"][stat].get("mul", 0.0) < -1.0: _error("equipment.json", path + ".modifiers." + stat + ".mul", "-1 이상 필요")
	for file: String in _structural_ok:
		if not file.begins_with("bosses/"): continue
		var boss: Dictionary = documents[file]
		if boss["id"] != file.get_file().get_basename(): _error(file, "$.id", "파일명과 id 불일치")
		if boss["arena"]["left"] >= boss["arena"]["right"]: _error(file, "$.arena", "left < right 필요")
		for pattern_id: String in boss["patterns"]:
			var pattern: Dictionary = boss["patterns"][pattern_id]
			if pattern["min_distance"] > pattern["max_distance"]: _error(file, "$.patterns." + pattern_id, "min_distance <= max_distance 필요")
		var previous: float = 1.0
		for i: int in boss["phases"].size():
			var phase: Dictionary = boss["phases"][i]
			var path: String = "$.phases[%d]" % i
			if phase["hp_above"] >= previous: _error(file, path + ".hp_above", "1 미만에서 엄격한 내림차순 필요")
			previous = phase["hp_above"]
		if previous != 0.0: _error(file, "$.phases", "마지막 hp_above=0 필요")
		for i: int in boss["drops"].size():
			var drop: Dictionary = boss["drops"][i]
			var path: String = "$.drops[%d]" % i
			if drop.has("min") != drop.has("max"): _error(file, path, "min/max는 함께 필요")
			if not drop.has("min") and not drop.has("chance"): _error(file, path, "min/max 또는 chance 필요")
			if drop.has("min") and drop.has("max") and drop["min"] > drop["max"]: _error(file, path, "min <= max 필요")
		for i: int in boss["unlocks"].size():
			if boss["unlocks"][i] == boss["id"]: _error(file, "$.unlocks[%d]" % i, "자기 자신 해금 불가")

func _lookup(group: String, id: String) -> Dictionary:
	if not is_valid or not _indexes[group].has(id):
		push_error("DataRegistry 조회 차단: %s/%s" % [group, id])
		return {}
	return _indexes[group][id].duplicate(true)

func get_boss(id: String) -> Dictionary:
	return _lookup("bosses", id)

func get_weapon(id: String) -> Dictionary:
	return _lookup("weapons", id)

func get_equipment(id: String) -> Dictionary:
	return _lookup("equipment", id)

func all_equipment() -> Array:
	return _indexes["equipment"].values().duplicate(true) if is_valid else []

func get_material(id: String) -> Dictionary:
	return _lookup("materials", id)

func all_bosses() -> Array:
	var result: Array = _indexes["bosses"].values().duplicate(true) if is_valid else []
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["order"] < b["order"] if a["order"] != b["order"] else str(a["id"]) < str(b["id"]))
	return result

func initial_bosses() -> Array:
	return all_bosses().filter(func(boss: Dictionary) -> bool: return boss["initially_unlocked"]).map(func(boss: Dictionary) -> String: return boss["id"])

func validate_cutout(value: Dictionary, file: String) -> void:
	if float(value["idle_min"]) > float(value["idle_max"]): _error(file,"$.idle_min","idle_min <= idle_max 필요")
	for id: String in value["moves"]:
		var m: Dictionary = value["moves"][id]
		if not (float(m["windup"]) <= float(m["active_start"]) and float(m["active_start"]) < float(m["active_end"]) and float(m["active_end"]) <= float(m["punish_end"]) and float(m["punish_end"]) <= float(m["duration"])):
			_error(file,"$.moves."+id,"windup <= active_start < active_end <= punish_end <= duration 필요")
		if m["animation"] not in ["slam","slam_heavy","slam_high","sweep","stomp"]: _error(file,"$.moves."+id+".animation","지원하지 않는 리그 모션")

extends Node
signal changed
const Calc = preload("res://scripts/stats/StatCalc.gd")
var state: Dictionary = {}
var save_error: String = ""
var save_blocked: bool = false
var storage_path: String = "user://save.json"
var progression_run: bool = false
var selected_boss: String = ""
var migration_warnings: Array[String] = []
var migration_changed: bool = false
var pending_reward: Dictionary = {}
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	var test_path: String = OS.get_environment("GATE1_TEST_SAVE")
	if not test_path.is_empty(): storage_path = test_path
	rng.randomize()
	if DataRegistry.is_valid:
		var initial: Array = DataRegistry.initial_bosses()
		var bosses: Array = DataRegistry.all_bosses()
		selected_boss = initial[0] if not initial.is_empty() else (bosses[0]["id"] if not bosses.is_empty() else "")
		load_save()

func fresh() -> Dictionary:
	var materials: Dictionary = {}
	for material: Dictionary in DataRegistry.documents["materials.json"]: materials[material["id"]] = 0
	return {"version":1,"materials":materials,"owned":[],"equipped":{"weapon":"","armor":"","charm":""},"unlocked":DataRegistry.initial_bosses(),"records":{},"last_reward_token":""}

func validate(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.get("version") != 1 or not value.get("materials") is Dictionary or not value.get("owned") is Array or not value.get("equipped") is Dictionary or not value.get("unlocked") is Array or not value.get("records") is Dictionary or not value.get("last_reward_token") is String: return false
	var known_materials: Dictionary = fresh()["materials"]
	if value["materials"].size() != known_materials.size(): return false
	for id: String in value["materials"]:
		var amount: Variant = value["materials"][id]
		if not known_materials.has(id) or not _integer(amount) or float(amount) < 0: return false
	var equipment: Dictionary = {}
	for item: Dictionary in DataRegistry.all_equipment(): equipment[item["id"]] = item
	var seen: Dictionary = {}
	for id: Variant in value["owned"]:
		if not id is String or not equipment.has(id) or seen.has(id): return false
		seen[id] = true
	if value["equipped"].size() != 3: return false
	for slot: String in ["weapon","armor","charm"]:
		var id: Variant = value["equipped"].get(slot)
		if not id is String: return false
		if id != "" and (id not in value["owned"] or equipment[id]["slot"] != slot): return false
	var bosses: Dictionary = DataRegistry._indexes["bosses"]
	seen.clear()
	for id: Variant in value["unlocked"]:
		if not id is String or not bosses.has(id) or seen.has(id): return false
		seen[id] = true
	for id: String in DataRegistry.initial_bosses():
		if id not in value["unlocked"]: return false
	for id: String in value["records"]:
		var record: Variant = value["records"][id]
		if not bosses.has(id) or not record is Dictionary: return false
		if not _integer(record.get("kills")) or float(record["kills"]) < 1: return false
		var best: Variant = record.get("best_time")
		if not (best is float or best is int) or not is_finite(float(best)) or float(best) < 0: return false
	return true

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))

func load_save() -> bool:
	state = fresh()
	save_error = ""
	save_blocked = false
	migration_warnings.clear()
	if not FileAccess.file_exists(storage_path):
		if not _recover_missing_save(): return false
		if not FileAccess.file_exists(storage_path): return true
	var parser: JSON = JSON.new()
	var parsed: Variant = null
	if parser.parse(FileAccess.get_file_as_string(storage_path)) == OK: parsed = parser.data
	var migrated: Dictionary = migrate_save(parsed)
	if migrated.is_empty() or not validate(migrated):
		save_error = "진행 저장 파일을 읽을 수 없습니다. 원본은 보존했습니다. 초기화 전에 확인하세요: "+ProjectSettings.globalize_path(storage_path)
		save_blocked = true
		return false
	if migration_changed:
		var backup: String = storage_path+".pre-migrate.bak"
		if FileAccess.file_exists(backup):
			var stamp: String = str(int(Time.get_unix_time_from_system()*1000000))
			backup = storage_path+".pre-migrate-"+stamp+".bak"
			var suffix: int = 0
			while FileAccess.file_exists(backup):
				suffix += 1
				backup = storage_path+".pre-migrate-"+stamp+"-"+str(suffix)+".bak"
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(storage_path),ProjectSettings.globalize_path(backup)) != OK or not commit(migrated):
			save_error = "저장 이전/백업 실패 · 원본 보존"
			save_blocked = true
			return false
	else: state = migrated
	for warning: String in migration_warnings: push_warning("Save migration: "+warning)
	var first: Array = DataRegistry.all_bosses()
	if selected_boss.is_empty() and not first.is_empty(): selected_boss = first[0]["id"]
	changed.emit()
	return true

func commit(next: Dictionary) -> bool:
	if save_blocked: return false
	if not validate(next):
		save_error = "저장 데이터 검증 실패"
		return false
	# Identical hub autosaves must not rotate away the previous distinct state.
	if FileAccess.file_exists(storage_path):
		var existing: Variant = JSON.parse_string(FileAccess.get_file_as_string(storage_path))
		if Tuning.same_values(existing,next):
			state = next
			save_error = ""
			changed.emit()
			return true
	var file: FileAccess = FileAccess.open(storage_path+".tmp",FileAccess.WRITE)
	if file == null:
		save_error = "저장 실패: "+str(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(next,"  ")+"\n")
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result == OK and FileAccess.file_exists(storage_path): result = DirAccess.copy_absolute(ProjectSettings.globalize_path(storage_path),ProjectSettings.globalize_path(storage_path+".bak"))
	if result == OK: result = DirAccess.rename_absolute(ProjectSettings.globalize_path(storage_path+".tmp"),ProjectSettings.globalize_path(storage_path))
	if result != OK:
		save_error = "저장 실패: "+str(result)
		return false
	state = next
	save_error = ""
	changed.emit()
	return true

func save() -> bool:
	return commit(state.duplicate(true))

func reset_progress() -> bool:
	# Keep a durable reset backup; normal autosave rotates the separate .bak.
	if FileAccess.file_exists(storage_path):
		var backup: String = storage_path+".reset-"+str(Time.get_unix_time_from_system()).replace(".","-")+".bak"
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(storage_path),ProjectSettings.globalize_path(backup)) != OK:
			save_error = "초기화 전 백업 실패 · 원본 유지"
			return false
	save_blocked = false
	var good: bool = commit(fresh())
	if good: pending_reward.clear()
	return good

func equipment() -> Array:
	var result: Array = []
	for slot: String in ["weapon","armor","charm"]:
		var id: String = state["equipped"][slot]
		if not id.is_empty(): result.append(DataRegistry.get_equipment(id))
	return result

func loadout() -> Dictionary:
	return Calc.calculate(Tuning.player,equipment())

func can_craft(id: String) -> bool:
	if save_blocked or not pending_reward.is_empty() or id in state["owned"]: return false
	var item: Dictionary = DataRegistry.get_equipment(id)
	if item.is_empty() or (not Tuning.player["parry_enabled"] and Calc.parry_only(item)): return false
	for material: String in item["recipe"]:
		if int(state["materials"].get(material,0)) < int(item["recipe"][material]): return false
	return true

func craft(id: String) -> bool:
	if not can_craft(id): return false
	var next: Dictionary = state.duplicate(true)
	for material: String in DataRegistry.get_equipment(id)["recipe"]: next["materials"][material] -= int(DataRegistry.get_equipment(id)["recipe"][material])
	next["owned"].append(id)
	return commit(next)

func equip(slot: String, id: String) -> bool:
	if slot not in ["weapon","armor","charm"] or not pending_reward.is_empty(): return false
	if id != "" and (id not in state["owned"] or DataRegistry.get_equipment(id)["slot"] != slot): return false
	var next: Dictionary = state.duplicate(true)
	next["equipped"][slot] = id
	return commit(next)

func award_win(boss: Dictionary, seconds: float, token: String, debug_used: bool = false) -> Dictionary:
	if state["last_reward_token"] == token: return {}
	if not pending_reward.is_empty(): return retry_reward()
	var drops: Dictionary = {}
	for drop: Dictionary in boss["drops"]:
		if drop.has("chance") and rng.randf() >= float(drop["chance"]): continue
		drops[drop["id"]] = rng.randi_range(int(drop.get("min",1)),int(drop.get("max",1)))
	var next: Dictionary = state.duplicate(true)
	for id: String in drops: next["materials"][id] += drops[id]
	for id: String in boss["unlocks"]:
		if id not in next["unlocked"]: next["unlocked"].append(id)
	var record: Dictionary = next["records"].get(boss["id"],{"kills":0,"best_time":0.0})
	record["kills"] += 1
	if not debug_used: record["best_time"] = seconds if float(record["best_time"]) <= 0 else minf(float(record["best_time"]),seconds)
	next["records"][boss["id"]] = record
	next["last_reward_token"] = token
	pending_reward = {"state":next,"drops":drops}
	return retry_reward()

func retry_reward() -> Dictionary:
	if pending_reward.is_empty(): return {}
	var drops: Dictionary = pending_reward["drops"].duplicate()
	if not commit(pending_reward["state"]): return {}
	pending_reward.clear()
	return drops

func migrate_save(value: Variant) -> Dictionary:
	migration_changed = false
	migration_warnings.clear()
	if not value is Dictionary or not _integer(value.get("version")) or value["version"] < 1: return {}
	if not value.get("materials") is Dictionary or not value.get("owned") is Array or not value.get("equipped") is Dictionary or not value.get("unlocked") is Array or not value.get("records") is Dictionary or not value.get("last_reward_token") is String: return {}
	if value["equipped"].size() != 3: return {}
	for slot: String in ["weapon","armor","charm"]:
		if not value["equipped"].get(slot) is String: return {}
	for amount: Variant in value["materials"].values():
		if not _integer(amount) or amount < 0: return {}
	for id: Variant in value["owned"]+value["unlocked"]:
		if not id is String: return {}
	for record: Variant in value["records"].values():
		if not record is Dictionary or not _integer(record.get("kills")) or record["kills"] < 1: return {}
		var time: Variant = record.get("best_time")
		if not (time is float or time is int) or not is_finite(float(time)) or float(time) < 0: return {}
	var next: Dictionary = value.duplicate(true)
	if next["version"] != 1: migration_warnings.append("구조 호환 저장 version %s → 1" % next["version"])
	next["version"] = 1
	var known: Dictionary = fresh()["materials"]
	for id: String in next["materials"].keys():
		if not known.has(id):
			next["materials"].erase(id)
			migration_warnings.append("삭제 재료 제거: "+id)
	for id: String in known:
		if not next["materials"].has(id):
			next["materials"][id] = 0
			migration_warnings.append("새 재료 0으로 추가: "+id)
	var equipment_ids: Array = DataRegistry.all_equipment().map(func(item: Dictionary) -> String: return item["id"])
	for id: String in next["owned"].duplicate():
		if id not in equipment_ids:
			next["owned"].erase(id)
			migration_warnings.append("삭제 장비 제거: "+id)
	for slot: String in next["equipped"]:
		var id: String = next["equipped"][slot]
		if not id.is_empty() and id not in equipment_ids:
			next["equipped"][slot] = ""
			migration_warnings.append("삭제 장비 장착 해제: "+id)
	var boss_ids: Array = DataRegistry.all_bosses().map(func(boss: Dictionary) -> String: return boss["id"])
	for id: String in next["unlocked"].duplicate():
		if id not in boss_ids:
			next["unlocked"].erase(id)
			migration_warnings.append("삭제 보스 해금 제거: "+id)
	for id: String in next["records"].keys():
		if id not in boss_ids:
			next["records"].erase(id)
			migration_warnings.append("삭제 보스 기록 제거: "+id)
	for id: String in DataRegistry.initial_bosses():
		if id not in next["unlocked"]: next["unlocked"].append(id)
	migration_changed = not Tuning.same_values(next,value)
	return next

func _recover_missing_save() -> bool:
	var found: bool = false
	for suffix: String in [".tmp",".bak"]:
		var candidate: String = storage_path+suffix
		if not FileAccess.file_exists(candidate): continue
		found = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(candidate))
		var recovered: Dictionary = migrate_save(parsed)
		if recovered.is_empty() or not validate(recovered): continue
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(candidate),ProjectSettings.globalize_path(storage_path)) == OK:
			return true
	if found:
		save_error = "본 저장 파일이 없고 복구 파일을 읽거나 복원할 수 없습니다. .tmp/.bak를 보존했습니다."
		save_blocked = true
		return false
	return true

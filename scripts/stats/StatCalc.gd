extends RefCounted
static func calculate(base: Dictionary, equipment: Array) -> Dictionary:
	var stats: Dictionary = base.duplicate(true)
	stats["damage_mult"] = 1.0
	var adds: Dictionary = {}
	var muls: Dictionary = {}
	var effects: Array = []
	var weapon_id: String = "sword_basic"
	for item: Dictionary in equipment:
		if item.has("weapon_id"): weapon_id = item["weapon_id"]
		for key: String in item["modifiers"]:
			adds[key] = float(adds.get(key,0))+float(item["modifiers"][key].get("add",0))
			muls[key] = float(muls.get(key,0))+float(item["modifiers"][key].get("mul",0))
		effects.append_array(item["effects"].duplicate(true))
	for key: String in stats:
		if stats[key] is bool: continue
		stats[key] = (float(stats[key])+float(adds.get(key,0)))*(1+float(muls.get(key,0)))
	for effect: Dictionary in effects:
		match effect["type"]:
			"potion_bonus": stats["potion_count"] += int(effect["count"])
			"parry_window_bonus":
				if stats["parry_enabled"]: stats["parry_window"] += float(effect["seconds"])
	return {"stats":stats,"effects":effects,"weapon_id":weapon_id}

static func parry_only(item: Dictionary) -> bool:
	if item["effects"].is_empty(): return false
	for effect: Dictionary in item["effects"]:
		if effect["type"] not in ["parry_window_bonus","on_parry_heal"]: return false
	return true

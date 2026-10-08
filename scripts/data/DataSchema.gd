extends RefCounted
## Structural contracts only. Gameplay values live in res://data.

static func obj(required: Dictionary, optional: Dictionary = {}) -> Dictionary:
	return {"kind": "object", "required": required, "optional": optional}

static func arr(item: Variant, minimum: int = 0) -> Dictionary:
	return {"kind": "array", "item": item, "minimum": minimum}

static func choice(values: Array) -> Dictionary:
	return {"kind": "enum", "values": values}

static func mapping(value: Variant, minimum: int = 0) -> Dictionary:
	return {"kind": "map", "value": value, "minimum": minimum}

static func player_schema() -> Dictionary:
	var fields: Dictionary = {}
	for key: String in ["move_speed", "ground_accel", "air_accel", "gravity", "fall_gravity_mult", "max_fall_speed", "jump_velocity", "coyote_time", "jump_buffer", "dash_distance", "dash_iframe", "dash_cooldown", "perfect_dodge_window", "parry_window", "parry_whiff_recovery", "parry_cooldown", "hurt_iframe", "hurt_knockback", "potion_heal", "potion_channel"]:
		fields[key] = "nonnegative"
	fields.merge({"jump_cut_mult": "nonnegative", "dash_duration": "nonnegative", "parry_enabled": "bool", "max_hp": "nonnegative_int", "potion_count": "nonnegative_int", "hurt_recovery": "nonnegative", "air_dash_count": "nonnegative_int"})
	fields.merge({"defense_buffer":"nonnegative", "defense_cancel_hurt":"bool", "min_vulnerable_gap":"nonnegative", "parry_whiff_cancel":"bool", "parry_whiff_dash_cancel":"bool", "device_switch_axis":"ratio"})
	fields.merge({"attack_during_dash":"bool", "dash_attack_continues_after_dash":"bool", "dash_direction_grace":"nonnegative", "attack_hold_repeat":"bool", "pogo_resets_air_dash":"bool"})
	fields.merge({"instant_move":"bool", "ground_decel":"nonnegative", "air_decel":"nonnegative", "attack_move_mult":"nonnegative", "attack_direction_chain":"bool", "attack_buffer":"nonnegative", "attack_cancel_on_jump":"bool", "attack_cancel_on_dash":"bool", "attack_release_clears_buffer":"bool"})
	for key: String in ["bow_input_buffer", "bow_charge_time", "bow_cooldown", "bow_damage_min", "bow_damage_max", "bow_speed_min", "bow_speed_max", "bow_turn_rate", "bow_lock_range", "bow_lifetime", "bow_hit_size"]: fields[key] = "nonnegative"
	for key: String in ["bow_charge_time","bow_speed_min","bow_speed_max","bow_lifetime","bow_hit_size","bow_lock_range"]: fields[key] = "positive"
	return obj(fields)

static func feedback_schema() -> Dictionary:
	var fields: Dictionary = {"damage_numbers": "bool", "hitstop_time_scale": "nonnegative"}
	for key: String in ["hitstop_on_hit", "hitstop_on_parry", "hitstop_on_player_hurt", "shake_on_hit", "shake_on_parry", "shake_on_player_hurt", "shake_decay", "boss_hit_flash"]:
		fields[key] = "nonnegative"
	return obj(fields)

static func training_schema() -> Dictionary:
	return obj({
		"arena": obj({"floor_y":"number", "left":"number", "right":"number", "platform_thickness":"positive", "platforms":arr(obj({"x":"number", "y":"number", "w":"positive"}), 2)}),
		"player":obj({"spawn":"vector", "size":"size", "color":"color", "weapon_id":"id"}),
		"dummy":obj({"enabled":"bool", "position":"vector", "size":"size", "color":"color", "attack_interval":"positive", "warning_time":"positive", "attack_cycle":arr(choice(["melee", "projectile"]), 1), "hitbox_size":"size", "hitbox_offset_y":"number", "hitbox_duration":"positive", "damage":"positive", "projectile_speed":"positive", "projectile_size":"size", "projectile_lifetime":"positive", "parry_stagger":"nonnegative"}),
		"feedback":obj({"message_duration":"positive", "number_duration":"positive", "number_rise_speed":"nonnegative", "attack_color":"color", "debug_speeds":arr("positive", 1)})
	})

static func battle_schema() -> Dictionary:
	return obj({"boss_id":"id", "player_spawn":"vector", "boss_spawn":"vector", "intro_duration":"nonnegative", "result_input_delay":"nonnegative", "selection_retry":"positive", "projectile_lifetime":"positive", "shockwave_width":"positive", "fall_warning_height":"positive", "platform_thickness":"positive"})

static func attack(extra: Dictionary = {}) -> Dictionary:
	var fields: Dictionary = {"damage": "positive", "startup": "nonnegative", "active": "positive", "recovery": "nonnegative", "chain_at":"nonnegative", "reach": "positive", "height": "positive"}
	fields.merge(extra)
	return obj(fields)

static func weapons_schema() -> Dictionary:
	return arr(obj({"id": "id", "name": "text", "combo": arr(attack({"knockback": "nonnegative", "lunge": "nonnegative"}), 1), "combo_window": "nonnegative", "air_attack": attack(), "down_attack": attack({"pogo_velocity": "positive"}), "up_attack": attack(), "flags": arr(choice(["dash_cancel"]))}), 1)

static func materials_schema() -> Dictionary:
	return arr(obj({"id": "id", "name": "text"}, {"rare": "bool"}), 1)

static func equipment_schema() -> Dictionary:
	return arr(obj({"id": "id", "name": "text", "slot": choice(["weapon", "armor", "charm"]), "recipe": mapping("positive_int", 1), "modifiers": mapping(obj({}, {"add": "number", "mul": "number"})), "effects": arr("effect")}, {"weapon_id": "id"}), 1)

static func boss_schema() -> Dictionary:
	return obj({
		"id": "id", "name": "text", "initially_unlocked":"bool", "order":"nonnegative_int", "max_hp": "positive", "body": obj({"shape": choice(["rect", "triangle", "circle"]), "size": "size", "color": "color"}),
		"contact_damage": "nonnegative", "gravity": "nonnegative",
		"arena": obj({"floor_y": "number", "left": "number", "right": "number", "platforms": arr(obj({"x": "number", "y": "number", "w": "positive"}))}),
		"stagger": obj({"threshold": "positive", "duration": "positive", "decay_per_sec": "nonnegative", "parry_gain": "nonnegative", "heavy_hit_gain": "nonnegative", "heavy_damage_threshold": "positive", "damage_mult": "positive"}),
		"phases": arr(obj({"hp_above": "ratio", "speed_mult": "positive", "patterns": arr(obj({"id": "id", "weight": "positive"}), 1)}, {"enter_pattern": "id"}), 1),
		"patterns": mapping(obj({"cooldown": "nonnegative", "min_distance": "nonnegative", "max_distance": "nonnegative", "steps": arr("step", 1)}), 1),
		"drops": arr(obj({"id": "id"}, {"min": "positive_int", "max": "positive_int", "chance": "ratio"})), "unlocks": arr("id")
	}, {"cutout":golem_schema()})

static func effect_schema(kind: String) -> Dictionary:
	var types: Dictionary = {
		"on_perfect_dodge_damage_buff": {"mult": "positive", "duration": "positive"},
		"potion_bonus": {"count": "nonnegative_int"}, "parry_window_bonus": {"seconds": "nonnegative"}, "on_parry_heal": {"amount": "nonnegative"}
	}
	if not types.has(kind):
		return {}
	var fields: Dictionary = types[kind].duplicate()
	fields["type"] = "text"
	return obj(fields)

static func step_schema(kind: String) -> Dictionary:
	var targets: Dictionary = choice(["player_x", "arena_left", "arena_right", "arena_center", "above_player"])
	var damage_box: Dictionary = obj({"offset": "vector", "size": "size", "damage": "positive", "knockback": "nonnegative", "parriable": "bool"})
	var schemas: Dictionary = {
		"cutout_attack": obj({"move":choice(["slam","sweep","stomp"])}),
		"wait": obj({"duration": "nonnegative"}),
		"face_target": obj({}),
		"telegraph": obj({"shape": choice(["rect", "triangle", "circle"]), "size": "size", "duration": "positive", "color": "color"}, {"offset": "vector", "target": choice(["player_x", "self"])}),
		"move_to": obj({"target": targets, "speed": "positive"}, {"offset_y": "number", "stop_distance": "nonnegative", "max_duration":"positive"}),
		"dash": obj({"direction": choice(["facing", "to_target"]), "speed": "positive", "distance": "positive"}, {"hitbox": damage_box}),
		"jump": obj({"target": choice(["player_x", "arena_left", "arena_right", "arena_center", "opposite_side"]), "height": "positive", "duration": "positive"}),
		"hitbox": obj({"offset": "vector", "size": "size", "duration": "positive", "damage": "positive", "knockback": "nonnegative", "parriable": "bool", "attach": choice(["self", "world"])}),
		"shockwave": obj({"direction": choice(["left", "right", "both"]), "speed": "positive", "height": "positive", "damage": "positive", "parriable": "bool"}),
		"projectile": obj({"count": "positive_int", "spread_deg": "nonnegative", "aim": choice(["target", "down", "forward"]), "speed": "positive", "size": "size", "damage": "positive", "parriable": "bool"}, {"gravity": "nonnegative", "parriable_indices": arr("nonnegative_int"), "reflect_damage": "positive", "reflect_stagger": "nonnegative"}),
		"falling": obj({"count": "positive_int", "x_mode": choice(["random", "around_player"]), "spread": "nonnegative", "warn_time": "positive", "size": "size", "damage": "positive", "fall_speed": "positive", "spawn_y": "number"}),
		"set_vulnerable": obj({"value": "bool"}),
		"repeat": obj({"times": "positive_int", "steps": arr("step", 1)}, {"between_steps": arr("step", 1)})
	}
	if not schemas.has(kind):
		return {}
	var result: Dictionary = schemas[kind]
	result["required"]["type"] = "text"
	return result

static func golem_schema() -> Dictionary:
	var attack: Dictionary = obj({"animation": "text", "source_windup": "nonnegative", "windup": "nonnegative", "active_start": "nonnegative", "active_end": "nonnegative", "punish_end": "nonnegative", "duration": "positive", "hitbox_x": "number", "hitbox_y": "number", "hitbox_width": "positive", "hitbox_height": "positive", "damage": "positive", "knockback": "nonnegative", "parriable": "bool", "shake": "nonnegative"})
	var fields: Dictionary = {"scale": "positive", "weakpoint_enabled": "bool", "weakpoint_size": "positive", "weakpoint_multiplier": "positive", "foot_zone": "positive", "foot_dwell": "positive", "idle_min": "positive", "idle_max": "positive", "phase2_windup": "positive", "phase2_shockwave": "bool", "shockwave_speed": "positive", "shockwave_damage": "positive", "shockwave_height": "positive"}
	fields.merge({"walk_enabled":"bool","walk_speed":"positive","walk_stop_distance":"positive","walk_stride":"positive","walk_lift":"nonnegative","contact_damage":"nonnegative","contact_interval":"positive"})
	fields["moves"] = obj({"slam":attack,"sweep":attack,"stomp":attack})
	return obj(fields)

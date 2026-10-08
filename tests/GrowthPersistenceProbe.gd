extends Node
func _ready() -> void:
	var good: bool = not OS.get_environment("GATE1_TEST_SAVE").is_empty() and not GameState.save_blocked
	good = good and GameState.state["records"].get("golem",{}).get("kills",0) == 4
	good = good and GameState.state["equipped"] == {"weapon":"slab_greatsword","armor":"rock_mail","charm":"core_ward"}
	good = good and "wing" in GameState.state["unlocked"] and GameState.loadout()["stats"]["max_hp"] == 130
	print("GROWTH_FRESH_PROCESS ",good)
	get_tree().quit(0 if good else 1)

extends "res://scripts/boss/steps/Step.gd"
# Expansion retains the JSON order and inserts between_steps only between passes.
static func expand(value: Dictionary) -> Array:
	var result: Array = []
	for index: int in int(value["times"]):
		result.append_array(value["steps"])
		if index+1 < int(value["times"]): result.append_array(value.get("between_steps",[]))
	return result

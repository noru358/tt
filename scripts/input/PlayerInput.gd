class_name PlayerInput
extends Node
## Device-scoped adapter. -1 = keyboard; >=0 = a specific joypad ID.
@export var device_id: int = -1
@export var auto_device: bool = true
var blocked: bool = false
var received: Dictionary = {}
var history_version: int = 0
var input_clock: float = 0.0
var _current: Dictionary = {}
var _previous: Dictionary = {}
var _focused: bool = true
var _pending_press: Dictionary = {}
var _pending_release: Dictionary = {}
var _pending_directions: Dictionary = {}
var _press_directions: Dictionary = {}
var _pressed_edges: Dictionary = {}
var _released_edges: Dictionary = {}
var _last_horizontal: float = 1.0
var _last_vertical: float = 1.0
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"aim_up", &"aim_down", &"jump", &"dash", &"attack", &"magic_bow", &"parry", &"potion", &"pause", &"retry"]

func _ready() -> void:
	process_priority = -100
	process_physics_priority = -100

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		clear_history()
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true
		clear_history()
		_seed_held()

func _input(event: InputEvent) -> void:
	if event.is_echo() or blocked or not _focused: return
	var next_device: int = device_id
	if auto_device:
		if event is InputEventKey and event.pressed: next_device = -1
		elif event is InputEventJoypadButton and event.pressed: next_device = event.device
		elif event is InputEventJoypadMotion and absf(event.axis_value) >= float(Tuning.player["device_switch_axis"]) and not _keyboard_held(): next_device = event.device
	if next_device != device_id:
		clear_history()
		device_id = next_device
		_seed_held()
	if event is InputEventKey:
		if device_id != -1: return
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if device_id != event.device: return
	else: return
	for action: StringName in ACTIONS:
		if event.is_action_pressed(action):
			_pending_press[action] = input_clock
			received[action] = int(received.get(action,0))+1
			if action == &"move_left": _last_horizontal = -1
			elif action == &"move_right": _last_horizontal = 1
			elif action == &"aim_up": _last_vertical = -1
			elif action == &"aim_down": _last_vertical = 1
			_pending_directions[action] = _raw_direction()
		elif event.is_action_released(action): _pending_release[action] = true

func clear_history() -> void:
	history_version += 1
	_pending_press.clear()
	_pending_release.clear()
	_pending_directions.clear()
	_press_directions.clear()
	_pressed_edges.clear()
	_released_edges.clear()
	_current.clear()
	_previous.clear()

func set_blocked(value: bool) -> void:
	blocked = value
	clear_history()
	# Seed held states on resume, so an old held button isn't a fresh action.
	if not blocked: _seed_held()

func _seed_held() -> void:
	for action: StringName in ACTIONS: _current[action] = _read_strength(action)
	_previous = _current.duplicate()

func _physics_process(delta: float) -> void:
	input_clock += delta
	_press_directions.clear()
	_previous = _current.duplicate()
	_pressed_edges.clear()
	_released_edges = _pending_release.duplicate()
	# Every received edge is consumed once on the next physics tick.
	for action: StringName in _pending_press:
		_pressed_edges[action] = true
		_press_directions[action] = _pending_directions[action]
	_pending_press.clear()
	_pending_release.clear()
	_pending_directions.clear()
	for action: StringName in ACTIONS:
		_current[action] = _read_strength(action) if _focused and not blocked else 0.0

func _read_strength(action: StringName) -> float:
	var result: float = 0.0
	for binding: InputEvent in InputMap.action_get_events(action):
		if device_id == -1 and binding is InputEventKey:
			if Input.is_physical_key_pressed(binding.physical_keycode): result = 1.0
		elif device_id >= 0 and binding is InputEventJoypadButton:
			if Input.is_joy_button_pressed(device_id, binding.button_index): result = 1.0
		elif device_id >= 0 and binding is InputEventJoypadMotion:
			var amount: float = Input.get_joy_axis(device_id, binding.axis) * signf(binding.axis_value)
			var deadzone: float = InputMap.action_get_deadzone(action)
			if amount > deadzone: result = maxf(result, (amount - deadzone) / (1.0 - deadzone))
	return result

func strength(action: StringName) -> float:
	return float(_current.get(action, 0.0))

func pressed(action: StringName) -> bool:
	return strength(action) > 0.0

func just_pressed(action: StringName) -> bool:
	return _pressed_edges.has(action) or (pressed(action) and float(_previous.get(action, 0.0)) == 0.0)

func just_released(action: StringName) -> bool:
	return _released_edges.has(action) or (not pressed(action) and float(_previous.get(action, 0.0)) > 0.0)

func horizontal() -> float:
	if pressed(&"move_left") and pressed(&"move_right"): return _last_horizontal
	return strength(&"move_right")-strength(&"move_left")

func vertical() -> float:
	if pressed(&"aim_up") and pressed(&"aim_down"): return _last_vertical
	return strength(&"aim_down")-strength(&"aim_up")

func _raw_direction() -> Vector2:
	var left: float = _read_strength(&"move_left")
	var right: float = _read_strength(&"move_right")
	var up: float = _read_strength(&"aim_up")
	var down: float = _read_strength(&"aim_down")
	return Vector2(_last_horizontal if left > 0 and right > 0 else right-left,_last_vertical if up > 0 and down > 0 else down-up)

func direction_at_press(action: StringName) -> Vector2:
	return _press_directions.get(action,Vector2(horizontal(),vertical()))

func _keyboard_held() -> bool:
	for code: int in range(256):
		# Printable physical keys plus the gameplay special keys below.
		if Input.is_physical_key_pressed(code): return true
	for code: int in range(KEY_SPECIAL,KEY_SPECIAL+128):
		if Input.is_physical_key_pressed(code): return true
	return false

class_name CircuitInput
extends RefCounted
## Physical keyboard positions and Godot's actual gamepad axes, shared by tests and game.

static func install() -> void:
	var keys: Dictionary = {
		"throttle": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE], "shift_up": [KEY_E], "shift_down": [KEY_Q],
		"drs": [KEY_F], "camera_toggle": [KEY_C], "pause": [KEY_ESCAPE],
		"reset_car": [KEY_R], "ghost_toggle": [KEY_G], "coach_toggle": [KEY_K],
		"training_toggle": [KEY_T]
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.12)
		InputMap.action_erase_events(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	axis("throttle", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	button("handbrake", JOY_BUTTON_A)
	button("drs", JOY_BUTTON_X)
	button("camera_toggle", JOY_BUTTON_Y)
	button("shift_up", JOY_BUTTON_RIGHT_SHOULDER)
	button("shift_down", JOY_BUTTON_LEFT_SHOULDER)
	button("pause", JOY_BUTTON_START)
	button("reset_car", JOY_BUTTON_BACK)

static func axis(action: String, axis_index: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis_index
	event.axis_value = direction
	InputMap.action_add_event(action, event)

static func button(action: String, index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	InputMap.action_add_event(action, event)

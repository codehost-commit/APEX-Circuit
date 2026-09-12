extends Node3D
## Runtime composition is deliberate: the slice stays text-only until final art arrives.

func _ready() -> void:
	_setup_input_map()
	Engine.max_fps = RaceConfig.target_fps
	get_viewport().set_embedding_subwindows(false)
	print("APEX Circuit booted: Forward+ project, Jolt configured, game systems loading.")

func _setup_input_map() -> void:
	var bindings := {
		"throttle": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
		"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT],
		"handbrake": [KEY_SPACE], "shift_up": [KEY_E], "shift_down": [KEY_Q],
		"drs": [KEY_F], "camera_toggle": [KEY_C], "pause": [KEY_ESCAPE]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)

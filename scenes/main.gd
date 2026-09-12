extends Node3D
## Runtime composition is deliberate: the slice stays text-only until final art arrives.

var track: CircuitTrack
var player_car: RaycastFormulaCar

func _ready() -> void:
	_setup_input_map()
	Engine.max_fps = RaceConfig.target_fps
	get_viewport().set_embedding_subwindows(false)
	_build_environment()
	track = CircuitTrack.new()
	track.name = "ApexLoop"
	add_child(track)
	player_car = RaycastFormulaCar.new()
	player_car.name = "PlayerCar"
	player_car.player_controlled = true
	player_car.driver_name = "YOU"
	player_car.track = track
	player_car.global_transform = track.pose_at_grid(0)
	add_child(player_car)
	player_car.race_enabled = true
	GameState.player_car = player_car
	print("APEX Circuit booted: Forward+ project, Jolt configured, game systems loading.")

func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8fa9bf")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#b9c6d0")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment_node.environment = environment
	add_child(environment_node)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -30.0, 0.0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = RaceConfig.shadow_distance
	add_child(sun)

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

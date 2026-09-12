extends Node3D
## Runtime composition is deliberate: the slice stays text-only until final art arrives.

var track: CircuitTrack
var player_car: RaycastFormulaCar
var all_cars: Array[RaycastFormulaCar] = []
var _ai_profile: RacingLineProfile
var race_director: RaceDirector
var hud: RaceHUD
var menu: ApexMenu
var menu_cinematic: MenuCinematic

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
	all_cars.append(player_car)
	_spawn_ai_field()
	race_director = RaceDirector.new()
	race_director.name = "RaceDirector"
	add_child(race_director)
	race_director.setup(track, all_cars)
	GameState.race_director = race_director
	hud = RaceHUD.new()
	add_child(hud)
	hud.setup(track, all_cars)
	menu_cinematic = MenuCinematic.new()
	add_child(menu_cinematic)
	menu_cinematic.setup(track, all_cars)
	menu = ApexMenu.new()
	add_child(menu)
	menu.qualifying_requested.connect(_start_qualifying)
	menu.race_requested.connect(_start_race)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	race_director.start_preview()
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

func _spawn_ai_field() -> void:
	_ai_profile = RacingLineProfile.new()
	_ai_profile.build(track, player_car.tuning)
	var colors := [Color("#2189d5"), Color("#dfb42c"), Color("#35af68"), Color("#7b55bd"), Color("#dd6947"), Color("#df4384"), Color("#46b8bd"), Color("#d6dfed"), Color("#9ca637"), Color("#d33c3c"), Color("#788796")]
	for index in RaceConfig.field_ai_count:
		var car := RaycastFormulaCar.new()
		car.name = "AI_%02d" % (index + 1)
		car.driver_name = "AI %02d" % (index + 1)
		car.livery_color = colors[index % colors.size()]
		car.track = track
		car.global_transform = track.pose_at_grid(index + 1)
		add_child(car)
		car.race_enabled = true
		all_cars.append(car)
	for index in RaceConfig.field_ai_count:
		var driver := AIFormulaDriver.new()
		driver.name = "Driver_%02d" % (index + 1)
		driver.pace_multiplier = 0.975 + float(index % 6) * 0.006
		driver.reaction_seconds = 0.10 + float(index % 3) * 0.04
		driver.error_amplitude = 0.006 + float(index % 4) * 0.004
		driver.driver_seed = index + 17
		add_child(driver)
		driver.setup(all_cars[index + 1], track, _ai_profile, all_cars)

func _start_qualifying() -> void:
	menu.visible = false
	menu_cinematic.set_active(false)
	player_car.activate_chase_camera()
	race_director.start_qualifying()

func _start_race() -> void:
	menu.visible = false
	menu_cinematic.set_active(false)
	player_car.activate_chase_camera()
	race_director.start_race()

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

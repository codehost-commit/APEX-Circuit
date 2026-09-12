extends Node3D
## Real scene composition. All modes use the same car, circuit and physics.
var track: CircuitTrack
var player_car: RaycastFormulaCar
var all_cars: Array[RaycastFormulaCar] = []
var drivers: Array[AIFormulaDriver] = []
var _ai_profile: RacingLineProfile
var race_director: RaceDirector
var hud: RaceHUD
var menu: ApexMenu
var menu_cinematic: MenuCinematic
var world_environment: WorldEnvironment
var active_session := "race"
var _preview_stuck: Dictionary = {}
var preview_recoveries := 0
var _capture_elapsed := 0.0
var _capture_path := ""
var _capture_after := 4.0
var _capture_camera := 0
var _autodrive := false
var _frame_samples: Array[float] = []
var _preview_driver: AIFormulaDriver

func _ready() -> void:
	CircuitInput.install()
	Engine.max_fps = RaceConfig.target_fps
	_build_environment()
	track = CircuitTrack.new()
	track.name = "ApexGrandPrixCircuit"
	add_child(track)
	_build_field()
	race_director = RaceDirector.new()
	race_director.name = "RaceDirector"
	add_child(race_director)
	race_director.setup(track, all_cars)
	EventBus.session_started.connect(_session_started)
	GameState.race_director = race_director
	hud = RaceHUD.new()
	add_child(hud)
	hud.setup(track, all_cars)
	hud.restart_requested.connect(_restart_session)
	hud.menu_requested.connect(_return_to_menu)
	hud.skip_qualifying_requested.connect(_skip_qualifying)
	menu_cinematic = MenuCinematic.new()
	add_child(menu_cinematic)
	menu_cinematic.setup(track, all_cars)
	menu = ApexMenu.new()
	add_child(menu)
	menu.qualifying_requested.connect(_start_qualifying)
	menu.race_requested.connect(_start_race)
	menu.time_trial_requested.connect(_start_time_trial)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	_return_to_menu()
	var practice := PracticeTools.new()
	add_child(practice)
	practice.setup(self)
	_read_run_arguments()
	print("APEX | %.1f m | %d drivers | profile %.2f s | physical 120 Hz" % [track.total_length, all_cars.size(), _ai_profile.nominal_lap_seconds])

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4277a8")
	sky_material.sky_horizon_color = Color("#bdd0d7")
	sky_material.ground_bottom_color = Color("#4e6150")
	sky_material.ground_horizon_color = Color("#bcc8bd")
	sky_material.sky_curve = 0.65
	sky_material.sun_angle_max = 3.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.62
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.22
	environment.ssao_enabled = true
	environment.ssao_radius = 1.0
	environment.ssao_intensity = 1.1
	environment.ssr_enabled = RaceConfig.enable_ssr
	environment.sdfgi_enabled = RaceConfig.enable_sdfgi
	environment.fog_enabled = true
	environment.fog_light_color = Color("#b6c7ce")
	environment.fog_density = 0.000075
	environment.fog_sky_affect = 0.12
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	sun.light_energy = 1.65
	sun.light_color = Color("#fff2d9")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	sun.directional_shadow_fade_start = 0.80
	add_child(sun)

func _session_started(mode: int) -> void:
	match mode:
		GameState.Mode.RACE:
			active_session = "race"
		GameState.Mode.QUALIFYING:
			active_session = "qualifying"
		GameState.Mode.TIME_TRIAL:
			active_session = "time_trial"

func _build_field() -> void:
	var colors := ["#159fea", "#ef3d4e", "#ffc62f", "#15ac88", "#ec7a26", "#744fda", "#d5e0e8", "#dd4685", "#3dbccd", "#304b9f", "#afd752", "#788c9d"]
	var names := ["YOU", "M. VALE", "A. SERRANO", "K. NOVAK", "J. BLAKE", "R. MORI", "S. COSTA", "L. REED", "D. PARK", "N. STONE", "E. ROSS", "T. GRAY"]
	for index in RaceConfig.grid_size:
		var car := RaycastFormulaCar.new()
		car.name = "PlayerCar" if index == 0 else "Competitor%02d" % index
		car.player_controlled = index == 0
		car.driver_name = names[index % names.size()]
		car.livery_color = Color(colors[index % colors.size()])
		car.track = track
		if ResourceLoader.exists("res://assets/cars/formula_car.tscn"):
			car.visual_scene = load("res://assets/cars/formula_car.tscn")
		car.transform = track.pose_at_grid(index)
		add_child(car)
		all_cars.append(car)
	player_car = all_cars[0]
	GameState.player_car = player_car
	_ai_profile = RacingLineProfile.new()
	_ai_profile.build(track, player_car.tuning)
	for index in all_cars.size():
		var driver := AIFormulaDriver.new()
		driver.name = "Driver%02d" % index
		driver.pace_multiplier = 0.96 - float(index) * 0.0018
		driver.reaction_seconds = 0.14 + float(index % 4) * 0.025
		driver.error_amplitude = 0.004 + float(index % 3) * 0.001
		driver.driver_seed = randi()
		add_child(driver)
		driver.setup(all_cars[index], track, _ai_profile, all_cars)
		drivers.append(driver)
	_preview_driver = drivers[0]

func _prepare_session() -> void:
	get_tree().paused = false
	GameState.paused = false
	menu.visible = false
	menu_cinematic.set_active(false)
	_preview_driver.enabled = false
	for car in all_cars:
		car.visible = true
		car.freeze = false
		car.collision_layer = 2
		car.collision_mask = 3
		car.automated_input = not car.player_controlled
	player_car.activate_chase_camera()
	for driver in drivers:
		driver.tactics_enabled = true
		driver.reset_session()

func _start_qualifying() -> void:
	active_session = "qualifying"
	_prepare_session()
	race_director.start_qualifying()
	for driver in drivers:
		driver.reset_session()

func _start_race() -> void:
	active_session = "race"
	_prepare_session()
	race_director.start_race()

func _start_time_trial() -> void:
	active_session = "time_trial"
	_prepare_session()
	race_director.start_time_trial()

func _skip_qualifying() -> void:
	active_session = "race"
	_prepare_session()
	race_director.skip_to_grid()

func _restart_session() -> void:
	match active_session:
		"time_trial": _start_time_trial()
		"qualifying": _start_qualifying()
		_: _start_race()

func _return_to_menu() -> void:
	get_tree().paused = false
	GameState.paused = false
	race_director.start_preview()
	menu.visible = true
	hud.visible = false
	_preview_stuck.clear()
	preview_recoveries = 0
	player_car.set_camera_mode(0)
	for index in all_cars.size():
		var car := all_cars[index]
		car.visible = true
		car.freeze = false
		car.collision_layer = 2
		car.collision_mask = 3
		car.automated_input = true
		var distance := track.total_length * float(index) / float(all_cars.size())
		var sample := _ai_profile.sample_at_distance(distance)
		car.reset_to_pose(Transform3D(Basis.looking_at(sample.tangent), sample.position + Vector3.UP * 0.075), true)
		car.race_progress = distance
		car.race_enabled = true
		car.set_flying_speed(_ai_profile.target_speed_at(distance) * 0.92)
		drivers[index].enabled = true
		drivers[index].tactics_enabled = false
		drivers[index].reset_session()
	menu_cinematic.set_active(true)

func _physics_process(delta: float) -> void:
	if GameState.mode == GameState.Mode.MENU:
		for index in all_cars.size():
			var car := all_cars[index]
			var p := track.progress_at(car.global_position)
			var failed := car.speed_mps < 2.0 or absf(float(p.offset)) > track.road_half_width + track.kerb_width or car.global_basis.y.y < 0.5
			_preview_stuck[index] = float(_preview_stuck.get(index, 0.0)) + delta if failed else 0.0
			if float(_preview_stuck[index]) > 4.0:
				preview_recoveries += 1
				car.reset_to_pose(track.nearest_safe_pose(car.global_position), true)
				car.set_flying_speed(minf(35.0, _ai_profile.target_speed_at(float(p.progress))))
				drivers[index].reset_session()
				_preview_stuck[index] = 0.0
	if Input.is_action_just_pressed("reset_car") and GameState.mode != GameState.Mode.MENU:
		race_director.reset_player()
	if Input.is_action_just_pressed("ghost_toggle"):
		GameState.ghost_enabled = not GameState.ghost_enabled

func _read_run_arguments() -> void:
	# Local QA only. The normal F6/F5 launch always starts at the menu.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--session="):
			match argument.get_slice("=", 1):
				"time_trial": _start_time_trial()
				"qualifying": _start_qualifying()
				"race": _start_race()
		elif argument.begins_with("--capture="):
			_capture_path = argument.trim_prefix("--capture=")
		elif argument.begins_with("--capture-after="):
			_capture_after = float(argument.trim_prefix("--capture-after="))
		elif argument.begins_with("--camera="):
			_capture_camera = int(argument.trim_prefix("--camera="))
		elif argument == "--autodrive":
			_autodrive = true
	if GameState.mode != GameState.Mode.MENU:
		player_car.set_camera_mode(_capture_camera)
		if _capture_camera == 3:
			var inspection := Camera3D.new()
			add_child(inspection)
			inspection.global_position = player_car.global_position + player_car.global_basis.x * 4.2 - player_car.global_basis.z * 5.0 + Vector3.UP * 2.7
			inspection.look_at(player_car.global_position + Vector3.UP * 0.5)
			inspection.fov = 52.0
			inspection.current = true
		if _autodrive:
			player_car.automated_input = true
			drivers[0].enabled = true
			drivers[0].reset_session()

func _process(delta: float) -> void:
	if _capture_path.is_empty():
		return
	_capture_elapsed += delta
	if _capture_elapsed > 2.0:
		_frame_samples.append(delta)
	if _capture_elapsed > _capture_after:
		var path := _capture_path
		_capture_path = ""
		await RenderingServer.frame_post_draw
		var snapshot := get_viewport().get_texture().get_image()
		var result := snapshot.save_png(path)
		_frame_samples.sort()
		var p95 := _frame_samples[int(float(_frame_samples.size() - 1) * 0.95)] if not _frame_samples.is_empty() else 0.0
		print("CAPTURE ", path, " result=", result, " fps=", Engine.get_frames_per_second(), " p95_frame_ms=", p95 * 1000.0, " gpu_memory_mb=", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
			" physics_ms=", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			" process_ms=", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			" draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			" primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		get_tree().quit()

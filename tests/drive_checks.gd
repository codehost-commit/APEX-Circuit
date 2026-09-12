extends Node
## Integration tests use actual Jolt physics and the complete production scene.
## Run: godot --headless --path . --fixed-fps 120 tests/drive_checks.tscn
var game: Node3D
var car: RaycastFormulaCar
var failures: Array[String] = []
var results: Dictionary = {}
var lap_times: Array[float] = []
var valid_laps := 0
var _case := "all"

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--case="):
			_case = argument.trim_prefix("--case=")
	if _case not in ["all", "basics", "rules", "flow", "lap", "field", "fieldquick", "race", "race_full"]:
		push_error("Unknown drive-check case: " + _case)
		get_tree().quit(2)
		return
	game = load("res://scenes/main.tscn").instantiate()
	add_child(game)
	# Automated hot laps never replace the player's saved personal best.
	game.race_director._record_path = "res://tests/artifacts/qa_personal_best.json"
	game.race_director.personal_best = INF
	game.race_director.best_record.clear()
	Engine.max_fps = 0
	car = game.player_car
	await frames(3)
	if _case in ["all", "basics"]:
		geometry_checks()
		await handling_checks()
	if _case in ["all", "lap"]:
		await full_lap_checks()
	if _case in ["all", "field", "fieldquick"]:
		await field_checks()
	if _case in ["all", "rules"]:
		rule_checks()
	if _case in ["all", "flow"]:
		session_flow_checks()
		# Flush pending body pose resets before destroying the Jolt world.
		await frames(3)
	if _case in ["race", "race_full"]:
		await race_checks()
	results.failures = failures
	print("DRIVE_CHECKS_RESULT ", JSON.stringify(results))
	get_tree().quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures.append(label)

func session_flow_checks() -> void:
	var director := game.race_director as RaceDirector
	director.set_physics_process(false)
	game._return_to_menu()
	check(GameState.mode == GameState.Mode.MENU and game.menu.visible and not game.hud.visible, "Menu restores the floating overlay and hides the racing HUD")
	game.menu.time_trial_requested.emit()
	check(GameState.mode == GameState.Mode.TIME_TRIAL and not game.menu.visible and not car.automated_input and not game.drivers[0].enabled, "Time Trial button transfers control from menu AI to the player")
	var isolated := true
	for competitor: RaycastFormulaCar in game.all_cars:
		if competitor != car:
			isolated = isolated and not competitor.visible and competitor.freeze and competitor.collision_layer == 0
	check(isolated, "Time Trial removes every competitor from rendering and collision")
	for mode in 3:
		car.set_camera_mode(mode)
		game.hud._process(0.0)
		check(not game.hud.cockpit.visible and game.hud._instruments.visible, "Camera %d has exactly one instrument display" % mode)
	GameState.set_paused(true)
	game.hud.restart_requested.emit()
	check(not get_tree().paused and GameState.mode == GameState.Mode.TIME_TRIAL and car.lap == 0, "Restart resumes and resets the current Time Trial mode")
	director.end_time_trial()
	game.hud._process(0.0)
	check(GameState.mode == GameState.Mode.RESULTS and game.hud._results.visible, "Ending Time Trial displays session results")
	game.hud.menu_requested.emit()
	var field_restored := true
	for competitor: RaycastFormulaCar in game.all_cars:
		field_restored = field_restored and competitor.visible and not competitor.freeze and competitor.collision_layer == 2
	check(field_restored and game.menu.visible, "Returning from solo results restores all twelve physical menu cars")
	game.menu.qualifying_requested.emit()
	game.hud._process(0.0)
	check(GameState.mode == GameState.Mode.QUALIFYING and game.hud._skip.visible and not game.hud._skip.disabled, "Qualifying offers skip before the player records any lap")
	var rival: RaycastFormulaCar = game.all_cars[1]
	director._status(rival).best_lap = 95.0
	director._status(car).best_lap = 96.0
	game.hud._skip.pressed.emit()
	check(GameState.mode == GameState.Mode.RACE and director.grid_order[0] == rival and director.grid_order[1] == car, "Skip to grid orders cars by their valid qualifying bests")
	game._start_qualifying()
	director.race_time = RaceConfig.qualifying_duration
	director._physics_process(1.0 / 120.0)
	check(GameState.mode == GameState.Mode.RACE and game.active_session == "race", "Automatic qualifying expiry updates the active session to race")
	game.hud.restart_requested.emit()
	check(GameState.mode == GameState.Mode.RACE and not director.green, "Restart after automatic qualifying starts race lights, not another qualifying session")
	game._return_to_menu()
	var left_event := InputEventKey.new()
	left_event.physical_keycode = KEY_A
	var right_event := InputEventKey.new()
	right_event.physical_keycode = KEY_D
	check(InputMap.event_is_action(left_event, "steer_left") and not InputMap.event_is_action(left_event, "steer_right") and InputMap.event_is_action(right_event, "steer_right"), "Physical A and D bind to left and right, respectively")
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	check(InputMap.event_is_action(trigger, "throttle") and not InputMap.event_is_action(trigger, "brake"), "Right gamepad trigger is throttle, not brake")
	results.session_flow = {"passed":failures.is_empty()}

func frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame

func geometry_checks() -> void:
	var circuit := game.track as CircuitTrack
	check(absf(circuit.total_length - 4239.53) < 12.0, "Original prototype track length is preserved")
	check(is_equal_approx(circuit.road_half_width, 10.5) and is_equal_approx(circuit.kerb_width, 7.25), "Original road and revised kerb dimensions")
	var missing := 0
	var discontinuities := 0
	var max_projection_error := 0.0
	var space := game.get_world_3d().direct_space_state
	for i in 1500:
		var distance := circuit.total_length * float(i) / 1500.0
		var sample := circuit.sample_at_distance(distance)
		var p: Vector3 = sample.position
		var next: Vector3 = circuit.sample_at_distance(distance + 0.1).position
		if p.distance_to(next) > 0.15:
			discontinuities += 1
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 2.0, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf(float(hit.position.y) - p.y) > 0.15:
			missing += 1
		var projected: float = circuit.progress_at(p).progress
		max_projection_error = maxf(max_projection_error, absf(wrapf(projected - distance, -circuit.total_length * 0.5, circuit.total_length * 0.5)))
	results.geometry = {"length": circuit.total_length, "missing_collision": missing, "discontinuities": discontinuities, "max_projection_error_m": max_projection_error}
	check(missing == 0, "Road has continuous collision at 1500 samples including seam")
	check(discontinuities == 0 and max_projection_error < 1.0, "Continuous spline and inverse progress mapping")
	var start := circuit.sample_at_distance(70.0)
	check(float(circuit.get_surface_at(start.position).grip) == 1.0, "Asphalt grip")
	check(float(circuit.get_surface_at(start.position + start.normal * 14.0).grip) < 0.65, "Kerb grip matches slippery prototype")
	check(circuit.checkpoint_distances.size() == 5 and circuit.sector_distances.size() == 3 and circuit.drs_zones.size() == 3, "Five checkpoints, three sectors, three DRS zones")

func reset_for_controls(speed := 0.0, steer := 0.0, throttle := 0.0, brake := 0.0) -> void:
	game._start_time_trial()
	car.automated_input = true
	game.drivers[0].enabled = false
	var sample: Dictionary = game.track.sample_at_distance(30.0)
	car.reset_to_pose(game.track.nearest_safe_pose(sample.position), true)
	car.race_enabled = true
	car.set_flying_speed(speed)
	car.ai_command = {"throttle": throttle, "brake": brake, "steer": steer, "drs": false}
	await frames(3)

func handling_checks() -> void:
	await reset_for_controls(0.0, 0.0, 1.0, 0.0)
	var hundred := INF
	for tick in 600:
		await frames(1)
		if car.speed_mps >= 100.0 / 3.6 and not is_finite(hundred):
			hundred = float(tick + 1) / 120.0
	results.acceleration = {"zero_to_100_seconds": hundred, "speed_at_5_seconds_kmh": car.speed_mps * 3.6, "gear": car.gear, "rpm": car.rpm, "grounded": car.grounded_wheels}
	check(hundred > 1.8 and hundred < 4.0, "Physical 0–100 km/h in 1.8–4 seconds")
	check(car.speed_mps > 45.0 and car.gear >= 3 and car.rpm > car.tuning.idle_rpm, "Acceleration, gears and mechanical RPM advance")
	check(car.grounded_wheels == 4 and absf(car.global_basis.y.y) > 0.95, "Four suspension contacts and stable chassis")
	await reset_for_controls(15.0, 0.45, 0.25, 0.0)
	var origin := car.global_position
	var initial_right := car.global_basis.x
	await frames(120)
	var right_movement := (car.global_position - origin).dot(initial_right)
	results.right_movement_m = right_movement
	check(right_movement > 0.5, "D/right steering turns the car to its right")
	await reset_for_controls(15.0, -0.45, 0.25, 0.0)
	origin = car.global_position
	initial_right = car.global_basis.x
	await frames(120)
	var left_movement := (car.global_position - origin).dot(initial_right)
	results.left_movement_m = left_movement
	check(left_movement < -0.5, "A/left steering turns the car to its left")
	await reset_for_controls(55.0, 0.0, 0.0, 1.0)
	origin = car.global_position
	await frames(240)
	results.braking = {"speed_after_2_seconds_kmh": car.speed_mps * 3.6, "distance_m": car.global_position.distance_to(origin)}
	check(car.speed_mps < 24.0, "Full braking sheds more than 110 km/h in two seconds")
	car.drs_available = true
	car.ai_command = {"throttle": 1.0, "brake": 0.0, "steer": 0.0, "drs": true}
	game.race_director.set_physics_process(false)
	await frames(24)
	check(car.drs_open, "Eligible requested DRS opens")
	car.ai_command.brake = 1.0
	car.ai_command.throttle = 0.0
	await frames(12)
	check(not car.drs_open, "Braking shuts DRS")
	game.race_director.set_physics_process(true)
	var before := car.global_position
	GameState.set_paused(true)
	for index in 5:
		await get_tree().process_frame
	check(car.global_position.is_equal_approx(before), "Pause actually freezes vehicle physics")
	GameState.set_paused(false)

func full_lap_checks() -> void:
	game._start_time_trial()
	car.automated_input = true
	game.drivers[0].enabled = true
	game.drivers[0].tactics_enabled = false
	game.drivers[0].reset_session()
	lap_times.clear()
	valid_laps = 0
	EventBus.lap_completed.connect(_lap)
	var max_offset := 0.0
	var previous_lap := 0
	for tick in 120 * 250:
		await frames(1)
		var projection: Dictionary = game.track.progress_at(car.global_position)
		max_offset = maxf(max_offset, absf(float(projection.offset)))
		if tick % 1200 == 0:
			print("LAP_RUN t=", tick / 120, " s=", snappedf(car.race_progress, 0.1), " kph=", snappedf(car.speed_mps * 3.6, 0.1), " offset=", snappedf(float(projection.offset), 0.1), " steer=", snappedf(car.steering_input, 0.01))
		if car.lap >= 2:
			break
	EventBus.lap_completed.disconnect(_lap)
	results.laps = {"times": lap_times, "valid_laps": valid_laps, "max_offset_m": max_offset, "last_sectors": game.race_director.get_player_status().last_sectors}
	check(lap_times.size() >= 2 and valid_laps >= 2, "Two complete valid physical AI laps with no respawn")
	check(max_offset < game.track.road_half_width + game.track.kerb_width, "AI stays inside legal width around whole track")

func _lap(completed_car: Node, _number: int, seconds: float, valid: bool) -> void:
	if completed_car == car:
		lap_times.append(seconds)
		if valid:
			valid_laps += 1
		print("LAP_COMPLETED ", seconds, " valid=", valid)

func race_checks() -> void:
	RaceConfig.race_laps = 5 if _case == "race_full" else 2
	game._start_race()
	# Hold the player on the grid; the test driver takes over only at green.
	car.automated_input = true
	game.drivers[0].enabled = false
	car.ai_command = {"throttle":0.0, "brake":1.0, "steer":0.0, "drs":false}
	while not game.race_director.green:
		await frames(1)
	game.drivers[0].enabled = true
	for tick in 120 * (760 if _case == "race_full" else 360):
		await frames(1)
		if tick % 3600 == 0:
			var distances: Array = []
			for competitor: RaycastFormulaCar in game.all_cars:
				distances.append([competitor.driver_name, competitor.lap, snappedf(competitor.race_progress, 1.0), snappedf(competitor.damage,0.01),competitor.penalty_seconds])
			print("RACE_RUN t=", tick / 120, " field=", distances)
		if GameState.mode == GameState.Mode.RESULTS:
			break
	var finishers := 0
	var penalties := 0.0
	for row: Dictionary in game.race_director.get_classification():
		finishers += 1 if bool(row.finished) else 0
		penalties += float(row.penalty)
	results.race = {"finishers":finishers,"elapsed":game.race_director.race_time,"penalties":penalties,"results_shown":GameState.mode == GameState.Mode.RESULTS}
	check(GameState.mode == GameState.Mode.RESULTS and finishers == 12, "Twelve physical cars complete grid-to-classification race")

func field_checks() -> void:
	game._return_to_menu()
	var max_off := 0.0
	var slow_samples := 0
	var slow_streaks: Dictionary = {}
	var longest_slow_streak := 0
	for tick in 120 * (30 if _case == "fieldquick" else 100):
		await frames(1)
		if tick % 120 == 0:
			for competitor: RaycastFormulaCar in game.all_cars:
				var offset := absf(float(game.track.progress_at(competitor.global_position).offset))
				max_off = maxf(max_off, offset)
				if competitor.speed_mps < 5.0:
					slow_samples += 1
					slow_streaks[competitor] = int(slow_streaks.get(competitor, 0)) + 1
					longest_slow_streak = maxi(longest_slow_streak, slow_streaks[competitor])
					if slow_samples < 12:
						print("FIELD_SLOW t=", tick / 120, " car=", competitor.driver_name, " s=", competitor.race_progress, " offset=", offset, " damage=", competitor.damage, " surface=", competitor.current_surface, " target=", game.drivers[game.all_cars.find(competitor)].target_speed, " throttle=", competitor.throttle_input, " brake=", competitor.brake_input)
				else:
					slow_streaks[competitor] = 0
	results.field = {"max_offset_m": max_off, "slow_samples": slow_samples, "longest_slow_seconds":longest_slow_streak, "recoveries":game.preview_recoveries}
	check(longest_slow_streak < 3 and game.preview_recoveries == 0, "Menu field sustains flying laps without stuck cars or recovery teleports")
	check(max_off < game.track.road_half_width + game.track.kerb_width, "Whole menu field stays within the legal track")

func rule_checks() -> void:
	# Controlled poses isolate rule logic; the separate lap test verifies that
	# the actual physical car can cross these same gates without teleporting.
	game._start_time_trial()
	var director := game.race_director as RaceDirector
	director.set_physics_process(false)
	director._record_path = "res://tests/artifacts/rule_record.json"
	director.personal_best = INF
	car.automated_input = true
	var length: float = game.track.total_length
	var status: Dictionary = director._status(car)
	status.last_progress = length - 4.0
	car.speed_mps = 60.0
	for distance in range(0, int(ceil(length)) + 12, 4):
		var sample: Dictionary = game.track.sample_at_distance(float(distance))
		car.global_transform = Transform3D(Basis.looking_at(sample.tangent), sample.position + Vector3.UP * 0.04)
		director.race_time += 4.0 / 60.0
		director._update_car_progress(4.0 / 60.0)
	var completed: Dictionary = director.get_player_status()
	check(car.lap == 1 and bool(completed.last_lap_valid), "One ordered circuit traversal records exactly one valid lap")
	var sum := 0.0
	for seconds: float in completed.last_sectors:
		sum += seconds
	check(absf(sum - float(completed.last_lap)) < 0.00001, "Three measured sectors sum exactly to the lap time")
	game._start_time_trial()
	status = director._status(car)
	director.race_time = 1.0
	director._begin_lap(status, 1.0)
	status.last_progress = length - 4.0
	car.global_transform = game.track.nearest_safe_pose(game.track.sample_at_distance(2.0).position)
	car.speed_mps = 60.0
	director.race_time = 80.0
	director._update_car_progress(0.1)
	check(car.lap == 0 and not is_finite(float(status.best_lap)), "Start-line shortcut without checkpoints cannot record a lap")
	game._start_race()
	director.set_physics_process(false)
	var lights: Array[int] = []
	var ticks := 0
	while not director.green and ticks < 2000:
		director._update_start_lights(1.0 / 120.0)
		if not lights.has(director.lights_lit):
			lights.append(director.lights_lit)
		ticks += 1
	check(director.green and lights.has(1) and lights.has(5), "Start visits all five light states then releases the race")
	var rival: RaycastFormulaCar = game.all_cars[1]
	status = director._status(car)
	var zone: Vector2 = game.track.drs_zones[1]
	var detection := float(game.track.drs_detection_distances[1])
	car.race_progress = detection + 1.0
	rival.race_progress = car.race_progress + 30.0
	car.speed_mps = 60.0
	rival.speed_mps = 60.0
	director.race_time = 10.0
	var crossed_at := director._crossing_time(detection - 1.0, detection + 1.0, detection, 1.0 / 120.0)
	director._status(rival).drs_crossings[1] = crossed_at - 0.5
	director._update_drs(car, status, detection - 1.0, detection + 1.0)
	director._update_drs(car, status, zone.x - 1.0, zone.x + 1.0)
	check(car.drs_available, "Half-second gap at detection authorizes DRS at activation")
	director._update_drs(car, status, zone.y - 1.0, zone.y + 1.0)
	check(not car.drs_available, "DRS permission ends at the zone exit")
	rival.speed_mps = 5.0
	car.speed_mps = 100.0
	check(is_equal_approx(director._detection_gap(car, 1, crossed_at), 0.5), "DRS uses detector timestamps, independent of subsequent speeds")
	director._status(rival).drs_crossings[1] = crossed_at - 1.01
	director._update_drs(car, status, detection - 1.0, detection + 1.0)
	check(not bool(status.drs_eligible[1]), "A measured gap above one second denies race DRS")
	director._status(rival).drs_crossings[1] = crossed_at + 0.01
	check(not is_finite(director._detection_gap(car, 1, crossed_at)), "A trailing car crossing later cannot grant DRS")
	# The follower is first in the car array. Both cross within this physics
	# tick, so eligibility must use the prepass, not update iteration order.
	for competitor: RaycastFormulaCar in [car, rival]:
		var offset := 0.5 if competitor == car else 1.5
		competitor.global_transform = game.track.nearest_safe_pose(game.track.sample_at_distance(detection + offset).position)
		director._status(competitor).last_progress = detection + offset - 2.0
		competitor.speed_mps = 60.0
	director._record_drs_detections(1.0 / 120.0)
	var follower_crossing := float(status.drs_crossings[1])
	check(absf(director._detection_gap(car, 1, follower_crossing) - 1.0 / 240.0) < 0.00002, "Same-tick detector timestamps are interpolated independently of car order")
	director._clear_drs_detection(car, status)
	check(not bool(status.drs_eligible[1]) and not is_finite(float(status.drs_crossings[1])) and not car.drs_available, "Recovery clears stale DRS crossings and eligibility")
	car.global_transform = game.track.nearest_safe_pose(game.track.sample_at_distance(40.0).position)
	rival.global_transform = car.global_transform
	rival.global_position += -car.global_basis.z * 3.0
	car.linear_velocity = -car.global_basis.z * 50.0
	rival.linear_velocity = -car.global_basis.z * 30.0
	director.race_time = 30.0
	director._note_incident(car, rival, 0.5, "test rear-end")
	check(director.pending_incidents.size() == 1 and car.penalty_seconds == 0.0, "Rear-end incident is deferred, not immediately penalized")
	director._update_pending_incidents(31.0)
	check(car.penalty_seconds == RaceConfig.penalty_firm_seconds and rival.penalty_seconds == 0.0, "Deferred steward penalty identifies the closing aggressor")
	for competitor: RaycastFormulaCar in game.all_cars:
		competitor.finished = true
		director._status(competitor).finish_time = 100.0 + game.all_cars.find(competitor)
	director._update_classification()
	var rows := director.get_classification()
	check(rows[0].car == rival, "Penalty-adjusted finish times change final classification")
	results.rules = {"sectors": completed.last_sectors, "lap": completed.last_lap, "lights": lights, "rear_end_penalty": car.penalty_seconds}
	status.timeline = [Vector2(0.0, 10.0), Vector2(100.0, 20.0)]
	director.race_time = 25.0
	check(absf(director._row_gap({"car":car,"finished":false,"progress":100.0}, {"car":rival,"finished":false,"progress":50.0}) - 10.0) < 0.0001, "Live gaps use interpolated passage times at the same distance")
	game._start_race()
	car.global_position += -car.global_basis.z * 3.0
	director._update_start_lights(0.001)
	director._update_start_lights(0.001)
	check(car.penalty_seconds == 5.0, "Moving before lights out gives exactly one jump-start penalty")
	game._start_time_trial()
	status = director._status(car)
	var sample: Dictionary = game.track.sample_at_distance(150.0)
	car.global_transform = Transform3D(Basis.looking_at(sample.tangent), sample.position + sample.normal * 17.7 + Vector3.UP * 0.075)
	director._update_track_limits(car, status, 0.5)
	check(bool(status.lap_valid), "A wheel remaining on the legal kerb prevents an all-four-off violation")
	car.global_position += sample.normal * 7.0
	director._update_track_limits(car, status, 0.5)
	check(not bool(status.lap_valid) and int(status.limits) == 1, "All four wheels off invalidates the lap and registers a limits warning")
	car.damage = 0.37
	director.reset_player()
	check(is_equal_approx(car.damage, 0.37), "Checkpoint recovery does not repair collision damage")
	game._start_time_trial()
	check(car.damage == 0.0, "Restarting a session repairs and resets the car")
	director.personal_best = 72.5
	director.best_record = [[0.0,0.0,0.0,0.1,0.0,0.0], [72.5,length,0.0,0.1,0.0,0.0]]
	director._save_record()
	director.personal_best = INF
	director.best_record.clear()
	director._load_record()
	check(director.personal_best == 72.5 and director.best_record.size() == 2, "Personal-best time and ghost survive a save/load round trip")

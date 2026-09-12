class_name RaceDirector
extends Node
## Simulation-clock timing. Ordered physical checkpoint gates authorize each lap.

var circuit: CircuitTrack
var cars: Array[RaycastFormulaCar] = []
var statuses: Dictionary = {}
var grid_order: Array[RaycastFormulaCar] = []
var race_time := 0.0
var qualifying_time := 0.0
var light_timer := 0.0
var lights_lit := 0
var green := false
var qualifying_active := false
var pending_incidents: Array[Dictionary] = []
var personal_best := INF
var best_record: Array = []
var best_sectors := [INF, INF, INF]
var _random := RandomNumberGenerator.new()
var _last_rows: Array = []
var _incident_cooldowns: Dictionary = {}
var _classification_timer := 0.0
var _finish_deadline := INF
var _ghost: Node3D
var _ghost_index := 0
var _recording: Array = []
var _record_timer := 0.0
var _record_path := "user://apex_original_circuit_v2_record.json"

func setup(track_value: CircuitTrack, field: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	cars = field
	grid_order = field.duplicate()
	_random.randomize()
	for car in cars:
		statuses[car.get_instance_id()] = _make_status(car)
		car.race_enabled = false
	EventBus.incident.connect(_note_incident)
	_load_record()
	_create_ghost()

func start_preview() -> void:
	GameState.reset_to_menu()
	green = false
	qualifying_active = false
	_ghost.visible = false
	_set_lights(0)
	for car in cars:
		car.visible = true
		car.collision_layer = 2
		car.collision_mask = 3
		car.freeze = false
		car.race_enabled = true
		car.finished = false
		car.drs_available = false

func _prepare(mode: int) -> void:
	GameState.set_paused(false)
	GameState.mode = mode
	GameState.session_mode = mode
	GameState.elapsed_seconds = 0.0
	GameState.start_state = GameState.StartState.GREEN
	race_time = 0.0
	qualifying_time = 0.0
	qualifying_active = mode == GameState.Mode.QUALIFYING
	green = mode != GameState.Mode.RACE
	_finish_deadline = INF
	pending_incidents.clear()
	_incident_cooldowns.clear()
	_recording.clear()
	_record_timer = 0.0
	_ghost_index = 0
	_ghost.visible = false
	for index in cars.size():
		var car := cars[index]
		car.freeze = false
		car.visible = mode != GameState.Mode.TIME_TRIAL or car.player_controlled
		car.collision_layer = 2 if car.visible else 0
		car.collision_mask = 3 if car.visible else 0
		car.reset_to_pose(circuit.pose_at_grid(index), true)
		car.finished = false
		car.race_enabled = green and car.visible
		car.freeze = not car.visible
		car.penalty_seconds = 0.0
		car.lap = 0
		car.drs_available = false
		statuses[car.get_instance_id()] = _make_status(car)
	_set_lights(0)
	_update_classification()
	EventBus.session_started.emit(mode)

func start_race(from_qualifying := false) -> void:
	if from_qualifying:
		grid_order.sort_custom(func(a: RaycastFormulaCar, b: RaycastFormulaCar) -> bool:
			var first := float(_status(a).best_lap)
			var second := float(_status(b).best_lap)
			return first < second if first != second else cars.find(a) < cars.find(b))
	else:
		grid_order = cars.duplicate()
	_prepare(GameState.Mode.RACE)
	GameState.total_laps = RaceConfig.race_laps
	GameState.start_state = GameState.StartState.LIGHTS
	for index in grid_order.size():
		var car := grid_order[index]
		car.reset_to_pose(circuit.pose_at_grid(index), true)
		statuses[car.get_instance_id()] = _make_status(car)
		_status(car).grid_position = car.global_position
		car.race_enabled = car.player_controlled
	lights_lit = 0
	light_timer = 2.0
	_update_classification()
	EventBus.race_message.emit("STARTING GRID", "Hold the brake. Five red lights, then lights out.", 3.0)

func start_qualifying() -> void:
	_prepare(GameState.Mode.QUALIFYING)
	for index in cars.size():
		if index == 0:
			continue
		var car := cars[index]
		var sample := circuit.sample_at_distance(circuit.total_length * float(index) / float(cars.size()))
		car.reset_to_pose(_sample_pose(sample), true)
		car.set_flying_speed(30.0)
		statuses[car.get_instance_id()] = _make_status(car)
	EventBus.race_message.emit("QUALIFYING", "Cross the line to start a flying lap. Valid times decide the grid.", 5.0)

func start_time_trial() -> void:
	_prepare(GameState.Mode.TIME_TRIAL)
	EventBus.race_message.emit("TIME TRIAL", "Unlimited laps. Five checkpoints. Three sectors. Your clean personal best becomes the ghost.", 5.0)

func skip_to_grid() -> void:
	if qualifying_active:
		start_race(true)

func reset_player() -> void:
	var car := GameState.player_car as RaycastFormulaCar
	if car == null or GameState.mode == GameState.Mode.MENU:
		return
	var status := _status(car)
	var safe_distance := float(status.safe_progress)
	car.reset_to_pose(_sample_pose(circuit.sample_at_distance(safe_distance)))
	car.race_enabled = green
	status.last_progress = safe_distance
	status.stuck_time = 0.0
	_clear_drs_detection(car, status)
	_invalidate(car, status, "Reset to checkpoint")
	if GameState.mode == GameState.Mode.RACE:
		_apply_penalty(car, RaceConfig.recovery_penalty_seconds, "checkpoint recovery")
	EventBus.player_reset.emit(car)
	EventBus.race_message.emit("RECOVERED", "Returned to the last verified checkpoint. Current lap invalid.", 3.0)

func retire_player() -> void:
	if GameState.mode == GameState.Mode.TIME_TRIAL:
		end_time_trial()
		return
	_retire(GameState.player_car as RaycastFormulaCar, "Player retired")
	_finish_deadline = minf(_finish_deadline, race_time + 15.0)

func end_time_trial() -> void:
	_resolve_all_incidents()
	_update_classification()
	GameState.finish_race()
	EventBus.session_finished.emit(_last_rows)

func _physics_process(delta: float) -> void:
	if GameState.paused or GameState.mode == GameState.Mode.MENU or GameState.mode == GameState.Mode.RESULTS:
		return
	if GameState.mode == GameState.Mode.RACE and not green:
		_update_start_lights(delta)
		return
	race_time += delta
	qualifying_time = race_time
	GameState.elapsed_seconds = race_time
	_update_car_progress(delta)
	_update_pending_incidents(delta)
	_update_ghost(delta)
	_classification_timer -= delta
	if _classification_timer <= 0.0:
		_update_classification()
		_classification_timer = 0.12
	if qualifying_active and qualifying_time >= RaceConfig.qualifying_duration:
		skip_to_grid()
	elif GameState.mode == GameState.Mode.RACE:
		_check_finish()

func _update_start_lights(delta: float) -> void:
	light_timer -= delta
	for car in cars:
		var status := _status(car)
		if car.global_position.distance_to(status.grid_position) > 2.0 and not bool(status.jump_start):
			status.jump_start = true
			_apply_penalty(car, 5.0, "jump start")
	if light_timer > 0.0:
		return
	if lights_lit < 5:
		lights_lit += 1
		light_timer = 0.85 if lights_lit < 5 else _random.randf_range(1.0, 3.0)
		_set_lights(lights_lit)
	else:
		green = true
		GameState.start_state = GameState.StartState.GREEN
		for car in cars:
			car.race_enabled = true
		_set_lights(0, true)
		EventBus.race_message.emit("LIGHTS OUT", "Go, go, go!", 1.4)

func _update_car_progress(delta: float) -> void:
	# Record every detector crossing before evaluating any driver. Otherwise
	# cars crossing in the same physics tick depend on their scene-tree order.
	_record_drs_detections(delta)
	for car in cars:
		if not car.visible or car.finished:
			continue
		var status := _status(car)
		var projection := circuit.progress_at(car.global_position)
		var progress := float(projection.progress)
		car.race_progress = progress
		var previous := float(status.last_progress)
		var travelled := wrapf(progress - previous, -circuit.total_length * 0.5, circuit.total_length * 0.5)
		var physical_step := travelled > 0.0 and travelled < maxf(15.0, car.speed_mps * delta * 3.0)
		_update_track_limits(car, status, delta)
		var in_gate := absf(float(projection.offset)) <= RaceConfig.track_width * 0.5 + RaceConfig.kerb_width + 2.0
		if physical_step:
			status.distance += travelled
			status.wrong_way_time = maxf(0.0, float(status.wrong_way_time) - delta * 2.0)
			if in_gate:
				for index in circuit.checkpoint_distances.size():
					if index == int(status.checkpoint) and _crossed(previous, progress, float(circuit.checkpoint_distances[index])):
						status.checkpoint += 1
						status.safe_progress = float(circuit.checkpoint_distances[index])
				if bool(status.started):
					for index in 2:
						if index == int(status.current_sector) and _crossed(previous, progress, float(circuit.sector_distances[index])):
							_complete_sector(car, status, index, _crossing_time(previous, progress, float(circuit.sector_distances[index]), delta))
				if _crossed(previous, progress, 0.0):
					var crossed_at := _crossing_time(previous, progress, 0.0, delta)
					if not bool(status.started):
						_begin_lap(status, crossed_at)
					elif int(status.checkpoint) == circuit.checkpoint_distances.size():
						_complete_lap(car, status, crossed_at)
					else:
						_invalidate(car, status, "Missed checkpoint")
						_begin_lap(status, crossed_at)
			_update_drs(car, status, previous, progress, delta)
		elif travelled < -0.2:
			status.wrong_way_time += delta
		if float(status.wrong_way_time) > 2.0 and car.player_controlled:
			EventBus.race_message.emit("WRONG WAY", "Turn around safely. R recovers to your last checkpoint.", 1.0)
		status.last_progress = progress
		if race_time >= float(status.next_timing_sample):
			status.next_timing_sample = race_time + 0.10
			var total_progress := float(car.lap) * circuit.total_length + progress - (0.0 if bool(status.started) else circuit.total_length)
			var history: Array = status.timeline
			if history.is_empty() or total_progress > float(history[-1].x):
				history.append(Vector2(total_progress, race_time))
				if history.size() > 6000:
					history.pop_front()
		status.current_lap = race_time - float(status.lap_start) if bool(status.started) else 0.0
		status.delta = _delta_at(progress, float(status.current_lap)) if bool(status.started) else INF
		_update_recovery(car, status, delta)
		if car.damage >= 0.995:
			_retire(car, "Terminal damage")

func _crossed(previous: float, current: float, target: float) -> bool:
	var step := fposmod(current - previous, circuit.total_length)
	var distance := fposmod(target - previous, circuit.total_length)
	return distance > 0.00001 and distance <= step and step < circuit.total_length * 0.1

func _crossing_time(previous: float, current: float, target: float, delta: float) -> float:
	var step := fposmod(current - previous, circuit.total_length)
	var fraction := clampf(fposmod(target - previous, circuit.total_length) / maxf(step, 0.001), 0.0, 1.0)
	return race_time - delta * (1.0 - fraction)

func _begin_lap(status: Dictionary, now: float) -> void:
	status.started = true
	status.lap_start = now
	status.sector_start = now
	status.current_sector = 0
	status.checkpoint = 0
	status.lap_valid = true
	status.sector_valid = [true, true, true]
	status.sectors = [INF, INF, INF]
	status.safe_progress = 0.0

func _complete_sector(car: RaycastFormulaCar, status: Dictionary, sector: int, now: float) -> void:
	var seconds := now - float(status.sector_start)
	status.sectors[sector] = seconds
	if bool(status.sector_valid[sector]):
		status.sector_pb[sector] = seconds < float(status.best_sectors[sector])
		status.best_sectors[sector] = minf(float(status.best_sectors[sector]), seconds)
	status.sector_start = now
	status.current_sector = mini(sector + 1, 2)
	EventBus.sector_completed.emit(car, sector, seconds)

func _complete_lap(car: RaycastFormulaCar, status: Dictionary, now: float) -> void:
	_complete_sector(car, status, 2, now)
	var seconds := now - float(status.lap_start)
	var valid := bool(status.lap_valid) and seconds > 20.0
	status.last_lap = seconds
	status.last_lap_valid = valid
	status.last_sectors = status.sectors.duplicate()
	car.completed_lap_time = seconds
	car.lap += 1
	if valid:
		status.best_lap = minf(float(status.best_lap), seconds)
		if car.player_controlled and GameState.mode == GameState.Mode.TIME_TRIAL and seconds < personal_best:
			personal_best = seconds
			best_sectors = status.sectors.duplicate()
			_recording.append([seconds, circuit.total_length, car.global_position.x, car.global_position.y, car.global_position.z, car.rotation.y])
			best_record = _recording.duplicate(true)
			_save_record()
			EventBus.race_message.emit("PERSONAL BEST", "%s - ghost updated" % format_time(seconds), 4.0)
	EventBus.lap_completed.emit(car, car.lap, seconds, valid)
	if car.player_controlled:
		_recording.clear()
		_ghost_index = 0
	_begin_lap(status, now)
	if GameState.mode == GameState.Mode.RACE and car.lap >= GameState.total_laps:
		car.finished = true
		car.race_enabled = false
		# Classified cars must never become stationary crash obstacles at the line.
		car.collision_layer = 0
		car.collision_mask = 1
		status.finish_time = now
		if car.player_controlled:
			_finish_deadline = now + 75.0
			EventBus.race_message.emit("CHEQUERED FLAG", "Your race is complete. Waiting for the field and race control.", 7.0)

func _update_track_limits(car: RaycastFormulaCar, status: Dictionary, delta: float) -> void:
	var legal := not car.all_wheels_off_track()
	if not legal:
		status.off_track_time += delta
		if float(status.off_track_time) >= RaceConfig.track_limit_min_seconds and not bool(status.offtrack_reported):
			status.offtrack_reported = true
			_invalidate(car, status, "Track limits")
			if race_time >= float(status.pushed_until):
				status.limits += 1
				if GameState.mode == GameState.Mode.RACE and int(status.limits) > RaceConfig.limit_warnings_before_penalty:
					_apply_penalty(car, RaceConfig.track_limits_penalty_seconds, "repeated track limits")
					status.limits = 0
	else:
		status.off_track_time = 0.0
		status.offtrack_reported = false
	status.was_legal = legal

func _invalidate(car: RaycastFormulaCar, status: Dictionary, reason: String) -> void:
	var was_valid := bool(status.lap_valid)
	status.lap_valid = false
	status.sector_valid[int(status.current_sector)] = false
	if was_valid:
		EventBus.lap_invalidated.emit(car, reason)
		if car.player_controlled:
			EventBus.race_message.emit("LAP INVALID", "%s - complete the lap to start a new attempt." % reason, 3.0)

func _record_drs_detections(delta: float) -> void:
	for car in cars:
		if not car.visible or car.finished:
			continue
		var status := _status(car)
		var projection := circuit.progress_at(car.global_position)
		var progress := float(projection.progress)
		var previous := float(status.last_progress)
		var step := wrapf(progress - previous, -circuit.total_length * 0.5, circuit.total_length * 0.5)
		if step <= 0.0 or step >= maxf(15.0, car.speed_mps * delta * 3.0):
			continue
		if absf(float(projection.offset)) > RaceConfig.track_width * 0.5 + RaceConfig.kerb_width + 2.0:
			continue
		for index in circuit.drs_detection_distances.size():
			var detection := float(circuit.drs_detection_distances[index])
			if _crossed(previous, progress, detection):
				status.drs_crossings[index] = _crossing_time(previous, progress, detection, delta)

func _update_drs(car: RaycastFormulaCar, status: Dictionary, previous: float, progress: float, delta := 1.0 / 120.0) -> void:
	var available := false
	for index in circuit.drs_zones.size():
		var zone: Vector2 = circuit.drs_zones[index]
		var detection := float(circuit.drs_detection_distances[index])
		if _crossed(previous, progress, detection):
			var crossed_at := _crossing_time(previous, progress, detection, delta)
			status.drs_eligible[index] = _detection_gap(car, index, crossed_at) <= RaceConfig.drs_gap_seconds
		if progress >= zone.x and progress <= zone.y:
			available = GameState.mode != GameState.Mode.RACE or bool(status.drs_eligible[index])
	if car.drs_available != available:
		car.drs_available = available
		EventBus.drs_changed.emit(car, available)
	if not available or car.brake_input > 0.05:
		car.drs_open = false

func _detection_gap(car: RaycastFormulaCar, zone_index: int, crossed_at: float) -> float:
	var closest := INF
	for other in cars:
		if other == car or other.finished or not other.visible:
			continue
		var gap := crossed_at - float(_status(other).drs_crossings[zone_index])
		if gap >= 0.0:
			closest = minf(closest, gap)
	return closest

func _clear_drs_detection(car: RaycastFormulaCar, status: Dictionary) -> void:
	status.drs_crossings = [-INF, -INF, -INF]
	status.drs_eligible = [false, false, false]
	car.drs_available = false
	car.drs_open = false

func _update_recovery(car: RaycastFormulaCar, status: Dictionary, delta: float) -> void:
	if car.speed_mps < 1.0 and race_time > 10.0:
		status.stuck_time += delta
	else:
		status.stuck_time = 0.0
	if not car.player_controlled and float(status.stuck_time) > 12.0:
		var safe_distance := float(status.safe_progress)
		car.reset_to_pose(_sample_pose(circuit.sample_at_distance(safe_distance)))
		status.last_progress = safe_distance
		status.stuck_time = 0.0
		_clear_drs_detection(car, status)
		_invalidate(car, status, "Recovery")
		if GameState.mode == GameState.Mode.RACE:
			_apply_penalty(car, 10.0, "recovery")

func _note_incident(first: Node, second: Node, severity: float, detail: String) -> void:
	if not green or GameState.mode != GameState.Mode.RACE or not first is RaycastFormulaCar or not second is RaycastFormulaCar:
		return
	var a := first as RaycastFormulaCar
	var b := second as RaycastFormulaCar
	var key := "%d:%d" % [mini(a.get_instance_id(), b.get_instance_id()), maxi(a.get_instance_id(), b.get_instance_id())]
	if race_time < float(_incident_cooldowns.get(key, -1.0)):
		return
	_incident_cooldowns[key] = race_time + 8.0
	var delta_position := b.global_position - a.global_position
	var a_forward := -a.global_basis.z
	var b_forward := -b.global_basis.z
	var aggressor: RaycastFormulaCar
	if delta_position.dot(a_forward) > 1.2 and (a.linear_velocity - b.linear_velocity).dot(a_forward) > 1.0:
		aggressor = a
	elif (-delta_position).dot(b_forward) > 1.2 and (b.linear_velocity - a.linear_velocity).dot(b_forward) > 1.0:
		aggressor = b
	else:
		var toward := delta_position.normalized()
		var a_closing := a.linear_velocity.dot(toward)
		var b_closing := b.linear_velocity.dot(-toward)
		if absf(a_closing - b_closing) < 2.0:
			return # Ambiguous wheel-to-wheel contact is a racing incident.
		aggressor = a if a_closing > b_closing else b
	var victim := b if aggressor == a else a
	_status(victim).pushed_until = race_time + 4.0
	var delay := _random.randf_range(RaceConfig.incident_delay_min, RaceConfig.incident_delay_max)
	if _leader_laps_remaining() <= 1:
		delay = minf(delay, RaceConfig.incident_end_delay)
	pending_incidents.append({"key": key, "remaining": delay, "car": aggressor, "severity": severity, "detail": detail})
	EventBus.race_message.emit("INCIDENT UNDER REVIEW", "%s / %s" % [a.driver_name, b.driver_name], 3.0)

func _update_pending_incidents(delta: float) -> void:
	for index in range(pending_incidents.size() - 1, -1, -1):
		var pending := pending_incidents[index]
		pending.remaining -= delta
		if float(pending.remaining) <= 0.0:
			_resolve_incident(pending)
			pending_incidents.remove_at(index)

func _resolve_incident(pending: Dictionary) -> void:
	var severity := float(pending.severity)
	var seconds := RaceConfig.penalty_heavy_seconds if severity >= RaceConfig.penalty_heavy_threshold else (RaceConfig.penalty_firm_seconds if severity >= RaceConfig.penalty_firm_threshold else RaceConfig.penalty_light_seconds)
	_apply_penalty(pending.car, seconds, "avoidable contact")

func _resolve_all_incidents() -> void:
	for pending in pending_incidents:
		_resolve_incident(pending)
	pending_incidents.clear()

func _apply_penalty(car: RaycastFormulaCar, seconds: float, reason: String) -> void:
	car.penalty_seconds += seconds
	_status(car).penalty_log.append("+%.0fs %s" % [seconds, reason])
	EventBus.penalty_applied.emit(car, seconds, reason)
	EventBus.race_message.emit("TIME PENALTY", "%s +%.0fs / %s" % [car.driver_name, seconds, reason], 3.0)

func _retire(car: RaycastFormulaCar, reason: String) -> void:
	if car == null or bool(_status(car).retired):
		return
	_status(car).retired = true
	_status(car).retirement_reason = reason
	car.finished = true
	car.race_enabled = false
	car.collision_layer = 0
	if car.player_controlled:
		_finish_deadline = race_time + 30.0
	EventBus.race_message.emit("RETIRED", "%s / %s" % [car.driver_name, reason], 3.0)

func _check_finish() -> void:
	var player := GameState.player_car as RaycastFormulaCar
	var player_done := player != null and player.finished
	var all_done := true
	for car in cars:
		if not car.finished:
			all_done = false
	if player_done and (all_done or race_time >= _finish_deadline):
		_resolve_all_incidents()
		_update_classification()
		GameState.finish_race()
		EventBus.session_finished.emit(_last_rows)

func _update_classification() -> void:
	var rows: Array = []
	for car in cars:
		if not car.visible:
			continue
		var status := _status(car)
		var progress := float(car.lap) * circuit.total_length + car.race_progress
		if not bool(status.started):
			progress -= circuit.total_length
		rows.append({"car": car, "driver": car.driver_name, "lap": car.lap, "progress": progress, "finished": car.finished and not bool(status.retired), "retired": bool(status.retired), "time": float(status.finish_time) + car.penalty_seconds, "penalty": car.penalty_seconds, "best_lap": float(status.best_lap), "gap": 0.0, "interval": 0.0, "penalty_log": status.penalty_log})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if qualifying_active:
			return float(a.best_lap) < float(b.best_lap) if a.best_lap != b.best_lap else float(a.progress) > float(b.progress)
		if bool(a.retired) != bool(b.retired):
			return not bool(a.retired)
		if bool(a.finished) and bool(b.finished):
			return float(a.time) < float(b.time)
		if bool(a.finished) != bool(b.finished):
			return bool(a.finished)
		return float(a.progress) > float(b.progress))
	for index in rows.size():
		rows[index].position = index + 1
		if index > 0:
			rows[index].gap = _row_gap(rows[0], rows[index])
			rows[index].interval = _row_gap(rows[index - 1], rows[index])
	_last_rows = rows
	EventBus.classification_changed.emit(rows)

func _row_gap(a: Dictionary, b: Dictionary) -> float:
	if qualifying_active:
		return float(b.best_lap) - float(a.best_lap) if is_finite(float(a.best_lap)) and is_finite(float(b.best_lap)) else INF
	if bool(a.finished) and bool(b.finished):
		return float(b.time) - float(a.time)
	var passed_at := _time_at_progress(a.car, float(b.progress))
	return maxf(0.0, race_time - passed_at) if is_finite(passed_at) else INF

func _time_at_progress(car: RaycastFormulaCar, progress: float) -> float:
	# Interpolated time at the same distance, not distance divided by current speed.
	var history: Array = _status(car).get("timeline", [])
	if history.size() < 2 or progress < float(history[0].x) or progress > float(history[-1].x):
		return INF
	var low := 0
	var high := history.size() - 1
	while low < high:
		var middle := (low + high) / 2
		if float(history[middle].x) < progress:
			low = middle + 1
		else:
			high = middle
	if low == 0:
		return float(history[0].y)
	var first: Vector2 = history[low - 1]
	var second: Vector2 = history[low]
	return lerpf(first.y, second.y, clampf((progress - first.x) / maxf(second.x - first.x, 0.001), 0.0, 1.0))

func get_classification() -> Array:
	return _last_rows.duplicate()

func get_player_status() -> Dictionary:
	if GameState.player_car == null:
		return {}
	return _status(GameState.player_car).duplicate(true)

func _leader_laps_remaining() -> int:
	var lap := 0
	for car in cars:
		lap = maxi(lap, car.lap)
	return GameState.total_laps - lap

func _make_status(car: RaycastFormulaCar) -> Dictionary:
	var progress := float(circuit.progress_at(car.global_position).progress)
	return {"last_progress": progress, "distance": 0.0, "started": false, "lap_start": 0.0, "sector_start": 0.0, "current_lap": 0.0, "current_sector": 0, "lap_valid": true, "last_lap": INF, "last_lap_valid": true, "best_lap": INF, "finish_time": INF, "limits": 0, "off_track_time": 0.0, "offtrack_reported": false, "was_legal": true, "stuck_time": 0.0, "drs_eligible": [false, false, false], "checkpoint": 0, "safe_progress": 0.0, "sectors": [INF, INF, INF], "last_sectors": [INF, INF, INF], "best_sectors": [INF, INF, INF], "sector_pb": [false, false, false], "sector_valid": [true, true, true], "retired": false, "retirement_reason": "", "penalty_log": [], "pushed_until": -1.0, "wrong_way_time": 0.0, "delta": INF, "grid_position": car.global_position, "jump_start": false}

func _status(car: RaycastFormulaCar) -> Dictionary:
	if not statuses.has(car.get_instance_id()):
		statuses[car.get_instance_id()] = _make_status(car)
	if not statuses[car.get_instance_id()].has("timeline"):
		statuses[car.get_instance_id()].timeline = []
		statuses[car.get_instance_id()].next_timing_sample = 0.0
	if not statuses[car.get_instance_id()].has("drs_crossings"):
		statuses[car.get_instance_id()].drs_crossings = [-INF, -INF, -INF]
	return statuses[car.get_instance_id()]

func _sample_pose(sample: Dictionary) -> Transform3D:
	return Transform3D(Basis.looking_at(sample.tangent, Vector3.UP), sample.position + Vector3.UP * 0.04)

func _set_lights(count: int, extinguished := false) -> void:
	if circuit.has_method("set_start_lights"):
		circuit.set_start_lights(count, extinguished)
	EventBus.start_lights_changed.emit(count, extinguished)

static func format_time(seconds: float) -> String:
	if not is_finite(seconds) or seconds <= 0.0:
		return "--:--.---"
	return "%d:%06.3f" % [int(seconds / 60.0), fposmod(seconds, 60.0)]

func _create_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "PersonalBestGhost"
	add_child(_ghost)
	var player := cars[0]
	var wheels: Array[Dictionary] = []
	for wheel: Dictionary in player._wheels:
		wheels.append({"name": wheel.name, "local_position": wheel.local_position, "front": wheel.front})
	var visual := preload("res://cars/formula_visual.gd").new()
	visual.name = "CompleteGhostCar"
	visual.ghost_mode = true
	visual.configure(player.livery_color, player.tuning, wheels)
	_ghost.add_child(visual)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.30, 0.82, 1.0, 0.24)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material(visual, material)
	_ghost.visible = false

func _ghost_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_ghost_material(child, material)

func _update_ghost(delta: float) -> void:
	var player := GameState.player_car as RaycastFormulaCar
	if player == null:
		return
	var status := _status(player)
	var time_trial := GameState.mode == GameState.Mode.TIME_TRIAL
	_ghost.visible = time_trial and GameState.ghost_enabled and bool(status.started) and best_record.size() >= 2
	if time_trial and bool(status.started):
		_record_timer -= delta
		if _record_timer <= 0.0:
			_record_timer = 0.05
			_recording.append([float(status.current_lap), player.race_progress, player.global_position.x, player.global_position.y, player.global_position.z, player.rotation.y, player.rotation.x, player.rotation.z, player.steering_input, player.drs_open])
	if not _ghost.visible:
		return
	var current := float(status.current_lap)
	while _ghost_index + 1 < best_record.size() - 1 and float(best_record[_ghost_index + 1][0]) < current:
		_ghost_index += 1
	var first: Array = best_record[_ghost_index]
	var second: Array = best_record[_ghost_index + 1]
	var fraction := clampf((current - float(first[0])) / maxf(float(second[0]) - float(first[0]), 0.001), 0.0, 1.0)
	_ghost.position = Vector3(float(first[2]), float(first[3]), float(first[4])).lerp(Vector3(float(second[2]), float(second[3]), float(second[4])), fraction)
	_ghost.rotation.y = lerp_angle(float(first[5]), float(second[5]), fraction)
	var visual := _ghost.get_node("CompleteGhostCar")
	var steer := lerpf(float(first[8]),float(second[8]),fraction) if first.size() > 8 and second.size() > 8 else 0.0
	if first.size() > 7 and second.size() > 7:
		_ghost.rotation.x = lerp_angle(float(first[6]),float(second[6]),fraction)
		_ghost.rotation.z = lerp_angle(float(first[7]),float(second[7]),fraction)
	var recorded_speed := Vector3(float(first[2]),float(first[3]),float(first[4])).distance_to(Vector3(float(second[2]),float(second[3]),float(second[4]))) / maxf(0.01,float(second[0])-float(first[0]))
	for wheel: Dictionary in visual._wheels:
		wheel.roll_node.rotation.x -= recorded_speed / player.tuning.wheel_radius * delta
		wheel.visual.rotation.y = -steer * player.get_max_steering_angle(recorded_speed) if wheel.front else 0.0
	visual._flap.rotation.x = deg_to_rad(1 if first.size() > 9 and bool(first[9]) else -24)
	if current > personal_best:
		_ghost.visible = false

func _delta_at(progress: float, elapsed: float) -> float:
	if best_record.size() < 2:
		return INF
	var low := 0
	var high := best_record.size() - 1
	while low < high:
		var mid := int((low + high) / 2)
		if float(best_record[mid][1]) < progress:
			low = mid + 1
		else:
			high = mid
	if low == 0:
		return elapsed - float(best_record[0][0])
	var first: Array = best_record[low - 1]
	var second: Array = best_record[low]
	var fraction := clampf((progress - float(first[1])) / maxf(float(second[1]) - float(first[1]), 0.001), 0.0, 1.0)
	return elapsed - lerpf(float(first[0]), float(second[0]), fraction)

func _save_record() -> void:
	var file := FileAccess.open(_record_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"lap": personal_best, "sectors": best_sectors, "record": best_record}))

func _load_record() -> void:
	if not FileAccess.file_exists(_record_path):
		return
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(_record_path))
	if result is Dictionary and result.has("lap") and result.has("record"):
		personal_best = float(result.lap)
		best_record = result.record
		best_sectors = result.get("sectors", [INF, INF, INF])

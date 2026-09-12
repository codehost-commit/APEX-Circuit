class_name RaceDirector
extends Node
## Owns session timing, order and rules. Vehicle/AI code never decides race outcomes.

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
var _random := RandomNumberGenerator.new()
var _last_rows: Array = []
var _lights: Array[MeshInstance3D] = []

func setup(track_value: CircuitTrack, field: Array[RaycastFormulaCar]) -> void:
	circuit = track_value
	cars = field
	grid_order = field.duplicate()
	_random.randomize()
	for car in cars:
		statuses[car.get_instance_id()] = _make_status(car)
		car.race_enabled = false
	EventBus.incident.connect(_note_incident)
	_create_start_lights()

func start_preview() -> void:
	GameState.reset_to_menu()
	green = false
	qualifying_active = false
	for car in cars:
		car.race_enabled = true
		car.finished = false
		car.drs_available = false

func start_race(from_qualifying := false) -> void:
	qualifying_active = false
	if from_qualifying:
		grid_order.sort_custom(func(first: RaycastFormulaCar, second: RaycastFormulaCar) -> bool: return float(_status(first).best_lap) < float(_status(second).best_lap))
	race_time = 0.0
	green = false
	lights_lit = 0
	light_timer = RaceConfig.start_light_min_hold
	GameState.total_laps = RaceConfig.race_laps
	GameState.begin_race()
	for index in grid_order.size():
		var car := grid_order[index]
		car.reset_to_pose(circuit.pose_at_grid(index))
		car.race_enabled = false
		car.penalty_seconds = 0.0
		car.lap = 0
		car.race_progress = circuit.progress_at(car.global_position).progress
		statuses[car.get_instance_id()] = _make_status(car)
	_set_lights(0, false)
	EventBus.race_message.emit("FORM UP", "Five lights will begin shortly", 2.0)

func start_qualifying() -> void:
	qualifying_active = true
	qualifying_time = 0.0
	green = true
	GameState.mode = GameState.Mode.QUALIFYING
	GameState.start_state = GameState.StartState.GREEN
	for index in cars.size():
		var car := cars[index]
		car.reset_to_pose(circuit.pose_at_grid(index))
		car.race_enabled = true
		car.lap = 0
		statuses[car.get_instance_id()] = _make_status(car)
	EventBus.race_message.emit("QUALIFYING", "Set your best valid lap — press Escape to skip to the grid", 4.0)

func skip_to_grid() -> void:
	for car in cars:
		var status := _status(car)
		if not is_finite(float(status.best_lap)):
			status.best_lap = _estimated_ai_lap(car)
			statuses[car.get_instance_id()] = status
	start_race(true)

func _physics_process(delta: float) -> void:
	if GameState.paused:
		return
	if qualifying_active:
		qualifying_time += delta
		_update_car_progress(delta, true)
		if qualifying_time >= RaceConfig.qualifying_duration:
			skip_to_grid()
		return
	if GameState.mode != GameState.Mode.RACE:
		return
	_update_start_lights(delta)
	if green:
		race_time += delta
		GameState.elapsed_seconds = race_time
		_update_car_progress(delta, false)
		_update_pending_incidents(delta)
		_update_classification()

func _update_start_lights(delta: float) -> void:
	if green:
		return
	light_timer -= delta
	if lights_lit < 5 and light_timer <= 0.0:
		lights_lit += 1
		light_timer = RaceConfig.start_light_step_seconds
		if lights_lit == 5:
			light_timer = _random.randf_range(RaceConfig.start_light_min_hold, RaceConfig.start_light_max_hold)
		_set_lights(lights_lit, false)
	elif lights_lit == 5 and light_timer <= 0.0:
		green = true
		GameState.start_state = GameState.StartState.GREEN
		for car in cars:
			car.race_enabled = true
		_set_lights(0, true)
		EventBus.race_message.emit("LIGHTS OUT", "RACE ON", 1.4)

func _update_car_progress(delta: float, is_qualifying: bool) -> void:
	for car in cars:
		if car.finished:
			continue
		var status := _status(car)
		var projection := circuit.progress_at(car.global_position)
		var progress: float = projection.progress
		car.race_progress = progress
		var last_progress: float = status.last_progress
		_update_sector(car, status, progress)
		if last_progress > circuit.total_length * RaceConfig.lap_wrap_before and progress < circuit.total_length * RaceConfig.lap_wrap_after:
			_complete_lap(car, status, is_qualifying)
		status.last_progress = progress
		_update_track_limits(car, status, delta)
		_update_drs(car, status)
		_update_recovery(car, status, delta)
		statuses[car.get_instance_id()] = status

func _update_sector(car: RaycastFormulaCar, status: Dictionary, progress: float) -> void:
	var sector := 0
	if progress >= circuit.sector_distances[1]:
		sector = 2
	elif progress >= circuit.sector_distances[0]:
		sector = 1
	if sector > int(status.last_sector):
		var now := qualifying_time if qualifying_active else race_time
		EventBus.sector_completed.emit(car, sector, now - float(status.sector_start))
		status.sector_start = now
		status.last_sector = sector
	elif progress < circuit.sector_distances[0] and int(status.last_sector) == 2:
		status.last_sector = 0

func _complete_lap(car: RaycastFormulaCar, status: Dictionary, is_qualifying: bool) -> void:
	var now := qualifying_time if is_qualifying else race_time
	var lap_time := now - float(status.lap_start)
	var valid := bool(status.lap_valid)
	car.completed_lap_time = lap_time
	car.lap += 1
	status.lap_start = now
	status.sector_start = now
	status.lap_valid = true
	status.last_sector = 0
	if valid:
		status.best_lap = minf(float(status.best_lap), lap_time)
	EventBus.lap_completed.emit(car, car.lap, lap_time, valid)
	if is_qualifying:
		if car.lap >= RaceConfig.qualifying_laps:
			car.race_enabled = false
		return
	if car.lap >= GameState.total_laps:
		car.finished = true
		car.race_enabled = false
		status.finish_time = now + car.penalty_seconds
		EventBus.race_message.emit("CHEQUERED FLAG" if car.player_controlled else "CAR FINISHED", "%s P%d" % [car.driver_name, _position_of(car)], 2.0)
		if car.player_controlled:
			GameState.finish_race()

func _update_track_limits(car: RaycastFormulaCar, status: Dictionary, delta: float) -> void:
	var legal := car.all_wheels_legal()
	if not legal:
		status.off_track_time += delta
	elif not bool(status.was_legal):
		if float(status.off_track_time) >= RaceConfig.track_limit_min_seconds:
			status.limits += 1
			status.lap_valid = false
			if int(status.limits) > RaceConfig.limit_warnings_before_penalty:
				_apply_penalty(car, RaceConfig.track_limits_penalty_seconds, "track limits")
				status.limits = 0
			elif car.player_controlled:
				EventBus.race_message.emit("TRACK LIMITS", "Warning %d/%d" % [status.limits, RaceConfig.limit_warnings_before_penalty], 2.0)
		status.off_track_time = 0.0
	status.was_legal = legal

func _update_drs(car: RaycastFormulaCar, status: Dictionary) -> void:
	var progress := car.race_progress
	var in_zone := progress >= RaceConfig.drs_zone_start and progress <= RaceConfig.drs_zone_start + RaceConfig.drs_zone_length
	if progress >= RaceConfig.drs_detection_start and progress <= RaceConfig.drs_detection_start + RaceConfig.drs_detection_window:
		var ahead_gap := _nearest_ahead_gap(car)
		status.drs_eligible = ahead_gap <= maxf(car.speed_mps, RaceConfig.drs_min_reference_speed) * RaceConfig.drs_gap_seconds
	var available := in_zone and (qualifying_active or bool(status.drs_eligible))
	if car.drs_available != available:
		car.drs_available = available
		EventBus.drs_changed.emit(car, available)

func _nearest_ahead_gap(car: RaycastFormulaCar) -> float:
	var closest := INF
	for other in cars:
		if other == car:
			continue
		var gap := fposmod(other.race_progress - car.race_progress, circuit.total_length)
		if gap > RaceConfig.ai_side_by_side_distance:
			closest = minf(closest, gap)
	return closest

func _update_recovery(car: RaycastFormulaCar, status: Dictionary, delta: float) -> void:
	var surface := circuit.get_surface_at(car.global_position)
	var moving := car.speed_mps > RaceConfig.recovery_min_speed
	if not surface.legal and not moving:
		status.stuck_time += delta
	else:
		status.stuck_time = 0.0
	if float(status.stuck_time) > RaceConfig.respawn_after_seconds:
		car.reset_to_pose(circuit.nearest_safe_pose(car.global_position))
		status.stuck_time = 0.0
		_apply_penalty(car, RaceConfig.recovery_penalty_seconds, "unsafe recovery")

func _note_incident(first: Node, second: Node, severity: float, detail: String) -> void:
	if not green or not (first is RaycastFormulaCar) or not (second is RaycastFormulaCar):
		return
	var first_car := first as RaycastFormulaCar
	var second_car := second as RaycastFormulaCar
	var key := "%d:%d" % [mini(first_car.get_instance_id(), second_car.get_instance_id()), maxi(first_car.get_instance_id(), second_car.get_instance_id())]
	for pending in pending_incidents:
		if pending.key == key:
			return
	var aggressor := first_car if first_car.linear_velocity.length() >= second_car.linear_velocity.length() else second_car
	var delay := _random.randf_range(RaceConfig.incident_delay_min, RaceConfig.incident_delay_max)
	if _leader_laps_remaining() <= 1:
		delay = minf(delay, RaceConfig.incident_end_delay)
	pending_incidents.append({"key": key, "remaining": delay, "car": aggressor, "severity": severity, "detail": detail, "other": second_car if aggressor == first_car else first_car})
	EventBus.race_message.emit("INCIDENT NOTED", "%s & %s" % [first_car.driver_name, second_car.driver_name], RaceConfig.incident_message_seconds)

func _update_pending_incidents(delta: float) -> void:
	for index in range(pending_incidents.size() - 1, -1, -1):
		var pending := pending_incidents[index]
		pending.remaining -= delta
		if float(pending.remaining) > 0.0:
			pending_incidents[index] = pending
			continue
		var severity: float = pending.severity
		var seconds := RaceConfig.penalty_light_seconds
		if severity >= RaceConfig.penalty_heavy_threshold:
			seconds = RaceConfig.penalty_heavy_seconds
		elif severity >= RaceConfig.penalty_firm_threshold:
			seconds = RaceConfig.penalty_firm_seconds
		_apply_penalty(pending.car, seconds, "avoidable contact")
		pending_incidents.remove_at(index)

func _apply_penalty(car: RaycastFormulaCar, seconds: float, reason: String) -> void:
	car.penalty_seconds += seconds
	EventBus.penalty_applied.emit(car, seconds, reason)
	EventBus.race_message.emit("PENALTY", "%s +%.0fs — %s" % [car.driver_name, seconds, reason], RaceConfig.penalty_message_seconds)

func _update_classification() -> void:
	var rows: Array = []
	for car in cars:
		var status := _status(car)
		rows.append({"car": car, "driver": car.driver_name, "lap": car.lap, "progress": float(car.lap) * circuit.total_length + car.race_progress, "finished": car.finished, "time": float(status.finish_time) if car.finished else race_time + car.penalty_seconds, "penalty": car.penalty_seconds, "best_lap": float(status.best_lap)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.finished) and bool(b.finished):
			return float(a.time) < float(b.time)
		if bool(a.finished) != bool(b.finished):
			return bool(a.finished)
		return float(a.progress) > float(b.progress)
	)
	for index in rows.size():
		rows[index].position = index + 1
	_last_rows = rows
	EventBus.classification_changed.emit(rows)

func get_classification() -> Array:
	return _last_rows.duplicate(true)

func get_player_status() -> Dictionary:
	return _status(GameState.player_car).duplicate(true)

func _position_of(car: RaycastFormulaCar) -> int:
	for row in _last_rows:
		if row.car == car:
			return int(row.position)
	return 1

func _leader_laps_remaining() -> int:
	var leader_lap := 0
	for car in cars:
		leader_lap = maxi(leader_lap, car.lap)
	return GameState.total_laps - leader_lap

func _estimated_ai_lap(car: RaycastFormulaCar) -> float:
	var base := circuit.total_length / RaceConfig.ai_estimated_lap_speed
	return base * _random.randf_range(RaceConfig.qualifying_variance_low, RaceConfig.qualifying_variance_high)

func _make_status(car: RaycastFormulaCar) -> Dictionary:
	return {"last_progress": circuit.progress_at(car.global_position).progress, "lap_start": 0.0, "sector_start": 0.0, "last_sector": 0, "lap_valid": true, "best_lap": INF, "finish_time": INF, "limits": 0, "off_track_time": 0.0, "was_legal": true, "stuck_time": 0.0, "drs_eligible": false}

func _status(car: RaycastFormulaCar) -> Dictionary:
	return statuses.get(car.get_instance_id(), _make_status(car))

func _create_start_lights() -> void:
	var rig := Node3D.new()
	rig.name = "StartLightRig"
	var sample := circuit.sample_at_distance(7.0)
	rig.position = sample.position + Vector3.UP * 5.5 + sample.normal * 2.0
	rig.rotation.y = atan2(sample.tangent.x, sample.tangent.z)
	add_child(rig)
	for index in 5:
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.34
		sphere.height = 0.68
		lamp.mesh = sphere
		lamp.position = Vector3((float(index) - 2.0) * 0.94, 0.0, 0.0)
		lamp.material_override = _light_material(false, false)
		rig.add_child(lamp)
		_lights.append(lamp)

func _set_lights(count: int, is_green: bool) -> void:
	for index in _lights.size():
		_lights[index].material_override = _light_material(index < count, is_green)
	EventBus.start_lights_changed.emit(count, is_green)

func _light_material(red: bool, is_green: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#16d46d") if is_green else (Color("#e52c35") if red else Color("#17191c"))
	material.emission_enabled = red or is_green
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 2.4
	return material

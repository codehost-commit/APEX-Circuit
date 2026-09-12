class_name AIFormulaDriver
extends Node
## Physical pure-pursuit controller adapted from the Python driver:
## continuous lanes, committed passes, swept side-by-side corridors and anticipation.
@export var pace_multiplier := 0.99
@export var reaction_seconds := 0.14
@export var error_amplitude := 0.006
@export var driver_seed := 1
@export var enabled := true
@export var tactics_enabled := true

var car: RaycastFormulaCar
var circuit: CircuitTrack
var profile: RacingLineProfile
var opponents: Array[RaycastFormulaCar] = []
var lane_offset := 0.0
var desired_lane_offset := 0.0
var tactical_commit_seconds := 0.0
var lap_noise := 0.0
var session_noise := 0.0
var target_speed := 0.0
var tactic := "FOLLOW"
var _random := RandomNumberGenerator.new()
var _last_lap := 0
var _decision_timer := 0.0
var _launch_timer := 0.0
var _was_enabled := false
var _pass_target: RaycastFormulaCar
var _projection := {}
var _speed_integral := 0.0

func setup(car_value: RaycastFormulaCar, track_value: CircuitTrack, profile_value: RacingLineProfile, field: Array[RaycastFormulaCar]) -> void:
	car = car_value
	circuit = track_value
	profile = profile_value
	opponents = field
	_random.seed = driver_seed
	reset_session()

func reset_session() -> void:
	session_noise = _random.randf_range(-RaceConfig.ai_noise_per_session, RaceConfig.ai_noise_per_session)
	lap_noise = _random.randf_range(-error_amplitude, error_amplitude)
	var projection := circuit.progress_at(car.global_position)
	lane_offset = float(projection.offset)
	desired_lane_offset = lane_offset
	tactical_commit_seconds = 0.6
	_launch_timer = reaction_seconds
	_was_enabled = false
	_speed_integral = 0.0
	_pass_target = null

func _physics_process(delta: float) -> void:
	if car == null or not enabled or not car.race_enabled or car.finished:
		_was_enabled = false
		return
	if not _was_enabled:
		_was_enabled = true
		_launch_timer = reaction_seconds if car.speed_mps < 2.0 else 0.0
	_launch_timer = maxf(0.0, _launch_timer - delta)
	if _launch_timer > 0.0:
		car.ai_command = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drs": false}
		return
	_projection = circuit.progress_at(car.global_position)
	car.race_progress = float(_projection.progress)
	if car.lap != _last_lap:
		_last_lap = car.lap
		lap_noise = _random.randf_range(-error_amplitude, error_amplitude)
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = 1.0 / RaceConfig.ai_control_hz
		_update_tactics(_decision_timer)
	var corridor := _corridor(lane_offset, desired_lane_offset)
	desired_lane_offset = clampf(desired_lane_offset, corridor.x, corridor.y)
	var blend_target := lerpf(lane_offset, desired_lane_offset, 1.0 - exp(-delta * 2.5))
	lane_offset = move_toward(lane_offset, blend_target, RaceConfig.ai_lane_change_rate * delta)
	var lookahead := clampf(RaceConfig.ai_preview_base + car.speed_mps * RaceConfig.ai_preview_speed_scale, 9.0, 36.0)
	var bend := absf(circuit.curvature_at(car.race_progress + lookahead))
	if bend > 0.025:
		lookahead = minf(lookahead, 16.0)
	var sample := profile.sample_at_distance(car.race_progress + lookahead)
	# Tactical lane offsets are absolute relative to centreline; in clean air
	# follow the solved racing line and progressively blend out of it for passes.
	var path_offset: float = sample.offset
	var tactical_weight := clampf(absf(lane_offset) / 2.0, 0.0, 1.0)
	# Clamp the FINAL absolute target, not merely the tactical offset. Otherwise
	# the base racing line can still steer through an alongside car.
	var absolute_target := clampf(path_offset * (1.0 - tactical_weight) + lane_offset, corridor.x, corridor.y)
	var target_position: Vector3 = sample.position + sample.normal * (absolute_target - path_offset)
	var local_target := car.to_local(target_position)
	var distance_squared := maxf(local_target.x * local_target.x + local_target.z * local_target.z, 4.0)
	var desired_curvature := 2.0 * local_target.x / distance_squared
	var steer_angle := atan(car.tuning.wheelbase * desired_curvature)
	var desired_yaw := -car.speed_mps * desired_curvature
	# Correct under/over-rotation without moving the body or adding artificial forces.
	steer_angle += (car.angular_velocity.y - desired_yaw) * RaceConfig.ai_heading_damping
	var rack_limit: float = car.max_steer_for_speed(car.speed_mps)
	var steer := clampf(steer_angle / maxf(rack_limit, 0.001), -1.0, 1.0)
	target_speed = profile.braking_target(car.race_progress, car.speed_mps) * pace_multiplier * (1.0 + session_noise + lap_noise)
	target_speed = minf(target_speed, _traffic_speed_limit())
	if tactic != "FOLLOW" and absf(circuit.curvature_at(car.race_progress + lookahead)) > 0.01:
		target_speed *= 0.92
	# Steering recovery on a large excursion; the director owns delayed respawns.
	if absf(float(_projection.offset)) > circuit.road_half_width:
		target_speed = minf(target_speed, 22.0)
	var speed_error := target_speed - car.speed_mps
	_speed_integral = clampf(_speed_integral + speed_error * delta, -3.0, 6.0)
	var throttle := clampf(speed_error * 0.28 + _speed_integral * 0.025, 0.0, 1.0)
	var brake := clampf(-speed_error * 0.18, 0.0, 0.90)
	if brake > 0.025:
		throttle = 0.0
	# The driver lifts to protect the rear under combined slip, using ordinary inputs.
	if absf(car.lateral_g) > 2.8 and absf(steer) > 0.85:
		throttle = minf(throttle, 0.65)
	car.ai_command = {"throttle": throttle, "brake": brake, "steer": steer,
		"drs": car.drs_available and brake < 0.02 and absf(steer) < 0.55}

func _update_tactics(delta: float) -> void:
	tactical_commit_seconds = maxf(0.0, tactical_commit_seconds - delta)
	if not tactics_enabled:
		desired_lane_offset = 0.0
		return
	if tactical_commit_seconds > 0.0:
		return
	var passing_clear := true
	for distance: float in [0.0, 20.0, 40.0, 60.0]:
		if circuit.curvature_at(car.race_progress + distance) > 0.018:
			passing_clear = false
	var nearest: RaycastFormulaCar
	var gap := INF
	var behind: RaycastFormulaCar
	var behind_gap := INF
	for other in opponents:
		if other == car or not other.visible or other.finished:
			continue
		var other_projection := circuit.progress_at(other.global_position)
		var delta_s := _signed_track_gap(car.race_progress, float(other_projection.progress))
		if delta_s > 0.0 and delta_s < gap:
			nearest = other
			gap = delta_s
		elif delta_s < 0.0 and -delta_s < behind_gap:
			behind = other
			behind_gap = -delta_s
	if nearest != null and passing_clear and gap < RaceConfig.ai_attack_distance and car.speed_mps > nearest.speed_mps - 0.7:
		var other_offset: float = circuit.progress_at(nearest.global_position).offset
		var candidates := [clampf(other_offset - RaceConfig.ai_pass_width, -RaceConfig.ai_max_lane_offset, RaceConfig.ai_max_lane_offset), clampf(other_offset + RaceConfig.ai_pass_width, -RaceConfig.ai_max_lane_offset, RaceConfig.ai_max_lane_offset)]
		var best_score := INF
		var chosen := lane_offset
		for candidate: float in candidates:
			var interval := _corridor(lane_offset, candidate)
			if candidate < interval.x or candidate > interval.y or absf(candidate - other_offset) < RaceConfig.ai_corridor_width:
				continue
			var score := absf(candidate - lane_offset)
			for other in opponents:
				if other == car or other == nearest or not other.visible:
					continue
				var p := circuit.progress_at(other.global_position)
				if absf(_signed_track_gap(car.race_progress, float(p.progress))) < 35.0 and absf(candidate - float(p.offset)) < RaceConfig.ai_corridor_width:
					score += 20.0
			if score < best_score:
				best_score = score
				chosen = candidate
		desired_lane_offset = chosen
		_pass_target = nearest
		tactic = "ATTACK"
		tactical_commit_seconds = RaceConfig.ai_tactical_commit_time
	elif behind != null and behind_gap < RaceConfig.ai_defend_distance and behind.speed_mps > car.speed_mps:
		var signed_bend := circuit.signed_curvature_at(car.race_progress + 50.0)
		desired_lane_offset = -signf(signed_bend) * RaceConfig.ai_defend_lane_offset
		tactic = "DEFEND"
		tactical_commit_seconds = RaceConfig.ai_tactical_commit_time
	else:
		desired_lane_offset = 0.0
		tactic = "FOLLOW"
		_pass_target = null

func _corridor(current: float, requested: float) -> Vector2:
	var allowed := Vector2(-RaceConfig.ai_max_lane_offset, RaceConfig.ai_max_lane_offset)
	for other in opponents:
		if other == car or not other.visible or other.finished:
			continue
		var p := circuit.progress_at(other.global_position)
		if absf(_signed_track_gap(car.race_progress, float(p.progress))) > RaceConfig.ai_side_by_side_distance:
			continue
		var lateral: float = p.offset
		# Preserve the side already occupied, including the entire swept path.
		if float(_projection.get("offset", current)) <= lateral:
			allowed.y = minf(allowed.y, lateral - RaceConfig.ai_corridor_width)
		else:
			allowed.x = maxf(allowed.x, lateral + RaceConfig.ai_corridor_width)
	if allowed.x > allowed.y:
		return Vector2(current, current)
	return allowed

func _traffic_speed_limit() -> float:
	var cap := RaceConfig.ai_top_speed
	for other in opponents:
		if other == car or not other.visible or other.finished:
			continue
		var projection := circuit.progress_at(other.global_position)
		var forward_gap := _signed_track_gap(car.race_progress, float(projection.progress))
		# Track-space following still sees the leader around a bend. Using only
		# local X discarded the very car we were following whenever the road curved.
		var lateral_gap := absf(float(projection.offset) - float(_projection.offset))
		if forward_gap <= 0.0 or forward_gap > maxf(16.0, car.speed_mps * 1.8) or lateral_gap > RaceConfig.ai_corridor_width + 0.4:
			continue
		var safe_gap := 7.0 + car.speed_mps * RaceConfig.ai_follow_time
		var allowed_speed := other.speed_mps + (forward_gap - safe_gap) * 0.8
		cap = minf(cap, maxf(0.0, allowed_speed))
	return cap

func _signed_track_gap(from_progress: float, other_progress: float) -> float:
	return fposmod(other_progress - from_progress + circuit.total_length * 0.5, circuit.total_length) - circuit.total_length * 0.5

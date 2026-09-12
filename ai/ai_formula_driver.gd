class_name AIFormulaDriver
extends Node
## Pure-pursuit driver with a smooth lane target, speed profile, tactics and anti-encroachment corridor.

@export var pace_multiplier := 0.99
@export var reaction_seconds := 0.14
@export var error_amplitude := 0.018
@export var driver_seed := 1

var car: RaycastFormulaCar
var circuit: CircuitTrack
var profile: RacingLineProfile
var opponents: Array[RaycastFormulaCar] = []
var lane_offset := 0.0
var desired_lane_offset := 0.0
var tactical_commit_seconds := 0.0
var lap_noise := 0.0
var _random := RandomNumberGenerator.new()
var _last_lap := 0

func setup(car_value: RaycastFormulaCar, track_value: CircuitTrack, profile_value: RacingLineProfile, field: Array[RaycastFormulaCar]) -> void:
	car = car_value
	circuit = track_value
	profile = profile_value
	opponents = field
	_random.seed = driver_seed
	lap_noise = _random.randf_range(-error_amplitude, error_amplitude)

func _physics_process(delta: float) -> void:
	if car == null or circuit == null or profile == null or not car.race_enabled or car.finished:
		return
	var projection := circuit.progress_at(car.global_position)
	car.race_progress = float(projection.progress)
	if car.lap != _last_lap:
		_last_lap = car.lap
		lap_noise = _random.randf_range(-error_amplitude, error_amplitude)
	_update_tactics(delta, projection)
	var lookahead := clampf(RaceConfig.ai_lookahead_base + car.speed_mps * RaceConfig.ai_lookahead_speed_scale, RaceConfig.ai_lookahead_min, RaceConfig.ai_lookahead_max)
	var target := circuit.sample_at_distance(car.race_progress + lookahead)
	var target_position: Vector3 = target.position + target.normal * lane_offset
	var local_target := car.to_local(target_position)
	var steer := clampf(atan2(local_target.x, -local_target.z) * RaceConfig.ai_steering_gain, -1.0, 1.0)
	var speed_target := profile.target_speed_at(car.race_progress) * pace_multiplier * (1.0 + lap_noise)
	var upcoming := profile.upcoming_min_speed(car.race_progress, lookahead * RaceConfig.ai_brake_lookahead_scale) * pace_multiplier
	speed_target = minf(speed_target, upcoming + RaceConfig.ai_corner_overspeed)
	var speed_error := speed_target - car.speed_mps
	var throttle := clampf(speed_error * RaceConfig.ai_throttle_gain, 0.0, 1.0)
	var brake := clampf(-speed_error * RaceConfig.ai_brake_gain, 0.0, 1.0)
	if brake > RaceConfig.ai_brake_deadzone:
		throttle = 0.0
	car.ai_command = {"throttle": throttle, "brake": brake, "steer": steer, "drs": _may_use_drs()}

func _update_tactics(delta: float, projection: Dictionary) -> void:
	tactical_commit_seconds = maxf(0.0, tactical_commit_seconds - delta)
	var nearest_ahead: RaycastFormulaCar
	var nearest_behind: RaycastFormulaCar
	var ahead_distance := INF
	var behind_distance := INF
	for other in opponents:
		if other == car or other.finished:
			continue
		var other_progress := circuit.progress_at(other.global_position)
		var gap := _signed_track_gap(float(projection.progress), float(other_progress.progress))
		if gap > 0.0 and gap < ahead_distance:
			ahead_distance = gap
			nearest_ahead = other
		elif gap < 0.0 and -gap < behind_distance:
			behind_distance = -gap
			nearest_behind = other
	if tactical_commit_seconds <= 0.0:
		if nearest_ahead != null and ahead_distance < RaceConfig.ai_attack_distance and car.speed_mps >= nearest_ahead.speed_mps - RaceConfig.ai_attack_speed_delta:
			desired_lane_offset = _pick_passing_lane(nearest_ahead, projection)
			tactical_commit_seconds = RaceConfig.ai_tactical_commit_time
		elif nearest_behind != null and behind_distance < RaceConfig.ai_defend_distance and nearest_behind.speed_mps > car.speed_mps:
			desired_lane_offset = _inside_lane(projection)
			tactical_commit_seconds = RaceConfig.ai_tactical_commit_time
		else:
			desired_lane_offset = 0.0
	if _would_encroach(projection, desired_lane_offset):
		desired_lane_offset = lane_offset
	lane_offset = move_toward(lane_offset, desired_lane_offset, RaceConfig.ai_lane_change_rate * delta)

func _pick_passing_lane(ahead: RaycastFormulaCar, projection: Dictionary) -> float:
	var ahead_projection := circuit.progress_at(ahead.global_position)
	var side := -1.0 if float(ahead_projection.offset) >= 0.0 else 1.0
	return side * RaceConfig.ai_pass_lane_offset

func _inside_lane(projection: Dictionary) -> float:
	var curvature := circuit.curvature_at(float(projection.progress) + RaceConfig.ai_inside_lookahead)
	var turn_side := signf(curvature)
	return -turn_side * RaceConfig.ai_defend_lane_offset if turn_side != 0.0 else -RaceConfig.ai_defend_lane_offset

func _would_encroach(projection: Dictionary, requested_lane: float) -> bool:
	for other in opponents:
		if other == car:
			continue
		var other_projection := circuit.progress_at(other.global_position)
		var longitudinal_gap := absf(_signed_track_gap(float(projection.progress), float(other_projection.progress)))
		if longitudinal_gap > RaceConfig.ai_side_by_side_distance:
			continue
		if absf(requested_lane - float(other_projection.offset)) < RaceConfig.ai_corridor_width:
			return true
	return false

func _may_use_drs() -> bool:
	for other in opponents:
		if other == car:
			continue
		var gap := _signed_track_gap(car.race_progress, other.race_progress)
		if gap > 0.0 and gap < RaceConfig.drs_zone_length and car.speed_mps > RaceConfig.ai_drs_min_speed:
			return true
	return false

func _signed_track_gap(from_progress: float, other_progress: float) -> float:
	var gap := fposmod(other_progress - from_progress + circuit.total_length * 0.5, circuit.total_length) - circuit.total_length * 0.5
	return gap

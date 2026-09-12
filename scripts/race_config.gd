extends Node
## Global session tunables. Car-specific numbers live in CarTuning.

@export_category("Race")
@export var grid_size := 12
@export var race_laps := 5
@export var qualifying_laps := 3
@export var checkpoint_radius := 18.0
@export var drs_gap_seconds := 1.0
@export var drs_zone_length := 118.0
@export var limit_warnings_before_penalty := 3
@export var respawn_after_seconds := 4.0
@export var start_light_min_hold := 2.4
@export var start_light_max_hold := 4.8
@export var incident_delay_min := 15.0
@export var incident_delay_max := 30.0

@export_category("World")
@export var gravity := 9.81
@export var fixed_delta_hint := 0.0166667
@export var track_width := 15.0
@export var kerb_width := 2.2
@export var preview_camera_cut_min := 15.0
@export var preview_camera_cut_max := 29.0

@export_category("Performance")
@export var menu_ai_count := 8
@export var field_ai_count := 11
@export var shadow_distance := 110.0
@export var target_fps := 30

@export_category("AI")
@export var ai_profile_samples := 240
@export var ai_top_speed := 91.5
@export var ai_initial_corner_speed := 35.0
@export var ai_min_corner_speed := 12.0
@export var ai_corner_iterations := 4
@export var ai_profile_relaxation_passes := 4
@export var ai_straight_curvature := 0.001
@export var ai_lateral_margin := 0.84
@export var ai_braking_accel := 28.0
@export var ai_accel := 12.0
@export var ai_lookahead_base := 6.0
@export var ai_lookahead_speed_scale := 0.42
@export var ai_lookahead_min := 6.0
@export var ai_lookahead_max := 30.0
@export var ai_brake_lookahead_scale := 2.5
@export var ai_steering_gain := 1.45
@export var ai_throttle_gain := 0.20
@export var ai_brake_gain := 0.24
@export var ai_brake_deadzone := 0.04
@export var ai_corner_overspeed := 2.5
@export var ai_attack_distance := 34.0
@export var ai_attack_speed_delta := 1.2
@export var ai_defend_distance := 25.0
@export var ai_tactical_commit_time := 2.7
@export var ai_pass_lane_offset := 3.2
@export var ai_defend_lane_offset := 2.5
@export var ai_lane_change_rate := 1.25
@export var ai_inside_lookahead := 18.0
@export var ai_side_by_side_distance := 9.5
@export var ai_corridor_width := 2.2
@export var ai_drs_min_speed := 38.0

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

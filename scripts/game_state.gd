extends Node
## Session state deliberately stays tiny. Systems communicate through EventBus.

enum Mode { MENU, QUALIFYING, RACE, RESULTS, TIME_TRIAL, GRID }
enum StartState { IDLE, LIGHTS, GREEN, FINISHED }

var mode: Mode = Mode.MENU
var start_state: StartState = StartState.IDLE
var total_laps: int = 5
var player_car: Node3D
var race_director: Node
var elapsed_seconds := 0.0
var paused := false
var session_mode: Mode = Mode.RACE
var ghost_enabled := true
var telemetry_enabled := true
var speed_unit := "kmh"
var graphics_quality := 1
var mouse_look := true

func set_paused(value: bool) -> void:
	paused = value
	get_tree().paused = value

func begin_race() -> void:
	mode = Mode.RACE
	start_state = StartState.LIGHTS
	elapsed_seconds = 0.0
	set_paused(false)

func finish_race() -> void:
	mode = Mode.RESULTS
	start_state = StartState.FINISHED

func reset_to_menu() -> void:
	mode = Mode.MENU
	start_state = StartState.IDLE
	set_paused(false)

extends Node
## AppState - global session state: selected game and play mode.

enum Mode { NONE, AI, LAN_HOST, LAN_CLIENT, ONLINE }

var current_mode: Mode = Mode.NONE
var selected_game: String = "xiangqi"
var player_name: String = "Player"

signal mode_changed(mode: Mode)

func set_mode(mode: Mode) -> void:
	current_mode = mode
	mode_changed.emit(mode)

func reset() -> void:
	current_mode = Mode.NONE
	mode_changed.emit(current_mode)

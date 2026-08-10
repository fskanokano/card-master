extends Control
class_name GameBase
## Abstract base for all board games. Concrete games override setup/new_game/apply_move.
## This is the extension seam: add a new game by extending GameBase and registering in GameRegistry.

signal game_over(result: Dictionary) # {winner: int, reason: String}
signal move_made(from: Vector2i, to: Vector2i)

var game_id: String = ""
var player_count: int = 2

func setup(_config: Dictionary) -> void:
	pass

func new_game() -> void:
	pass

func apply_move(_from: Vector2i, _to: Vector2i) -> bool:
	return false

func is_valid_move(_from: Vector2i, _to: Vector2i, _side: int) -> bool:
	return false

func get_current_side() -> int:
	return 0

func is_game_over() -> Dictionary:
	return {"over": false}

func back_to_lobby() -> void:
	var rm: Node = get_node_or_null("/root/RoomManager")
	if rm != null and rm.has_method("leave_room"):
		rm.call("leave_room")
	else:
		NetworkHub.leave()
	AppState.reset()
	get_tree().change_scene_to_file("res://scenes/lobby/Lobby.tscn")

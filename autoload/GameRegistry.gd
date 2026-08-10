extends Node
## GameRegistry - central registry of all board/card games.
## Designed for easy extension: add entry to GAMES, done.

const GAMES: Dictionary = {
	"xiangqi": {"name": "Chinese Chess", "scene": "res://scenes/games/xiangqi/XiangqiGame.tscn", "icon": "", "players": [2], "status": "available"},
	"chess_placeholder": {"name": "Chess (Coming Soon)", "scene": "", "status": "coming_soon"},
	"go_placeholder": {"name": "Go (Coming Soon)", "scene": "", "status": "coming_soon"},
}

## Returns only games where status == "available", each entry includes its id.
func get_available_games() -> Array:
	var out: Array = []
	for id in GAMES:
		var entry: Dictionary = GAMES[id]
		if entry.get("status", "") == "available":
			var copy: Dictionary = entry.duplicate()
			copy["id"] = id
			out.append(copy)
	return out

func get_game(id: String) -> Dictionary:
	if GAMES.has(id):
		return GAMES[id]
	return {}

func is_available(id: String) -> bool:
	return GAMES.has(id) and GAMES[id].get("status", "") == "available"

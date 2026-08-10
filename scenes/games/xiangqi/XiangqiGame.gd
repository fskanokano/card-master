extends GameBase
## Xiangqi game controller: AI, LAN turn ownership, status chrome — Apple HIG shell.

var _board: Array = []
var _side_to_move: int = XiangqiLogic.RED
var _selected: Vector2i = Vector2i(-1, -1)
var _ai_side: int = XiangqiLogic.BLACK
var _game_over: bool = false
var _ai_thinking: bool = false

# LAN turn authority: host = RED, client = BLACK
var _my_side: int = XiangqiLogic.RED

@onready var _board_view: XiangqiBoard = %XiangqiBoard
@onready var _status_card: Panel = %StatusCard
@onready var _status_label: Label = %StatusLabel
@onready var _sub_label: Label = %SubLabel
@onready var _btn_undo: Button = %BtnUndo
@onready var _btn_new: Button = %BtnNew
@onready var _btn_lobby: Button = %BtnLobby

var _history: Array = [] # stack of {board, side, last_from, last_to}

func _ready() -> void:
	game_id = "xiangqi"
	_apply_apple_chrome()
	_resolve_sides()
	new_game()
	_wire_board()
	_wire_buttons()
	_wire_network()
	_refresh_ui()

func _apply_apple_chrome() -> void:
	AppleStyle.apply_card(_status_card)
	AppleStyle.apply_secondary_button(_btn_undo)
	AppleStyle.apply_primary_button(_btn_new)
	AppleStyle.apply_secondary_button(_btn_lobby)
	# Root bg
	var bg: ColorRect = get_node_or_null("Bg") as ColorRect
	if bg != null:
		bg.color = ApplePalette.BG

func _resolve_sides() -> void:
	match AppState.current_mode:
		AppState.Mode.AI:
			_my_side = XiangqiLogic.RED
			_ai_side = XiangqiLogic.BLACK
		AppState.Mode.LAN_HOST:
			_my_side = XiangqiLogic.RED
		AppState.Mode.LAN_CLIENT:
			_my_side = XiangqiLogic.BLACK
		_:
			_my_side = XiangqiLogic.RED

func _wire_board() -> void:
	_board_view.try_move.connect(_on_try_move)
	_board_view.square_selected.connect(_on_square_selected)

func _wire_buttons() -> void:
	_btn_undo.pressed.connect(_on_undo)
	_btn_new.pressed.connect(new_game)
	_btn_lobby.pressed.connect(func() -> void: back_to_lobby())

func _wire_network() -> void:
	NetworkHub.peer_connected.connect(func(_id: int) -> void: _refresh_ui())
	NetworkHub.peer_disconnected.connect(func(_id: int) -> void: _refresh_ui())
	NetworkHub.connection_failed.connect(func() -> void: _sub_label.text = "Connection failed.")
	RoomManager.room_peer_left.connect(func(_id: int) -> void:
		if not _game_over:
			_sub_label.text = "Opponent disconnected."
	)
	RoomManager.room_error.connect(func(msg: String) -> void: _sub_label.text = msg)

func setup(_config: Dictionary) -> void:
	pass

func new_game() -> void:
	_board = XiangqiLogic.initial_board()
	_side_to_move = XiangqiLogic.RED
	_selected = Vector2i(-1, -1)
	_game_over = false
	_ai_thinking = false
	_history.clear()
	_board_view.set_last_move(Vector2i(-1, -1), Vector2i(-1, -1))
	_sync_board()
	_refresh_ui()
	if AppState.current_mode == AppState.Mode.AI and _side_to_move == _ai_side:
		_trigger_ai()

func _sync_board() -> void:
	_board_view.set_board(_board)
	_board_view.set_selection(_selected, _legal_for_selected())
	_board_view.interactable = not _game_over and not _ai_thinking and _is_my_turn()

func _legal_for_selected() -> Array[Vector2i]:
	if _selected.x == -1:
		return []
	var p: int = _board[_selected.y][_selected.x]
	if p == 0 or XiangqiLogic.piece_side(p) != _side_to_move:
		return []
	var out: Array[Vector2i] = []
	for m in (XiangqiLogic.all_legal_moves(_board, _side_to_move) as Array):
		if m["from"] == _selected:
			out.append(m["to"])
	return out

func _on_square_selected(pos: Vector2i) -> void:
	if _game_over or _ai_thinking or not _is_my_turn():
		return
	if pos.x == -1:
		_selected = Vector2i(-1, -1)
		_sync_board()
		return
	var p: int = _board[pos.y][pos.x]
	if p != 0 and XiangqiLogic.piece_side(p) == _side_to_move:
		_selected = pos
	else:
		_selected = Vector2i(-1, -1)
	_sync_board()

func _on_try_move(from: Vector2i, to: Vector2i) -> void:
	if _game_over or _ai_thinking or not _is_my_turn():
		return
	_do_move(from, to, true)

func _do_move(from: Vector2i, to: Vector2i, broadcast: bool) -> void:
	if not XiangqiLogic.is_legal(_board, from.x, from.y, to.x, to.y, _side_to_move):
		return
	_history.append({
		"board": XiangqiLogic.clone_board(_board),
		"side": _side_to_move,
		"last_from": _board_view.last_move_from,
		"last_to": _board_view.last_move_to,
	})
	_board = XiangqiLogic.apply_on_clone(_board, from.x, from.y, to.x, to.y)
	_board_view.set_last_move(from, to)
	var mover: int = _side_to_move
	_side_to_move = XiangqiLogic.BLACK if _side_to_move == XiangqiLogic.RED else XiangqiLogic.RED
	_selected = Vector2i(-1, -1)
	move_made.emit(from, to)
	_check_game_over(mover)
	_sync_board()
	_refresh_ui()
	if broadcast and _is_lan():
		_rpc_remote_move.rpc(from, to)
	if not _game_over and AppState.current_mode == AppState.Mode.AI and _side_to_move == _ai_side:
		_trigger_ai()

func _check_game_over(mover: int) -> void:
	# Mover just moved; check if opponent is checkmated
	if XiangqiLogic.is_checkmate(_board, _side_to_move):
		_game_over = true
		var winner: String = "Red" if mover == XiangqiLogic.RED else "Black"
		_sub_label.text = "%s wins by checkmate." % winner
		game_over.emit({"winner": mover, "reason": "checkmate"})
		return
	if XiangqiLogic.is_stalemate_no_moves(_board, _side_to_move):
		if XiangqiLogic.is_in_check(_board, _side_to_move):
			_game_over = true
			var w2: String = "Red" if mover == XiangqiLogic.RED else "Black"
			_sub_label.text = "%s wins." % w2
			game_over.emit({"winner": mover, "reason": "checkmate"})
		else:
			_game_over = true
			_sub_label.text = "Draw — stalemate."
			game_over.emit({"winner": 0, "reason": "stalemate"})

func _is_lan() -> bool:
	return AppState.current_mode in [AppState.Mode.LAN_HOST, AppState.Mode.LAN_CLIENT]

func _is_my_turn() -> bool:
	if AppState.current_mode == AppState.Mode.AI:
		return _side_to_move != _ai_side
	if _is_lan():
		return _side_to_move == _my_side
	return true

func _trigger_ai() -> void:
	_ai_thinking = true
	_sync_board()
	_refresh_ui()
	# Defer to next frame so UI paints "Thinking…"
	await get_tree().process_frame
	var mv: Dictionary = XiangqiAI.best_move(_board, _side_to_move, 2)
	_ai_thinking = false
	if mv.is_empty() or _game_over:
		_sync_board()
		_refresh_ui()
		return
	_do_move(mv["from"], mv["to"], false)

func _on_undo() -> void:
	if _history.is_empty() or _game_over:
		return
	if AppState.current_mode == AppState.Mode.AI:
		# Undo full round (AI + player) if possible
		var to_pop: int = 2 if _history.size() >= 2 else 1
		for _i in range(to_pop):
			if _history.is_empty():
				break
			var snap: Dictionary = _history.pop_back()
			_board = snap["board"]
			_side_to_move = snap["side"]
			_board_view.set_last_move(snap["last_from"], snap["last_to"])
	else:
		var snap2: Dictionary = _history.pop_back()
		_board = snap2["board"]
		_side_to_move = snap2["side"]
		_board_view.set_last_move(snap2["last_from"], snap2["last_to"])
	_selected = Vector2i(-1, -1)
	_game_over = false
	_sync_board()
	_refresh_ui()

func _refresh_ui() -> void:
	if _game_over:
		_status_label.text = "Game Over"
		_status_label.add_theme_color_override("font_color", ApplePalette.RED)
		_board_view.interactable = false
		return
	var side_name: String = "Red" if _side_to_move == XiangqiLogic.RED else "Black"
	var my_turn: bool = _is_my_turn()
	if AppState.current_mode == AppState.Mode.AI:
		if _ai_thinking:
			_status_label.text = "Thinking…"
			_sub_label.text = "Black is calculating."
		elif my_turn:
			_status_label.text = "Your move"
			_sub_label.text = "You are Red  •  Tap a piece, then a highlighted square."
		else:
			_status_label.text = "Opponent’s move"
			_sub_label.text = "Black to play."
	elif _is_lan():
		var role: String = "Host (Red)" if AppState.current_mode == AppState.Mode.LAN_HOST else "Client (Black)"
		if my_turn:
			_status_label.text = "Your move  •  %s" % side_name
			_sub_label.text = "%s  •  %s" % [role, "LAN — your turn." if NetworkHub.is_connected_to_peer() else "Waiting for peer…"]
		else:
			_status_label.text = "Opponent’s move  •  %s" % side_name
			_sub_label.text = "%s  •  Waiting for opponent." % role
	else:
		_status_label.text = "%s to move" % side_name
		_sub_label.text = "Tap a piece, then a highlighted square."
	_status_label.add_theme_color_override("font_color", ApplePalette.LABEL)
	if XiangqiLogic.is_in_check(_board, _side_to_move):
		_status_label.text += "  •  Check!"
		_status_label.add_theme_color_override("font_color", ApplePalette.RED)
	_board_view.interactable = not _game_over and not _ai_thinking and my_turn

# --- LAN sync ---

@rpc("any_peer", "call_local", "reliable")
func _rpc_remote_move(from: Vector2i, to: Vector2i) -> void:
	# Ignore echo on sender (call_local)
	if multiplayer.get_remote_sender_id() == 0:
		return
	# Validate it is opponent's turn
	var sender_side: int = XiangqiLogic.BLACK if _my_side == XiangqiLogic.RED else XiangqiLogic.RED
	if _side_to_move != sender_side:
		return
	_do_move(from, to, false)

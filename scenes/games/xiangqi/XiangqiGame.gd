extends GameBase
## Xiangqi — 真·流畅位移，无瞬移。棋子飞行期间源/目标均隐藏，被吃子淡出。

var _board: Array = []
var _side_to_move: int = XiangqiLogic.RED
var _selected: Vector2i = Vector2i(-1, -1)
var _ai_side: int = XiangqiLogic.BLACK
var _game_over: bool = false
var _ai_thinking: bool = false
var _my_side: int = XiangqiLogic.RED
var _is_animating: bool = false

@onready var _board_view: XiangqiBoard = %XiangqiBoard
@onready var _status_card: Panel = %StatusCard
@onready var _status_label: Label = %StatusLabel
@onready var _sub_label: Label = %SubLabel
@onready var _btn_undo: Button = %BtnUndo
@onready var _btn_new: Button = %BtnNew
@onready var _btn_lobby: Button = %BtnLobby

var _history: Array = []

func _ready() -> void:
	game_id = "xiangqi"
	_apply_enterprise_chrome()
	_apply_immersive_insets()
	_resolve_sides()
	new_game()
	_wire_board()
	_wire_buttons()
	_wire_network()
	_refresh_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _on_viewport_resized() -> void:
	_apply_immersive_insets()
	if _board_view != null:
		_board_view._update_layout()

func _apply_immersive_insets() -> void:
	# 全面屏：刘海/手势条安全区
	var safe := DisplayServer.get_display_safe_area()
	var win_size := DisplayServer.window_get_size()
	# Godot 4 get_window_safe_area 需 4.3+；回退用 window_get_size
	var inset_top: int = 0
	var inset_bottom: int = 0
	if safe.size.y > 0 and safe.position.y > 0:
		inset_top = int(safe.position.y)
		inset_bottom = int(win_size.y - (safe.position.y + safe.size.y))
	# 也兼容 NOTCH via get_window_safe_area if available
	if inset_top == 0:
		# 常见全面屏状态栏 24-44pt
		var is_mobile: bool = OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"]
		if is_mobile:
			inset_top = 28
			inset_bottom = 18
	var top_bar: Panel = get_node_or_null("TopBar") as Panel
	if top_bar != null:
		top_bar.offset_top = inset_top
		top_bar.offset_bottom = inset_top + 64
	var board_wrap: Control = get_node_or_null("BoardWrap") as Control
	if board_wrap != null:
		board_wrap.offset_top = inset_top + 64
		board_wrap.offset_bottom = -52 - inset_bottom
	var bottom_bar: Panel = get_node_or_null("BottomBar") as Panel
	if bottom_bar != null:
		bottom_bar.offset_top = -52 - inset_bottom
		bottom_bar.offset_bottom = -inset_bottom

func _apply_enterprise_chrome() -> void:
	var top: Panel = get_node("TopBar")
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color("#0D1219", 0.96)
	tsb.corner_radius_top_left = 0; tsb.corner_radius_top_right = 0; tsb.corner_radius_bottom_right = 0; tsb.corner_radius_bottom_left = 0
	tsb.border_color = ApplePalette.SEPARATOR; tsb.border_width_bottom = 1
	tsb.content_margin_left = 16; tsb.content_margin_top = 10; tsb.content_margin_right = 16; tsb.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel", tsb)
	var sc_sb := StyleBoxFlat.new()
	sc_sb.bg_color = Color("#111A26")
	sc_sb.corner_radius_top_left = 12; sc_sb.corner_radius_top_right = 12; sc_sb.corner_radius_bottom_right = 12; sc_sb.corner_radius_bottom_left = 12
	sc_sb.border_color = ApplePalette.HAIRLINE_GOLD; sc_sb.border_width_left = 1; sc_sb.border_width_top = 1; sc_sb.border_width_right = 1; sc_sb.border_width_bottom = 1
	sc_sb.content_margin_left = 12; sc_sb.content_margin_top = 6; sc_sb.content_margin_right = 12; sc_sb.content_margin_bottom = 6
	_status_card.add_theme_stylebox_override("panel", sc_sb)
	var bot: Panel = get_node("BottomBar")
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#0D1219", 0.96)
	bsb.border_color = ApplePalette.SEPARATOR; bsb.border_width_top = 1
	bsb.content_margin_left = 16; bsb.content_margin_top = 10; bsb.content_margin_right = 16; bsb.content_margin_bottom = 10
	bot.add_theme_stylebox_override("panel", bsb)
	var badge: Panel = get_node("BottomBar/BottomInner/BottomBadge")
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color("#111A26")
	badge_sb.corner_radius_top_left = 20; badge_sb.corner_radius_top_right = 20; badge_sb.corner_radius_bottom_right = 20; badge_sb.corner_radius_bottom_left = 20
	badge_sb.border_color = ApplePalette.SEPARATOR; badge_sb.border_width_left = 1; badge_sb.border_width_top = 1; badge_sb.border_width_right = 1; badge_sb.border_width_bottom = 1
	badge_sb.content_margin_left = 8; badge_sb.content_margin_top = 4; badge_sb.content_margin_right = 8; badge_sb.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_sb)
	AppleStyle.apply_secondary_button(_btn_lobby)
	AppleStyle.apply_primary_button(_btn_new)
	AppleStyle.apply_secondary_button(_btn_undo)

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
	NetworkHub.connection_failed.connect(func() -> void: _sub_label.text = "连接失败")
	RoomManager.room_peer_left.connect(func(_id: int) -> void:
		if not _game_over:
			_sub_label.text = "对手已断开连接"
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
	_is_animating = false
	_history.clear()
	_board_view.set_last_move(Vector2i(-1, -1), Vector2i(-1, -1))
	_sync_board()
	_refresh_ui()
	if AppState.current_mode == AppState.Mode.AI and _side_to_move == _ai_side:
		_trigger_ai()

func _sync_board() -> void:
	_board_view.set_board(_board)
	_board_view.set_selection(_selected, _legal_for_selected())
	_board_view.interactable = not _game_over and not _ai_thinking and not _is_animating and _is_my_turn()

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
	if _game_over or _ai_thinking or _is_animating or not _is_my_turn():
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
	if _game_over or _ai_thinking or _is_animating or not _is_my_turn():
		return
	_do_move(from, to, true)

func _do_move(from: Vector2i, to: Vector2i, broadcast: bool) -> void:
	if not XiangqiLogic.is_legal(_board, from.x, from.y, to.x, to.y, _side_to_move):
		return
	# 关键：先捕获信息，再启动飞行
	var mover_piece: int = _board[from.y][from.x]
	var captured: int = _board[to.y][to.x]
	_history.append({
		"board": XiangqiLogic.clone_board(_board),
		"side": _side_to_move,
		"last_from": _board_view.last_move_from,
		"last_to": _board_view.last_move_to,
	})
	# 立即启动飞行（board 仍为旧状态，飞行棋隐藏源/目标）
	_is_animating = true
	_sync_board()
	_board_view.animate_move(from, to, mover_piece, captured)
	# 动画期间锁定交互
	_board_view.interactable = false
	# 计算飞行时长，与 Board 保持一致
	var dist: float = Vector2(from).distance_to(Vector2(to))
	var dur: float = clamp(0.26 + dist * 0.018, 0.26, 0.46)
	if dist >= 6:
		dur += 0.04
	# 延迟提交 board 与回合切换，等待飞行落位
	await get_tree().create_timer(dur).timeout
	if not is_inside_tree():
		return
	# 真正落地
	_board = XiangqiLogic.apply_on_clone(_board, from.x, from.y, to.x, to.y)
	_board_view.set_last_move(from, to)
	var mover: int = _side_to_move
	_side_to_move = XiangqiLogic.BLACK if _side_to_move == XiangqiLogic.RED else XiangqiLogic.RED
	_selected = Vector2i(-1, -1)
	_is_animating = false
	move_made.emit(from, to)
	_check_game_over(mover)
	_sync_board()
	_refresh_ui()
	if broadcast and _is_lan():
		_rpc_remote_move.rpc(from, to)
	if not _game_over and AppState.current_mode == AppState.Mode.AI and _side_to_move == _ai_side:
		_trigger_ai()

func _check_game_over(mover: int) -> void:
	if XiangqiLogic.is_checkmate(_board, _side_to_move):
		_game_over = true
		_sub_label.text = "%s 将杀获胜" % ("红方" if mover == XiangqiLogic.RED else "黑方")
		game_over.emit({"winner": mover, "reason": "checkmate"})
		return
	if XiangqiLogic.is_stalemate_no_moves(_board, _side_to_move):
		if XiangqiLogic.is_in_check(_board, _side_to_move):
			_game_over = true
			_sub_label.text = "%s 获胜" % ("红方" if mover == XiangqiLogic.RED else "黑方")
			game_over.emit({"winner": mover, "reason": "checkmate"})
		else:
			_game_over = true
			_sub_label.text = "和棋  ·  困毙"
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
	if _is_animating:
		await get_tree().create_timer(0.12).timeout
	_ai_thinking = true
	_sync_board()
	_refresh_ui()
	await get_tree().process_frame
	await get_tree().create_timer(0.18).timeout
	if not is_inside_tree() or _game_over or _is_animating:
		_ai_thinking = false
		_sync_board()
		_refresh_ui()
		return
	var mv: Dictionary = XiangqiAI.best_move(_board, _side_to_move, 2)
	_ai_thinking = false
	if mv.is_empty() or _game_over:
		_sync_board()
		_refresh_ui()
		return
	_do_move(mv["from"], mv["to"], false)

func _on_undo() -> void:
	if _is_animating or _history.is_empty() or _game_over:
		return
	if _board_view.is_animating():
		return
	if AppState.current_mode == AppState.Mode.AI:
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
		_status_label.text = "对局结束"
		_status_label.add_theme_color_override("font_color", ApplePalette.RED)
		var sc: StyleBoxFlat = _status_card.get_theme_stylebox("panel") as StyleBoxFlat
		if sc != null:
			sc.border_color = ApplePalette.RED
			sc.bg_color = Color("#1A1214")
		_board_view.interactable = false
		return
	var side_name: String = "红方" if _side_to_move == XiangqiLogic.RED else "黑方"
	var my_turn: bool = _is_my_turn()
	if _is_animating:
		_status_label.text = "落子中…"
		_sub_label.text = "棋子飞行中"
	elif AppState.current_mode == AppState.Mode.AI:
		if _ai_thinking:
			_status_label.text = "AI 思考中…"
			_sub_label.text = "黑方正在计算"
		elif my_turn:
			_status_label.text = "轮到你走棋"
			_sub_label.text = "你是红方  ·  拖拽或点击棋子至鎏金落点"
		else:
			_status_label.text = "对手回合"
			_sub_label.text = "黑方走棋"
	elif _is_lan():
		var role: String = "主机 · 红方" if AppState.current_mode == AppState.Mode.LAN_HOST else "客机 · 黑方"
		if my_turn:
			_status_label.text = "你的回合  ·  %s" % side_name
			_sub_label.text = "%s  ·  %s" % [role, "你的回合" if NetworkHub.is_connected_to_peer() else "等待对手连接…"]
		else:
			_status_label.text = "对手回合  ·  %s" % side_name
			_sub_label.text = "%s  ·  等待对手落子" % role
	else:
		_status_label.text = "%s 行棋" % side_name
		_sub_label.text = "拖拽棋子或点击高亮落点"
	_status_label.add_theme_color_override("font_color", ApplePalette.LABEL)
	var sc2: StyleBoxFlat = _status_card.get_theme_stylebox("panel") as StyleBoxFlat
	if sc2 != null:
		sc2.border_color = ApplePalette.HAIRLINE_GOLD
		sc2.bg_color = Color("#111A26")
	if XiangqiLogic.is_in_check(_board, _side_to_move):
		_status_label.text += "  ·  将军！"
		_status_label.add_theme_color_override("font_color", ApplePalette.RED)
		if sc2 != null:
			sc2.border_color = ApplePalette.RED
			sc2.bg_color = Color("#1A1214")
	_board_view.interactable = not _game_over and not _ai_thinking and not _is_animating and my_turn

@rpc("any_peer", "call_local", "reliable")
func _rpc_remote_move(from: Vector2i, to: Vector2i) -> void:
	if multiplayer.get_remote_sender_id() == 0:
		return
	var sender_side: int = XiangqiLogic.BLACK if _my_side == XiangqiLogic.RED else XiangqiLogic.RED
	if _side_to_move != sender_side:
		return
	# 远端落子同样走飞行
	_do_move(from, to, false)

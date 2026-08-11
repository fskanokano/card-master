extends GameBase
## Xiangqi — 真·手游级对局：超大棋盘吃满屏 + 全量音效 + 飞行无瞬移

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
	# 入场微动
	_animate_enter()

func _animate_enter() -> void:
	var top: Control = get_node_or_null("TopBar") as Control
	var board_wrap: Control = get_node_or_null("BoardWrap") as Control
	var bottom: Control = get_node_or_null("BottomBar") as Control
	for n in [board_wrap, bottom]:
		if n == null:
			continue
		n.modulate.a = 0.0
		var tw := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(n, "modulate:a", 1.0, 0.32)
		await get_tree().create_timer(0.06).timeout

func _on_viewport_resized() -> void:
	_apply_immersive_insets()
	if _board_view != null:
		_board_view._update_layout()

func _apply_immersive_insets() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win_size := DisplayServer.window_get_size()
	var inset_top: int = 0
	var inset_bottom: int = 0
	if safe.size.y > 0 and safe.position.y > 0:
		inset_top = int(safe.position.y)
		inset_bottom = int(win_size.y - (safe.position.y + safe.size.y))
	if inset_top == 0:
		var is_mobile: bool = OS.has_feature("mobile") or DisplayServer.get_name() in ["Android", "iOS"]
		if is_mobile:
			inset_top = 30
			inset_bottom = 22
	# 手游规格：顶栏更高、更易点
	var top_h: int = 68
	var bot_h: int = 64
	var top_bar: Panel = get_node_or_null("TopBar") as Panel
	if top_bar != null:
		top_bar.offset_top = inset_top
		top_bar.offset_bottom = inset_top + top_h
	var board_wrap: Control = get_node_or_null("BoardWrap") as Control
	if board_wrap != null:
		board_wrap.offset_top = inset_top + top_h
		board_wrap.offset_bottom = -bot_h - inset_bottom
		# 左右也吃到安全区
		var inset_l: int = int(safe.position.x) if safe.size.x > 0 and safe.position.x > 0 else 0
		var inset_r: int = int(win_size.x - (safe.position.x + safe.size.x)) if safe.size.x > 0 else 0
		# 竖屏下左右不额外偏移，棋盘自己会居中吃满
		board_wrap.offset_left = inset_l
		board_wrap.offset_right = -inset_r
	var bottom_bar: Panel = get_node_or_null("BottomBar") as Panel
	if bottom_bar != null:
		bottom_bar.offset_top = -bot_h - inset_bottom
		bottom_bar.offset_bottom = -inset_bottom

func _apply_enterprise_chrome() -> void:
	var top: Panel = get_node("TopBar")
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color("#0D1219", 0.98)
	tsb.corner_radius_top_left = 0; tsb.corner_radius_top_right = 0; tsb.corner_radius_bottom_right = 0; tsb.corner_radius_bottom_left = 0
	tsb.border_color = ApplePalette.SEPARATOR; tsb.border_width_bottom = 1
	tsb.content_margin_left = 14; tsb.content_margin_top = 10; tsb.content_margin_right = 14; tsb.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel", tsb)
	# 标题更大
	var tcn: Label = get_node_or_null("TopBar/TopInner/TopTitle/TitleCN") as Label
	if tcn != null:
		tcn.add_theme_font_size_override("font_size", 17)
	var ten: Label = get_node_or_null("TopBar/TopInner/TopTitle/TitleEN") as Label
	if ten != null:
		ten.add_theme_font_size_override("font_size", 11)
	var sc_sb := StyleBoxFlat.new()
	sc_sb.bg_color = Color("#111A26")
	sc_sb.corner_radius_top_left = 14; sc_sb.corner_radius_top_right = 14; sc_sb.corner_radius_bottom_right = 14; sc_sb.corner_radius_bottom_left = 14
	sc_sb.border_color = ApplePalette.HAIRLINE_GOLD; sc_sb.border_width_left = 1; sc_sb.border_width_top = 1; sc_sb.border_width_right = 1; sc_sb.border_width_bottom = 1
	sc_sb.content_margin_left = 14; sc_sb.content_margin_top = 7; sc_sb.content_margin_right = 14; sc_sb.content_margin_bottom = 7
	_status_card.add_theme_stylebox_override("panel", sc_sb)
	var bot: Panel = get_node("BottomBar")
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color("#0D1219", 0.98)
	bsb.border_color = ApplePalette.SEPARATOR; bsb.border_width_top = 1
	bsb.content_margin_left = 14; bsb.content_margin_top = 12; bsb.content_margin_right = 14; bsb.content_margin_bottom = 12
	bot.add_theme_stylebox_override("panel", bsb)
	var badge: Panel = get_node("BottomBar/BottomInner/BottomBadge")
	var badge_sb := StyleBoxFlat.new()
	badge_sb.bg_color = Color("#111A26")
	badge_sb.corner_radius_top_left = 20; badge_sb.corner_radius_top_right = 20; badge_sb.corner_radius_bottom_right = 20; badge_sb.corner_radius_bottom_left = 20
	badge_sb.border_color = ApplePalette.SEPARATOR; badge_sb.border_width_left = 1; badge_sb.border_width_top = 1; badge_sb.border_width_right = 1; badge_sb.border_width_bottom = 1
	badge_sb.content_margin_left = 10; badge_sb.content_margin_top = 5; badge_sb.content_margin_right = 10; badge_sb.content_margin_bottom = 5
	badge.add_theme_stylebox_override("panel", badge_sb)
	# 手游大按钮：44pt 高度、更大字
	AppleStyle.apply_secondary_button(_btn_lobby)
	_btn_lobby.custom_minimum_size = Vector2(112, 44)
	_btn_lobby.add_theme_font_size_override("font_size", 14)
	AppleStyle.apply_primary_button(_btn_new)
	_btn_new.custom_minimum_size = Vector2(92, 44)
	_btn_new.add_theme_font_size_override("font_size", 15)
	AppleStyle.apply_secondary_button(_btn_undo)
	_btn_undo.custom_minimum_size = Vector2(92, 44)
	_btn_undo.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_font_size_override("font_size", 14)
	_sub_label.add_theme_font_size_override("font_size", 13)

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
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_tap"):
		am.call("play_tap")
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
		# 选中音效已由 Board 发起，这里不再重复
	else:
		_selected = Vector2i(-1, -1)
	_sync_board()

func _on_try_move(from: Vector2i, to: Vector2i) -> void:
	if _game_over or _ai_thinking or _is_animating or not _is_my_turn():
		return
	_do_move(from, to, true)

func _do_move(from: Vector2i, to: Vector2i, broadcast: bool) -> void:
	if not XiangqiLogic.is_legal(_board, from.x, from.y, to.x, to.y, _side_to_move):
		var am_err: Node = get_node_or_null("/root/AudioManager")
		if am_err != null and am_err.has_method("play_invalid"):
			am_err.call("play_invalid")
		return
	var mover_piece: int = _board[from.y][from.x]
	var captured: int = _board[to.y][to.x]
	_history.append({
		"board": XiangqiLogic.clone_board(_board),
		"side": _side_to_move,
		"last_from": _board_view.last_move_from,
		"last_to": _board_view.last_move_to,
	})
	_is_animating = true
	_sync_board()
	_board_view.animate_move(from, to, mover_piece, captured)
	_board_view.interactable = false
	# 飞行时底部文案
	_sub_label.text = "落子中…"
	var dist: float = Vector2(from).distance_to(Vector2(to))
	var dur: float = clamp(0.24 + dist * 0.022, 0.26, 0.50)
	if dist >= 5:
		dur += 0.04
	await get_tree().create_timer(dur).timeout
	if not is_inside_tree():
		return
	_board = XiangqiLogic.apply_on_clone(_board, from.x, from.y, to.x, to.y)
	_board_view.set_last_move(from, to)
	var mover: int = _side_to_move
	_side_to_move = XiangqiLogic.BLACK if _side_to_move == XiangqiLogic.RED else XiangqiLogic.RED
	_selected = Vector2i(-1, -1)
	_is_animating = false
	move_made.emit(from, to)
	var was_check: bool = XiangqiLogic.is_in_check(_board, _side_to_move)
	var is_capture: bool = captured != 0
	_check_game_over(mover)
	# 音效：将军>吃子>普通
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null:
		if _game_over:
			if mover == _my_side:
				if am.has_method("play_win"):
					am.call("play_win")
			else:
				if am.has_method("play_lose"):
					am.call("play_lose")
		elif am.has_method("play_move_result"):
			am.call("play_move_result", is_capture, was_check)
		elif was_check and am.has_method("play_check"):
			am.call("play_check")
		elif is_capture and am.has_method("play_capture"):
			am.call("play_capture")
		elif am.has_method("play_move"):
			am.call("play_move")
	# 获胜震动
	if _game_over and am != null:
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(60)
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
		await get_tree().create_timer(0.14).timeout
	_ai_thinking = true
	_sync_board()
	_refresh_ui()
	await get_tree().process_frame
	await get_tree().create_timer(0.22).timeout
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
	var am: Node = get_node_or_null("/root/AudioManager")
	if am != null and am.has_method("play_tap"):
		am.call("play_tap")
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
		_sub_label.text = "棋子飞行中  ·  请稍候"
	elif AppState.current_mode == AppState.Mode.AI:
		if _ai_thinking:
			_status_label.text = "AI 思考中…"
			_sub_label.text = "黑方正在计算"
		elif my_turn:
			_status_label.text = "轮到你走棋"
			_sub_label.text = "你是红方  ·  长按拖动棋子到鎏金落点"
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
		_sub_label.text = "长按拖动棋子到高亮落点  ·  非法位置会弹回"
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
	_do_move(from, to, false)

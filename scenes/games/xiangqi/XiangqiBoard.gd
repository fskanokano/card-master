extends Control
class_name XiangqiBoard
## XiangqiBoard — Enterprise luxury rendering + 沉浸式全面屏 + 流畅位移
## 关键：棋子不再瞬移 — 全程 Tween 位移 + 抬起抛物线 + 阴影呼吸 + 吃子消散，
## 源/目标格在动画期间均隐藏，仅飞行棋可见。

signal try_move(from: Vector2i, to: Vector2i)
signal square_selected(pos: Vector2i)

var board: Array = []
var selected: Vector2i = Vector2i(-1, -1)
var legal_targets: Array[Vector2i] = []
var last_move_from: Vector2i = Vector2i(-1, -1)
var last_move_to: Vector2i = Vector2i(-1, -1)
var interactable: bool = true

# ── Layout（响应式） ──────────────────────────────────────
var _cell: float = 56.0
var _origin: Vector2 = Vector2(28, 28)
var _board_pad: float = 14.0
var _frame_thick: float = 14.0

# ── Animation state ──────────────────────────────────────
var _anim_tween: Tween = null
var _anim_from: Vector2i = Vector2i(-1, -1)
var _anim_to: Vector2i = Vector2i(-1, -1)
var _anim_piece: int = 0
var _anim_captured: int = 0
var _anim_is_capture: bool = false
var _anim_pos_from: Vector2 = Vector2.ZERO
var _anim_pos_to: Vector2 = Vector2.ZERO
var _anim_progress: float = 0.0:
	set(v):
		_anim_progress = v
		queue_redraw()
var _anim_capture_alpha: float = 1.0:
	set(v):
		_anim_capture_alpha = v
		queue_redraw()
var _anim_capture_scale: float = 1.0:
	set(v):
		_anim_capture_scale = v
		queue_redraw()

# ── Touch drag ───────────────────────────────────────────
var _drag_from: Vector2i = Vector2i(-1, -1)
var _drag_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _drag_threshold: float = 10.0
var _touch_start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	# 响应式：监听尺寸变化
	resized.connect(_update_layout)
	_update_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()

func _update_layout() -> void:
	# 以可用尺寸自适应 _cell，保证 9×10 完整可见且最大化利用
	var avail: Vector2 = size
	if avail.x < 40 or avail.y < 40:
		avail = custom_minimum_size
		if avail.x < 40:
			avail = Vector2(360, 600)
	# 优先按宽度算，其次高度约束
	var max_w: float = avail.x - _frame_thick * 2 - _board_pad * 2
	var max_h: float = avail.y - _frame_thick * 2 - _board_pad * 2
	var cell_by_w: float = max_w / 8.0
	var cell_by_h: float = max_h / 9.0
	_cell = min(cell_by_w, cell_by_h)
	_cell = clamp(_cell, 28.0, 64.0)
	# 居中 origin
	var board_w: float = 8 * _cell
	var board_h: float = 9 * _cell
	var total_w: float = board_w + _frame_thick * 2 + _board_pad * 2
	var total_h: float = board_h + _frame_thick * 2 + _board_pad * 2
	# 如果 Control 本身比 total 大，则居中；否则紧贴 frame
	var ox: float = _frame_thick + _board_pad + (max(0, avail.x - total_w) / 2.0)
	var oy: float = _frame_thick + _board_pad + (max(0, avail.y - total_h) / 2.0)
	_origin = Vector2(ox, oy)
	# 同步最小尺寸，避免父容器过度压缩
	custom_minimum_size = Vector2(total_w, total_h)
	queue_redraw()

func get_board_pixel_size() -> Vector2:
	return Vector2(8 * _cell + _frame_thick * 2 + _board_pad * 2, 9 * _cell + _frame_thick * 2 + _board_pad * 2)

func set_board(b: Array) -> void:
	board = b
	queue_redraw()

func set_selection(sel: Vector2i, targets: Array[Vector2i]) -> void:
	selected = sel
	legal_targets = targets
	queue_redraw()

func set_last_move(f: Vector2i, t: Vector2i) -> void:
	last_move_from = f
	last_move_to = t
	queue_redraw()

# ── 核心：流畅位移动画（无瞬移） ──────────────────────────

func animate_move(from: Vector2i, to: Vector2i, piece: int = 0, captured: int = 0) -> void:
	if from.x < 0 or to.x < 0:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
		# 强制结束上一段
		_anim_from = Vector2i(-1, -1)
		_anim_to = Vector2i(-1, -1)
		_anim_piece = 0
		_anim_captured = 0
	var p: int = piece if piece != 0 else (board[from.y][from.x] if from.y >= 0 and from.y < 10 and from.x >= 0 and from.x < 9 else 0)
	if p == 0:
		return
	_anim_from = from
	_anim_to = to
	_anim_piece = p
	_anim_captured = captured
	_anim_is_capture = captured != 0
	_anim_pos_from = board_to_local(from.x, from.y)
	_anim_pos_to = board_to_local(to.x, to.y)
	_anim_progress = 0.0
	_anim_capture_alpha = 1.0
	_anim_capture_scale = 1.0

	var dist: float = Vector2(from).distance_to(Vector2(to))
	# 距离越远越久，基础 260ms + 每格 ~18ms，上限 460ms
	var dur: float = clamp(0.26 + dist * 0.018, 0.26, 0.46)
	# 长距离（车/炮跨半盘）略加弹性
	if dist >= 6:
		dur += 0.04

	_anim_tween = create_tween()
	_anim_tween.set_parallel(false)
	# 主位移 — cubic out，丝滑不生硬
	_anim_tween.tween_property(self, "_anim_progress", 1.0, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if _anim_is_capture:
		# 被吃子在后半程消散：先保持，300ms 开始缩小+淡出
		var cap_tween := create_tween()
		cap_tween.tween_property(self, "_anim_capture_alpha", 1.0, dur * 0.55)
		cap_tween.tween_property(self, "_anim_capture_alpha", 0.0, dur * 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		cap_tween.parallel().tween_property(self, "_anim_capture_scale", 0.72, dur * 0.38).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		_anim_tween.tween_callback(func() -> void:
			_anim_from = Vector2i(-1, -1)
			_anim_to = Vector2i(-1, -1)
			_anim_piece = 0
			_anim_captured = 0
			_anim_is_capture = false
			_anim_progress = 0.0
			_anim_capture_alpha = 1.0
			_anim_capture_scale = 1.0
			queue_redraw()
		)
	else:
		_anim_tween.tween_callback(func() -> void:
			_anim_from = Vector2i(-1, -1)
			_anim_to = Vector2i(-1, -1)
			_anim_piece = 0
			_anim_progress = 0.0
			queue_redraw()
		)
	queue_redraw()
	# 轻震动（移动端）
	_try_haptic(18)

func is_animating() -> bool:
	return _anim_piece != 0

func board_to_local(bx: int, by: int) -> Vector2:
	return Vector2(_origin.x + bx * _cell, _origin.y + by * _cell)

func local_to_board(p: Vector2) -> Vector2i:
	return Vector2i(int(round((p.x - _origin.x) / _cell)), int(round((p.y - _origin.y) / _cell)))

# ── 输入：点击 + 拖拽 ────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if not interactable:
		return
	if _anim_piece != 0:
		return

	# 触屏/鼠标按下
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_touch_start_pos = st.position
			var pos: Vector2i = local_to_board(st.position)
			if not XiangqiLogic.inside_board(pos.x, pos.y):
				return
			# 若点在己方棋子上，进入拖拽预备
			if board[pos.y][pos.x] != 0 and selected == pos:
				_drag_from = pos
				_drag_pos = st.position
				_is_dragging = false
			elif board[pos.y][pos.x] != 0:
				# 先选中
				square_selected.emit(pos)
				_drag_from = pos
				_drag_pos = st.position
				_is_dragging = false
				_try_haptic(10)
			accept_event()
		else:
			# 抬起
			if _is_dragging and _drag_from.x != -1:
				var drop: Vector2i = local_to_board(st.position)
				if XiangqiLogic.inside_board(drop.x, drop.y):
					for t in legal_targets:
						if t == drop:
							try_move.emit(_drag_from, drop)
							_drag_from = Vector2i(-1, -1)
							_is_dragging = false
							accept_event()
							return
				# 未落在合法点则视为选中
				_drag_from = Vector2i(-1, -1)
			_is_dragging = false
			_drag_from = Vector2i(-1, -1)
			queue_redraw()
			accept_event()
		return

	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		if _drag_from.x != -1:
			if not _is_dragging and sd.position.distance_to(_touch_start_pos) > _drag_threshold:
				_is_dragging = true
				queue_redraw()
			if _is_dragging:
				_drag_pos = sd.position
				queue_redraw()
				accept_event()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2i = local_to_board(event.position)
		if not XiangqiLogic.inside_board(pos.x, pos.y):
			return
		if selected.x != -1:
			for t in legal_targets:
				if t == pos:
					try_move.emit(selected, pos)
					_try_haptic(14)
					return
			var p: int = board[pos.y][pos.x]
			if p != 0:
				square_selected.emit(pos)
				_try_haptic(10)
			else:
				square_selected.emit(Vector2i(-1, -1))
		else:
			square_selected.emit(pos)
			if board[pos.y][pos.x] != 0:
				_try_haptic(10)
		accept_event()

	if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
		if _drag_from.x != -1:
			var mp: Vector2 = event.position
			if not _is_dragging and mp.distance_to(_touch_start_pos) > _drag_threshold:
				_is_dragging = true
			if _is_dragging:
				_drag_pos = mp
				queue_redraw()
				accept_event()

func _try_haptic(ms: int) -> void:
	if OS.has_feature("mobile") or DisplayServer.get_name() == "Android" or DisplayServer.get_name() == "iOS":
		# Godot 4.3+ 支持 Input.vibrate_handheld；旧版用 OS.vibrate
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(ms)
		else:
			# 容错
			pass

# ── 绘制 ─────────────────────────────────────────────────

func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	# 外框 — 胡桃木，圆角随 _cell 微调
	var r_outer: float = clamp(_cell * 0.38, 14, 22)
	_draw_rounded_rect(outer, r_outer, ApplePalette.BOARD_FRAME)
	_draw_rounded_rect_outline(outer.grow(-1), r_outer, ApplePalette.BOARD_FRAME_HIGHLIGHT, 1.0)
	draw_line(Vector2(_frame_thick, _frame_thick - 6), Vector2(size.x - _frame_thick, _frame_thick - 6), Color("#D4A574", 0.10), 1.0)
	# 羊皮纸
	var paper := Rect2(Vector2(_frame_thick, _frame_thick), size - Vector2(_frame_thick * 2, _frame_thick * 2))
	_draw_rounded_rect(paper, r_outer - 6, ApplePalette.BOARD_PAPER)
	# 纸纹
	var grain: Color = Color("#8C6A3A", 0.055)
	for gy in range(7):
		var yy: float = paper.position.y + paper.size.y * (0.14 + gy * 0.12)
		draw_line(Vector2(paper.position.x + 10, yy), Vector2(paper.position.x + paper.size.x - 10, yy + 0.6), grain, 1.0)
	draw_line(paper.position + Vector2(0, 1), paper.position + Vector2(paper.size.x, 1), Color("#000000", 0.06), 1.0)

	# 网格
	var river_top: float = _origin.y + 4 * _cell
	var river_bot: float = _origin.y + 5 * _cell
	var river_rect := Rect2(Vector2(_origin.x - 10, river_top), Vector2(8 * _cell + 20, river_bot - river_top))
	draw_rect(river_rect, ApplePalette.BOARD_RIVER_TINT)
	var line_col: Color = ApplePalette.BOARD_LINE
	var line_soft: Color = ApplePalette.BOARD_LINE_SOFT
	for y in range(10):
		var yy2: float = _origin.y + y * _cell
		draw_line(Vector2(_origin.x, yy2), Vector2(_origin.x + 8 * _cell, yy2), line_col, 1.2 if y == 0 or y == 9 else 1.0)
	for x in range(9):
		var xx: float = _origin.x + x * _cell
		if x == 0 or x == 8:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, _origin.y + 9 * _cell), line_col, 1.2)
		else:
			draw_line(Vector2(xx, _origin.y), Vector2(xx, river_top), line_soft, 1.0)
			draw_line(Vector2(xx, river_bot), Vector2(xx, _origin.y + 9 * _cell), line_soft, 1.0)
	var palace_col: Color = Color("#2B1E0F", 0.62)
	for seg in [[Vector2i(3, 0), Vector2i(5, 2)], [Vector2i(5, 0), Vector2i(3, 2)], [Vector2i(3, 7), Vector2i(5, 9)], [Vector2i(5, 7), Vector2i(3, 9)]]:
		var a: Vector2 = board_to_local(seg[0].x, seg[0].y)
		var b2: Vector2 = board_to_local(seg[1].x, seg[1].y)
		draw_line(a, b2, palace_col, 1.2)
	for p in [[0, 2], [2, 2], [6, 2], [8, 2], [0, 7], [2, 7], [6, 7], [8, 7], [1, 3], [7, 3]]:
		_draw_corner_marks(p[0], p[1])
	var font: Font = ThemeDB.fallback_font
	var river_fs: int = int(clamp(_cell * 0.28, 12, 16))
	draw_string(font, Vector2(_origin.x + 1.45 * _cell, (river_top + river_bot) / 2 + 5), "楚  河", HORIZONTAL_ALIGNMENT_LEFT, -1, river_fs, ApplePalette.BOARD_RIVER_INK)
	draw_string(font, Vector2(_origin.x + 5.35 * _cell, (river_top + river_bot) / 2 + 5), "汉  界", HORIZONTAL_ALIGNMENT_LEFT, -1, river_fs, ApplePalette.BOARD_RIVER_INK)
	draw_string(font, Vector2(_origin.x + 3.05 * _cell, (river_top + river_bot) / 2 + 4), "·", HORIZONTAL_ALIGNMENT_LEFT, -1, int(river_fs * 0.65), Color("#2B1E0F", 0.22))

	# 高亮：上一步（飞行中淡化）
	var last_alpha: float = 1.0 - _anim_progress * 0.5 if _anim_piece != 0 else 1.0
	if last_move_from.x != -1:
		_highlight_square(last_move_from, Color("#D4A574", 0.14 * last_alpha), 12)
	if last_move_to.x != -1 and not (_anim_piece != 0 and _anim_to == last_move_to):
		_highlight_square(last_move_to, Color("#D4A574", 0.20 * last_alpha), 12)
	# 选中
	if selected.x != -1 and not (_is_dragging and selected == _drag_from):
		_highlight_square(selected, Color("#2EC4B6", 0.08), 12)
		_draw_square_ring(selected, ApplePalette.GOLD, 2.0, 12)
		_draw_square_ring(selected, Color("#D4A574", 0.18), 6.0, 12)
	# 合法目标
	for t in legal_targets:
		# 拖拽中目标脉动
		var c: Vector2 = board_to_local(t.x, t.y)
		var is_capture: bool = board[t.y][t.x] != 0
		if is_capture:
			draw_arc(c, 20, 0, TAU, 32, Color("#E8583A", 0.90), 2.4)
			draw_arc(c, 17, 0, TAU, 32, Color("#D4A574", 0.42), 1.0)
			draw_circle(c, 5, Color("#E8583A", 0.16))
		else:
			draw_circle(c, 9, Color("#2EC4B6", 0.13))
			draw_circle(c, 7, Color("#2EC4B6", 0.92))
			draw_circle(c, 3.4, Color.WHITE)
			draw_arc(c, 7, 0, TAU, 24, Color("#D4A574", 0.32), 1.0)

	if board.is_empty():
		return

	# 棋子：静止棋（动画期间隐藏源与目标）
	for y in range(10):
		for x in range(9):
			var p: int = board[y][x]
			if p == 0:
				continue
			var cur: Vector2i = Vector2i(x, y)
			if _anim_piece != 0:
				if cur == _anim_from:
					continue
				if cur == _anim_to:
					continue
			# 拖拽中的选中棋隐藏（由拖拽层绘制）
			if _is_dragging and cur == _drag_from:
				continue
			_draw_piece(board_to_local(x, y), p, font, 1.0, 1.0, 0.0)

	# 被吃子消散（在目标点）
	if _anim_is_capture and _anim_captured != 0 and _anim_progress > 0.0:
		var cap_pos: Vector2 = board_to_local(_anim_to.x, _anim_to.y)
		# 轻微上浮消散
		var lift: float = -6 * ease(_anim_progress, 0.45)
		_draw_piece(cap_pos + Vector2(0, lift), _anim_captured, font, _anim_capture_alpha, _anim_capture_scale, 0.0)

	# 飞行棋 — 抛物线抬起 + 阴影呼吸 + 轻微缩放
	if _anim_piece != 0 and _anim_from.x != -1 and _anim_to.x != -1 and _anim_progress > 0.0:
		var t: float = _anim_progress
		var fly: Vector2 = _anim_pos_from.lerp(_anim_pos_to, t)
		# 抛物线 lift：sin(π*t) * 高度，高度随距离
		var dist2: float = _anim_pos_from.distance_to(_anim_pos_to)
		var lift_h: float = clamp(dist2 * 0.12, 10, 26)
		fly.y -= sin(t * PI) * lift_h
		var scale: float = 1.0 + sin(t * PI) * 0.08
		var shadow_alpha: float = lerp(0.26, 0.10, sin(t * PI))
		var lift_for_shadow: float = sin(t * PI) * lift_h
		# 阴影在地面，跟随但不抬起
		var ground: Vector2 = _anim_pos_from.lerp(_anim_pos_to, t)
		_draw_piece_shadow(ground + Vector2(0, 3 + lift_for_shadow * 0.18), shadow_alpha)
		_draw_piece(fly, _anim_piece, font, 1.0, scale, lift_for_shadow)

	# 拖拽棋 — 跟手
	if _is_dragging and _drag_from.x != -1:
		var drag_piece: int = board[_drag_from.y][_drag_from.x] if board[_drag_from.y][_drag_from.x] != 0 else 0
		if drag_piece == 0 and _anim_piece != 0 and _drag_from == _anim_from:
			drag_piece = _anim_piece
		if drag_piece != 0:
			_draw_piece_shadow(_drag_pos + Vector2(0, 8), 0.18)
			_draw_piece(_drag_pos + Vector2(0, -14), drag_piece, font, 1.0, 1.06, 14)

func _draw_piece_shadow(center: Vector2, alpha: float) -> void:
	draw_circle(center, 22, Color("#000000", alpha * 0.55))
	draw_circle(center + Vector2(2, 1), 14, Color("#000000", alpha * 0.22))

func _draw_corner_marks(bx: int, by: int) -> void:
	var c: Vector2 = board_to_local(bx, by)
	var s: float = clamp(_cell * 0.12, 6, 8)
	var gap: float = clamp(_cell * 0.06, 3, 4.2)
	var col: Color = Color("#2B1E0F", 0.36)
	var dirs: Array = [[-1, -1], [1, -1], [-1, 1], [1, 1]]
	for d in dirs:
		var dx: int = d[0]; var dy: int = d[1]
		var px: float = c.x + dx * gap
		var py: float = c.y + dy * gap
		draw_line(Vector2(px, py), Vector2(px + dx * s, py), col, 1.0)
		draw_line(Vector2(px, py), Vector2(px, py + dy * s), col, 1.0)

func _draw_piece(center: Vector2, p: int, font: Font, alpha: float = 1.0, scale: float = 1.0, lift: float = 0.0) -> void:
	var is_red: bool = p > 0
	var r: float = 22 * scale
	var r_in: float = 18.8 * scale
	# 已在外层绘制阴影的飞行/拖拽情况，常规棋子仍需阴影
	if lift == 0.0 and scale == 1.0:
		draw_circle(center + Vector2(0, 3), r, Color("#000000", 0.24 * alpha))
		draw_circle(center + Vector2(0, 1.2), r, Color("#000000", 0.10 * alpha))
	var ring_col: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	var ring_highlight: Color = Color("#E7A87A") if is_red else Color("#4A5A73")
	ring_col.a *= alpha
	ring_highlight.a *= alpha
	draw_circle(center, r, ring_col)
	draw_arc(center + Vector2(-0.6 * scale, -0.8 * scale), r - 1 * scale, 1.15 * PI, 1.85 * PI, 20, ring_highlight, 1.2 * scale)
	var inlay: Color = ApplePalette.PIECE_RED_INLAY if is_red else ApplePalette.PIECE_BLACK_INLAY
	inlay.a *= alpha
	draw_circle(center, r_in, inlay)
	var gold: Color = ApplePalette.PIECE_GOLD_RING
	gold.a *= alpha
	draw_arc(center, r_in, 0, TAU, 32, gold, 1.0 * scale)
	draw_arc(center, 15.6 * scale, 0, TAU, 32, Color("#000000", 0.05 * alpha), 1.0 * scale)
	draw_circle(center + Vector2(-5 * scale, -6 * scale), 5 * scale, Color("#FFFFFF", 0.09 * alpha))
	var label: String = _piece_label(p)
	var fs: int = int(20 * scale)
	if fs < 12:
		fs = 12
	var disc: Color = ApplePalette.PIECE_RED if is_red else ApplePalette.PIECE_BLACK
	disc.a *= alpha
	var ts: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	var base: Vector2 = center - Vector2(ts.x / 2, -ts.y / 3.0)
	draw_string(font, base + Vector2(0, 1 * scale), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color("#000000", 0.16 * alpha))
	draw_string(font, base, label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, disc)

func _highlight_square(pos: Vector2i, col: Color, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var rect := Rect2(c - Vector2(23, 23) * (_cell / 56.0), Vector2(46, 46) * (_cell / 56.0))
	_draw_rounded_rect(rect, r * (_cell / 56.0), col)

func _draw_square_ring(pos: Vector2i, col: Color, w: float, r: float) -> void:
	var c: Vector2 = board_to_local(pos.x, pos.y)
	var s: float = _cell / 56.0
	var rect := Rect2(c - Vector2(23, 23) * s, Vector2(46, 46) * s)
	_draw_rounded_rect_outline(rect, r * s, col, w * s)

func _draw_rounded_rect(rect: Rect2, radius: float, col: Color) -> void:
	draw_rect(rect, col)
	for corner in [rect.position, Vector2(rect.position.x + rect.size.x - radius * 2, rect.position.y), Vector2(rect.position.x, rect.position.y + rect.size.y - radius * 2), rect.position + rect.size - Vector2(radius * 2, radius * 2)]:
		draw_circle(corner + Vector2(radius, radius), radius, col)

func _draw_rounded_rect_outline(rect: Rect2, radius: float, col: Color, w: float) -> void:
	var r: float = radius
	draw_line(rect.position + Vector2(r, 0), rect.position + Vector2(rect.size.x - r, 0), col, w)
	draw_line(rect.position + Vector2(rect.size.x, r), rect.position + Vector2(rect.size.x, rect.size.y - r), col, w)
	draw_line(rect.position + Vector2(rect.size.x - r, rect.size.y), rect.position + Vector2(r, rect.size.y), col, w)
	draw_line(rect.position + Vector2(0, rect.size.y - r), rect.position + Vector2(0, r), col, w)
	draw_arc(rect.position + Vector2(r, r), r, PI, 1.5 * PI, 16, col, w)
	draw_arc(rect.position + Vector2(rect.size.x - r, r), r, 1.5 * PI, TAU, 16, col, w)
	draw_arc(rect.position + Vector2(rect.size.x - r, rect.size.y - r), r, 0, 0.5 * PI, 16, col, w)
	draw_arc(rect.position + Vector2(r, rect.size.y - r), r, 0.5 * PI, PI, 16, col, w)

func _piece_label(p: int) -> String:
	var t: int = XiangqiLogic.piece_type(p)
	if p > 0:
		match t:
			XiangqiLogic.KING: return "帅"
			XiangqiLogic.ADVISOR: return "仕"
			XiangqiLogic.ELEPHANT: return "相"
			XiangqiLogic.HORSE: return "马"
			XiangqiLogic.CHARIOT: return "车"
			XiangqiLogic.CANNON: return "炮"
			XiangqiLogic.PAWN: return "兵"
			_: return "?"
	else:
		match t:
			XiangqiLogic.KING: return "将"
			XiangqiLogic.ADVISOR: return "士"
			XiangqiLogic.ELEPHANT: return "象"
			XiangqiLogic.HORSE: return "馬"
			XiangqiLogic.CHARIOT: return "車"
			XiangqiLogic.CANNON: return "砲"
			XiangqiLogic.PAWN: return "卒"
			_: return "?"
